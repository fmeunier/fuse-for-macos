/* DisplayPresenting.h: Renderer-neutral display presentation contract
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <Cocoa/Cocoa.h>

#include "ui/cocoa/cocoadisplay.h"
#include "ui/ui.h"

@protocol DisplayPresenting <NSObject>

-(void) applyFramebuffer:(Cocoa_Texture *)framebuffer;
-(void) removeFramebuffer;
-(void) applyOverlayState:(ui_statusbar_state)state
                   forItem:(ui_statusbar_item)item;
-(void) setBilinearFilteringEnabled:(BOOL)enabled;
-(void) performFullscreen;
-(void) shutdown;

@end
