/* OpenGLDisplayView.m: Implementation for the OpenGLDisplayView class
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

#import "OpenGLDisplayView.h"
#import "EmulationSessionController.h"
#import "FuseController.h"
#import "DebuggerController.h"
#import "Texture.h"

#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <OpenGL/glu.h>

#include "fuse.h"
#include "main.h"
#include "settings.h"
#include "ui/cocoa/cocoaui.h"
#include "ui/cocoa/dirty.h"

#define QZ_f 0x03
#define QZ_0 0x1D
#define QZ_1 0x12
#define QZ_2 0x13
#define QZ_3 0x14
#define QZ_4 0x15
#define QZ_5 0x16
#define QZ_m 0x2E

static const void *
get_byte_pointer(void *bitmap)
{
  return bitmap;
}

static CVReturn MyDisplayLinkCallback (
    CVDisplayLinkRef displayLink,
    const CVTimeStamp *inNow,
    const CVTimeStamp *inOutputTime,
    CVOptionFlags flagsIn,
    CVOptionFlags *flagsOut,
    void *displayLinkContext)
{
  CVReturn error =
        [(OpenGLDisplayView*) displayLinkContext displayFrame:inOutputTime];
  return error;
}

static int
get_offset( int window_width, int window_height,
            int image_width, int image_height, float* width_adjustment ) {
  static const float FULL_IMAGE_RATIO = 4./3.;
  static const float TOP_BORDER_HAIRCUT = 24.;
  static const float MINIMAL_HEIGHT = 240.-TOP_BORDER_HAIRCUT*2.;
  static const float MINIMAL_TOP_BOTTOM_RATIO = 320./MINIMAL_HEIGHT;
  static const float SIDE_BORDER_HAIRCUT = 31.;
  static const float MINIMAL_WIDTH = 320.-SIDE_BORDER_HAIRCUT*2.;
  static const float MINIMAL_LEFT_RIGHT_RATIO = MINIMAL_WIDTH/240.;
  float ratio = window_width/(float)window_height;
  *width_adjustment = 0.;
  if( fabs( ratio - FULL_IMAGE_RATIO ) < 0.01f ) {
    /* no change, we are already at 4:3 */
    return 0;
  }

  if( !settings_current.full_screen_panorama ) {
    // if wider then desirable then use max height and have black bars on left
    // and right borders
    if( ratio > FULL_IMAGE_RATIO ) {
      float height_scale = window_height / (float)image_height;
      float height_ratio = window_height * FULL_IMAGE_RATIO;
      *width_adjustment = (window_width - height_ratio)/(2.*height_scale);
      return 0;
    }
    // if narrower than desirable then use max width and have black bars on top
    // and bottom of frame
    float width_scale = window_width / (float)image_width;
    float width_ratio = window_width / FULL_IMAGE_RATIO;
    return (width_ratio - window_height)/(2.*width_scale);
  }
  if( ratio > MINIMAL_TOP_BOTTOM_RATIO ) {
    // Truncate the top and bottom borders as much as possible and put black
    // bars on the left and right borders to cover the remainder
    float height_scale = window_height / MINIMAL_HEIGHT;
    float height_ratio = window_height * MINIMAL_TOP_BOTTOM_RATIO;
    *width_adjustment = (window_width - height_ratio)/(2.*height_scale);
    return TOP_BORDER_HAIRCUT;
  } else if( ratio > FULL_IMAGE_RATIO ) {
    // Similar to above but need to appropriately scale the amount of border
    // truncation assuming that full width will be used
    float width_scale = window_width / (float)image_width;
    float height_pixels = window_width / FULL_IMAGE_RATIO;
    return (height_pixels - window_height) / (2.*width_scale);
  } else if( ratio < MINIMAL_LEFT_RIGHT_RATIO ) {
    // here we have maximum border truncation and black bars top and bottom
    float width_scale = window_width / MINIMAL_WIDTH;
    float width_ratio = window_width / MINIMAL_LEFT_RIGHT_RATIO;
    *width_adjustment = -SIDE_BORDER_HAIRCUT;
    return (width_ratio - window_height)/(2.*width_scale);
  }
  // here we have a little bit of truncation of the left and right borders and
  // leave the top and bottom borders alone
  float height_scale = window_height / (float)image_height;
  float width_pixels = window_height * FULL_IMAGE_RATIO;
  *width_adjustment = (window_width - width_pixels) / (2.*height_scale);
  return 0;
}

@implementation OpenGLDisplayView

static OpenGLDisplayView *instance = nil;

+(OpenGLDisplayView *) instance
{
  return instance;
}

-(void) applyFramebuffer:(DisplayFramebuffer *)framebuffer
{
  [self removeFramebuffer];
  [self createTexture:framebuffer];
}

-(void) removeFramebuffer
{
  [self destroyTexture];
}

-(void) applyOverlayState:(const DisplayOverlayState *)state
{
  [view_lock lock];
  overlay_state = *state;
  statusbar_updated = YES;
  [view_lock unlock];
}

-(void) setBilinearFilteringEnabled:(BOOL)enabled
{
  GLint filter = enabled ? GL_LINEAR : GL_NEAREST;
  GLuint i;

  if( !screenTexInitialised ) return;

  [view_lock lock];
  [self displayLinkStop];
  [[self openGLContext] makeCurrentContext];

  for( i = 0; i < MAX_SCREEN_BUFFERS; i++ ) {
    glBindTexture( GL_TEXTURE_RECTANGLE_ARB, screenTexId[i] );
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, filter );
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, filter );
  }

  [self displayLinkStart];
  [view_lock unlock];
}

-(void) performFullscreen
{
  [self fullscreen:nil];
}

-(void) shutdown
{
  [self displayLinkStop];
}

-(IBAction) fullscreen:(id)sender
{
  /* don't want to get a callback to display the screen while we are
   * fiddling with the window to draw into!
   */
  [self displayLinkStop];

  if( settings_current.full_screen ) {
    /* we need to go back to non-full screen */
    [fullscreenWindow close];
    [windowedWindow setContentView: self];
    [windowedWindow makeKeyAndOrderFront: self];
    [windowedWindow makeFirstResponder: self];
    settings_current.full_screen = 0;
    if( ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_release( 0 );
  } else {
    unsigned int windowStyle;
    NSRect       contentRect;

    windowedWindow = [self window];
    windowStyle    = NSBorderlessWindowMask;
    contentRect    = [[NSScreen mainScreen] frame];
    fullscreenWindow = [[NSWindow alloc] initWithContentRect:contentRect
                                         styleMask: windowStyle
                                         backing:NSBackingStoreBuffered
                                         defer: NO];
    if( fullscreenWindow != nil ) {
      settings_current.full_screen = 1;
      [fullscreenWindow setTitle: @"Fuse"];
      [fullscreenWindow setReleasedWhenClosed: YES];
      [fullscreenWindow setContentView: self];
      [fullscreenWindow makeKeyAndOrderFront:self ];
      [fullscreenWindow setLevel: NSScreenSaverWindowLevel - 1];
      [fullscreenWindow makeFirstResponder:self];
      if( !ui_mouse_grabbed ) ui_mouse_grabbed = ui_mouse_grab( 0 );
    }
  }

  [self displayLinkStart];

  [view_lock lock];
  statusbar_updated = YES;
  [view_lock unlock];
  [[FuseController singleton] releaseCmdKeys:@"f" withCode:QZ_f];
}

-(IBAction) zoom:(id)sender
{
  NSSize size;

  switch( [sender tag] ) {
  case 1: /* 320x240 */
    size.width = 320;
    size.height = 240;
    [[FuseController singleton] releaseCmdKeys:@"1" withCode:QZ_1];
    break;
  case 2: /* 640x480 */
    size.width = 640;
    size.height = 480;
    [[FuseController singleton] releaseCmdKeys:@"2" withCode:QZ_2];
    break;
  case 3: /* 960x720 */
    size.width = 960;
    size.height = 720;
    [[FuseController singleton] releaseCmdKeys:@"3" withCode:QZ_3];
    break;
  case 4: /* 1280x960 */
    size.width = 1280;
    size.height = 960;
    [[FuseController singleton] releaseCmdKeys:@"4" withCode:QZ_4];
    break;
  case 5: /* 1600x1200 */
    size.width = 1600;
    size.height = 1200;
    [[FuseController singleton] releaseCmdKeys:@"5" withCode:QZ_5];
    break;
  case 0:
  default: /* Actual size */
    size.width = screenTex[0].width;
    size.height = screenTex[0].height;
    [[FuseController singleton] releaseCmdKeys:@"0" withCode:QZ_0];
  }

  [[self window] setContentSize:size];
}

-(id) initWithFrame:(NSRect)frameRect
{
  /* Init pixel format attribs */
  NSOpenGLPixelFormatAttribute attrs[] = {
                                           NSOpenGLPFANoRecovery,
                                           NSOpenGLPFAAccelerated,
                                           NSOpenGLPFADoubleBuffer,
                                           0
                                         };

  /* Get pixel format from OpenGL */
  NSOpenGLPixelFormat* pixFmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
  if (!pixFmt) {
    NSLog(@"No pixel format -- exiting");
    exit(1);
  }

  if ( instance ) {
    [self dealloc];
    self = instance;
  } else {
    self = [super initWithFrame:frameRect pixelFormat:pixFmt];
    instance = self;

    buffered_screen.synchronization = (void *)[[NSLock alloc] init];

  }

  [pixFmt release];

  [[self openGLContext] makeCurrentContext];

  // Synchronize buffer swaps with vertical refresh rate
  GLint swapInt = 1;
  [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; 
    
  /* Setup some basic OpenGL stuff */
  glPixelStorei( GL_UNPACK_ALIGNMENT, 1 );
  glTexEnvi( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
  glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
  glColor4f(0.0f, 0.0f, 0.0f, 0.0f);

  greenCassette = [Texture alloc];
  redCassette = [Texture alloc];
  [self loadPicture: @"cassette" greenTex:greenCassette
                                   redTex:redCassette
                                  xOrigin:285
                                  yOrigin:220];
  greenMdr = [Texture alloc];
  redMdr = [Texture alloc];
  [self loadPicture: @"microdrive" greenTex:greenMdr
                                     redTex:redMdr
                                    xOrigin:264
                                    yOrigin:218];
  greenDisk = [Texture alloc];
  redDisk = [Texture alloc];
  [self loadPicture: @"plus3disk" greenTex:greenDisk
                                    redTex:redDisk
                                   xOrigin:243
                                   yOrigin:218];
  screenTexInitialised = NO;

  target_ratio = 4.0f/3.0f;

  [[EmulationSessionController instance] startWithDisplayPresenter:self];

  currentScreenTex = 0;

  statusbar_updated = NO;

  return self;
}

-(void)dealloc
{
  if (view_lock)
    [view_lock release];
  view_lock = nil;

  if( buffered_screen.synchronization )
    [(NSLock *)buffered_screen.synchronization release];
  buffered_screen.synchronization = nil;
  
  [super dealloc];
}

-(void) awakeFromNib
{
  /* keep the window in the standard aspect ratio if the user resizes */
  [[self window] setContentAspectRatio:NSMakeSize(4.0,3.0)];

  view_lock = [[NSLock alloc] init];

  CVReturn            error = kCVReturnSuccess;
  CGDirectDisplayID   displayID = CGMainDisplayID();
 
  mainViewDisplayID = displayID;

  error = CVDisplayLinkCreateWithCGDisplay( displayID, &displayLink );
  if( error ) {
    NSLog( @"DisplayLink created with error:%d", error );
    displayLink = NULL;
    return;
  }
  error = CVDisplayLinkSetOutputCallback( displayLink,
                                          MyDisplayLinkCallback, self );
  if( error ) {
    NSLog( @"Callback created with error:%d", error );
    return;
  }

  displayLinkRunning = NO;
}

- (void)windowWillClose:(NSNotification *)notification
{
  [[self window] setDelegate:nil];
  [[EmulationSessionController instance] stop];

  [redCassette release];
  redCassette = nil;
  [greenCassette release];
  greenCassette = nil;
  [redMdr release];
  redMdr = nil;
  [greenMdr release];
  greenMdr = nil;
  [redDisk release];
  redDisk = nil;
  [greenDisk release];
  greenDisk = nil;

  [self release];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
  [[EmulationSessionController instance] keyboardReleaseAll];
}

-(void) loadPicture: (NSString *) name
                      greenTex:(Texture*) greenTexture
                      redTex:(Texture*) redTexture
                      xOrigin:(int) x
                      yOrigin:(int) y
{
  NSString *filename;

  filename = [NSString stringWithFormat:@"%@_green", name];

  /* Colour first image green */
  (void)[greenTexture initWithImageFile:filename withXOrigin:x
                          withYOrigin:y];

  filename = [NSString stringWithFormat:@"%@_red", name];

  /* Colour second image red */
  (void)[redTexture initWithImageFile:filename withXOrigin:x
                        withYOrigin:y];
}

-(void) setNeedsDisplayYes
{
  [super setNeedsDisplay:YES];
}

-(void) blitIcon:(Texture*)iconTexture
{
  DisplayFramebuffer* texture = [iconTexture getTexture];
  GLuint textureName = [iconTexture getTextureId];

  /* Map pixel icon position to appropriate position on -1.0 to 1.0 canvas */
  float target_x1 = texture->x_offset * 2.0f / (float)DISPLAY_ASPECT_WIDTH
                    - 1.0f;
  float target_x2 = ( ( texture->x_offset + texture->width ) * 2.0f
                      / (float)DISPLAY_ASPECT_WIDTH ) - 1.0f;
  float target_y1 = 1.0f - texture->y_offset * 2.0f /
                    (float)DISPLAY_SCREEN_HEIGHT;
  float target_y2 = 1.0f - ( texture->y_offset + texture->height )
                    * 2.0f / (float)DISPLAY_SCREEN_HEIGHT;

  /* Bind and draw icon */
  glBindTexture( GL_TEXTURE_RECTANGLE_ARB, textureName );

  glBegin( GL_QUADS );

    glTexCoord2f( (float)texture->width, 0.0f );
    glVertex2f( target_x2, target_y1 );

    glTexCoord2f( (float)texture->width, (float)texture->height );
    glVertex2f( target_x2, target_y2 );

    glTexCoord2f( 0.0f, (float)texture->height );
    glVertex2f( target_x1, target_y2 );

    glTexCoord2f( 0.0f, 0.0f );
    glVertex2f( target_x1, target_y1 );

  glEnd();
}

-(void) iconOverlay
{
  switch( overlay_state.disk_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self blitIcon:greenDisk];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
    [self blitIcon:redDisk];
    break;
  case DISPLAY_OVERLAY_STATE_NOT_AVAILABLE:
    break;
  }

  switch( overlay_state.microdrive_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self blitIcon:greenMdr];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
    [self blitIcon:redMdr];
    break;
  case DISPLAY_OVERLAY_STATE_NOT_AVAILABLE:
    break;
  }

  switch( overlay_state.tape_state ) {
  case DISPLAY_OVERLAY_STATE_ACTIVE:
    [self blitIcon:greenCassette];
    break;
  case DISPLAY_OVERLAY_STATE_INACTIVE:
  case DISPLAY_OVERLAY_STATE_NOT_AVAILABLE:
    [self blitIcon:redCassette];
    break;
  }
}

-(void) drawRect:(NSRect)aRect
{
  [view_lock lock];

  [[self openGLContext] makeCurrentContext];

  /* Clear buffer, needs to be done each frame */
  glClear( GL_COLOR_BUFFER_BIT );

  if (!screenTexInitialised) {
    [view_lock unlock];
    return;
  }

  int border_x_offset = 0;
  int border_y_offset = 0;
  if( settings_current.full_screen ) {
    /* how much of the top and bottom borders should be eliminated? */
    NSRect rect = [self bounds];
    float width_adjustment = 0.0;

    border_x_offset =
      get_offset( rect.size.width, rect.size.height,
                  screenTex[currentScreenTex].width,
                  screenTex[currentScreenTex].height,
                  &width_adjustment );
    border_y_offset = width_adjustment;
  }

  /* Bind, update and draw new image */
  glBindTexture( GL_TEXTURE_RECTANGLE_ARB, screenTexId[currentScreenTex] );
  
  glBegin( GL_QUADS );
    glTexCoord2f( (float)(screenTex[currentScreenTex].width +
                          screenTex[currentScreenTex].x_offset + border_y_offset),
                  (float)(screenTex[currentScreenTex].y_offset + border_x_offset)
                  );
    glVertex2f( 1.0f, 1.0f );

    glTexCoord2f( (float)(screenTex[currentScreenTex].width +
                          screenTex[currentScreenTex].x_offset + border_y_offset),
                  (float)(screenTex[currentScreenTex].height +
                          screenTex[currentScreenTex].y_offset - border_x_offset)
                  );
    glVertex2f( 1.0f, -1.0f );

    glTexCoord2f( (float)screenTex[currentScreenTex].x_offset - border_y_offset,
                  (float)(screenTex[currentScreenTex].height +
                          screenTex[currentScreenTex].y_offset - border_x_offset)
                  );
    glVertex2f( -1.0f, -1.0f );

    glTexCoord2f( (float)screenTex[currentScreenTex].x_offset - border_y_offset,
                  (float)(screenTex[currentScreenTex].y_offset + border_x_offset)
                  );
    glVertex2f( -1.0f, 1.0f );
  glEnd();

  if ( settings_current.statusbar ) [self iconOverlay];

  /* Swap buffer to screen */
  [[self openGLContext] flushBuffer];

  statusbar_updated = NO;

  [view_lock unlock];
}

/* Called by AppKit (e.g. -[NSOpenGLView _invalidateGStatesForTree]) when the
   drawable needs to be updated — including during live window resize. */
-(void) update
{
  [view_lock lock];
  [super update];
  [view_lock unlock];
}

/* scrolled, moved or resized. */
-(void) reshape
{
  [view_lock lock];
  NSRect rect;

  [[self openGLContext] makeCurrentContext];
  [[self openGLContext] update];

  rect = [self bounds];

  glViewport( 0, 0, (int) rect.size.width, (int) rect.size.height );

  glMatrixMode( GL_PROJECTION );
  glLoadIdentity();

  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity();

  statusbar_updated = YES;
  [view_lock unlock];
}

-(void) destroyTexture
{
  GLuint i;

  if (!screenTexInitialised)
    return;

  [view_lock lock];

  [self displayLinkStop];

  glDeleteTextures( MAX_SCREEN_BUFFERS, screenTexId );
  for(i = 0; i < MAX_SCREEN_BUFFERS; i++)
  {
    if( screenTex[i].ownership & DISPLAY_FRAMEBUFFER_OWNS_BACKING_STORAGE ) {
      free( screenTex[i].backing_storage );
      screenTex[i].backing_storage = NULL;
    }
    if( screenTex[i].ownership & DISPLAY_FRAMEBUFFER_OWNS_DIRTY_REGIONS ) {
      pig_dirty_close( screenTex[i].dirty_regions );
      screenTex[i].dirty_regions = NULL;
    }
    screenTex[i].ownership = 0;
  }
  screenTexInitialised = NO;
  [view_lock unlock];
}

-(void) createTexture:(DisplayFramebuffer*)newScreen
{
  [view_lock lock];
  GLuint i;

  [[self openGLContext] makeCurrentContext];
  [[self openGLContext] update];

  glGenTextures( MAX_SCREEN_BUFFERS, screenTexId );

  for(i = 0; i < MAX_SCREEN_BUFFERS; i++)
  {
    screenTex[i].pixel_format = newScreen->pixel_format;
    screenTex[i].storage_width = newScreen->storage_width;
    screenTex[i].storage_height = newScreen->storage_height;
    screenTex[i].width = newScreen->width;
    screenTex[i].height = newScreen->height;
    screenTex[i].x_offset = newScreen->x_offset;
    screenTex[i].y_offset = newScreen->y_offset;
    screenTex[i].generation = newScreen->generation;
    screenTex[i].synchronization = NULL;
    screenTex[i].backing_storage = calloc( screenTex[i].storage_width * screenTex[i].storage_height,
                                  sizeof(uint16_t) );
    if( !screenTex[i].backing_storage ) {
      NSLog( @"%s: couldn't create screenTex[%ud].backing_storage\n", fuse_progname,
             (unsigned int)i );
      return;
    }
    screenTex[i].stride = screenTex[i].storage_width * sizeof(uint16_t);
    screenTex[i].ownership = DISPLAY_FRAMEBUFFER_OWNS_BACKING_STORAGE;

    glDisable( GL_TEXTURE_2D );
    glEnable( GL_TEXTURE_RECTANGLE_ARB );
    glBindTexture( GL_TEXTURE_RECTANGLE_ARB, screenTexId[i] );

#if 0
    // These should increase texture upload performance, but instead seem to cause
    // issues with some ATI drivers (and perhaps GMA too), so I'm disabling for now
    // maybe revisit come 10.7
    glTextureRangeAPPLE( GL_TEXTURE_RECTANGLE_ARB,
                         screenTex[i].storage_width * screenTex[i].stride,
                         screenTex[i].backing_storage );

    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_STORAGE_HINT_APPLE,
                     GL_STORAGE_CACHED_APPLE );
    glPixelStorei( GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE );
#endif
    GLint filter = settings_current.bilinear_filter ? GL_LINEAR : GL_NEAREST;
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, filter );
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, filter );
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
    glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
    glPixelStorei( GL_UNPACK_ROW_LENGTH, 0 );

    glTexImage2D( GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGB, screenTex[i].storage_width,
                  screenTex[i].storage_height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5,
                  screenTex[i].backing_storage );
  }
  screenTexInitialised = YES;

  [self displayLinkStart];

  [view_lock unlock];
}

-(void) mouseMoved:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] mouseMoved:theEvent];
}

-(void) mouseDown:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] mouseDown:theEvent];
}

-(void) mouseUp:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] mouseUp:theEvent];
}

-(void) rightMouseDown:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] rightMouseDown:theEvent];
}

-(void) rightMouseUp:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] rightMouseUp:theEvent];
}

-(void) otherMouseDown:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] otherMouseDown:theEvent];
}

-(void) otherMouseUp:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] otherMouseUp:theEvent];
}

-(void) flagsChanged:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] flagsChanged:theEvent];
}

-(void) keyDown:(NSEvent *)theEvent
{
  if( settings_current.full_screen ) {
    unichar c = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
    switch (c) {
    case 27:
      [self fullscreen:nil];
      return;
      break;
    }
  }
  [[EmulationSessionController instance] keyDown:theEvent];
}

-(void) keyUp:(NSEvent *)theEvent
{
  [[EmulationSessionController instance] keyUp:theEvent];
}

-(BOOL) acceptsFirstResponder
{
  return YES;
}

-(BOOL) becomeFirstResponder
{
  return YES;
}

-(BOOL) resignFirstResponder
{
  return YES;
}

-(BOOL) isFlipped
{
  return YES;
}

/* Minimise code from example code posted by user arekkusu
 * (http://www.idevgames.com) at http://www.idevgames.com in thread
 * "Properly minimizing an OpenGL view"
 */
-(void) copyGLtoQuartz
{
  NSSize  size = [self frame].size;
  GLfloat zero = 0.0f;
  long    rowbytes = size.width * 4;
  rowbytes = (rowbytes + 3)& ~3;      // ctx rowbytes is always multiple of 4, per glGrab
  unsigned char* bitmap = malloc(rowbytes * size.height);
 
  // Stuffing around with OpenGL context - lock view while we do 
  [view_lock lock];

  [[NSOpenGLContext currentContext] makeCurrentContext];
  glFinish();                         // finish any pending OpenGL commands
  glPushAttrib(GL_ALL_ATTRIB_BITS);   // reset all properties that affect glReadPixels, in case app was using them
  glDisable(GL_COLOR_TABLE);
  glDisable(GL_CONVOLUTION_1D);
  glDisable(GL_CONVOLUTION_2D);
  glDisable(GL_HISTOGRAM);
  glDisable(GL_MINMAX);
  glDisable(GL_POST_COLOR_MATRIX_COLOR_TABLE);
  glDisable(GL_POST_CONVOLUTION_COLOR_TABLE);
  glDisable(GL_SEPARABLE_2D);
  
  glPixelMapfv(GL_PIXEL_MAP_R_TO_R, 1, &zero);
  glPixelMapfv(GL_PIXEL_MAP_G_TO_G, 1, &zero);
  glPixelMapfv(GL_PIXEL_MAP_B_TO_B, 1, &zero);
  glPixelMapfv(GL_PIXEL_MAP_A_TO_A, 1, &zero);
  
  glPixelStorei(GL_PACK_SWAP_BYTES, 0);
  glPixelStorei(GL_PACK_LSB_FIRST, 0);
  glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
  glPixelStorei(GL_PACK_ALIGNMENT, 4); // force 4-byte alignment from RGBA framebuffer
  glPixelStorei(GL_PACK_ROW_LENGTH, 0);
  glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_PACK_SKIP_ROWS, 0);
  glPixelStorei(GL_PACK_SKIP_IMAGES, 0);
  
  glPixelTransferi(GL_MAP_COLOR, 0);
  glPixelTransferf(GL_RED_SCALE, 1.0f);
  glPixelTransferf(GL_RED_BIAS, 0.0f);
  glPixelTransferf(GL_GREEN_SCALE, 1.0f);
  glPixelTransferf(GL_GREEN_BIAS, 0.0f);
  glPixelTransferf(GL_BLUE_SCALE, 1.0f);
  glPixelTransferf(GL_BLUE_BIAS, 0.0f);
  glPixelTransferf(GL_ALPHA_SCALE, 1.0f);
  glPixelTransferf(GL_ALPHA_BIAS, 0.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_RED_SCALE, 1.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_RED_BIAS, 0.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_GREEN_SCALE, 1.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_GREEN_BIAS, 0.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_BLUE_SCALE, 1.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_BLUE_BIAS, 0.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_ALPHA_SCALE, 1.0f);
  glPixelTransferf(GL_POST_COLOR_MATRIX_ALPHA_BIAS, 0.0f);
  glReadPixels(0, 0, size.width, size.height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, bitmap);
  glPopAttrib();

  [view_lock unlock];

  [self lockFocus];
  // create a CGImageRef from the memory block
  CGDataProviderDirectCallbacks gProviderCallbacks = { 0, get_byte_pointer, NULL, NULL, NULL };
  CGDataProviderRef provider = CGDataProviderCreateDirect(bitmap, rowbytes * size.height, &gProviderCallbacks);
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGImageRef cgImage = CGImageCreate(size.width, size.height, 8, 32, rowbytes, cs,
      kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst, provider, NULL, NO,
      kCGRenderingIntentDefault);

  // composite the CGImage into the view
  CGContextRef gc = [[NSGraphicsContext currentContext] graphicsPort];
  CGContextDrawImage(gc, CGRectMake(0, 0, size.width, size.height), cgImage);

  // clean up
  CGImageRelease(cgImage);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(cs);
  free(bitmap);

  [self unlockFocus];
  [[self window] flushWindow];
}

-(void) windowWillMiniaturize:(NSNotification *)aNotification
{
  [self copyGLtoQuartz];	
  [[self window] setOpaque:NO]; // required to make the Quartz underlay and the window shadow appear correctly
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
  [[self window] setOpaque:YES];
}

-(BOOL) windowShouldClose:(id)window
{
  if( cocoaui_confirm( "Exit Fuse?" ) ) {
    int error = [[EmulationSessionController instance] checkMediaChanged];
    if( error ) return NO;

    [self displayLinkStop];

    return YES;
  }
  return NO;
}

-(CVReturn) displayFrame:(const CVTimeStamp *)timeStamp
{
  int i;
  PIG_dirtytable *workdirty = NULL;
 
  // Is it possible that while waiting for a lock the emulator is stopped?
  // or already holds the lock? If so give up on updating the frame rather
  // than deadlock on getting the lock - may mean that we miss some screen
  // updates if we are invoked while the buffered screen is being updated
  if( !buffered_screen.synchronization ||
      [(NSLock *)buffered_screen.synchronization tryLock] == NO ) {
    return kCVReturnSuccess;
  }

  if( buffered_screen.dirty_regions->count == 0 && !statusbar_updated ) {
    [(NSLock *)buffered_screen.synchronization unlock];
    return kCVReturnSuccess;
  }

  if( buffered_screen.dirty_regions->count > 0 ) {

    // Make sure we lock the view if we are going to update the textures so
    // there is no concurrent access to the OpenGL context as the displaylink
    // callback is not on the main thread where resizing-related drawing will
    // occur, also cover the screen texture swap
    [view_lock lock];

    if (screenTex[currentScreenTex].dirty_regions)
      pig_dirty_copy( &workdirty, screenTex[currentScreenTex].dirty_regions );

    currentScreenTex = !currentScreenTex;

    pig_dirty_copy( &screenTex[currentScreenTex].dirty_regions, buffered_screen.dirty_regions );
    
    if( workdirty )
      pig_dirty_merge(workdirty, screenTex[currentScreenTex].dirty_regions);
    else
      pig_dirty_copy(&workdirty, screenTex[currentScreenTex].dirty_regions);
    
    /* Draw texture to screen */
    for(i = 0; i < workdirty->count; ++i)
      copy_area( &screenTex[currentScreenTex], &buffered_screen,
                 workdirty->rects + i );
    
    buffered_screen.dirty_regions->count = 0;
    
    pig_dirty_close( workdirty );

    [[self openGLContext] makeCurrentContext];
    
    /* Bind, update and draw new image */
    glBindTexture( GL_TEXTURE_RECTANGLE_ARB, screenTexId[currentScreenTex] );
    
    glTexSubImage2D( GL_TEXTURE_RECTANGLE_ARB, 0, 0, 0,
                     screenTex[currentScreenTex].storage_width,
                     screenTex[currentScreenTex].storage_height, GL_RGB,
                     GL_UNSIGNED_SHORT_5_6_5,
                     screenTex[currentScreenTex].backing_storage );

    [view_lock unlock];
  }

  [(NSLock *)buffered_screen.synchronization unlock];

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  [self drawRect:NSZeroRect];
  [pool release];

  return kCVReturnSuccess;
}

-(void) windowChangedScreen:(NSNotification*)inNotification
{
  NSWindow *window = [self window];
  CGDirectDisplayID displayID = (CGDirectDisplayID)[[[[window screen]
         deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
  if((displayID != 0) && (mainViewDisplayID != displayID))
  {
    CVDisplayLinkSetCurrentCGDisplay(displayLink, displayID);
    mainViewDisplayID = displayID;
  }
}

-(void) windowDidDeminiaturize:(NSNotification *)inNotification
{
  [[FuseController singleton] releaseCmdKeys:@"m" withCode:QZ_m];
}

-(void) displayLinkStop
{
  if( displayLinkRunning == YES ) {
    CVReturn error = CVDisplayLinkStop( displayLink );
    if( error ) {
      NSLog( @"error stopping displayLink:%d", error );
    }
    displayLinkRunning = NO;
  }
}

-(void) displayLinkStart
{
  if( displayLinkRunning == NO ) {
    CVReturn error = CVDisplayLinkStart( displayLink );
    if( error ) {
      NSLog( @"error starting displayLink:%d", error );
    }
    displayLinkRunning = YES;
  }
}

@end
