/*
 *  ColourMacros.h
 *  Mac2Spec 3
 *
 *  Created by James on 3/12/2005.
 *  Copyright 2005 James Weatherley. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

#ifndef COLOUR_MACROS
#define COLOUR_MACROS

#define RED(x)   (x & 0x00FF0000) >> 16
#define GREEN(x) (x & 0x0000FF00) >> 8
#define BLUE(x)  (x & 0x000000FF)

#define PAPER 0
#define INK 1

#define SPEC_BLACK          0x00000000
#define SPEC_BLUE           0x0000007F
#define SPEC_RED            0x007F0000
#define SPEC_MAGENTA        0x007F007F
#define SPEC_GREEN          0x00007F00
#define SPEC_CYAN           0x00007F7F
#define SPEC_YELLOW         0x007F7F00
#define SPEC_WHITE          0x007F7F7F
#define SPEC_BRIGHT_BLUE    0x000000FF
#define SPEC_BRIGHT_RED     0x00FF0000
#define SPEC_BRIGHT_MAGENTA 0x00FF00FF
#define SPEC_BRIGHT_GREEN   0x0000FF00
#define SPEC_BRIGHT_CYAN    0x0000FFFF
#define SPEC_BRIGHT_YELLOW  0x00FFFF00
#define SPEC_BRIGHT_WHITE   0x00FFFFFF

#define SPEC_PALETTE_SIZE 16

void initColourTable();

// Retrieve the spectrum RGB for a given spectrum index.
int spectrumColourFromIndex(int idx);

// Retrieve spectrum index for a given Mac RGB.
int spectrumIndexFromRGB(int macRGB);

// Retrieve spectrum RGB from Mac RGB.
int spectrumRGBFromMacRGB(int macRGB);

int nearestColour2(int paper, int ink, int colour);

#endif
