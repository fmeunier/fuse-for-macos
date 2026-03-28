---
title: ROM Preferences
description: This section describes the Fuse ROMs preferences dialog.
order: 60
group: Fuse Preferences
---

An individual setting is available for each Spectrum variant emulated by Fuse
which allows selection of the ROM(s) used by that machine. Simply select the ROM
you wish to use, and then reset the Spectrum for the change to take effect.

Fuse also provides ROM settings for peripherals that require their own ROMs.
The Currah μSpeech interface requires both the μSpeech interface ROM and the
SP0256-AL2 speech ROM. These ROM files are not supplied with Fuse for macOS.

The SP0256-AL2 ROM should be named `sp0256-al2.rom`; the ROM expected by Fuse
has CRC-32 `b504ac15`. An alternative authorised ROM distributed by Joe Zbiciak
has CRC-32 `df8de0b0`; when using that ROM, bit ordering in the data bytes must
be reversed.

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
