#!/usr/bin/env python3
"""Check the Cocoa startup-failure guard and acknowledged main-thread alert.

This is a source-level check, not an interactive alert test.
"""
import pathlib

root = pathlib.Path(__file__).resolve().parents[2]
wrapper = (root / "fusepb/models/Emulator.m").read_text()
start = wrapper.index("  if( fuse_init( ac, av ) ) {")
end = wrapper.index("\n  while( !fuse_exiting )", start)
failure = wrapper[start:end]
assert "fuse_exiting = 1;" in failure
assert failure.index("fuse_exiting = 1;") < failure.index("dispatch_sync(")
assert "dispatch_get_main_queue()" in failure
assert '[alert setMessageText:@"Fuse could not start"]' in failure
assert '[alert addButtonWithTitle:@"Quit"]' in failure
assert "[alert runModal];" in failure
assert end < wrapper.index("  fuse_end();", end)
print("cocoa-startup-failure-guard: passed (source checks)")
