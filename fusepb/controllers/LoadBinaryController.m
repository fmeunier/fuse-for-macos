/* LoadBinaryController.m: Routines for dealing with the Load Binary Panel
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
#include <string.h>

#import "LoadBinaryController.h"
#import "BinaryDataContainerView.h"
#import "EmulationSessionController.h"

#include "memory_pages.h"
#include "spectrum.h"
#include <libspectrum.h>
#include "utils.h"

static utils_file u_file;

@implementation LoadBinaryController

- (id)init
{
  NSWindow *window = [[NSWindow alloc]
    initWithContentRect:NSMakeRect( 0, 0, 580, 200 )
              styleMask:NSWindowStyleMaskTitled
                backing:NSBackingStoreBuffered defer:NO];
  self = [super initWithWindow:window];
  [window release];
  if( !self ) return nil;

  [window setTitle:@"Import Binary Data"];
  [window center];
  BinaryDataContainerView *container = [[BinaryDataContainerView alloc]
    initWithFrame:[[window contentView] bounds]];
  __block LoadBinaryController *controller = self;
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
  size_t i, length = [view lengthValue];
  libspectrum_word start = (libspectrum_word)[view startValue];

  if( ![view canApply] || !u_file.buffer || length > u_file.length ) return;

  for( i = 0; i < length; i++ )
    writebyte_internal( (libspectrum_word)(start + i), u_file.buffer[i] );

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
  utils_close_file( &u_file );
  memset( &u_file, 0, sizeof( u_file ) );
  [[EmulationSessionController instance] unpause];
}

- (IBAction)chooseFile:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setAllowsMultipleSelection:NO];
  [panel setCanChooseDirectories:NO];
  if( [panel runModal] == NSModalResponseOK ) {
    utils_file new_file;
    NSString *path = [[panel URL] path];

    if( utils_read_file( [path fileSystemRepresentation], &new_file ) ) return;
    utils_close_file( &u_file );
    u_file = new_file;
    [(BinaryDataContainerView *)[[self window] contentView]
      selectFile:path importLength:@(new_file.length)];
  }
}

@end
