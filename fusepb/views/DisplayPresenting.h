/* DisplayPresenting.h: Renderer-neutral display presentation contract
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <Cocoa/Cocoa.h>

#include "ui/cocoa/cocoadisplay.h"

#include "DisplayOverlayState.h"

@protocol DisplayPresenting <NSObject>

/* DisplayHostView starts and stops each selected presenter exactly once. */
-(void) start;
-(void) shutdown;

-(void) applyFramebuffer:(DisplayFramebuffer *)framebuffer;
-(DisplayFramebuffer *) acquireFramebuffer;
-(void) publishFramebuffer:(DisplayFramebuffer *)framebuffer;
-(void) removeFramebuffer;
-(void) applyOverlayState:(const DisplayOverlayState *)state;
-(void) setBilinearFilteringEnabled:(BOOL)enabled;
-(void) zoom:(id)sender;

/* DisplayHostView owns the window and forwards renderer-relevant changes. */
-(void) windowWillMiniaturize:(NSNotification *)notification;
-(void) windowDidMiniaturize:(NSNotification *)notification;
-(void) windowDidDeminiaturize:(NSNotification *)notification;
-(void) windowDidChangeScreen:(NSNotification *)notification;

/* Fullscreen window ownership belongs to DisplayHostView. */
-(void) performFullscreen;

@end
