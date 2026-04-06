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
#import "PreferencesBridges.h"

#include <config.h>

#include <assert.h>

#include "settings.h"

@implementation JoystickConfigurationController

- (id)init
{
  self = [super initWithWindowNibName:@"JoystickConfiguration"];

  [self setWindowFrameAutosaveName:@"JoystickConfigurationWindow"];

  return self;
}

- (IBAction)apply:(id)sender;
{
  NSUserDefaults *currentValues = [NSUserDefaults standardUserDefaults];

  switch(joyNum) {
  case 1:
    [currentValues setObject:@([[joyFire1 selectedItem] tag]) forKey:@"joystick1fire1"];
    [currentValues setObject:@([[joyFire2 selectedItem] tag]) forKey:@"joystick1fire2"];
    [currentValues setObject:@([[joyFire3 selectedItem] tag]) forKey:@"joystick1fire3"];
    [currentValues setObject:@([[joyFire4 selectedItem] tag]) forKey:@"joystick1fire4"];
    [currentValues setObject:@([[joyFire5 selectedItem] tag]) forKey:@"joystick1fire5"];
    [currentValues setObject:@([[joyFire6 selectedItem] tag]) forKey:@"joystick1fire6"];
    [currentValues setObject:@([[joyFire7 selectedItem] tag]) forKey:@"joystick1fire7"];
    [currentValues setObject:@([[joyFire8 selectedItem] tag]) forKey:@"joystick1fire8"];
    [currentValues setObject:@([[joyFire9 selectedItem] tag]) forKey:@"joystick1fire9"];
    [currentValues setObject:@([[joyFire10 selectedItem] tag]) forKey:@"joystick1fire10"];
    [currentValues setObject:@([[joyFire11 selectedItem] tag]) forKey:@"joystick1fire11"];
    [currentValues setObject:@([[joyFire12 selectedItem] tag]) forKey:@"joystick1fire12"];
    [currentValues setObject:@([[joyFire13 selectedItem] tag]) forKey:@"joystick1fire13"];
    [currentValues setObject:@([[joyFire14 selectedItem] tag]) forKey:@"joystick1fire14"];
    [currentValues setObject:@([[joyFire15 selectedItem] tag]) forKey:@"joystick1fire15"];
    [currentValues setObject:@([[joyXAxis selectedItem] tag]) forKey:@"joy1x"];
    [currentValues setObject:@([[joyYAxis selectedItem] tag]) forKey:@"joy1y"];
    break;
  case 2:
    [currentValues setObject:@([[joyFire1 selectedItem] tag]) forKey:@"joystick2fire1"];
    [currentValues setObject:@([[joyFire2 selectedItem] tag]) forKey:@"joystick2fire2"];
    [currentValues setObject:@([[joyFire3 selectedItem] tag]) forKey:@"joystick2fire3"];
    [currentValues setObject:@([[joyFire4 selectedItem] tag]) forKey:@"joystick2fire4"];
    [currentValues setObject:@([[joyFire5 selectedItem] tag]) forKey:@"joystick2fire5"];
    [currentValues setObject:@([[joyFire6 selectedItem] tag]) forKey:@"joystick2fire6"];
    [currentValues setObject:@([[joyFire7 selectedItem] tag]) forKey:@"joystick2fire7"];
    [currentValues setObject:@([[joyFire8 selectedItem] tag]) forKey:@"joystick2fire8"];
    [currentValues setObject:@([[joyFire9 selectedItem] tag]) forKey:@"joystick2fire9"];
    [currentValues setObject:@([[joyFire10 selectedItem] tag]) forKey:@"joystick2fire10"];
    [currentValues setObject:@([[joyFire11 selectedItem] tag]) forKey:@"joystick2fire11"];
    [currentValues setObject:@([[joyFire12 selectedItem] tag]) forKey:@"joystick2fire12"];
    [currentValues setObject:@([[joyFire13 selectedItem] tag]) forKey:@"joystick2fire13"];
    [currentValues setObject:@([[joyFire14 selectedItem] tag]) forKey:@"joystick2fire14"];
    [currentValues setObject:@([[joyFire15 selectedItem] tag]) forKey:@"joystick2fire15"];
    [currentValues setObject:@([[joyXAxis selectedItem] tag]) forKey:@"joy2x"];
    [currentValues setObject:@([[joyYAxis selectedItem] tag]) forKey:@"joy2y"];
    break;
  default:
    assert(0);
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
  NSArray *key_titles;
  NSArray *key_values;
  size_t i;
  NSUInteger key_count;
  int x_axis = 0, y_axis = 0;

  joyNum = [sender tag];

  [super showWindow:sender];

  [joyXAxis removeAllItems];
  [joyYAxis removeAllItems];

  switch(joyNum) {
  case 1:
    [joyFire1 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_1]];
    [joyFire2 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_2]];
    [joyFire3 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_3]];
    [joyFire4 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_4]];
    [joyFire5 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_5]];
    [joyFire6 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_6]];
    [joyFire7 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_7]];
    [joyFire8 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_8]];
    [joyFire9 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_9]];
    [joyFire10 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_10]];
    [joyFire11 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_11]];
    [joyFire12 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_12]];
    [joyFire13 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_13]];
    [joyFire14 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_14]];
    [joyFire15 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_1_fire_15]];
    x_axis = settings_current.joy1_xaxis;
    y_axis = settings_current.joy1_yaxis;
    break;
  case 2:
    [joyFire1 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_1]];
    [joyFire2 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_2]];
    [joyFire3 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_3]];
    [joyFire4 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_4]];
    [joyFire5 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_5]];
    [joyFire6 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_6]];
    [joyFire7 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_7]];
    [joyFire8 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_8]];
    [joyFire9 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_9]];
    [joyFire10 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_10]];
    [joyFire11 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_11]];
    [joyFire12 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_12]];
    [joyFire13 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_13]];
    [joyFire14 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_14]];
    [joyFire15 selectItemAtIndex:[joyXAxis
                      indexOfItemWithTag:settings_current.joystick_2_fire_15]];
    x_axis = settings_current.joy2_xaxis;
    y_axis = settings_current.joy2_yaxis;
    break;
  default:
    assert(0);
  }

  for( i=0; i<15; i++ ) {
    [joyXAxis addItemWithTitle:[NSString stringWithFormat:@"%ld", i]];
    [[joyXAxis lastItem] setTag:i];
    [joyYAxis addItemWithTitle:[NSString stringWithFormat:@"%ld", i]];
    [[joyYAxis lastItem] setTag:i];

    if( i == x_axis ) {
      [joyXAxis selectItemAtIndex:[joyXAxis indexOfItemWithTag:i]];
    }

    if( i == y_axis ) {
      [joyYAxis selectItemAtIndex:[joyYAxis indexOfItemWithTag:i]];
    }
  }
  
  [joyFire1 removeAllItems];
  [joyFire2 removeAllItems];
  [joyFire3 removeAllItems];
  [joyFire4 removeAllItems];
  [joyFire5 removeAllItems];
  [joyFire6 removeAllItems];
  [joyFire7 removeAllItems];
  [joyFire8 removeAllItems];
  [joyFire9 removeAllItems];
  [joyFire10 removeAllItems];
  [joyFire11 removeAllItems];
  [joyFire12 removeAllItems];
  [joyFire13 removeAllItems];
  [joyFire14 removeAllItems];
  [joyFire15 removeAllItems];

  key_titles = cocoa_joystick_configuration_key_titles();
  key_values = cocoa_joystick_configuration_key_values();
  key_count = MIN( [key_titles count], [key_values count] );

  for( i = 0; i < key_count; i++ ) {
    NSString *title;
    NSInteger value;

    title = [key_titles objectAtIndex:i];
    value = [[key_values objectAtIndex:i] integerValue];

    [joyFire1 addItemWithTitle:title];
    [[joyFire1 lastItem] setTag:value];
    [joyFire2 addItemWithTitle:title];
    [[joyFire2 lastItem] setTag:value];
    [joyFire3 addItemWithTitle:title];
    [[joyFire3 lastItem] setTag:value];
    [joyFire4 addItemWithTitle:title];
    [[joyFire4 lastItem] setTag:value];
    [joyFire5 addItemWithTitle:title];
    [[joyFire5 lastItem] setTag:value];
    [joyFire6 addItemWithTitle:title];
    [[joyFire6 lastItem] setTag:value];
    [joyFire7 addItemWithTitle:title];
    [[joyFire7 lastItem] setTag:value];
    [joyFire8 addItemWithTitle:title];
    [[joyFire8 lastItem] setTag:value];
    [joyFire9 addItemWithTitle:title];
    [[joyFire9 lastItem] setTag:value];
    [joyFire10 addItemWithTitle:title];
    [[joyFire10 lastItem] setTag:value];
    [joyFire11 addItemWithTitle:title];
    [[joyFire11 lastItem] setTag:value];
    [joyFire12 addItemWithTitle:title];
    [[joyFire12 lastItem] setTag:value];
    [joyFire13 addItemWithTitle:title];
    [[joyFire13 lastItem] setTag:value];
    [joyFire14 addItemWithTitle:title];
    [[joyFire14 lastItem] setTag:value];
    [joyFire15 addItemWithTitle:title];
    [[joyFire15 lastItem] setTag:value];
  }

  switch(joyNum) {
  case 1:
    [joyFire1 selectItemAtIndex:[joyFire1
                      indexOfItemWithTag:settings_current.joystick_1_fire_1]];
    [joyFire2 selectItemAtIndex:[joyFire2
                      indexOfItemWithTag:settings_current.joystick_1_fire_2]];
    [joyFire3 selectItemAtIndex:[joyFire3
                      indexOfItemWithTag:settings_current.joystick_1_fire_3]];
    [joyFire4 selectItemAtIndex:[joyFire4
                      indexOfItemWithTag:settings_current.joystick_1_fire_4]];
    [joyFire5 selectItemAtIndex:[joyFire5
                      indexOfItemWithTag:settings_current.joystick_1_fire_5]];
    [joyFire6 selectItemAtIndex:[joyFire6
                      indexOfItemWithTag:settings_current.joystick_1_fire_6]];
    [joyFire7 selectItemAtIndex:[joyFire7
                      indexOfItemWithTag:settings_current.joystick_1_fire_7]];
    [joyFire8 selectItemAtIndex:[joyFire8
                      indexOfItemWithTag:settings_current.joystick_1_fire_8]];
    [joyFire9 selectItemAtIndex:[joyFire9
                      indexOfItemWithTag:settings_current.joystick_1_fire_9]];
    [joyFire10 selectItemAtIndex:[joyFire10
                      indexOfItemWithTag:settings_current.joystick_1_fire_10]];
    [joyFire11 selectItemAtIndex:[joyFire1
                      indexOfItemWithTag:settings_current.joystick_1_fire_11]];
    [joyFire12 selectItemAtIndex:[joyFire2
                      indexOfItemWithTag:settings_current.joystick_1_fire_12]];
    [joyFire13 selectItemAtIndex:[joyFire3
                      indexOfItemWithTag:settings_current.joystick_1_fire_13]];
    [joyFire14 selectItemAtIndex:[joyFire4
                      indexOfItemWithTag:settings_current.joystick_1_fire_14]];
    [joyFire15 selectItemAtIndex:[joyFire5
                      indexOfItemWithTag:settings_current.joystick_1_fire_15]];
    break;
  case 2:
    [joyFire1 selectItemAtIndex:[joyFire1
                      indexOfItemWithTag:settings_current.joystick_2_fire_1]];
    [joyFire2 selectItemAtIndex:[joyFire2
                      indexOfItemWithTag:settings_current.joystick_2_fire_2]];
    [joyFire3 selectItemAtIndex:[joyFire3
                      indexOfItemWithTag:settings_current.joystick_2_fire_3]];
    [joyFire4 selectItemAtIndex:[joyFire4
                      indexOfItemWithTag:settings_current.joystick_2_fire_4]];
    [joyFire5 selectItemAtIndex:[joyFire5
                      indexOfItemWithTag:settings_current.joystick_2_fire_5]];
    [joyFire6 selectItemAtIndex:[joyFire6
                      indexOfItemWithTag:settings_current.joystick_2_fire_6]];
    [joyFire7 selectItemAtIndex:[joyFire7
                      indexOfItemWithTag:settings_current.joystick_2_fire_7]];
    [joyFire8 selectItemAtIndex:[joyFire8
                      indexOfItemWithTag:settings_current.joystick_2_fire_8]];
    [joyFire9 selectItemAtIndex:[joyFire9
                      indexOfItemWithTag:settings_current.joystick_2_fire_9]];
    [joyFire10 selectItemAtIndex:[joyFire10
                      indexOfItemWithTag:settings_current.joystick_2_fire_10]];
    [joyFire11 selectItemAtIndex:[joyFire1
                      indexOfItemWithTag:settings_current.joystick_2_fire_11]];
    [joyFire12 selectItemAtIndex:[joyFire2
                      indexOfItemWithTag:settings_current.joystick_2_fire_12]];
    [joyFire13 selectItemAtIndex:[joyFire3
                      indexOfItemWithTag:settings_current.joystick_2_fire_13]];
    [joyFire14 selectItemAtIndex:[joyFire4
                      indexOfItemWithTag:settings_current.joystick_2_fire_14]];
    [joyFire15 selectItemAtIndex:[joyFire5
                      indexOfItemWithTag:settings_current.joystick_2_fire_15]];
    break;
  default:
    assert(0);
  }

  [NSApp runModalForWindow:[self window]];
}

@end
