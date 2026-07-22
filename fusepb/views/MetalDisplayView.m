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
#define MAX_UPDATE_RECT 300

typedef struct {
  vector_float4 position;
  vector_float4 texture_coordinates;
} DisplayVertices;

typedef enum {
  DISPLAY_FRAMEBUFFER_SLOT_WRITABLE,
  DISPLAY_FRAMEBUFFER_SLOT_READY,
  DISPLAY_FRAMEBUFFER_SLOT_IN_FLIGHT
} DisplayFramebufferSlotState;

@interface DisplayFramebufferSlot : NSObject
{
@public
  id <MTLBuffer> buffer;
  id <MTLTexture> texture;
  DisplayFramebuffer framebuffer;
  DisplayFramebufferSlotState state;
}
-(id) initWithDevice:(id <MTLDevice>)device
         framebuffer:(const DisplayFramebuffer *)source;
@end

@implementation DisplayFramebufferSlot

-(id) initWithDevice:(id <MTLDevice>)device
         framebuffer:(const DisplayFramebuffer *)source
{
  MTLTextureDescriptor *texture_descriptor;
  NSUInteger alignment;
  NSUInteger natural_stride;
  NSUInteger aligned_stride;

  self = [super init];
  if( !self ) return nil;

  alignment = [device minimumLinearTextureAlignmentForPixelFormat:
               MTLPixelFormatB5G6R5Unorm];
  natural_stride = source->storage_width * sizeof( uint16_t );
  aligned_stride = ( natural_stride + alignment - 1 ) / alignment * alignment;
  buffer = [device newBufferWithLength:aligned_stride * source->storage_height
                                options:MTLResourceStorageModeShared];
  if( !buffer ) {
    [self release];
    return nil;
  }

  texture_descriptor = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatB5G6R5Unorm
    width:source->storage_width height:source->storage_height mipmapped:NO];
  [texture_descriptor setUsage:MTLTextureUsageShaderRead];
  texture = [buffer newTextureWithDescriptor:texture_descriptor offset:0
                                 bytesPerRow:aligned_stride];
  if( !texture ) {
    [self release];
    return nil;
  }

  framebuffer = *source;
  framebuffer.stride = aligned_stride;
  framebuffer.backing_storage = [buffer contents];
  framebuffer.dirty_regions = pig_dirty_open( MAX_UPDATE_RECT );
  framebuffer.ownership = 0;
  if( !framebuffer.dirty_regions ) {
    [self release];
    return nil;
  }
  state = DISPLAY_FRAMEBUFFER_SLOT_WRITABLE;

  return self;
}

-(void) dealloc
{
  pig_dirty_close( framebuffer.dirty_regions );
  [texture release];
  [buffer release];
  [super dealloc];
}

@end

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
  framebuffer_slots = [[NSMutableArray alloc] initWithCapacity:DISPLAY_FRAMEBUFFER_SLOT_COUNT];
  in_flight_command_buffers = [[NSMutableArray alloc] init];
  framebuffer_slot_lock = [[NSLock alloc] init];
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
  [self removeFramebuffer];
  [framebuffer_slot_lock release];
  [in_flight_command_buffers release];
  [framebuffer_slots release];
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

  [super dealloc];
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
  DisplayFramebufferSlot *slot = nil;
  DisplayFramebuffer *slot_framebuffer;
  DisplayVertices vertices;
  float x_offset = 0.0f;
  float y_offset = 0.0f;
  NSInteger i;

  drawable = [view currentDrawable];
  render_pass_descriptor = [view currentRenderPassDescriptor];
  if( !drawable || !render_pass_descriptor || !command_queue ) return;

  [framebuffer_slot_lock lock];
  for( i = [framebuffer_slots count] - 1; i >= 0; i-- ) {
    DisplayFramebufferSlot *candidate = [framebuffer_slots objectAtIndex:i];

    if( candidate->state == DISPLAY_FRAMEBUFFER_SLOT_READY ) {
      slot = candidate;
      slot->state = DISPLAY_FRAMEBUFFER_SLOT_IN_FLIGHT;
      break;
    }
  }
  [framebuffer_slot_lock unlock];

  command_buffer = [command_queue commandBuffer];
  command_encoder = [command_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];
  slot_framebuffer = slot ? &slot->framebuffer : NULL;
  if( command_encoder && pipeline_state && slot_framebuffer ) {
    if( settings_current.full_screen ) {
      x_offset = get_offset( view.drawableSize.width, view.drawableSize.height,
                             slot_framebuffer->width, slot_framebuffer->height,
                             &y_offset );
    }
    vertices.position = (vector_float4){ -1.0f, 1.0f, 1.0f, -1.0f };
    vertices.texture_coordinates = (vector_float4){
      ( slot_framebuffer->x_offset - y_offset ) / slot_framebuffer->storage_width,
      ( slot_framebuffer->y_offset + x_offset ) / slot_framebuffer->storage_height,
      ( slot_framebuffer->x_offset + slot_framebuffer->width + y_offset ) /
        slot_framebuffer->storage_width,
      ( slot_framebuffer->y_offset + slot_framebuffer->height - x_offset ) /
        slot_framebuffer->storage_height
    };
    [command_encoder setRenderPipelineState:pipeline_state];
    [command_encoder setVertexBytes:&vertices length:sizeof( vertices ) atIndex:0];
    [command_encoder setFragmentTexture:slot->texture atIndex:0];
    [command_encoder setFragmentSamplerState:bilinear_filtering_enabled ? linear_sampler : nearest_sampler
                                     atIndex:0];
    [command_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [self drawOverlays:command_encoder];
    [command_encoder endEncoding];
  } else if( command_encoder ) {
    [command_encoder endEncoding];
  }
  if( slot ) {
    [framebuffer_slot_lock lock];
    [in_flight_command_buffers addObject:command_buffer];
    [framebuffer_slot_lock unlock];
    [command_buffer addCompletedHandler:^(id <MTLCommandBuffer> completed_buffer) {
      [framebuffer_slot_lock lock];
      slot->state = DISPLAY_FRAMEBUFFER_SLOT_WRITABLE;
      [in_flight_command_buffers removeObject:completed_buffer];
      [framebuffer_slot_lock unlock];
    }];
  }
  [command_buffer presentDrawable:drawable];
  [command_buffer commit];
}

-(void) mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

-(void) start
{
  [self setPaused:NO];
}

-(void) shutdown
{
  [self setPaused:YES];
}

-(void) applyFramebuffer:(DisplayFramebuffer *)new_framebuffer
{
  int i;

  [self removeFramebuffer];
  framebuffer = new_framebuffer;
  if( !framebuffer ) return;

  [framebuffer_slot_lock lock];
  for( i = 0; i < DISPLAY_FRAMEBUFFER_SLOT_COUNT; i++ ) {
    DisplayFramebufferSlot *slot = [[DisplayFramebufferSlot alloc]
      initWithDevice:[self device] framebuffer:framebuffer];

    if( !slot ) break;
    [framebuffer_slots addObject:slot];
    buffered_screen_ring.slots[i] = &slot->framebuffer;
    [slot release];
  }
  accepting_framebuffers = [framebuffer_slots count] == DISPLAY_FRAMEBUFFER_SLOT_COUNT;
  [framebuffer_slot_lock unlock];
  if( !accepting_framebuffers ) [self removeFramebuffer];
  bilinear_filtering_enabled = settings_current.bilinear_filter;
}

-(DisplayFramebuffer *) acquireFramebuffer
{
  DisplayFramebufferSlot *slot;

  [framebuffer_slot_lock lock];
  if( !accepting_framebuffers ) {
    [framebuffer_slot_lock unlock];
    return NULL;
  }
  for( slot in framebuffer_slots ) {
    if( slot->state == DISPLAY_FRAMEBUFFER_SLOT_WRITABLE ) {
      [framebuffer_slot_lock unlock];
      return &slot->framebuffer;
    }
  }
  [framebuffer_slot_lock unlock];

  /* Drop this frame: all slots are currently sampled by the GPU. */
  return NULL;
}

-(void) publishFramebuffer:(DisplayFramebuffer *)new_framebuffer
{
  DisplayFramebufferSlot *slot;

  [framebuffer_slot_lock lock];
  if( accepting_framebuffers ) {
    for( slot in framebuffer_slots ) {
      if( slot->state == DISPLAY_FRAMEBUFFER_SLOT_READY )
        slot->state = DISPLAY_FRAMEBUFFER_SLOT_WRITABLE;
      if( &slot->framebuffer == new_framebuffer )
        slot->state = DISPLAY_FRAMEBUFFER_SLOT_READY;
    }
  }
  [framebuffer_slot_lock unlock];
}

-(void) removeFramebuffer
{
  NSArray *command_buffers;
  id <MTLCommandBuffer> command_buffer;

  [framebuffer_slot_lock lock];
  accepting_framebuffers = NO;
  command_buffers = [[in_flight_command_buffers copy] autorelease];
  [framebuffer_slot_lock unlock];
  for( command_buffer in command_buffers ) [command_buffer waitUntilCompleted];

  [framebuffer_slot_lock lock];
  [in_flight_command_buffers removeAllObjects];
  [framebuffer_slots removeAllObjects];
  memset( &buffered_screen_ring, 0, sizeof( buffered_screen_ring ) );
  framebuffer = NULL;
  [framebuffer_slot_lock unlock];
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
