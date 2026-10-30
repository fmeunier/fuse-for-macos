/* SaveBinaryController.m: Routines for dealing with the Save Binary Panel
   Copyright (c) 2003 Fredrick Meunier

   $Id$

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

   E-mail: pak21-fuse@srcf.ucam.org

*/

#include <config.h>

#import "SaveBinaryController.h"
#import "BinaryDataContainerView.h"
#import "EmulationSessionController.h"

#include "spectrum.h"
#include <libspectrum.h>
#include "utils.h"

@implementation SaveBinaryController

- (id)init
{
  NSWindow *window = [[NSWindow alloc]
    initWithContentRect:NSMakeRect( 0, 0, 580, 200 )
              styleMask:NSWindowStyleMaskTitled
                backing:NSBackingStoreBuffered defer:NO];
  self = [super initWithWindow:window];
  [window release];
  if( !self ) return nil;

  [window setTitle:@"Export Binary Data"];
  [window center];
  BinaryDataContainerView *container = [[BinaryDataContainerView alloc]
    initWithFrame:[[window contentView] bounds]];
  __block SaveBinaryController *controller = self;
  container.chooseHandler = ^{ [controller chooseFile:nil]; };
  container.applyHandler = ^{ [controller apply:nil]; };
  container.cancelHandler = ^{ [controller cancel:nil]; };
  [window setContentView:container];
  [container release];
  return self;
}

- (IBAction)apply:(id)sender
{
  BinaryDataContainerView *view = (id)[[self window] contentView];

  if( ![view canApply] ) return;
  if( utils_save_binary( (libspectrum_word)[view startValue],
                        (size_t)[view lengthValue],
                        [[view filename] fileSystemRepresentation] ) ) return;
  [self cancel:self];
}

- (IBAction)cancel:(id)sender
{
  [NSApp stopModal];
  [[self window] orderOut:nil];
}

- (void)showWindow:(id)sender
{
  if( [[self window] isVisible] ) return;
  [[EmulationSessionController instance] pause];
  [(BinaryDataContainerView *)[[self window] contentView] reset];
  [super showWindow:sender];
  [NSApp runModalForWindow:[self window]];
  [[self window] orderOut:nil];
  [[EmulationSessionController instance] unpause];
}

- (IBAction)chooseFile:(id)sender
{
  NSSavePanel *panel = [NSSavePanel savePanel];
  if( [panel runModal] == NSModalResponseOK ) {
    [(BinaryDataContainerView *)[[self window] contentView]
      selectFile:[[panel URL] path] importLength:nil];
  }
}

@end
