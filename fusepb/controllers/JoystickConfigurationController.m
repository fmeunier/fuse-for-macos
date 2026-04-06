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

- (void)configureForTargetNumber:(NSNumber *)targetNumber
                           xAxis:(NSNumber *)xAxis
                           yAxis:(NSNumber *)yAxis
                       fireValues:(NSArray *)fireValues;
- (NSDictionary *)defaultsValues;
- (NSNumber *)selectedXAxisValue;
- (NSNumber *)selectedYAxisValue;
- (NSArray *)selectedFireValues;

@end

static void
update_current_joystick_settings( int joystick_number, int x_axis, int y_axis,
                                  NSArray *fire_values )
{
  switch( joystick_number ) {
  case 1:
    settings_current.joy1_xaxis = x_axis;
    settings_current.joy1_yaxis = y_axis;
    settings_current.joystick_1_fire_1 = [[fire_values objectAtIndex:0] intValue];
    settings_current.joystick_1_fire_2 = [[fire_values objectAtIndex:1] intValue];
    settings_current.joystick_1_fire_3 = [[fire_values objectAtIndex:2] intValue];
    settings_current.joystick_1_fire_4 = [[fire_values objectAtIndex:3] intValue];
    settings_current.joystick_1_fire_5 = [[fire_values objectAtIndex:4] intValue];
    settings_current.joystick_1_fire_6 = [[fire_values objectAtIndex:5] intValue];
    settings_current.joystick_1_fire_7 = [[fire_values objectAtIndex:6] intValue];
    settings_current.joystick_1_fire_8 = [[fire_values objectAtIndex:7] intValue];
    settings_current.joystick_1_fire_9 = [[fire_values objectAtIndex:8] intValue];
    settings_current.joystick_1_fire_10 = [[fire_values objectAtIndex:9] intValue];
    settings_current.joystick_1_fire_11 = [[fire_values objectAtIndex:10] intValue];
    settings_current.joystick_1_fire_12 = [[fire_values objectAtIndex:11] intValue];
    settings_current.joystick_1_fire_13 = [[fire_values objectAtIndex:12] intValue];
    settings_current.joystick_1_fire_14 = [[fire_values objectAtIndex:13] intValue];
    settings_current.joystick_1_fire_15 = [[fire_values objectAtIndex:14] intValue];
    break;
  case 2:
    settings_current.joy2_xaxis = x_axis;
    settings_current.joy2_yaxis = y_axis;
    settings_current.joystick_2_fire_1 = [[fire_values objectAtIndex:0] intValue];
    settings_current.joystick_2_fire_2 = [[fire_values objectAtIndex:1] intValue];
    settings_current.joystick_2_fire_3 = [[fire_values objectAtIndex:2] intValue];
    settings_current.joystick_2_fire_4 = [[fire_values objectAtIndex:3] intValue];
    settings_current.joystick_2_fire_5 = [[fire_values objectAtIndex:4] intValue];
    settings_current.joystick_2_fire_6 = [[fire_values objectAtIndex:5] intValue];
    settings_current.joystick_2_fire_7 = [[fire_values objectAtIndex:6] intValue];
    settings_current.joystick_2_fire_8 = [[fire_values objectAtIndex:7] intValue];
    settings_current.joystick_2_fire_9 = [[fire_values objectAtIndex:8] intValue];
    settings_current.joystick_2_fire_10 = [[fire_values objectAtIndex:9] intValue];
    settings_current.joystick_2_fire_11 = [[fire_values objectAtIndex:10] intValue];
    settings_current.joystick_2_fire_12 = [[fire_values objectAtIndex:11] intValue];
    settings_current.joystick_2_fire_13 = [[fire_values objectAtIndex:12] intValue];
    settings_current.joystick_2_fire_14 = [[fire_values objectAtIndex:13] intValue];
    settings_current.joystick_2_fire_15 = [[fire_values objectAtIndex:14] intValue];
    break;
  default:
    assert( 0 );
  }
}

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

@interface JoystickConfigurationController () <NSWindowDelegate>

- (void)installContainerView;

@end

@implementation JoystickConfigurationController

- (id)init
{
  self = [super initWithWindowNibName:@"JoystickConfiguration"];

  [self setWindowFrameAutosaveName:@"JoystickConfigurationSwiftUIWindow"];

  return self;
}

- (void)awakeFromNib
{
  NSWindow *window;

  window = [self window];
  [[self window] setDelegate:self];
  [window setContentMinSize:NSMakeSize( 696, 312 )];
  [window setContentSize:NSMakeSize( 696, 312 )];

  containerView = [[JoystickConfigurationContainerView alloc]
                    initWithFrame:[contentContainer bounds]];
  [containerView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  [self installContainerView];
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
  NSArray *fire_values;
  NSEnumerator *key_enumerator;
  id key;

  currentValues = [NSUserDefaults standardUserDefaults];

  defaultsValues = [containerView defaultsValues];
  key_enumerator = [defaultsValues keyEnumerator];

  while( ( key = [key_enumerator nextObject] ) ) {
    [currentValues setObject:[defaultsValues objectForKey:key] forKey:key];
  }

  fire_values = [containerView selectedFireValues];
  update_current_joystick_settings( joyNum,
                                    [[containerView selectedXAxisValue] intValue],
                                    [[containerView selectedYAxisValue] intValue],
                                    fire_values );

  [self cancel:self];
}

- (IBAction)cancel:(id)sender
{
  [NSApp stopModal];
  [[self window] close];
}

- (void)installContainerView
{
  [containerView setFrame:[contentContainer bounds]];
  [contentContainer addSubview:containerView];
}

- (void)windowWillClose:(NSNotification *)notification
{
  if( [notification object] == [self window] && [NSApp modalWindow] == [self window] ) {
    [NSApp stopModal];
  }
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

  [super showWindow:sender];
  [NSApp runModalForWindow:[self window]];
}

@end
