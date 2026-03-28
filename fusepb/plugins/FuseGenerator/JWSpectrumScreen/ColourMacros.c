/*
 *  ColourMacros.c
 *  Mac2Spec 3
 *
 *  Created by James on 3/12/2005.
 *  Copyright 2005 James Weatherley. All rights reserved.
 *
 */

#include "ColourMacros.h"
#include <assert.h>

#define SPEC_COLOUR(x)    (x & 0x00400000) >> 21 | (x & 0x00004000) >> 12 | (x & 0x00000040) >> 6

static int SPEC_PALETTE[] = {
	SPEC_BLACK,
	SPEC_BLUE,
	SPEC_RED,
	SPEC_MAGENTA,
	SPEC_GREEN,
	SPEC_CYAN,
	SPEC_YELLOW,
	SPEC_WHITE,
	SPEC_BRIGHT_BLUE,
	SPEC_BRIGHT_RED,
	SPEC_BRIGHT_MAGENTA,
	SPEC_BRIGHT_GREEN,
	SPEC_BRIGHT_CYAN,
	SPEC_BRIGHT_YELLOW,
	SPEC_BRIGHT_WHITE
};

static int colourLookupTable[SPEC_PALETTE_SIZE - 1][SPEC_PALETTE_SIZE - 1];

void initColourTable()
{
	static int init = 0;
	
	if(!init) {
		// Create the two colour distance lookup table.
		int i, j;
		int rI, gI, bI;
		int rJ, gJ, bJ;
		int colI, colJ;
		int d;
		
		for(i = 0; i < SPEC_PALETTE_SIZE - 1; ++i) {
			for(j = 0; j < SPEC_PALETTE_SIZE - 1; ++j) {
				colJ = SPEC_PALETTE[j];
				colI = SPEC_PALETTE[i];
				rJ = RED(colJ);
				gJ = GREEN(colJ);
				bJ = BLUE(colJ);
				rI = RED(colI);
				gI = GREEN(colI);
				bI = BLUE(colI);              
				d = (rJ - rI) * (rJ - rI) + 
					(gJ - gI) * (gJ - gI) + 
					(bJ - bI) * (bJ - bI);
				colourLookupTable[i][j] = d;
			}
		}
		init = 1;
	}
}


// Retrieve the spectrum RGB for a given index.
int spectrumColourFromIndex(int idx)
{
	return SPEC_PALETTE[idx];
}

// Retrieve the Spectrum colour number (0 Black; 1 blue; etc) for a RGB value.
int spectrumIndexFromRGB(int macRGB)
{
	int colour = SPEC_COLOUR(macRGB);
		
    // Check for bright.
    if(macRGB & 0x00808080) {
        colour += 7;
    }
    return colour;
}

// Retrieve spectrum RGB from Mac RGB.
int spectrumRGBFromMacRGB(int macRGB)
{
	return spectrumColourFromIndex(spectrumIndexFromRGB(macRGB));
}

int nearestColour2(int paper, int ink, int colour)
{
    assert(paper >= 0);
    assert(colour >= 0);
    assert(paper < 16);
    assert(ink < 16);
    assert(colour < 16);
    
    // Grab a row saves the compiler multiplying twice to access the 2D array twice
    // in the following if() statement.
    const int* lookupRow = colourLookupTable[0] + 15 * colour;
    
    if(ink < 0 || lookupRow[paper] < lookupRow[ink]) {
        return spectrumColourFromIndex(paper);
    } else {
        return spectrumColourFromIndex(ink);
    }
}
