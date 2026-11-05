#!/usr/bin/env python3
"""Exercise the Cocoa ROM boundary without running the emulator.

Run from the repository root: python3 fusepb/tests/test_rom_preferences.py
Compiles the actual generated mapping functions and controller methods with
small core/session stand-ins. Requires macOS, Python 3 and Xcode tools.
"""

import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]


def function(source, signature):
  start = source.index(signature)
  opening = source.index("{", start)
  depth = 1
  end = opening + 1
  while depth:
    depth += (source[end] == "{") - (source[end] == "}")
    end += 1
  return source[start:end]


def run_harness(directory, name, source):
  path = directory / (name + ".m")
  binary = directory / name
  path.write_text(source)
  subprocess.run([
    "xcrun", "clang", "-Wall", "-Wextra", "-Werror", "-Wno-unused-parameter",
    "-fobjc-exceptions", "-framework", "Foundation", str(path), "-o", str(binary),
  ], check=True)
  subprocess.run([str(binary)], check=True)
  print(name + ": passed")


def mapping_harness(generated):
  constructor = function(generated, "NSMutableArray*\nsettings_set_rom_array(")
  exporter = function(generated, "void\nsettings_get_rom_array(")
  fields = sorted(set(re.findall(r"settings->(rom_\w+)", constructor + exporter)))
  declarations = "\n".join("  char *" + name + ";" for name in fields)
  initialisers = "\n".join(
    '  settings_default.{0} = "{0}.rom";'.format(name) for name in fields)
  checks = "\n".join(
    '  assert(settings.{0} && !strcmp(settings.{0}, custom ? "/custom.rom" : settings_default.{0}));'.format(name)
    for name in fields)
  frees = "\n".join("  free(settings." + name + ");" for name in fields)
  # Use exactly the generated ROM preference reads, not a parallel mapping.
  reads = re.findall(
    r"  settings_set_string\( &settings->rom_\w+,\n"
    r"    settings_rom_path_value\( .*?\n.*? \) \);", generated)
  assert reads
  read_fields = set(re.findall(r"settings->(rom_\w+)", "\n".join(reads)))
  assert set(fields) <= read_fields
  declarations = "\n".join("  char *" + name + ";" for name in sorted(read_fields))
  # The load path includes ROMs which have no row in this dialog.
  initialisers = "\n".join(
    '  settings_default.{0} = "{0}.rom";'.format(name) for name in sorted(read_fields))
  free_all = "\n".join("  free(settings." + name + ");" for name in sorted(read_fields))
  return r'''
#import <Foundation/Foundation.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
typedef NSInteger libspectrum_machine;
static const NSUInteger machine_count = 32;
static libspectrum_machine machine_get_type(const char *name) {
  static NSMutableArray *names;
  if (!names) names = [NSMutableArray new];
  NSString *value = @(name);
  if (![names containsObject:value]) [names addObject:value];
  return [names indexOfObject:value];
}
static int machine_get_index(libspectrum_machine type) { return (int)type; }
@interface Machine : NSObject { libspectrum_machine type; }
+ (Machine *)machineForType:(libspectrum_machine)value;
- (libspectrum_machine)machineType;
- (NSString *)machineName;
@end
@implementation Machine
+ (Machine *)machineForType:(libspectrum_machine)value {
  Machine *machine = [[[self alloc] init] autorelease];
  machine->type = value;
  return machine;
}
- (libspectrum_machine)machineType { return type; }
- (NSString *)machineName { return @"Machine"; }
@end
typedef struct {
''' + declarations + r'''
} settings_info;
static settings_info settings_default;
static void settings_set_string(char **target, const char *value) {
  free(*target);
  *target = value ? strdup(value) : NULL;
}
''' + function(generated, "static const char *\nsettings_rom_path_value(") + "\n" + function(
    generated, "static NSString *\nsettings_rom_path_string(") + "\n" + function(
    generated, "NSInteger\nmachineroms_compare(") + "\n" + constructor + "\n" + exporter + r'''
static void read_rom_preferences(settings_info *settings, NSUserDefaults *defaults) {
''' + "\n".join(reads) + r'''
}
int main(void) {
  @autoreleasepool {
''' + initialisers + r'''
    settings_info settings = {0};
    NSMutableArray *rows = settings_set_rom_array(&settings);
    assert([rows count] > 20);
    // Null core paths become editable blanks, then export to defaults.
    settings_get_rom_array(&settings, rows);
    for (int custom = 0; custom < 2; custom++) {
      if (custom) {
        for (NSMutableDictionary *row in rows) {
          for (int i = 0; i < 4; i++) {
            NSString *key = [NSString stringWithFormat:@"rom%d", i];
            if ([row objectForKey:key]) [row setObject:@"/custom.rom" forKey:key];
          }
        }
        settings_get_rom_array(&settings, rows);
      } else {
        // Export must not overwrite the dialog's blank presentation values.
        for (NSDictionary *row in rows) assert([[row objectForKey:@"rom0"] isEqual:@""]);
      }
''' + checks + r'''
    }
    // Reset all rows using the same default keys as the dialog.
    for (NSMutableDictionary *row in rows) {
      for (int i = 0; i < 4; i++) {
        NSString *key = [NSString stringWithFormat:@"rom%d", i];
        NSString *value = [row objectForKey:[@"default_" stringByAppendingString:key]];
        if (value) [row setObject:value forKey:key];
      }
    }
    settings_get_rom_array(&settings, rows);
    {
      int custom = 0;
''' + checks + r'''
    }
''' + frees + r'''
    memset(&settings, 0, sizeof(settings));
    NSString *domain = [[NSUUID UUID] UUIDString];
    NSUserDefaults *defaults = [[[NSUserDefaults alloc] initWithSuiteName:domain] autorelease];
    // Missing, explicitly empty, and custom persisted paths.
    for (int state = 0; state < 3; state++) {
      NSMutableDictionary *values = [NSMutableDictionary dictionary];
      for (NSString *key in @[
''' + ",\n".join('        @"' + key + '"' for key in re.findall(r'stringForKey:@"([^"]+)"', "\n".join(reads))) + r'''
      ]) {
        if (state) [values setObject:state == 1 ? @"" : @"/custom.rom" forKey:key];
      }
      [defaults setPersistentDomain:values forName:domain];
      read_rom_preferences(&settings, defaults);
      int custom = state == 2;
''' + checks + r'''
    }
    [defaults removePersistentDomainForName:domain];
''' + free_all + r'''
  }
  return 0;
}
'''


def controller_harness(controller):
  lookup = function(controller, "BOOL\ncocoa_machine_rom_file_exists(")
  show = function(controller, "- (void)showWindow:(id)sender")
  return r'''
#import <Foundation/Foundation.h>
#include <assert.h>
#include <limits.h>
#include <string.h>
static NSString *search_directory;
#define UTILS_AUXILIARY_ROM 0
// Match utils_find_file_path's absolute-path success without existence check.
static int utils_find_file_path(const char *filename, char *path, int type) {
  NSString *name = @(filename);
  if (![name isAbsolutePath]) name = [search_directory stringByAppendingPathComponent:name];
  snprintf(path, PATH_MAX, "%s", [name fileSystemRepresentation]);
  return 0;
}
''' + lookup + r'''
static int pause_count, fail_stage, current_stage;
static void step(void) {
  if (++current_stage == fail_stage)
    [NSException raise:@"TestException" format:@"Injected Preferences failure"];
}
@interface EmulationSessionController : NSObject
+ (instancetype)instance;
- (void)pause;
- (void)unpause;
@end
@implementation EmulationSessionController
+ (instancetype)instance {
  static EmulationSessionController *instance;
  if (!instance) instance = [self new];
  return instance;
}
- (void)pause { pause_count++; }
- (void)unpause { pause_count--; }
@end
static int settings_current;
static void settings_write_config(int *settings) { step(); }
static NSMutableArray *settings_set_rom_array(int *settings) {
  step();
  return [NSMutableArray array];
}
static NSString * const NSWindowWillCloseNotification = @"TestWindowWillClose";
@interface TestRoot : NSObject
- (void)schedulePeripheralsWarmup;
@end
@implementation TestRoot
- (void)schedulePeripheralsWarmup { step(); }
@end
@interface TestApplication : NSObject
- (void)runModalForWindow:(id)window;
@end
@implementation TestApplication
- (void)runModalForWindow:(id)window { assert(pause_count == 1); step(); }
@end
static TestApplication *NSApp;
@interface TestWindowController : NSObject
- (void)showWindow:(id)sender;
@end
@implementation TestWindowController
- (void)showWindow:(id)sender { step(); }
@end
@interface PreferencesController : TestWindowController {
  NSMutableArray *machineRoms;
  TestRoot *preferencesRootContainerView;
}
- (void)configurePreferencesRootContainerView;
- (void)fixPhantomTypistMode;
- (id)window;
- (void)handleWillClose:(NSNotification *)note;
@end
@implementation PreferencesController
- (instancetype)init {
  if ((self = [super init])) preferencesRootContainerView = [TestRoot new];
  return self;
}
- (void)dealloc {
  [machineRoms release];
  [preferencesRootContainerView release];
  [super dealloc];
}
- (void)configurePreferencesRootContainerView { step(); }
- (void)fixPhantomTypistMode { step(); }
- (id)window { return self; }
- (void)handleWillClose:(NSNotification *)note { assert(0); }
''' + show + r'''
@end
int main(void) {
  @autoreleasepool {
    NSFileManager *manager = [NSFileManager defaultManager];
    search_directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    assert([manager createDirectoryAtPath:search_directory withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *path = [search_directory stringByAppendingPathComponent:@"test.rom"];
    assert([[@"ROM" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES]);
    assert(!cocoa_machine_rom_file_exists(NULL));
    assert(!cocoa_machine_rom_file_exists(""));
    assert(cocoa_machine_rom_file_exists([path fileSystemRepresentation]));
    assert(cocoa_machine_rom_file_exists("test.rom"));
    assert(!cocoa_machine_rom_file_exists([search_directory fileSystemRepresentation]));
    assert([manager removeItemAtPath:path error:NULL]);
    assert(!cocoa_machine_rom_file_exists([path fileSystemRepresentation]));
    assert(!cocoa_machine_rom_file_exists("test.rom"));
    assert([manager removeItemAtPath:search_directory error:NULL]);
    NSApp = [TestApplication new];
    PreferencesController *preferences = [PreferencesController new];
    // Exercise normal return, then exceptions at every setup/modal stage.
    for (fail_stage = 0; fail_stage <= 7; fail_stage++) {
      current_stage = 0;
      BOOL caught = NO;
      @try { [preferences showWindow:nil]; }
      @catch (NSException *exception) { caught = YES; }
      assert(caught == (fail_stage != 0));
      assert(pause_count == 0);
      // No stale close observer may remain after failure or normal return.
      [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowWillCloseNotification object:preferences];
    }
    [preferences release];
    [NSApp release];
  }
  return 0;
}
'''


def main():
  generated = subprocess.check_output([
    "perl", "-Iperl", "settings.pl", "settings.dat",
  ], cwd=ROOT / "fuse", text=True)
  controller = (ROOT / "fusepb/controllers/PreferencesController.m").read_text()
  with tempfile.TemporaryDirectory(prefix="fuse-rom-tests-") as directory:
    directory = pathlib.Path(directory)
    run_harness(directory, "rom-mappings", mapping_harness(generated))
    run_harness(directory, "rom-controller", controller_harness(controller))


if __name__ == "__main__":
  main()
