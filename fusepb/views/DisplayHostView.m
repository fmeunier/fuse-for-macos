/* DisplayHostView.m: Display presenter host
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "DisplayHostView.h"
#import "MetalDisplayView.h"
#import "EmulationSessionController.h"
#import "FuseController.h"

#include "input.h"
#include "settings.h"
#include "ui/cocoa/cocoaui.h"

#define QZ_f 0x03

@implementation DisplayHostView

-(void) awakeFromNib
{
  NSView *presenter_view;

  [super awakeFromNib];

  presenter_view = [[MetalDisplayView alloc] initWithFrame:[self bounds]];
  if( ![presenter_view conformsToProtocol:@protocol(DisplayPresenting)] ) {
    NSLog( @"%@ does not implement DisplayPresenting", [presenter_view class] );
    [presenter_view release];
    return;
  }

  display_presenter = (id <DisplayPresenting>)presenter_view;
  [presenter_view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [self addSubview:presenter_view];
  [presenter_view release];

  [[self window] setContentAspectRatio:NSMakeSize( 4.0, 3.0 )];
  [self start];
  [[EmulationSessionController instance] startWithDisplayPresenter:self];
}

-(void) applyFramebuffer:(DisplayFramebuffer *)framebuffer
{
  [display_presenter applyFramebuffer:framebuffer];
}

-(void) removeFramebuffer
{
  [display_presenter removeFramebuffer];
}

-(void) applyOverlayState:(const DisplayOverlayState *)state
{
  [display_presenter applyOverlayState:state];
}

-(void) setBilinearFilteringEnabled:(BOOL)enabled
{
  [display_presenter setBilinearFilteringEnabled:enabled];
}

-(void) performFullscreen
{
  [self fullscreen:nil];
}

-(void) start
{
  [display_presenter start];
}

-(void) shutdown
{
  [display_presenter shutdown];
}

-(IBAction) fullscreen:(id)sender
{
  [[self window] toggleFullScreen:sender];
  [[FuseController singleton] releaseCmdKeys:@"f" withCode:QZ_f];
}

-(void) windowWillEnterFullScreen:(NSNotification *)notification
{
  settings_current.full_screen = 1;
  if( !ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_grab( 0 );
}

-(void) windowWillExitFullScreen:(NSNotification *)notification
{
  settings_current.full_screen = 0;
  if( ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_release( 0 );
}

-(BOOL) validateMenuItem:(NSMenuItem *)menu_item
{
  if( [menu_item action] == @selector(zoom:) )
    return !settings_current.full_screen;

  return YES;
}

-(IBAction) zoom:(id)sender
{
  if( settings_current.full_screen ) return;

  [display_presenter zoom:sender];
}

-(void) mouseMoved:(NSEvent *)event
{
  [[EmulationSessionController instance] mouseMoved:event];
}

-(void) mouseDown:(NSEvent *)event
{
  [[EmulationSessionController instance] mouseDown:event];
}

-(void) mouseUp:(NSEvent *)event
{
  [[EmulationSessionController instance] mouseUp:event];
}

-(void) rightMouseDown:(NSEvent *)event
{
  [[EmulationSessionController instance] rightMouseDown:event];
}

-(void) rightMouseUp:(NSEvent *)event
{
  [[EmulationSessionController instance] rightMouseUp:event];
}

-(void) otherMouseDown:(NSEvent *)event
{
  [[EmulationSessionController instance] otherMouseDown:event];
}

-(void) otherMouseUp:(NSEvent *)event
{
  [[EmulationSessionController instance] otherMouseUp:event];
}

-(void) flagsChanged:(NSEvent *)event
{
  [[EmulationSessionController instance] flagsChanged:event];
}

-(void) keyDown:(NSEvent *)event
{
  if( settings_current.full_screen &&
      [[event charactersIgnoringModifiers] length] &&
      [[event charactersIgnoringModifiers] characterAtIndex:0] == 27 ) {
    [self fullscreen:nil];
    return;
  }

  [[EmulationSessionController instance] keyDown:event];
}

-(void) keyUp:(NSEvent *)event
{
  [[EmulationSessionController instance] keyUp:event];
}

-(BOOL) acceptsFirstResponder
{
  return YES;
}

-(void) windowWillClose:(NSNotification *)notification
{
  [[self window] setDelegate:nil];
  [[EmulationSessionController instance] stop];
  [display_presenter shutdown];
}

-(void) windowDidResignKey:(NSNotification *)notification
{
  [[EmulationSessionController instance] keyboardReleaseAll];
}

-(BOOL) windowShouldClose:(id)window
{
  if( !cocoaui_confirm( "Exit Fuse?" ) ) return NO;

  return ![[EmulationSessionController instance] checkMediaChanged];
}

-(void) windowWillMiniaturize:(NSNotification *)notification
{
  [display_presenter windowWillMiniaturize:notification];
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
  [display_presenter windowDidMiniaturize:notification];
}

-(void) windowDidDeminiaturize:(NSNotification *)notification
{
  [display_presenter windowDidDeminiaturize:notification];
}

-(void) windowDidChangeScreen:(NSNotification *)notification
{
  [display_presenter windowDidChangeScreen:notification];
}

@end
