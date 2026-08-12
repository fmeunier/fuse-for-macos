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

`test.mdr` is a manually created microdrive image containing a saved screen named
`test`. Prefer this fixture for manual MDR Quick Look testing because it reflects
a real formatted cartridge image.

`tzx-with-turbo-screen.tzx` is a minimal TZX file containing a single turbo-speed
data block (type 0x11) whose payload is a SCREEN$-sized block (flag byte 0xFF, 6912
zero bytes, checksum 0xFF).  It is used to exercise the `LIBSPECTRUM_TAPE_BLOCK_TURBO`
branch of `process_tape` in `LibspectrumSCRExtractor`.

Generation:
```python
import struct
header = b'ZXTape!\x1a\x01\x14'
screen_data = bytes([0xff]) + bytes(6912) + bytes([0xff])
data_len = struct.pack('<I', len(screen_data))[:3]
block = (bytes([0x11])
    + struct.pack('<H', 2168)   # pilot pulse
    + struct.pack('<H', 667)    # sync1
    + struct.pack('<H', 735)    # sync2
    + struct.pack('<H', 855)    # zero bit
    + struct.pack('<H', 1710)   # one bit
    + struct.pack('<H', 0)      # pilot count (no pilot tone)
    + bytes([8])                # last byte bits
    + struct.pack('<H', 1000)   # pause ms
    + data_len
    + screen_data)
open('tzx-with-turbo-screen.tzx', 'wb').write(header + block)
```
