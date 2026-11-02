/* FuseDisplayPixelConversionTests.m: Tests for fallback framebuffer upload
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

#include <math.h>
#include <simd/simd.h>
#include <stdlib.h>
#include <string.h>

#include "../views/DisplayPixelConversion.h"

@interface FuseDisplayPixelConversionTests : XCTestCase
@end

@implementation FuseDisplayPixelConversionTests

-(void) test_all_rgb565_values_expand_to_normalized_opaque_bgra
{
  uint16_t source[256];
  uint8_t dest[256 * 4];
  unsigned int row, x;

  for( row = 0; row < 256; row++ ) {
    for( x = 0; x < 256; x++ ) source[x] = row * 256 + x;
    display_rgb565_to_bgra8888( dest, sizeof( dest ), source, sizeof( source ),
                              256, 1 );
    for( x = 0; x < 256; x++ ) {
      unsigned int pixel = source[x];

      XCTAssertEqual( dest[4 * x], lround( ( pixel & 31 ) * 255.0 / 31.0 ) );
      XCTAssertEqual( dest[4 * x + 1], lround( ( ( pixel >> 5 ) & 63 ) * 255.0 / 63.0 ) );
      XCTAssertEqual( dest[4 * x + 2], lround( ( pixel >> 11 ) * 255.0 / 31.0 ) );
      XCTAssertEqual( dest[4 * x + 3], 255 );
    }
  }
}

-(void) test_conversion_respects_source_and_destination_row_padding
{
  const uint16_t source[2][4] = {
    { 0xf800, 0x07e0, 0x001f, 0xdead },
    { 0x0000, 0xffff, 0x8410, 0xbeef }
  };
  uint8_t dest[2][16];
  const uint8_t expected[2][12] = {
    { 0, 0, 255, 255, 0, 255, 0, 255, 255, 0, 0, 255 },
    { 0, 0, 0, 255, 255, 255, 255, 255, 132, 130, 132, 255 }
  };
  unsigned int y, x;

  memset( dest, 0xa5, sizeof( dest ) );
  display_rgb565_to_bgra8888( dest, sizeof( dest[0] ), source,
                            sizeof( source[0] ), 3, 2 );
  for( y = 0; y < 2; y++ ) {
    for( x = 0; x < 12; x++ ) XCTAssertEqual( dest[y][x], expected[y][x] );
    for( x = 12; x < 16; x++ ) XCTAssertEqual( dest[y][x], 0xa5 );
  }
}

-(void) test_reconversion_updates_previously_used_staging_memory
{
  uint16_t source = 0xf800;
  uint8_t dest[4];

  display_rgb565_to_bgra8888( dest, 4, &source, 2, 1, 1 );
  XCTAssertEqual( dest[2], 255 );
  source = 0x001f;
  display_rgb565_to_bgra8888( dest, 4, &source, 2, 1, 1 );
  XCTAssertEqual( dest[0], 255 );
  XCTAssertEqual( dest[1], 0 );
  XCTAssertEqual( dest[2], 0 );
  XCTAssertEqual( dest[3], 255 );
}

-(void) checkFallbackTextureWithLinearFiltering:(BOOL)linear
{
  id <MTLDevice> device = MTLCreateSystemDefaultDevice();
  id <MTLLibrary> library;
  id <MTLRenderPipelineState> pipeline;
  id <MTLTexture> input, output;
  id <MTLBuffer> readback;
  id <MTLCommandQueue> queue;
  id <MTLCommandBuffer> command;
  id <MTLRenderCommandEncoder> encoder;
  id <MTLBlitCommandEncoder> blit;
  id <MTLSamplerState> sampler;
  MTLTextureDescriptor *texture_descriptor;
  MTLRenderPipelineDescriptor *pipeline_descriptor;
  MTLRenderPassDescriptor *pass;
  MTLSamplerDescriptor *sampler_descriptor;
  NSString *shader_path, *shader_source;
  NSError *error = nil;
  NSUInteger width = linear ? 3 : 2;
  const uint16_t pixels[2] = { 0xf800, 0x001f };
  uint8_t converted[16];
  const uint8_t *result;
  const uint8_t expected_nearest[8] = { 0, 0, 255, 255, 255, 0, 0, 255 };
  const uint8_t expected_linear[12] = { 0, 0, 255, 255, 128, 0, 128, 255, 255, 0, 0, 255 };
  const uint8_t *expected = linear ? expected_linear : expected_nearest;
  NSUInteger i;
  struct {
    vector_float4 position;
    vector_float4 texture_coordinates;
  } vertices = { { -1, 1, 1, -1 }, { 0, 0, 1, 1 } };

  XCTAssertNotNil( device );
  if( !device ) return;
  shader_path = [[@(__FILE__) stringByDeletingLastPathComponent]
                 stringByAppendingPathComponent:@"../views/DisplayShaders.metal"];
  shader_source = [NSString stringWithContentsOfFile:shader_path
                            encoding:NSUTF8StringEncoding error:&error];
  XCTAssertNotNil( shader_source, @"%@", error );
  if( !shader_source ) {
    [device release];
    return;
  }
  library = [device newLibraryWithSource:shader_source options:nil error:&error];
  XCTAssertNotNil( library, @"%@", error );
  if( !library ) {
    [device release];
    return;
  }
  pipeline_descriptor = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
  pipeline_descriptor.vertexFunction = [[library newFunctionWithName:@"display_vertex"] autorelease];
  pipeline_descriptor.fragmentFunction = [[library newFunctionWithName:@"display_fragment"] autorelease];
  pipeline_descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  pipeline = [device newRenderPipelineStateWithDescriptor:pipeline_descriptor error:&error];
  XCTAssertNotNil( pipeline, @"%@", error );
  if( !pipeline ) {
    [library release];
    [device release];
    return;
  }

  /* Exercise the same ordinary texture, default storage and padded upload as
     the fallback. No unsupported RGB565 Metal format is queried or allocated. */
  texture_descriptor = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
    width:2 height:1 mipmapped:NO];
  texture_descriptor.usage = MTLTextureUsageShaderRead;
  input = [device newTextureWithDescriptor:texture_descriptor];
  display_rgb565_to_bgra8888( converted, sizeof( converted ), pixels,
                            sizeof( pixels ), 2, 1 );
  [input replaceRegion:MTLRegionMake2D( 0, 0, 2, 1 ) mipmapLevel:0
              withBytes:converted bytesPerRow:sizeof( converted )];
  texture_descriptor = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
    width:width height:1 mipmapped:NO];
  texture_descriptor.storageMode = MTLStorageModePrivate;
  texture_descriptor.usage = MTLTextureUsageRenderTarget;
  output = [device newTextureWithDescriptor:texture_descriptor];
  readback = [device newBufferWithLength:256 options:MTLResourceStorageModeShared];
  queue = [device newCommandQueue];
  sampler_descriptor = [[[MTLSamplerDescriptor alloc] init] autorelease];
  sampler_descriptor.minFilter = sampler_descriptor.magFilter =
    linear ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
  sampler_descriptor.sAddressMode = sampler_descriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
  sampler = [device newSamplerStateWithDescriptor:sampler_descriptor];
  XCTAssertNotNil( input );
  XCTAssertNotNil( output );
  XCTAssertNotNil( readback );
  XCTAssertNotNil( queue );
  XCTAssertNotNil( sampler );
  if( input && output && readback && queue && sampler ) {
    pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = output;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    command = [queue commandBuffer];
    encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setVertexBytes:&vertices length:sizeof( vertices ) atIndex:0];
    [encoder setFragmentTexture:input atIndex:0];
    [encoder setFragmentSamplerState:sampler atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [encoder endEncoding];
    blit = [command blitCommandEncoder];
    [blit copyFromTexture:output sourceSlice:0 sourceLevel:0
            sourceOrigin:MTLOriginMake( 0, 0, 0 ) sourceSize:MTLSizeMake( width, 1, 1 )
                toBuffer:readback destinationOffset:0 destinationBytesPerRow:256
                destinationBytesPerImage:256];
    [blit endEncoding];
    [command commit];
    [command waitUntilCompleted];
    XCTAssertNil( [command error] );
    result = [readback contents];
    for( i = 0; i < width * 4; i++ )
      XCTAssertLessThanOrEqual( abs( (int)result[i] - expected[i] ), linear ? 1 : 0 );
  }
  [sampler release];
  [queue release];
  [readback release];
  [output release];
  [input release];
  [pipeline release];
  [library release];
  [device release];
}

-(void) test_fallback_texture_with_nearest_filtering
{
  [self checkFallbackTextureWithLinearFiltering:NO];
}

-(void) test_fallback_texture_with_bilinear_filtering
{
  [self checkFallbackTextureWithLinearFiltering:YES];
}

@end
