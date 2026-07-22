/* MetalDisplayView.h: Inert Metal display presenter
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <MetalKit/MetalKit.h>

#import "DisplayPresenting.h"

@interface MetalDisplayView : MTKView <DisplayPresenting, MTKViewDelegate>
{
  id <MTLCommandQueue> command_queue;
  id <MTLRenderPipelineState> pipeline_state;
  id <MTLSamplerState> nearest_sampler;
  id <MTLSamplerState> linear_sampler;
  BOOL bilinear_filtering_enabled;
}

@end
