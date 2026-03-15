/*
 *  JWSpectrumScreenConstants.h
 *  Mac2SpecQLPlugin
 *
 *  Created by James Weatherley on 14/11/2007.
 *  Copyright 2007 James Weatherley. All rights reserved.
 *
 */

// Various constants relevant to Spectrum screens.
#define SCREEN_STANDARD_WIDTH		256
#define SCREEN_TIMEX_HIRES_WIDTH	512
#define SCREEN_STANDARD_HEIGHT		192

// These are the sizes of the saved bitmap - ie the .scr file.
// Not the size of a screen in the Spectrum's memory.
#define SCREEN_STANDARD_BYTES		6912
#define SCREEN_TIMEX_HI_COL_BYTES	12288
#define SCREEN_TIMEX_HI_RES_BYTES	12289

// Size of the bitmap portion of a standard Spectrum screen.
#define SCREEN_BITMAP_SIZE			0x1800

// Unsurprisingly, an enum defining the various screen modes.
typedef enum ScreenMode {
	ScreenModeSinclair,
	ScreenModeTimexHiCol,
	ScreenModeTimexHiRes,
	ScreenModeMLT
} ScreenMode;



// OUT 255 value for the various Timex High Res colour modes masked for just the
// colour bits.
typedef enum TimexHiResMode {
	TimexHiResBlackWhite	= 0,
	TimexHiResBlueYellow	= 8,
	TimexHiResRedCyan	= 16,
	TimexHiResMagentaGreen	= 24,
	TimexHiResGreenMagenta	= 32,
	TimexHiResCyanRed	= 40,
	TimexHiResYellowBlue	= 48,
	TimexHiResWhiteBlack	= 56
} TimexHiResMode;
