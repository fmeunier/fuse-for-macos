/* DisplayHostView.m: Runtime-selectable display presenter host
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "DisplayHostView.h"
#import "EmulationSessionController.h"
#import "FuseController.h"

#include "input.h"
#include "settings.h"
#include "ui/cocoa/cocoaui.h"

#define QZ_f 0x03

@interface DisplayFullscreenWindow : NSWindow
@end

@implementation DisplayFullscreenWindow

-(BOOL) canBecomeKeyWindow
{
  return YES;
}

@end

@implementation DisplayHostView

-(Class) displayPresenterClass
{
  NSString *backend = [[[NSProcessInfo processInfo] environment]
                       objectForKey:@"FUSE_DISPLAY_BACKEND"];

  if( !backend || [backend isEqualToString:@"opengl"] )
    return NSClassFromString( @"OpenGLDisplayView" );

  if( [backend isEqualToString:@"metal"] ) {
    Class metal_class = NSClassFromString( @"MetalDisplayView" );

    if( metal_class ) return metal_class;

    NSLog( @"FUSE_DISPLAY_BACKEND=metal is unavailable; using OpenGL" );
    return NSClassFromString( @"OpenGLDisplayView" );
  }

  NSLog( @"Invalid FUSE_DISPLAY_BACKEND=%@; using OpenGL", backend );
  return NSClassFromString( @"OpenGLDisplayView" );
}

-(void) awakeFromNib
{
  Class presenter_class = [self displayPresenterClass];
  NSView *presenter_view;

  [super awakeFromNib];

  if( !presenter_class ) {
    NSLog( @"OpenGL display presenter is unavailable" );
    return;
  }

  presenter_view = [[presenter_class alloc] initWithFrame:[self bounds]];
  if( ![presenter_view conformsToProtocol:@protocol(DisplayPresenting)] ) {
    NSLog( @"%@ does not implement DisplayPresenting", presenter_class );
    [presenter_view release];
    return;
  }

  display_presenter = (id <DisplayPresenting>)presenter_view;
  [presenter_view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [self addSubview:presenter_view];
  [presenter_view awakeFromNib];
  [presenter_view release];

  [[self window] setContentAspectRatio:NSMakeSize( 4.0, 3.0 )];
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

-(void) shutdown
{
  [display_presenter shutdown];
}

-(IBAction) fullscreen:(id)sender
{
  if( settings_current.full_screen ) {
    [fullscreen_window close];
    [windowed_window setContentView:self];
    [windowed_window makeKeyAndOrderFront:self];
    [windowed_window makeFirstResponder:self];
    settings_current.full_screen = 0;
    if( ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_release( 0 );
  } else {
    NSRect content_rect = [[NSScreen mainScreen] frame];

    windowed_window = [self window];
    fullscreen_window = [[DisplayFullscreenWindow alloc]
      initWithContentRect:content_rect styleMask:NSWindowStyleMaskBorderless
      backing:NSBackingStoreBuffered defer:NO];
    if( fullscreen_window ) {
      settings_current.full_screen = 1;
      [fullscreen_window setTitle:@"Fuse"];
      [fullscreen_window setReleasedWhenClosed:YES];
      [fullscreen_window setContentView:self];
      [fullscreen_window makeKeyAndOrderFront:self];
      [fullscreen_window setLevel:NSScreenSaverWindowLevel - 1];
      [fullscreen_window makeFirstResponder:self];
      if( !ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_grab( 0 );
    }
  }

  [[FuseController singleton] releaseCmdKeys:@"f" withCode:QZ_f];
}

-(IBAction) zoom:(id)sender
{
  if( [display_presenter respondsToSelector:@selector(zoom:)] )
    [(id)display_presenter zoom:sender];
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
  if( [display_presenter respondsToSelector:@selector(windowWillMiniaturize:)] )
    [(id)display_presenter windowWillMiniaturize:notification];
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
  if( [display_presenter respondsToSelector:@selector(windowDidMiniaturize:)] )
    [(id)display_presenter windowDidMiniaturize:notification];
}

-(void) windowDidDeminiaturize:(NSNotification *)notification
{
  if( [display_presenter respondsToSelector:@selector(windowDidDeminiaturize:)] )
    [(id)display_presenter windowDidDeminiaturize:notification];
}

-(void) windowDidChangeScreen:(NSNotification *)notification
{
  if( [display_presenter respondsToSelector:@selector(windowDidChangeScreen:)] )
    [(id)display_presenter windowDidChangeScreen:notification];
}

@end
