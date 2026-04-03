/* PreferencesController.m: Routines for dealing with the Preferences Panel
   Copyright (c) 2005 Fredrick Meunier

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

#include <libspectrum.h>

#include <string.h>

#import "FuseController.h"
#import "DisplayOpenGLView.h"
#import "JoystickConfigurationController.h"
#import "PreferencesController.h"
#import "CAMachines.h"
#import "Joysticks.h"
#import "HIDJoysticks.h"

#import "ScalerNameToIdTransformer.h"
#import "MachineScalerIsEnabled.h"
#import "MachineNameToIdTransformer.h"
#import "VolumeSliderToPrefTransformer.h"

#include "fuse.h"
#include "joystick.h"
#include "options_cocoa.h"
#include "periph.h"
#include "printer.h"
#include "settings.h"
#include "settings_cocoa.h"
#include "sound.h"
#include "machine.h"
#include "ui.h"
#include "ui/scaler/scaler.h"
#include "ui/uidisplay.h"

#define NONE 100

static NSString *preferences_toolbar_identifiers[] = {
  @"General",
  @"Sound",
  @"Peripherals",
  @"Recording",
  @"Inputs",
  @"ROM",
  @"Machine",
  @"Video",
};

static NSString *preferences_toolbar_symbols[] = {
  @"gearshape",
  @"speaker.wave.2",
  @"externaldrive",
  @"record.circle",
  @"gamecontroller",
  @"memorychip",
  @"desktopcomputer",
  @"sparkles.tv",
};

static NSImage *
preferences_toolbar_image( NSString *symbol_name )
{
  NSImage *image;
  NSImageSymbolConfiguration *configuration;

  configuration = [NSImageSymbolConfiguration configurationWithPointSize:20.0
                                                                  weight:NSFontWeightRegular];
  image = [NSImage imageWithSystemSymbolName:symbol_name
                       accessibilityDescription:nil];
  image = [[image imageWithSymbolConfiguration:configuration] copy];
  [image setTemplate:YES];

  return [image autorelease];
}

static void
replace_preferences_view_subviews( NSView *container, NSView *replacement )
{
  NSEnumerator *enumerator;
  NSView *subview;

  enumerator = [[container subviews] objectEnumerator];
  while( ( subview = [enumerator nextObject] ) ) {
    [subview removeFromSuperview];
  }

  [replacement setFrame:[container bounds]];
  [replacement setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [container addSubview:replacement];
}

NSArray *
cocoa_inputs_joysticks( void )
{
  return [[Joystick allJoysticks] valueForKey:@"joystickName"];
}

NSArray *
cocoa_inputs_hid_joysticks( void )
{
  return [[HIDJoystick allJoysticks] valueForKey:@"joystickName"];
}

NSArray *
cocoa_machine_names( void )
{
  return [[Machine allMachines] valueForKey:@"machineName"];
}

NSArray *
cocoa_machine_ids( void )
{
  NSArray *machines;
  NSMutableArray *machine_ids;
  NSEnumerator *enumerator;
  Machine *machine;

  machines = [Machine allMachines];
  machine_ids = [NSMutableArray arrayWithCapacity:[machines count]];
  enumerator = [machines objectEnumerator];

  while( ( machine = [enumerator nextObject] ) ) {
    const char *machine_id;

    machine_id = machine_get_id( [machine machineType] );
    [machine_ids addObject:machine_id ? @(machine_id) : @""];
  }

  return machine_ids;
}

BOOL
cocoa_video_machine_is_timex_enabled( void )
{
  NSUserDefaults *defaults;
  fuse_machine_info *machine_info;

  defaults = [NSUserDefaults standardUserDefaults];
  machine_info = machine_get_machine_info( [[defaults stringForKey:@"machine"] UTF8String] );

  return machine_info && machine_info->timex ? YES : NO;
}

BOOL
cocoa_video_machine_is_timex_disabled( void )
{
  return cocoa_video_machine_is_timex_enabled() ? NO : YES;
}

@implementation PreferencesController

+(void) initialize
{
  ScalerNameToIdTransformer *sNToITransformer;
  MachineScalerIsEnabled *machineScalerIsEnabled;
  MachineNameToIdTransformer *mToITransformer;
  VolumeSliderToPrefTransformer *vsToPTransformer;

  sNToITransformer = [[[ScalerNameToIdTransformer alloc] init] autorelease];

  [NSValueTransformer setValueTransformer:sNToITransformer
                                  forName:@"ScalerNameToIdTransformer"];

  machineScalerIsEnabled = [MachineScalerIsEnabled
                                machineScalerIsEnabledWithInt:1];

  [NSValueTransformer setValueTransformer:machineScalerIsEnabled
                                  forName:@"MachineTimexIsEnabled"];

  machineScalerIsEnabled = [MachineScalerIsEnabled
                                machineScalerIsEnabledWithInt:0];

  [NSValueTransformer setValueTransformer:machineScalerIsEnabled
                                  forName:@"MachineTimexIsDisabled"];

  mToITransformer = [[[MachineNameToIdTransformer alloc] init] autorelease];

  [NSValueTransformer setValueTransformer:mToITransformer
                                  forName:@"MachineNameToIdTransformer"];
								  
  vsToPTransformer = [[[VolumeSliderToPrefTransformer alloc] init] autorelease];

  [NSValueTransformer setValueTransformer:vsToPTransformer
                                  forName:@"VolumeSliderToPrefTransformer"];
}

- (void)windowDidLoad 
{ 
  [super windowDidLoad];
  [[self window] setFrameUsingName:@"PreferencesWindow"];
} 

- (void)windowDidMove: (NSNotification *)aNotification 
{ 
  [[self window] saveFrameUsingName:@"PreferencesWindow"];
} 

- (id)init
{
  self = [super initWithWindowNibName:@"Preferences"];

  return self;
}

- (void)awakeFromNib
{
  Class general_preferences_view_class;
  id general_preferences_view;
  Class sound_preferences_view_class;
  id sound_preferences_view;
  Class peripherals_preferences_view_class;
  id peripherals_preferences_view;
  Class recording_preferences_view_class;
  id recording_preferences_view;
  Class inputs_preferences_view_class;
  id inputs_preferences_view;
  Class machine_preferences_view_class;
  id machine_preferences_view;
  Class rom_preferences_view_class;
  id rom_preferences_view;
  Class video_preferences_view_class;
  id video_preferences_view;
  unsigned int selected_tab;
  NSToolbarItem *item;

  toolbar = [[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"];
  [toolbar setAllowsUserCustomization:NO];
  [toolbar setShowsBaselineSeparator:NO];
  [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
  [toolbar setSizeMode:NSToolbarSizeModeRegular];
  [toolbar setDelegate:self];
  [[self window] setToolbar:toolbar];
  [toolbar release];
  toolbar = [[self window] toolbar];

  general_preferences_view_class = NSClassFromString( @"GeneralPreferencesContainerView" );
  if( general_preferences_view_class ) {
    general_preferences_view = [[[general_preferences_view_class alloc]
                                 initWithFrame:[generalPrefsView bounds]] autorelease];
    if( [general_preferences_view respondsToSelector:@selector(configureWithResetTarget:action:)] ) {
      [general_preferences_view configureWithResetTarget:self
                                                  action:@selector(resetUserDefaults:)];
    }
    replace_preferences_view_subviews( generalPrefsView, general_preferences_view );
  }

  sound_preferences_view_class = NSClassFromString( @"SoundPreferencesContainerView" );
  if( sound_preferences_view_class ) {
    sound_preferences_view = [[[sound_preferences_view_class alloc]
                               initWithFrame:[soundPrefsView bounds]] autorelease];
    replace_preferences_view_subviews( soundPrefsView, sound_preferences_view );
  }

  peripherals_preferences_view_class = NSClassFromString( @"PeripheralsPreferencesContainerView" );
  if( peripherals_preferences_view_class ) {
    peripherals_preferences_view = [[[peripherals_preferences_view_class alloc]
                                     initWithFrame:[peripheralsPrefsView bounds]] autorelease];
    if( [peripherals_preferences_view respondsToSelector:@selector(configureWithFileChooserTarget:action:)] ) {
      [peripherals_preferences_view configureWithFileChooserTarget:self
                                                            action:@selector(chooseFile:)];
    }
    replace_preferences_view_subviews( peripheralsPrefsView, peripherals_preferences_view );
  }

  recording_preferences_view_class = NSClassFromString( @"RecordingPreferencesContainerView" );
  if( recording_preferences_view_class ) {
    recording_preferences_view = [[[recording_preferences_view_class alloc]
                                   initWithFrame:[rzxPrefsView bounds]] autorelease];
    replace_preferences_view_subviews( rzxPrefsView, recording_preferences_view );
  }

  inputs_preferences_view_class = NSClassFromString( @"InputsPreferencesContainerView" );
  if( inputs_preferences_view_class ) {
    inputs_preferences_view = [[[inputs_preferences_view_class alloc]
                                initWithFrame:[joysticksPrefsView bounds]] autorelease];
    if( [inputs_preferences_view respondsToSelector:@selector(configureWithSetupTarget:action:)] ) {
      [inputs_preferences_view configureWithSetupTarget:self
                                                 action:@selector(setup:)];
    }
    replace_preferences_view_subviews( joysticksPrefsView, inputs_preferences_view );
  }

  machine_preferences_view_class = NSClassFromString( @"MachinePreferencesContainerView" );
  if( machine_preferences_view_class ) {
    machine_preferences_view = [[[machine_preferences_view_class alloc]
                                 initWithFrame:[machinePrefsView bounds]] autorelease];
    replace_preferences_view_subviews( machinePrefsView, machine_preferences_view );
  }

  rom_preferences_view_class = NSClassFromString( @"ROMPreferencesContainerView" );
  if( rom_preferences_view_class ) {
    rom_preferences_view = [[[rom_preferences_view_class alloc]
                             initWithFrame:[romPrefsView bounds]] autorelease];
    if( [rom_preferences_view respondsToSelector:@selector(configureWithMachineRomsController:actionTarget:chooseAction:resetAction:)] ) {
      [rom_preferences_view configureWithMachineRomsController:machineRomsController
                                                   actionTarget:self
                                                   chooseAction:@selector(chooseROMFile:)
                                                    resetAction:@selector(resetROMFile:)];
    }
    replace_preferences_view_subviews( romPrefsView, rom_preferences_view );
  }

  video_preferences_view_class = NSClassFromString( @"VideoPreferencesContainerView" );
  if( video_preferences_view_class ) {
    video_preferences_view = [[[video_preferences_view_class alloc]
                               initWithFrame:[filterPrefsView bounds]] autorelease];
    replace_preferences_view_subviews( filterPrefsView, video_preferences_view );
  }

  [[self window] setToolbarStyle:NSWindowToolbarStylePreference];

  selected_tab = [[NSUserDefaults standardUserDefaults] integerForKey:@"preferencestab"];
  item = [[toolbar items] objectAtIndex:selected_tab];
  [toolbar setSelectedItemIdentifier:[item itemIdentifier]];
  [self selectPrefPanel:item];
}

- (NSArray *)toolbarItemIdentifiers
{
  return @[
    @"General",
    @"Sound",
    @"Peripherals",
    @"Recording",
    @"Inputs",
    @"ROM",
    @"Machine",
    @"Video",
  ];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)bar
        itemForItemIdentifier:(NSString *)item_identifier
    willBeInsertedIntoToolbar:(BOOL)flag
{
  unsigned int i;
  NSToolbarItem *item;

  for( i = 0; i < [self toolbarItemIdentifiers].count; i++ ) {
    if( [item_identifier isEqualToString:preferences_toolbar_identifiers[i]] ) {
      item = [[[NSToolbarItem alloc] initWithItemIdentifier:item_identifier]
              autorelease];
      [item setLabel:preferences_toolbar_identifiers[i]];
      [item setPaletteLabel:preferences_toolbar_identifiers[i]];
      [item setImage:preferences_toolbar_image( preferences_toolbar_symbols[i] )];
      [item setTag:i];
      [item setTarget:self];
      [item setAction:@selector(selectPrefPanel:)];
      [item setAutovalidates:NO];
      return item;
    }
  }

  return nil;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)bar
{
  return [self toolbarItemIdentifiers];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)bar
{
  return [self toolbarItemIdentifiers];
}

- (void)showWindow:(id)sender
{
  [[DisplayOpenGLView instance] pause];
  
  /* Values in Fuse may have been updated, put them in saved settings */
  settings_write_config( &settings_current );

  if( machineRoms ) {
    [machineRoms release];
    machineRoms = nil;
  }

  machineRoms = settings_set_rom_array( &settings_current );
  [machineRoms retain];

  [super showWindow:sender];

  [self fixPhantomTypistMode];

  [[NSNotificationCenter defaultCenter] addObserver:self
		 selector:@selector(handleWillClose:)
			 name:@"NSWindowWillCloseNotification"
		   object:[self window]];

  [NSApp runModalForWindow:[self window]];
}

- (void)fixPhantomTypistMode
{
  NSUserDefaults *currentValues = [NSUserDefaults standardUserDefaults];
  const char *setting = settings_current.phantom_typist_mode;
  
  if( strcasecmp( setting, "Keyword" ) == 0 ) {
    [currentValues setObject:@"Keyword" forKey:@"phantomtypistmode"];
  } else if( strcasecmp( setting, "Keystroke" ) == 0) {
    [currentValues setObject:@"Keystroke" forKey:@"phantomtypistmode"];
  } else if( strcasecmp( setting, "Menu" ) == 0) {
    [currentValues setObject:@"Menu" forKey:@"phantomtypistmode"];
  } else if( strcasecmp( setting, "Plus 2A" ) == 0 ||
            strcasecmp( setting, "plus2a" ) == 0) {
    [currentValues setObject:@"Plus 2A" forKey:@"phantomtypistmode"];
  } else if( strcasecmp( setting, "Plus 3" ) == 0 ||
            strcasecmp( setting, "plus3" ) == 0) {
    [currentValues setObject:@"Plus 3" forKey:@"phantomtypistmode"];
  } else if( strcasecmp( setting, "Disabled" ) == 0) {
    [currentValues setObject:@"Disabled" forKey:@"phantomtypistmode"];
  } else {
    [currentValues setObject:@"Auto" forKey:@"phantomtypistmode"];
  }
}

- (void)handleWillClose:(NSNotification *)note
{
  [NSApp stopModal];

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  int old_bilinear = settings_current.bilinear_filter;

  /* Values in shared defaults have been updated, pass them onto Fuse */
  read_config_file( &settings_current );

  if( strcmp( machine_current->id, settings_current.start_machine ) ) {
    machine_select_id( settings_current.start_machine );
  }

  // B&W TV status may have changed
  display_refresh_all();

  if( ( ( current_scaler != scaler_get_type(settings_current.start_scaler_mode) )
          && !scaler_select_id(settings_current.start_scaler_mode) ) ||
      old_bilinear != settings_current.bilinear_filter ) {
    uidisplay_hotswap_gfx_mode();
  }

  settings_get_rom_array( &settings_current, machineRoms );

  joystick_end();
  joystick_init( NULL );

  periph_posthook();

  [[DisplayOpenGLView instance] unpause];
}

- (IBAction)chooseFile:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  char buffer[PATH_MAX+1];
  int result;
  NSSavePanel *sPanel = [NSSavePanel savePanel];

  switch( [sender tag] ) {
  case 0:	/* graphic */
    [sPanel setAllowedFileTypes:@[@"pbm"]];
    break;
  case 1:	/* text */
    [sPanel setAllowedFileTypes:@[@"txt"]];
    break;
  }

  result = [sPanel runModal];
  if (result == NSOKButton) {
    NSString *oFile = [[sPanel URL] path];
    [oFile getFileSystemRepresentation:buffer maxLength:PATH_MAX];

    switch( [sender tag] ) {
    case 0:	/* graphic */
      [defaults setObject:@(buffer) forKey:@"graphicsfile"];
      break;
    case 1:	/* text */
      [defaults setObject:@(buffer) forKey:@"textfile"];
      break;
    }
    
    printer_end();
    printer_init( NULL );
  }
}

- (IBAction)setup:(id)sender
{
  if( !joystickConfigurationController ) {
    joystickConfigurationController = [[JoystickConfigurationController alloc]
                                        init];
  }

  [joystickConfigurationController showWindow:sender];
}

- (IBAction)chooseROMFile:(id)sender
{
  char buffer[PATH_MAX+1];
  int result;
  NSOpenPanel *oPanel = [NSOpenPanel openPanel];
  NSArray *romFileTypes = @[@"rom", @"ROM"];
  NSString *romString;

  [oPanel setAllowedFileTypes:romFileTypes];
  result = [oPanel runModal];
  if (result == NSOKButton) {
    NSString *key = NULL;
    NSString *oFile = [[oPanel URL] path];
    [oFile getFileSystemRepresentation:buffer maxLength:PATH_MAX];

    romString = @(buffer);

    switch( [sender tag] ) {
    case 0:
      key = @"rom0";
      break;
    case 1:
      key = @"rom1";
      break;
    case 2:
      key = @"rom2";
      break;
    case 3:
      key = @"rom3";
      break;
    }

    /* Update underlying model */
    [[machineRomsController selection] setValue:romString forKey:key];
  }
}

- (IBAction)resetROMFile:(id)sender
{
  NSString *romString;
  NSString *source_key = nil;
  NSString *dest_key = nil;

  switch( [sender tag] ) {
  case 0:
    source_key = @"default_rom0";
    dest_key = @"rom0";
    break;
  case 1:
    source_key = @"default_rom1";
    dest_key = @"rom1";
    break;
  case 2:
    source_key = @"default_rom2";
    dest_key = @"rom2";
    break;
  case 3:
    source_key = @"default_rom3";
    dest_key = @"rom3";
    break;
  }

  romString = [[machineRomsController selection] valueForKey:source_key];

  /* Update underlying model */
  [[machineRomsController selection] setValue:romString forKey:dest_key];
}

- (IBAction)resetUserDefaults:(id)sender
{
  int error;
  NSMutableArray *newMachineRoms;
  unsigned int i;

  error = NSRunAlertPanel(@"Are you sure you want to reset all your preferences to the default settings?", @"Fuse will change all custom settings to the values set when the program was first installed.", @"Cancel", @"OK", nil);

  if( error != NSAlertAlternateReturn ) return;

  [[NSUserDefaultsController sharedUserDefaultsController] revertToInitialValues:self];

  error = read_config_file( &settings_current );
  if( error ) ui_error( UI_ERROR_ERROR, "Error resetting preferences" );

  newMachineRoms = settings_set_rom_array( &settings_current );
  for( i=0; i<[newMachineRoms count]; i++ ) {
	[self replaceObjectInMachineRomsAtIndex:i withObject:[newMachineRoms objectAtIndex:i]];
  }
}

- (IBAction)selectPrefPanel:(id)item
{
  NSString *sender;

  if( item == nil ){  //set the pane to the default.
    sender = @"General";
    [toolbar setSelectedItemIdentifier:sender];
  } else {
    sender = [item label];
  }

  NSWindow *window = [self window];

  // make a temp pointer.
  NSView *prefsView = generalPrefsView;

  // set the title to the name of the Preference Item.
  [window setTitle:sender];

  if( [sender isEqualToString:@"Sound"] ) {
    prefsView = soundPrefsView;
  } else if( [sender isEqualToString:@"Peripherals"] ) {
    prefsView = peripheralsPrefsView;
  } else if( [sender isEqualToString:@"Recording"] ) {
    prefsView = rzxPrefsView;
  } else if( [sender isEqualToString:@"Inputs"] ) {
    prefsView = joysticksPrefsView;
  } else if( [sender isEqualToString:@"ROM"] ) {
    prefsView = romPrefsView;
  } else if( [sender isEqualToString:@"Machine"] ) {
    prefsView = machinePrefsView;
  } else if( [sender isEqualToString:@"Video"] ) {
    prefsView = filterPrefsView;
  }

  // to stop flicker, we make a temp blank view.
  NSView *tempView = [[NSView alloc] initWithFrame:[[window contentView] frame]];
  [window setContentView:tempView];
  [tempView release];

  // mojo to get the right frame for the new window.
  NSRect newFrame = [window frame];
  newFrame.size.height = [prefsView frame].size.height +
    ([window frame].size.height - [[window contentView] frame].size.height);
  newFrame.origin.y += ([[window contentView] frame].size.height -
                        [prefsView frame].size.height);

  // set the frame to newFrame and animate it.
  [window setShowsResizeIndicator:YES];
  [window setFrame:newFrame display:YES animate:YES];
  // set the main content view to the new view we have picked through the if structure above.
  [window setContentView:prefsView];

  [[NSUserDefaults standardUserDefaults]
    setObject:@([item tag]) forKey:@"preferencestab"];
}

// NSToolbar delegate method
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)bar
{
  // Every toolbar icon is selectable
  return [[bar items] valueForKey:@"itemIdentifier"];
}

- (unsigned int)countOfMachineRoms
{
  return [machineRoms count];
}

- (id)objectInMachineRomsAtIndex:(unsigned int)index
{
  return [machineRoms objectAtIndex:index];
}

- (void)insertObject:(id)anObject inMachineRomsAtIndex:(unsigned int)index
{
  [machineRoms insertObject:anObject atIndex:index];
}

- (void)removeObjectFromMachineRomsAtIndex:(unsigned int)index
{
  [machineRoms removeObjectAtIndex:index];
}

- (void)replaceObjectInMachineRomsAtIndex:(unsigned int)index withObject:(id)anObject
{
  [machineRoms replaceObjectAtIndex:index withObject:anObject];
}

@end
