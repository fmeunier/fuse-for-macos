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
#define PREFERENCES_CONTENT_WIDTH 680

@interface PreferencesRootContainerView : NSView

- (void)configureWithController:(NSObject *)controller
          machineRomsController:(NSArrayController *)machineRomsController;
- (void)selectPaneWithIdentifier:(NSString *)identifier;
- (NSSize)preferredPaneSize;

@end

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
  Class preferences_root_view_class;
  NSUInteger selected_tab;
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

  preferences_root_view_class = NSClassFromString( @"PreferencesRootContainerView" );
  if( preferences_root_view_class ) {
    preferencesRootContainerView = [[[preferences_root_view_class alloc]
                                     initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [self configurePreferencesRootContainerView];
    replace_preferences_view_subviews( [[self window] contentView], preferencesRootContainerView );
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

  [self configurePreferencesRootContainerView];

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
  NSInteger selected_tag;

  if( item == nil ){  //set the pane to the default.
    sender = @"General";
    [toolbar setSelectedItemIdentifier:sender];
    selected_tag = 0;
  } else {
    sender = [item label];
    selected_tag = [item tag];
  }

  NSWindow *window = [self window];
  // set the title to the name of the Preference Item.
  [window setTitle:sender];

  [preferencesRootContainerView selectPaneWithIdentifier:sender];
  [self applyPreferredPaneSize];

  [[NSUserDefaults standardUserDefaults]
    setObject:@(selected_tag) forKey:@"preferencestab"];
}

- (void)applyPreferredPaneSize
{
  NSWindow *window;
  NSRect current_frame;
  NSRect new_frame;
  NSSize content_size;

  if( !preferencesRootContainerView ) return;

  window = [self window];
  content_size = [preferencesRootContainerView preferredPaneSize];
  content_size.width = PREFERENCES_CONTENT_WIDTH;

  current_frame = [window frame];
  new_frame = [window frameRectForContentRect:NSMakeRect( 0, 0,
                                                          content_size.width,
                                                          content_size.height )];
  new_frame.origin.x = current_frame.origin.x;
  new_frame.origin.y = NSMaxY( current_frame ) - new_frame.size.height;

  [window setShowsResizeIndicator:YES];
  [window setFrame:new_frame display:YES animate:YES];
}

// NSToolbar delegate method
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)bar
{
  // Every toolbar icon is selectable
  return [[bar items] valueForKey:@"itemIdentifier"];
}

- (void)configurePreferencesRootContainerView
{
  if( !preferencesRootContainerView ) return;

  [preferencesRootContainerView configureWithController:self
                                  machineRomsController:machineRomsController];
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
