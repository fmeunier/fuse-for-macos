/* MetalDisplayView.m: Inert Metal display presenter
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "MetalDisplayView.h"

@implementation MetalDisplayView

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

  [pipeline_descriptor release];
  [vertex_function release];
  [fragment_function release];
  [library release];

  return self;
}

-(void) dealloc
{
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

  drawable = [view currentDrawable];
  render_pass_descriptor = [view currentRenderPassDescriptor];
  if( !drawable || !render_pass_descriptor || !command_queue ) return;

  command_buffer = [command_queue commandBuffer];
  command_encoder = [command_buffer
    renderCommandEncoderWithDescriptor:render_pass_descriptor];
  if( command_encoder ) [command_encoder endEncoding];
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
