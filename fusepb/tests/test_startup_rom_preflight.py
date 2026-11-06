#!/usr/bin/env python3
"""Exercise generated ROM metadata and the actual Cocoa startup preflight."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
header = (root / "fusepb/settings_cocoa.h").read_text()
metadata = header[header.index("static inline NSArray *\ncocoa_startup_rom_candidates"):header.rindex("#endif")]
source = (root / "fusepb/models/Emulator.m").read_text()
preflight = source[source.index("static BOOL\ncocoa_preflight_saved_machine"):source.index("@implementation Emulator")]
# Isolate preferences in this test; retain the actual selection logic.
preflight = preflight.replace("[NSUserDefaults standardUserDefaults]", "test_defaults")
harness = r'''
#import <Foundation/Foundation.h>
#include <assert.h>
#include <string.h>
static NSUserDefaults *test_defaults;
static NSSet *existing;
static BOOL cocoa_machine_rom_file_exists( const char *filename ) {
  return [existing containsObject:@(filename)];
}
METADATA
PREFLIGHT
int main( void ) {
  @autoreleasepool {
    NSString *suite = [[NSUUID UUID] UUIDString];
    test_defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    existing = [NSSet setWithArray:@[@"128p-0.rom", @"128p-1.rom", @"trdos.rom", @"48.rom"]];
    char *args[] = { "Fuse", NULL };
    assert( [cocoa_startup_rom_candidates(@"pentagon", test_defaults) count] == 3 );
    assert( [cocoa_startup_rom_candidates(@"pentagon512", test_defaults) count] == 4 );
    [test_defaults setObject:@"pentagon" forKey:@"machine"];
    assert( !cocoa_preflight_saved_machine(1, args) );
    [test_defaults setObject:@"pentagon512" forKey:@"machine"];
    assert( cocoa_preflight_saved_machine(1, args) );
    assert( [[test_defaults stringForKey:@"machine"] isEqualToString:@"48"] );

    [test_defaults setObject:@"pentagon512" forKey:@"machine"];
    [test_defaults setObject:@"/custom/gluck.rom" forKey:@"rompentagon5123"];
    existing = [existing setByAddingObject:@"/custom/gluck.rom"];
    assert( !cocoa_preflight_saved_machine(1, args) );
    [test_defaults setObject:@"" forKey:@"rompentagon5123"];
    assert( cocoa_preflight_saved_machine(1, args) );

    [test_defaults setObject:@"pentagon512" forKey:@"machine"];
    char *explicit_args[] = { "Fuse", "--machine", "pentagon512", NULL };
    assert( !cocoa_preflight_saved_machine(3, explicit_args) );
    char *short_args[] = { "Fuse", "-mpentagon512", NULL };
    assert( !cocoa_preflight_saved_machine(2, short_args) );
    char *equals_args[] = { "Fuse", "--machine=pentagon512", NULL };
    assert( !cocoa_preflight_saved_machine(2, equals_args) );

    // A missing custom path can still use the core's bundled default fallback.
    existing = [existing setByAddingObject:@"gluck.rom"];
    [test_defaults setObject:@"/missing/custom.rom" forKey:@"rompentagon5123"];
    assert( !cocoa_preflight_saved_machine(1, args) );
    [test_defaults removePersistentDomainForName:suite];
  }
  return 0;
}
'''.replace("METADATA", metadata).replace("PREFLIGHT", preflight)
with tempfile.TemporaryDirectory() as directory:
  path = pathlib.Path(directory) / "test.m"
  binary = pathlib.Path(directory) / "test"
  path.write_text(harness)
  subprocess.run(["xcrun", "clang", "-Wall", "-Wextra", "-Werror", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
  subprocess.run([str(binary)], check=True)
print("startup-rom-preflight: passed")
