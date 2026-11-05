---
title: ROM Preferences
description: This section describes the Fuse ROMs preferences dialog.
order: 60
group: Fuse Preferences
---

An individual setting is available for each Spectrum variant emulated by Fuse
which allows selection of the ROM(s) used by that machine. Simply select the ROM
you wish to use, and then reset the Spectrum for the change to take effect.

For ROMs which are not distributed with Fuse, store the files in any readable
location outside the application bundle, then use this pane to point Fuse at
them. A location in your home folder such as `Application Support` works well.

Fuse also provides ROM settings for peripherals that require their own ROMs.
Entries are available here for Beta 128, Didaktik 80, DISCiPLE, Sinclair
Interface 1, the Multiface variants, Opus Discovery, +D, Currah μSource and
Currah μSpeech. The Currah μSpeech interface requires both the μSpeech
interface ROM and the SP0256-AL2 speech ROM. These ROM files are not supplied
with Fuse for macOS.

The SP0256-AL2 ROM expected by Fuse has CRC-32 `b504ac15`. An alternative
authorised ROM distributed by Joe Zbiciak has CRC-32 `df8de0b0`; when using
that ROM, bit ordering in the data bytes must be reversed.

## Missing ROM files

Fuse can emulate Spectrum clones such as the Pentagon and Scorpion series,
but their ROM files are not distributed with Fuse because there is no clear
permission allowing their distribution. Some peripheral ROMs are also not
supplied. To use these machines or interfaces, you must provide the required
ROM files and configure them in *Fuse Preferences > ROM*.

ROMs for the Pentagon and Scorpion series, Didaktik and Opus disk interfaces,
Multiface interfaces, Currah μSpeech and μSource, and Sinclair Interface 1
must be supplied separately. Choose the appropriate ROM image for each machine or
interface. Its filename does not need to match Fuse's default filename, and
you do not need to rename it before selecting it.

If Fuse cannot find a readable default ROM file, the field appears blank with
*Select ROM file…* in its place. Fuse retains the default filename internally;
the blank field does not mean that the machine needs no ROM. A custom path
remains visible even if its file cannot be found.

Click *Choose…* to locate the required ROM, or enter its path in the field.
Hover over a field to see whether its ROM file is missing. Fields which do
not apply to the selected machine are blank and disabled.

*Reset* removes your custom ROM selection and returns to the default ROM.
If that ROM is not available, the field stays blank: you still
need to choose a ROM file. Reset does not install missing ROMs. Clearing a
field also returns to the default when you close Preferences.

After changing a ROM, reset the Spectrum for the change to take effect.

## Copyrights

Note that the ROM files distributed with this emulator are not covered by the
GNU GPL.

The following licenses apply:

**128-0.rom,
128-1.rom,
48.rom,
plus2-0.rom,
plus2-1.rom,
plus3-0.rom,
plus3-1.rom,
plus3-2.rom,
plus3-3.rom,
tc2048.rom**

These are copyright Amstrad, who allow distribution of the ROMs but retain the copyright. You may not sell the ROMs or embed the ROMs in hardware, although it is allowed to sell a product which contains the ROMs, so long as the charge is being made for the product, not for the ROMs themselves. See [here](http://groups.google.com/group/comp.sys.amstrad.8bit/msg/c092cc4d4943131e) for more details.

**tc2068-0.rom,
tc2068-1.rom**

These are derived from Amstrad code, so the above statement applies. The
modifications made by Timex are in the public domain.

**plus3e-0.rom,
plus3e-1.rom,
plus3e-2.rom,
plus3e-3.rom**

These are derived from Amstrad code, so the above statement applies. The
modifications are copyright Garry Lancaster.

**se-0.rom,
se-1.rom**

These are derived from Amstrad code, so the above statement applies. The
modifications are by Andrew Owen and are subject to the same conditions.

**plusd.rom**

This is copyright Datel Microelectronics, who allow distribution. See
[here](http://www.shadowmagic.org.uk/spectrum/datel.html) for
details.
