---
title: Sound Preferences
description: This section describes the Fuse sound preferences dialog.
order: 20
group: Fuse Preferences
---

Use the Sound pane of Fuse preferences to configure Fuses sound output.

OPTION | DESCRIPTION
:--- | :---
*Enabled* | Specify whether sound output should be enabled at all. When this option is disabled, Fuse will not make any sound.
*Beeper Volume* | Slider for the relative volume of the built-in beeper.
*AY Volume* | Slider for the relative volume of the AY-3-8912 chip in machines/interfaces that have one.
*SpecDrum Volume* | Slider for the relative volume of the SpecDrum when used as a peripheral.
*Covox Volume* | Slider for the relative volume of the Covox in machines/interfaces that have one.
*μSpeech Volume* | Slider for the relative volume of the Currah μSpeech speech output.
*Speaker Type* | Select the response used for emulated sound output. Automatic chooses the appropriate TV or internal-beeper response for the emulated machine; enabling Currah μSpeech also selects the TV response. TV speaker models sound heard through a television or external speaker connected to the MIC socket, Beeper models a machine's internal speaker, and Unfiltered provides the direct signal without speaker colouring. The non-automatic choices apply to every machine. Unrelated external sound interfaces such as Covox and SpecDrum are not routed through the speaker response.
*Loading sounds* | Normally, Fuse emulates tape-loading noise when loading from PZXs, TAPs or TZXs in real-time, albeit at a deliberately lower volume than on a real Spectrum. You can disable this option to eliminate the loading noise entirely.
*AY stereo separation* | By default, the sound output is mono, since this is all you got from an unmodified Spectrum. But using this option allows you to choose from None (mono), so-called ACB stereo or ABC stereo (for sound from the 128's AY-3-8912 sound chip).
