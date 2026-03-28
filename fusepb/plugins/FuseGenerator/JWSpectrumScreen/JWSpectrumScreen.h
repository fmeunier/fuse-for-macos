	//
//  JWSpectrumScreen.h
//  Mac2SpecQLPlugin
//
//  Created by James Weatherley on 09/11/2007.
//  Copyright 2007 James Weatherley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JWSpectrumScreenConstants.h"


// Structure representing a byte of screen.
typedef struct BitmapByteData {
	unsigned char bitmapByte;	// Bits 1 - ink, 0 - paper
	int paper;					// Paper colour in RGB
	int ink;					// Ink colour in RGB
} BitmapByteData;


@interface JWSpectrumScreen : NSObject {

	// The Spectrum screen. Bitmaps + attributes.
	NSMutableData* zxScreen;
	
	// What display mode are we using?
	ScreenMode mode;

	// Size of the canvas.
	// This is the size that OS X will draw, standard and
	// high colour screens will be 256x192, but high res
	// screens will be 512x384 to preserve the aspect ratio.
	NSSize canvasSize;
}

// Internal utility method.
- (BOOL)initialise:(int)mltHint;

// Create an instance from the passed data object.
// Returns 'nil' if:
//   The data pointed to is not the right size - see constants above.
- (id)initFromData:(NSData*)scrData mltHint:(int)mltHint;

// Returns an NSBitmapImageRep* so you can draw the screen on a Mac.
- (NSBitmapImageRep*)imageRep;

// Returns a bitmap byte, paper and ink.
// Preconditions:
//   x must be byte aligned - ie divisible by eight.
//   x and y must lie within 'canvasSize'.
//
// The ink and paper colours returned in BitmapByteData are
// Spectrum colours. They will be in the range 0 <= col < 14
// which represents BLACK to WHITE followed by the bright versions.
// of the non-black colours. Obtain an RGB value defined in ColourMacros.h
// as follows:
//   int macRGB = spectrumColourFromIndex(spectrumColour);
//
// Paper and ink are undefined for Timex high res screens.
- (BitmapByteData)bitmapByteDataAtX:(int)x y:(int)y;

// Save the Spectrum screen data as a SCR file at the given path.
// Returns 'YES' is the file was saved successfully.
- (BOOL)saveScrFile:(NSURL*)url;

// Return 'canvasSize'.
- (NSSize)canvasSize;

// Return the screen mode used to display the image.
- (ScreenMode)mode;

@end
