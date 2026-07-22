/* MetalDisplayView.m: Metal implementation of the display presenter
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "MetalDisplayView.h"
#import "FuseController.h"

#include <math.h>

#include "display.h"
#include "input.h"
#include "settings.h"

#define QZ_0 0x1D
#define QZ_1 0x12
#define QZ_2 0x13
#define QZ_3 0x14
#define QZ_4 0x15
#define QZ_5 0x16
#define QZ_m 0x2E

#define CASSETTE_X 285
#define CASSETTE_Y 220
#define MICRODRIVE_X 264
#define MICRODRIVE_Y 218
#define DISK_X 243
#define DISK_Y 218

typedef struct {
  vector_float4 position;
  vector_float4 texture_coordinates;
} DisplayVertices;

static int
get_offset( int window_width, int window_height, int image_width,
            int image_height, float *width_adjustment )
{
  static const float full_image_ratio = 4.0f / 3.0f;
  static const float top_border_haircut = 24.0f;
  static const float minimal_height = 240.0f - top_border_haircut * 2.0f;
  static const float minimal_top_bottom_ratio = 320.0f / minimal_height;
  static const float side_border_haircut = 31.0f;
  static const float minimal_width = 320.0f - side_border_haircut * 2.0f;
  static const float minimal_left_right_ratio = minimal_width / 240.0f;
  float ratio = window_width / (float)window_height;

  *width_adjustment = 0.0f;
  if( fabsf( ratio - full_image_ratio ) < 0.01f ) return 0;

  if( !settings_current.full_screen_panorama ) {
    if( ratio > full_image_ratio ) {
      float height_scale = window_height / (float)image_height;
      float height_ratio = window_height * full_image_ratio;

      *width_adjustment = ( window_width - height_ratio ) /
                          ( 2.0f * height_scale );
      return 0;
    }

    return ( window_width / full_image_ratio - window_height ) /
           ( 2.0f * ( window_width / (float)image_width ) );
  }

  if( ratio > minimal_top_bottom_ratio ) {
    float height_scale = window_height / minimal_height;
    float height_ratio = window_height * minimal_top_bottom_ratio;

    *width_adjustment = ( window_width - height_ratio ) /
                        ( 2.0f * height_scale );
    return top_border_haircut;
  } else if( ratio > full_image_ratio ) {
    float width_scale = window_width / (float)image_width;
    float height_pixels = window_width / full_image_ratio;

    return ( height_pixels - window_height ) / ( 2.0f * width_scale );
  } else if( ratio < minimal_left_right_ratio ) {
    float width_scale = window_width / minimal_width;
    float width_ratio = window_width / minimal_left_right_ratio;

    *width_adjustment = -side_border_haircut;
    return ( width_ratio - window_height ) / ( 2.0f * width_scale );
  } else {
    float height_scale = window_height / (float)image_height;
    float width_pixels = window_height * full_image_ratio;

    *width_adjustment = ( window_width - width_pixels ) /
                        ( 2.0f * height_scale );
    return 0;
  }
}

@implementation MetalDisplayView

-(id <MTLTexture>) loadTexture:(NSString *)name
{
  NSURL *url;
  MTKTextureLoader *loader;
  NSError *error;
  id <MTLTexture> texture;

  url = [[NSBundle mainBundle] URLForResource:name withExtension:@"png"];
  if( !url ) return nil;

  loader = [[MTKTextureLoader alloc] initWithDevice:[self device]];
  texture = [loader newTextureWithContentsOfURL:url options:nil error:&error];
  [loader release];
  if( !texture ) NSLog( @"Unable to load display icon %@: %@", name, error );

  return texture;
}

-(id) initWithFrame:(NSRect)frameRect
{
  id <MTLDevice> metal_device;
  id <MTLLibrary> library;
  id <MTLFunction> vertex_function;
  id <MTLFunction> fragment_function;
  MTLRenderPipelineDescriptor *pipeline_descriptor;
  MTLSamplerDescriptor *sampler_descriptor;
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
  [self setEnableSetNeedsDisplay:NO];

  command_queue = [[self device] newCommandQueue];
  library = [[self device] newDefaultLibrary];
  vertex_function = [library newFunctionWithName:@"display_vertex"];
  fragment_function = [library newFunctionWithName:@"display_fragment"];

  pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
  [pipeline_descriptor setVertexFunction:vertex_function];
  [pipeline_descriptor setFragmentFunction:fragment_function];
  [[pipeline_descriptor colorAttachments]
    objectAtIndexedSubscript:0].pixelFormat = [self colorPixelFormat];
  [[pipeline_descriptor colorAttachments] objectAtIndexedSubscript:0].blendingEnabled = YES;
  [[pipeline_descriptor colorAttachments] objectAtIndexedSubscript:0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
  [[pipeline_descriptor colorAttachments] objectAtIndexedSubscript:0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  [[pipeline_descriptor colorAttachments] objectAtIndexedSubscript:0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
  [[pipeline_descriptor colorAttachments] objectAtIndexedSubscript:0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  pipeline_state = [[self device]
    newRenderPipelineStateWithDescriptor:pipeline_descriptor error:&error];
  if( !pipeline_state )
    NSLog( @"Unable to create Metal display pipeline: %@", error );

  sampler_descriptor = [[MTLSamplerDescriptor alloc] init];
  [sampler_descriptor setMinFilter:MTLSamplerMinMagFilterNearest];
  [sampler_descriptor setMagFilter:MTLSamplerMinMagFilterNearest];
  [sampler_descriptor setSAddressMode:MTLSamplerAddressModeClampToEdge];
  [sampler_descriptor setTAddressMode:MTLSamplerAddressModeClampToEdge];
  nearest_sampler = [[self device]
    newSamplerStateWithDescriptor:sampler_descriptor];
  [sampler_descriptor setMinFilter:MTLSamplerMinMagFilterLinear];
  [sampler_descriptor setMagFilter:MTLSamplerMinMagFilterLinear];
  linear_sampler = [[self device]
    newSamplerStateWithDescriptor:sampler_descriptor];
  [sampler_descriptor release];

  green_cassette = [self loadTexture:@"cassette_green"];
  red_cassette = [self loadTexture:@"cassette_red"];
  green_mdr = [self loadTexture:@"microdrive_green"];
  red_mdr = [self loadTexture:@"microdrive_red"];
  green_disk = [self loadTexture:@"plus3disk_green"];
  red_disk = [self loadTexture:@"plus3disk_red"];

  [pipeline_descriptor release];
  [vertex_function release];
  [fragment_function release];
  [library release];

  return self;
}

-(void) dealloc
{
  [screen_texture release];
  [green_disk release];
  [red_disk release];
  [green_mdr release];
  [red_mdr release];
  [green_cassette release];
  [red_cassette release];
  [linear_sampler release];
  [nearest_sampler release];
  [pipeline_state release];
  [command_queue release];

  if( buffered_screen.synchronization )
    [(NSLock *)buffered_screen.synchronization release];
  buffered_screen.synchronization = nil;

  [super dealloc];
}

-(void) uploadDirtyRegions
{
  PIG_dirtytable *dirty_regions;
  int i;

  if( !framebuffer || !screen_texture || !buffered_screen.synchronization ) return;
  if( ![(NSLock *)buffered_screen.synchronization tryLock] ) return;

  dirty_regions = framebuffer->dirty_regions;
  for( i = 0; dirty_regions && i < dirty_regions->count; i++ ) {
    PIG_rect region = dirty_regions->rects[i];
    int x = MAX( 0, region.x );
    int y = MAX( 0, region.y );
    int width = MIN( region.w - ( x - region.x ), framebuffer->width - x );
    int height = MIN( region.h - ( y - region.y ), framebuffer->height - y );

    if( width > 0 && height > 0 ) {
      MTLRegion texture_region = MTLRegionMake2D( x + framebuffer->x_offset,
                                                   y + framebuffer->y_offset,
                                                   width, height );
      const void *source = (const uint8_t *)framebuffer->backing_storage +
                           ( y + framebuffer->y_offset ) * framebuffer->stride +
                           ( x + framebuffer->x_offset ) * sizeof( uint16_t );
      [screen_texture replaceRegion:texture_region mipmapLevel:0
                           withBytes:source bytesPerRow:framebuffer->stride];
    }
  }
  if( dirty_regions ) dirty_regions->count = 0;
  [(NSLock *)buffered_screen.synchronization unlock];
}

-(void) drawTexture:(id <MTLTexture>)texture
           xOrigin:(int)x yOrigin:(int)y
            encoder:(id <MTLRenderCommandEncoder>)encoder
{
  DisplayVertices vertices;
  float x1, x2, y1, y2;

  if( !texture || !framebuffer ) return;

  x1 = x * 2.0f / DISPLAY_ASPECT_WIDTH - 1.0f;
  x2 = ( x + texture.width ) * 2.0f / DISPLAY_ASPECT_WIDTH - 1.0f;
  y1 = 1.0f - y * 2.0f / DISPLAY_SCREEN_HEIGHT;
  y2 = 1.0f - ( y + texture.height ) * 2.0f / DISPLAY_SCREEN_HEIGHT;
  vertices.position = (vector_float4){ x1, y1, x2, y2 };
  vertices.texture_coordinates = (vector_float4){ 0.0f, 0.0f, 1.0f, 1.0f };
  [encoder setVertexBytes:&vertices length:sizeof( vertices ) atIndex:0];
  [encoder setFragmentTexture:texture atIndex:0];
  [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

-(void) drawOverlays:(id <MTLRenderCommandEncoder>)encoder
{
  if( !settings_current.statusbar ) return;

  switch( overlay_state.disk_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self drawTexture:green_disk xOrigin:DISK_X yOrigin:DISK_Y encoder:encoder];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
    [self drawTexture:red_disk xOrigin:DISK_X yOrigin:DISK_Y encoder:encoder];
    break;
  default:
    break;
  }
  switch( overlay_state.microdrive_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self drawTexture:green_mdr xOrigin:MICRODRIVE_X yOrigin:MICRODRIVE_Y encoder:encoder];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
    [self drawTexture:red_mdr xOrigin:MICRODRIVE_X yOrigin:MICRODRIVE_Y encoder:encoder];
    break;
  default:
    break;
  }
  switch( overlay_state.tape_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self drawTexture:green_cassette xOrigin:CASSETTE_X yOrigin:CASSETTE_Y encoder:encoder];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
  case DISPLAY_OVERLAY_STATE_NOT_AVAILABLE:
    [self drawTexture:red_cassette xOrigin:CASSETTE_X yOrigin:CASSETTE_Y encoder:encoder];
    break;
  }
}

-(void) drawInMTKView:(MTKView *)view
{
  id <CAMetalDrawable> drawable;
  MTLRenderPassDescriptor *render_pass_descriptor;
  id <MTLCommandBuffer> command_buffer;
  id <MTLRenderCommandEncoder> command_encoder;
  DisplayVertices vertices;
  float x_offset = 0.0f;
  float y_offset = 0.0f;

  [self uploadDirtyRegions];
  drawable = [view currentDrawable];
  render_pass_descriptor = [view currentRenderPassDescriptor];
  if( !drawable || !render_pass_descriptor || !command_queue ) return;

  command_buffer = [command_queue commandBuffer];
  command_encoder = [command_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];
  if( command_encoder && pipeline_state && screen_texture && framebuffer ) {
    if( settings_current.full_screen ) {
      x_offset = get_offset( view.drawableSize.width, view.drawableSize.height,
                             framebuffer->width, framebuffer->height, &y_offset );
    }
    vertices.position = (vector_float4){ -1.0f, 1.0f, 1.0f, -1.0f };
    vertices.texture_coordinates = (vector_float4){
      ( framebuffer->x_offset - y_offset ) / framebuffer->storage_width,
      ( framebuffer->y_offset + x_offset ) / framebuffer->storage_height,
      ( framebuffer->x_offset + framebuffer->width + y_offset ) /
        framebuffer->storage_width,
      ( framebuffer->y_offset + framebuffer->height - x_offset ) /
        framebuffer->storage_height
    };
    [command_encoder setRenderPipelineState:pipeline_state];
    [command_encoder setVertexBytes:&vertices length:sizeof( vertices ) atIndex:0];
    [command_encoder setFragmentTexture:screen_texture atIndex:0];
    [command_encoder setFragmentSamplerState:bilinear_filtering_enabled ? linear_sampler : nearest_sampler
                                     atIndex:0];
    [command_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [self drawOverlays:command_encoder];
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
  if( !buffered_screen.synchronization )
    buffered_screen.synchronization = (void *)[[NSLock alloc] init];
  [self setPaused:NO];
}

-(void) shutdown
{
  [self setPaused:YES];
}

-(void) applyFramebuffer:(DisplayFramebuffer *)new_framebuffer
{
  MTLTextureDescriptor *texture_descriptor;

  [self removeFramebuffer];
  framebuffer = new_framebuffer;
  if( !framebuffer ) return;

  texture_descriptor = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatB5G6R5Unorm
    width:framebuffer->storage_width height:framebuffer->storage_height
    mipmapped:NO];
  [texture_descriptor setUsage:MTLTextureUsageShaderRead];
  screen_texture = [[self device] newTextureWithDescriptor:texture_descriptor];
  bilinear_filtering_enabled = settings_current.bilinear_filter;
}

-(void) removeFramebuffer
{
  [screen_texture release];
  screen_texture = nil;
  framebuffer = NULL;
}

-(void) applyOverlayState:(const DisplayOverlayState *)state
{
  overlay_state = *state;
}

-(void) setBilinearFilteringEnabled:(BOOL)enabled
{
  bilinear_filtering_enabled = enabled;
}

-(void) zoom:(id)sender
{
  NSSize size;

  switch( [sender tag] ) {
  case 1:
    size = NSMakeSize( 320, 240 );
    [[FuseController singleton] releaseCmdKeys:@"1" withCode:QZ_1];
    break;
  case 2:
    size = NSMakeSize( 640, 480 );
    [[FuseController singleton] releaseCmdKeys:@"2" withCode:QZ_2];
    break;
  case 3:
    size = NSMakeSize( 960, 720 );
    [[FuseController singleton] releaseCmdKeys:@"3" withCode:QZ_3];
    break;
  case 4:
    size = NSMakeSize( 1280, 960 );
    [[FuseController singleton] releaseCmdKeys:@"4" withCode:QZ_4];
    break;
  case 5:
    size = NSMakeSize( 1600, 1200 );
    [[FuseController singleton] releaseCmdKeys:@"5" withCode:QZ_5];
    break;
  default:
    size = NSMakeSize( framebuffer ? framebuffer->width : 320,
                       framebuffer ? framebuffer->height : 240 );
    [[FuseController singleton] releaseCmdKeys:@"0" withCode:QZ_0];
    break;
  }
  [[self window] setContentSize:size];
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
  [[FuseController singleton] releaseCmdKeys:@"m" withCode:QZ_m];
  [self setPaused:NO];
}

-(void) windowDidChangeScreen:(NSNotification *)notification
{
}

@end
