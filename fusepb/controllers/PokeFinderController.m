/* PokeFinderController.m: Routines for dealing with the Poke Finder Panel
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

#import "PokeFinderController.h"
#import "EmulationSessionController.h"

#include "debugger/debugger.h"
#include "pokefinder/pokefinder.h"
#include "spectrum.h"

/* Match the Objective-C bridge used by the other SwiftUI containers. */
@interface PokeFinderContainerView : NSView
@property(copy) void (^searchHandler)(NSInteger);
@property(copy) void (^incrementHandler)(void);
@property(copy) void (^decrementHandler)(void);
@property(copy) void (^resetHandler)(void);
@property(copy) void (^closeHandler)(void);
@property(copy) void (^breakpointHandler)(NSInteger, NSInteger);
- (void)updateWithCount:(NSInteger)count locations:(NSArray *)locations;
@end

@implementation PokeFinderController

- (id)init
{
  NSWindow *window = [[NSWindow alloc]
    initWithContentRect:NSMakeRect( 0, 0, 360, 420 )
              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                         NSWindowStyleMaskResizable)
                backing:NSBackingStoreBuffered defer:NO];
  self = [super initWithWindow:window];
  [window release];
  if( !self ) return nil;

  [window setTitle:@"Poke Finder"];
  [window setContentMinSize:NSMakeSize( 320, 380 )];
  [window setDelegate:self];
  [window center];
  [self setWindowFrameAutosaveName:@"PokeFinderCompactWindow"];

  PokeFinderContainerView *container = [[PokeFinderContainerView alloc]
    initWithFrame:[[window contentView] bounds]];
  /* The controller owns the content view; blocks must not retain it back. */
  __block PokeFinderController *controller = self;
  container.searchHandler = ^(NSInteger value) {
    pokefinder_search( (int)value );
    [controller update_pokefinder];
  };
  container.incrementHandler = ^{
    pokefinder_incremented();
    [controller update_pokefinder];
  };
  container.decrementHandler = ^{
    pokefinder_decremented();
    [controller update_pokefinder];
  };
  container.resetHandler = ^{
    pokefinder_clear();
    [controller update_pokefinder];
  };
  container.closeHandler = ^{ [[controller window] close]; };
  container.breakpointHandler = ^(NSInteger bank, NSInteger offset) {
    (void)debugger_breakpoint_add_address( DEBUGGER_BREAKPOINT_TYPE_WRITE,
      memory_source_ram, (int)bank, offset, 0,
      DEBUGGER_BREAKPOINT_LIFE_PERMANENT, NULL );
  };
  [window setContentView:container];
  [container release];
  return self;
}

- (void)showWindow:(id)sender
{
  if( [[self window] isVisible] ) {
    [[self window] makeKeyAndOrderFront:sender];
    return;
  }

  [[EmulationSessionController instance] pause];
  [self update_pokefinder];
  [super showWindow:sender];
  [NSApp runModalForWindow:[self window]];
  [[self window] orderOut:nil];
  [[EmulationSessionController instance] unpause];
}

- (void)windowWillClose:(NSNotification *)notification
{
  if( [NSApp modalWindow] == [self window] ) [NSApp stopModal];
}

- (void)update_pokefinder
{
  NSMutableArray *locations = [NSMutableArray array];
  unsigned long page, offset;

  if( pokefinder_count && pokefinder_count <= 20 ) {
    for( page = 0; page < MEMORY_PAGES_IN_16K * SPECTRUM_RAM_PAGES; page++ ) {
      memory_page *mapping = &memory_map_ram[page];
      for( offset = 0; offset < MEMORY_PAGE_SIZE; offset++ ) {
        if( !(pokefinder_impossible[page][offset/8] & 1 << (offset & 7)) ) {
          [locations addObject:@{ @"bank": @(mapping->page_num),
                                 @"offset": @(mapping->offset + offset) }];
        }
      }
    }
  }
  [(PokeFinderContainerView *)[[self window] contentView]
    updateWithCount:pokefinder_count locations:locations];
}

@end
