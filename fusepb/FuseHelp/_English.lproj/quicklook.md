---
title: Quick Look Generator
description: This section describes Fuse's support of the Quick Look feature of macOS 10.5 and newer.
order: 250
---

On macOS 10.5 and newer, the Fuse Quick Look generator allows viewing
thumbnails and previews of ZX Spectrum emulation related files. The supported
types are:

## SCR and MLT Screen dumps

Preview and thumbnails for SCR and MLT screen dumps in all graphics modes.

## Snapshots (SZX, Z80, SNA, etc.)

The screen image embedded in the snapshot is extracted and used as the
thumbnail for the file. Advanced graphics effects produced in some demo programs
cannot be reproduced in this way in the same way as SCR files.

## RZX Spectrum recordings

The first embedded snapshot in the file is extracted and used as the thumbnail
for the file in the same way as snapshots above.

## Tape images (TAP and TZX)

Fuse uses the same extracted artwork for both Quick Look previews and
thumbnails of tape images when suitable image data is present.

If a tape contains embedded inlay artwork, that image is used. Otherwise, the
first Spectrum screen file (SCREEN$) stored with the standard ROM loader in the
tape is extracted and used in the same way as snapshot files above. Tapes which
do not contain extractable image data do not produce a Quick Look preview or
thumbnail.
