---
title: Spotlight Importer
description: This section describes Fuse's support of the Spotlight feature of macOS.
order: 240
---

The Fuse Spotlight importer allows Spotlight to find ZX Spectrum emulation related
files based on metadata in the files. The metadata supported is:

## Tape images

Fuse imports metadata from supported tape-image formats such as TZX, TAP, PZX,
CSW and similar files.

For TZX and other tape images carrying archive or hardware metadata, Spotlight can
index title, publishers, authors, year of release, languages, category,
original price, loader, origin, comment, audio channel count, duration, supported
machines and peripherals. It also indexes the filenames in ROM header blocks.
Simpler tape formats may expose only the metadata available in those files.

## Snapshots (SZX, Z80, SNA, etc.)

Machine type, and status of the enabled joysticks (Kempston, Cursor, Sinclair,
Timex and Fuller), ZXATASP and ZXCF IDE peripherals, and the Interface II and
Timex dock cartridges.

## RZX Spectrum recordings

As snapshots above.

## MDR Microdrive cartridge images

Cartridge length (sector count), write-protect status and the filenames stored
on the cartridge.

## Timex DCK cartridge images

Number of mapped 8K banks in a Timex DCK cartridge image.

## TR-DOS disk images and SCL archives

Filenames stored in TR-DOS disk images and SCL archives.

## +3 DSK and EDSK disk images

Disk geometry (tracks and sides) and, when present, the creator recorded in the
image header.

## HDF hard disk images

Disk geometry (cylinders and heads).

## Opus Discovery disk images

Disk geometry for OPD and OPU images (80 tracks and one or two sides, inferred
from the image size).

## DISCiPLE and +D disk images

Disk geometry for MGT and IMG images (80 tracks and two sides).

## Didaktik disk images

Disk geometry for D80 and D40 images (80 or 40 tracks, respectively, and two
sides).

## Interface 2 ROM cartridge images

Cartridge length in bytes.

## SCR Screen dumps

Graphics mode, width, height, orientation, colour space

## Custom Metadata Attribute Details

There are several Fuse-specific metadata attributes added by this importer, detailed below:

ATTRIBUTE | DESCRIPTION
:--- | :---
*Category* | type of software (arcade adventure, puzzle, word processor, ...)
*Price* | the original price the software sold for (includes currency)
*Loader* | protection scheme used in the title (Speedlock 1, Alkatraz, ...)
*Origin* | (Original, Budget re-release, ...)
*Machine* | Spectrum 16K, 48K (Issue 1), 48K, 128K, +2, +2A, +3, SE, Timex TC2048, Timex TC2068, Timex TS2068, Scorpion ZS 256, Pentagon 128K
*Joystick* | Kempston, Cursor, Sinclair 1, Sinclair 2, Timex 1, Timex 2, Fuller
*GraphicsMode* | Standard, HiColour, HiRes
*CartridgeLength* | number of sectors on a microdrive cartridge, mapped 8K banks in a Timex DCK cartridge, or the size in bytes of an Interface 2 ROM cartridge
*WriteProtect* | whether a microdrive cartridge is write protected
*FileNames* | filenames stored in a tape image, Microdrive cartridge, TR-DOS disk image or SCL archive
*DiskTracks* | number of tracks in a +3 DSK/EDSK, Opus Discovery, DISCiPLE/+D or Didaktik disk image, or cylinders in an HDF image
*DiskSides* | number of sides in a +3 DSK/EDSK, Opus Discovery, DISCiPLE/+D or Didaktik disk image, or heads in an HDF image
*DiskCreator* | creator recorded in a +3 DSK/EDSK image header
