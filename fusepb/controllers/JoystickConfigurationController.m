/* JoystickConfigurationController.m: Routines for dealing with the joystick cofiguration panel
   Copyright (c) 2004 Fredrick Meunier

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

#import "JoystickConfigurationController.h"

#include <config.h>

#include <assert.h>

#include "settings.h"

@interface JoystickConfigurationContainerView : NSView

- (void)configureWithController:(NSObject *)controller;
- (void)configureForTargetNumber:(NSNumber *)targetNumber
                           xAxis:(NSNumber *)xAxis
                           yAxis:(NSNumber *)yAxis
                       fireValues:(NSArray *)fireValues;
- (NSDictionary *)defaultsValues;

@end

static NSArray *
joystick_fire_values_for_settings( int joystick_number )
{
  NSMutableArray *values;

  values = [NSMutableArray arrayWithCapacity:15];

  switch( joystick_number ) {
  case 1:
    [values addObject:@(settings_current.joystick_1_fire_1)];
    [values addObject:@(settings_current.joystick_1_fire_2)];
    [values addObject:@(settings_current.joystick_1_fire_3)];
    [values addObject:@(settings_current.joystick_1_fire_4)];
    [values addObject:@(settings_current.joystick_1_fire_5)];
    [values addObject:@(settings_current.joystick_1_fire_6)];
    [values addObject:@(settings_current.joystick_1_fire_7)];
    [values addObject:@(settings_current.joystick_1_fire_8)];
    [values addObject:@(settings_current.joystick_1_fire_9)];
    [values addObject:@(settings_current.joystick_1_fire_10)];
    [values addObject:@(settings_current.joystick_1_fire_11)];
    [values addObject:@(settings_current.joystick_1_fire_12)];
    [values addObject:@(settings_current.joystick_1_fire_13)];
    [values addObject:@(settings_current.joystick_1_fire_14)];
    [values addObject:@(settings_current.joystick_1_fire_15)];
    break;
  case 2:
    [values addObject:@(settings_current.joystick_2_fire_1)];
    [values addObject:@(settings_current.joystick_2_fire_2)];
    [values addObject:@(settings_current.joystick_2_fire_3)];
    [values addObject:@(settings_current.joystick_2_fire_4)];
    [values addObject:@(settings_current.joystick_2_fire_5)];
    [values addObject:@(settings_current.joystick_2_fire_6)];
    [values addObject:@(settings_current.joystick_2_fire_7)];
    [values addObject:@(settings_current.joystick_2_fire_8)];
    [values addObject:@(settings_current.joystick_2_fire_9)];
    [values addObject:@(settings_current.joystick_2_fire_10)];
    [values addObject:@(settings_current.joystick_2_fire_11)];
    [values addObject:@(settings_current.joystick_2_fire_12)];
    [values addObject:@(settings_current.joystick_2_fire_13)];
    [values addObject:@(settings_current.joystick_2_fire_14)];
    [values addObject:@(settings_current.joystick_2_fire_15)];
    break;
  default:
    assert( 0 );
  }

  return values;
}

@implementation JoystickConfigurationController

- (id)init
{
  NSPanel *window;

  window = [[[NSPanel alloc] initWithContentRect:NSMakeRect( 82, 198, 696, 312 )
                                       styleMask:NSWindowStyleMaskTitled |
                                                 NSWindowStyleMaskClosable
                                         backing:NSBackingStoreBuffered
                                           defer:NO] autorelease];

  self = [super initWithWindow:window];
  if( !self ) return nil;

  [window setTitle:@"Real Joystick Setup"];
  [window setReleasedWhenClosed:NO];
  [window setHidesOnDeactivate:YES];
  [window setMinSize:NSMakeSize( 696, 312 )];

  containerView = [[JoystickConfigurationContainerView alloc]
                    initWithFrame:NSMakeRect( 0, 0, 696, 312 )];
  [containerView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [containerView configureWithController:self];
  [[self window] setContentView:containerView];

  [self setWindowFrameAutosaveName:@"JoystickConfigurationWindow"];

  return self;
}

- (void)dealloc
{
  [containerView release];

  [super dealloc];
}

- (IBAction)apply:(id)sender
{
  NSUserDefaults *currentValues;
  NSDictionary *defaultsValues;
  NSEnumerator *key_enumerator;
  id key;

  currentValues = [NSUserDefaults standardUserDefaults];

  defaultsValues = [containerView defaultsValues];
  key_enumerator = [defaultsValues keyEnumerator];

  while( ( key = [key_enumerator nextObject] ) ) {
    [currentValues setObject:[defaultsValues objectForKey:key] forKey:key];
  }

  [self cancel:self];
}

- (IBAction)cancel:(id)sender
{
  [NSApp stopModal];
  [[self window] close];
}

- (void)showWindow:(id)sender
{
  int x_axis, y_axis;

  joyNum = [sender tag];

  switch( joyNum ) {
  case 1:
    x_axis = settings_current.joy1_xaxis;
    y_axis = settings_current.joy1_yaxis;
    break;
  case 2:
    x_axis = settings_current.joy2_xaxis;
    y_axis = settings_current.joy2_yaxis;
    break;
  default:
    assert( 0 );
  }

  [containerView configureForTargetNumber:@(joyNum)
                                     xAxis:@(x_axis)
                                     yAxis:@(y_axis)
                                fireValues:joystick_fire_values_for_settings( joyNum )];

  [[self window] makeFirstResponder:nil];
  [super showWindow:sender];

  [NSApp runModalForWindow:[self window]];
}

@end
