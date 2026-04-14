# Quick Look Fixtures

`keyboard-inlay.tzx` is a clean Quick Look regression fixture for tape inlay extraction.

Provenance:
- Inlay artwork source: `fuse/lib/keyboard.png` created locally for this project.
- Loading screen source: `fuse/lib/keyboard.scr` from this repo.
- Tape payload source: `fusepb/deps/libspectrum/test/empty.z80`.

Generation:
```sh
sips -s format jpeg fuse/lib/keyboard.png --out /tmp/keyboard-inlay.jpg
/Users/fred/Documents/Code/HomeGrown/fuse-emulator-trunk-vanilla/fuse-utils/snap2tzx \
  -g "Fuse QuickLook" \
  -l "FUSEQL" \
  -$ fuse/lib/keyboard.scr \
  -o /tmp/keyboard-inlay-base.tzx \
  fusepb/deps/libspectrum/test/empty.z80
/Users/fred/Documents/Code/HomeGrown/fuse-emulator-trunk-vanilla/fuse-utils/tapeconv \
  -i /tmp/keyboard-inlay.jpg \
  /tmp/keyboard-inlay-base.tzx \
  fusepb/tests/fixtures/keyboard-inlay.tzx
```

Expected Quick Look behavior:
- Thumbnail extraction should prefer the embedded `Picture` custom block image.
- The tape also includes a `Spectrum Screen` loading screen via `snap2tzx`.
