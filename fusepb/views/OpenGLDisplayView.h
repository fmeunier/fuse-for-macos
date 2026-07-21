/* OpenGLDisplayView.h: Implementation for the OpenGLDisplayView class
   Copyright (c) 2006-2007 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

   Author contact information:

   E-mail: fredm@spamcop.net

*/

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <OpenGL/glu.h>

#include <libspectrum.h>

#include "input.h"
#include "machines/specplus3.h"
#include "peripherals/disk/beta.h"
#include "ui/cocoa/cocoadisplay.h"
#include "ui/ui.h"

#define MAX_SCREEN_BUFFERS 2

@class Texture;

@interface OpenGLDisplayView : NSOpenGLView
{
  /* Two backing textures */
  Cocoa_Texture screenTex[MAX_SCREEN_BUFFERS];
  GLuint screenTexId[MAX_SCREEN_BUFFERS];
  int currentScreenTex;

  Texture *redCassette;
  Texture *greenCassette;
  Texture *redMdr;
  Texture *greenMdr;
  Texture *redDisk;
  Texture *greenDisk;

  BOOL screenTexInitialised;

  ui_statusbar_state disk_state;
  ui_statusbar_state mdr_state;
  ui_statusbar_state tape_state;
  BOOL statusbar_updated;

  NSLock *view_lock;

  NSWindow *fullscreenWindow;
  NSWindow *windowedWindow;

  float target_ratio;

  CVDisplayLinkRef displayLink;
  CGDirectDisplayID mainViewDisplayID;
  BOOL displayLinkRunning;
}
+(OpenGLDisplayView *) instance;

-(IBAction) fullscreen:(id)sender;
-(IBAction) zoom:(id)sender;

-(void) createTexture:(Cocoa_Texture*)newScreen;
-(void) createTextureWithValue:(NSValue*)newScreenValue;
-(void) destroyTexture;
-(void) blitIcon:(Texture*)iconTexture;

-(id) initWithFrame:(NSRect)frameRect;
-(void) awakeFromNib;

-(void) loadPicture:(NSString *) name
           greenTex:(Texture*) greenTexture
             redTex:(Texture*) redTexture
            xOrigin:(int) x
            yOrigin:(int) y;

-(void) setNeedsDisplayYes;

-(void) setDiskState:(NSNumber*)state;
-(void) setTapeState:(NSNumber*)state;
-(void) setMdrState:(NSNumber*)state;

-(void) mouseMoved:(NSEvent *)theEvent;
-(void) mouseDown:(NSEvent *)theEvent;
-(void) mouseUp:(NSEvent *)theEvent;
-(void) rightMouseDown:(NSEvent *)theEvent;
-(void) rightMouseUp:(NSEvent *)theEvent;
-(void) otherMouseDown:(NSEvent *)theEvent;
-(void) otherMouseUp:(NSEvent *)theEvent;

-(void) flagsChanged:(NSEvent *)theEvent;
-(void) keyDown:(NSEvent *)theEvent;
-(void) keyUp:(NSEvent *)theEvent;

-(BOOL) acceptsFirstResponder;
-(BOOL) becomeFirstResponder;
-(BOOL) resignFirstResponder;

-(BOOL) isFlipped;

-(void) copyGLtoQuartz;
-(void) windowWillMiniaturize:(NSNotification *)aNotification;
-(void) windowDidMiniaturize:(NSNotification *)notification;
-(BOOL) windowShouldClose:(id)window;
-(void) windowDidResignKey:(NSNotification *)notification;

-(CVReturn) displayFrame:(const CVTimeStamp *)timeStamp;
-(void) windowChangedScreen:(NSNotification*)inNotification;
-(void) windowDidDeminiaturize:(NSNotification *)inNotification;

-(void) displayLinkStop;
-(void) displayLinkStart;

@end
