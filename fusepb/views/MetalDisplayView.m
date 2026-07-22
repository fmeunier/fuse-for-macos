/* MetalDisplayView.m: Inert Metal display presenter
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "MetalDisplayView.h"

/* RGB565 test pattern, arranged left-to-right, top-to-bottom. */
static const uint16_t test_pattern_pixels[] = {
  0x0000, 0xffff, 0xf800, 0x07e0,
  0x001f, 0x07ff, 0xf81f, 0xffe0,
};

#define TEST_PATTERN_WIDTH 4
#define TEST_PATTERN_HEIGHT 2

@implementation MetalDisplayView

-(id) initWithFrame:(NSRect)frameRect
{
  id <MTLDevice> metal_device;
  id <MTLLibrary> library;
  id <MTLFunction> vertex_function;
  id <MTLFunction> fragment_function;
  MTLRenderPipelineDescriptor *pipeline_descriptor;
  MTLSamplerDescriptor *sampler_descriptor;
  MTLTextureDescriptor *texture_descriptor;
  MTLRegion texture_region;
  NSError *error;

  metal_device = MTLCreateSystemDefaultDevice();
  if( !metal_device ) {
    [self release];
    return nil;
  }

  self = [super initWithFrame:frameRect device:metal_device];
  [metal_device release];
  if( !self ) return nil;

  [self setDelegate:self];
  [self setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
  [self setClearColor:MTLClearColorMake( 0.0, 0.0, 0.0, 1.0 )];
  [self setPaused:YES];
  [self setEnableSetNeedsDisplay:YES];

  command_queue = [[self device] newCommandQueue];
  library = [[self device] newDefaultLibrary];
  vertex_function = [library newFunctionWithName:@"display_vertex"];
  fragment_function = [library newFunctionWithName:@"display_fragment"];

  pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
  [pipeline_descriptor setVertexFunction:vertex_function];
  [pipeline_descriptor setFragmentFunction:fragment_function];
  [[pipeline_descriptor colorAttachments]
    objectAtIndexedSubscript:0].pixelFormat = [self colorPixelFormat];
  pipeline_state = [[self device]
    newRenderPipelineStateWithDescriptor:pipeline_descriptor error:&error];
  if( !pipeline_state )
    NSLog( @"Unable to create Metal display pipeline: %@", error );

  sampler_descriptor = [[MTLSamplerDescriptor alloc] init];
  [sampler_descriptor setMinFilter:MTLSamplerMinMagFilterNearest];
  [sampler_descriptor setMagFilter:MTLSamplerMinMagFilterNearest];
  nearest_sampler = [[self device]
    newSamplerStateWithDescriptor:sampler_descriptor];
  [sampler_descriptor setMinFilter:MTLSamplerMinMagFilterLinear];
  [sampler_descriptor setMagFilter:MTLSamplerMinMagFilterLinear];
  linear_sampler = [[self device]
    newSamplerStateWithDescriptor:sampler_descriptor];
  [sampler_descriptor release];

  texture_descriptor = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatB5G6R5Unorm
    width:TEST_PATTERN_WIDTH height:TEST_PATTERN_HEIGHT mipmapped:NO];
  [texture_descriptor setUsage:MTLTextureUsageShaderRead];
  test_pattern_texture = [[self device]
    newTextureWithDescriptor:texture_descriptor];
  texture_region = MTLRegionMake2D( 0, 0,
                                    TEST_PATTERN_WIDTH, TEST_PATTERN_HEIGHT );
  [test_pattern_texture replaceRegion:texture_region mipmapLevel:0
                            withBytes:test_pattern_pixels
                          bytesPerRow:TEST_PATTERN_WIDTH * sizeof( uint16_t )];

  [pipeline_descriptor release];
  [vertex_function release];
  [fragment_function release];
  [library release];

  return self;
}

-(void) dealloc
{
  [test_pattern_texture release];
  [linear_sampler release];
  [nearest_sampler release];
  [pipeline_state release];
  [command_queue release];

  [super dealloc];
}

-(void) drawInMTKView:(MTKView *)view
{
  id <CAMetalDrawable> drawable;
  MTLRenderPassDescriptor *render_pass_descriptor;
  id <MTLCommandBuffer> command_buffer;
  id <MTLRenderCommandEncoder> command_encoder;
  CGSize drawable_size;
  MTLViewport viewport;
  double pattern_aspect_ratio;
  double drawable_aspect_ratio;

  drawable = [view currentDrawable];
  render_pass_descriptor = [view currentRenderPassDescriptor];
  if( !drawable || !render_pass_descriptor || !command_queue ) return;

  command_buffer = [command_queue commandBuffer];
  command_encoder = [command_buffer
    renderCommandEncoderWithDescriptor:render_pass_descriptor];
  if( command_encoder && pipeline_state && test_pattern_texture ) {
    drawable_size = [view drawableSize];
    pattern_aspect_ratio = (double)TEST_PATTERN_WIDTH / TEST_PATTERN_HEIGHT;
    drawable_aspect_ratio = drawable_size.width / drawable_size.height;
    viewport.znear = 0.0;
    viewport.zfar = 1.0;

    if( drawable_aspect_ratio > pattern_aspect_ratio ) {
      viewport.width = drawable_size.height * pattern_aspect_ratio;
      viewport.height = drawable_size.height;
      viewport.originX = ( drawable_size.width - viewport.width ) / 2.0;
      viewport.originY = 0.0;
    } else {
      viewport.width = drawable_size.width;
      viewport.height = drawable_size.width / pattern_aspect_ratio;
      viewport.originX = 0.0;
      viewport.originY = ( drawable_size.height - viewport.height ) / 2.0;
    }

    [command_encoder setViewport:viewport];
    [command_encoder setRenderPipelineState:pipeline_state];
    [command_encoder setFragmentTexture:test_pattern_texture atIndex:0];
    [command_encoder setFragmentSamplerState:bilinear_filtering_enabled ? linear_sampler
                                                             : nearest_sampler
                                      atIndex:0];
    [command_encoder drawPrimitives:MTLPrimitiveTypeTriangle
                        vertexStart:0 vertexCount:6];
    [command_encoder endEncoding];
  } else if( command_encoder ) {
    [command_encoder endEncoding];
  }
  [command_buffer presentDrawable:drawable];
  [command_buffer commit];
}

-(void) mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

-(void) start
{
  [self setNeedsDisplay:YES];
}

-(void) shutdown
{
  [self setPaused:YES];
}

-(void) applyFramebuffer:(DisplayFramebuffer *)framebuffer
{
}

-(void) removeFramebuffer
{
}

-(void) applyOverlayState:(const DisplayOverlayState *)state
{
}

-(void) setBilinearFilteringEnabled:(BOOL)enabled
{
  bilinear_filtering_enabled = enabled;
}

-(void) zoom:(id)sender
{
}

-(void) performFullscreen
{
  /* Fullscreen ownership belongs to DisplayHostView. */
}

-(void) windowWillMiniaturize:(NSNotification *)notification
{
  [self setPaused:YES];
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
}

-(void) windowDidDeminiaturize:(NSNotification *)notification
{
  [self setPaused:YES];
  [self setNeedsDisplay:YES];
}

-(void) windowDidChangeScreen:(NSNotification *)notification
{
  [self setNeedsDisplay:YES];
}

@end
