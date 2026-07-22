/* DisplayHostView.h: Runtime-selectable display presenter host
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <Cocoa/Cocoa.h>

#import "DisplayPresenting.h"

@interface DisplayHostView : NSView <DisplayPresenting, NSWindowDelegate>
{
  id <DisplayPresenting> display_presenter;
  NSWindow *fullscreen_window;
  NSWindow *windowed_window;
}

-(IBAction) fullscreen:(id)sender;
-(IBAction) zoom:(id)sender;

@end
