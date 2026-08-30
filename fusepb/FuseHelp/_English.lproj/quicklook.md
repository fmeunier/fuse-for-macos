---
title: Quick Look Generator
description: This section describes Fuse's Quick Look previews and thumbnails.
order: 250
---

Fuse's Quick Look extensions provide thumbnails and previews for supported ZX
Spectrum files. The supported types are:

## SCR and MLT screen dumps

Previews and thumbnails are available for standard Spectrum screens, MLT
MultiColour screens, and Timex HiColour and HiRes screens.

## Snapshots (SZX, Z80, SNA, etc.)

The current emulated screen is reconstructed from the snapshot and used for its
preview and thumbnail. Supported modes include standard, Timex HiColour and
Timex HiRes screens. Advanced effects that depend on precisely timed screen
changes cannot be reproduced from a static snapshot.

## RZX Spectrum recordings

The first embedded snapshot is rendered in the same way as a standalone
snapshot.

## Tape images (TAP and TZX)

Fuse uses the same extracted artwork for both Quick Look previews and
thumbnails of tape images when suitable image data is present.

If a tape contains embedded inlay artwork, that image is used. Otherwise, Fuse
looks for a Spectrum SCREEN$ stored with a standard ROM or supported turbo
loader. Tapes without extractable image data do not produce a Quick Look preview
or thumbnail.
