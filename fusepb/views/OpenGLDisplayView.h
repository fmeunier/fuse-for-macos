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

#import "DisplayPresenting.h"

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

@interface OpenGLDisplayView : NSOpenGLView <DisplayPresenting>
{
  /* Two backing textures */
  DisplayFramebuffer screenTex[MAX_SCREEN_BUFFERS];
  GLuint screenTexId[MAX_SCREEN_BUFFERS];
  int currentScreenTex;

  Texture *redCassette;
  Texture *greenCassette;
  Texture *redMdr;
  Texture *greenMdr;
  Texture *redDisk;
  Texture *greenDisk;

  BOOL screenTexInitialised;

  DisplayOverlayState overlay_state;
  BOOL statusbar_updated;

  NSLock *view_lock;

  float target_ratio;

  CVDisplayLinkRef displayLink;
  CGDirectDisplayID mainViewDisplayID;
  BOOL displayLinkRunning;
}
+(OpenGLDisplayView *) instance;

-(IBAction) zoom:(id)sender;

-(void) applyFramebuffer:(DisplayFramebuffer *)framebuffer;
-(void) removeFramebuffer;
-(void) applyOverlayState:(const DisplayOverlayState *)state;
-(void) setBilinearFilteringEnabled:(BOOL)enabled;
-(void) performFullscreen;
-(void) shutdown;

-(void) createTexture:(DisplayFramebuffer *)newScreen;
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

-(void) copyGLtoQuartz;
-(void) windowWillMiniaturize:(NSNotification *)aNotification;
-(void) windowDidMiniaturize:(NSNotification *)notification;

-(CVReturn) displayFrame:(const CVTimeStamp *)timeStamp;
-(void) windowDidChangeScreen:(NSNotification*)inNotification;
-(void) windowDidDeminiaturize:(NSNotification *)inNotification;

-(void) displayLinkStop;
-(void) displayLinkStart;

@end
