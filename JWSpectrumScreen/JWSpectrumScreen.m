//
//  JWSpectrumScreen.m
//  Mac2SpecQLPlugin
//
//  Created by James Weatherley on 09/11/2007.
//  Copyright 2007 James Weatherley. All rights reserved.
//

#import "JWSpectrumScreen.h"
#import "ColourMacros.h"


typedef struct BitmapOffsets {
	int bitmapOffset;
	int attrOffset;
} BitmapOffsets;

// Internal method to get the offsets for the bitmap and attribute
// for a byte in the Spectrum screen file.
BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode);


@implementation JWSpectrumScreen

- (BOOL)initialise:(int)mltHint
{
	if(zxScreen) {
		if([zxScreen length] == SCREEN_STANDARD_BYTES) {
			canvasSize.width = SCREEN_STANDARD_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT;
			mode = ScreenModeSinclair;
		} else if([zxScreen length] == SCREEN_TIMEX_HI_COL_BYTES) {
			canvasSize.width = SCREEN_STANDARD_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT;
			mode = ScreenModeTimexHiCol;
            if(mltHint) {
                mode = ScreenModeMLT;
            }
		} else if([zxScreen length] == SCREEN_TIMEX_HI_RES_BYTES) {
			canvasSize.width = SCREEN_TIMEX_HIRES_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT * 2;
			mode = ScreenModeTimexHiRes;
		} else {
			// Invalid length.
			return NO;
		}

		return YES;
	}

	return NO;
}

- (id)initFromData:(NSData*)scrData mltHint:(int)mltHint
{
	self = [super init];
	if(self) {
		zxScreen = [[NSMutableData alloc] init];
		[zxScreen setData:scrData];
		
        if( [self initialise:mltHint] == NO ) {
		NSLog( @"JWSpectrumScreen: initFromData : Some problem with the source scrData.\n" );
			// Some problem with the source scrData.
			[self release];
			self = nil;
		}
	}
	return self;
}

- (NSBitmapImageRep*)imageRep
{
	NSBitmapImageRep* imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:0
										pixelsWide:canvasSize.width 
										pixelsHigh:canvasSize.height
										bitsPerSample:8
										samplesPerPixel:3
										hasAlpha:NO
										isPlanar:NO
										colorSpaceName:NSDeviceRGBColorSpace
										bytesPerRow:canvasSize.width * 3
										bitsPerPixel:24];
	
	if(imageRep) {
		unsigned char* imageBytes = [imageRep bitmapData];
		BitmapByteData bitmapByteData;
		
		for(int y = 0; y < canvasSize.height; ++y) {
			for(int x = 0; x < canvasSize.width; x += 8) {
				bitmapByteData = [self bitmapByteDataAtX:x y:y];
				
				for(int bit = 0; bit < 8; ++bit) {
					unsigned char mask = 1 << (7 - bit);
					int colour;
					if(bitmapByteData.bitmapByte & mask) {
						colour = spectrumColourFromIndex(bitmapByteData.ink);
					} else {
						colour = spectrumColourFromIndex(bitmapByteData.paper);
					}
					*imageBytes++ = RED(colour);
					*imageBytes++ = GREEN(colour);
					*imageBytes++ = BLUE(colour);
				}
			}
		}
	}
	
	return [imageRep autorelease];
}


- (BitmapByteData)bitmapByteDataAtX:(int)x y:(int)y
{
	// x must be byte aligned.
	// x and y must be within the canvas.
	assert(x % 8 == 0);
	assert(x < canvasSize.width);
	assert(y < canvasSize.height);

	const char* bitmapBytes = [zxScreen bytes];	
	BitmapByteData data;
	BitmapOffsets offsets = bitmapOffsets(x, y, mode);
	data.bitmapByte = bitmapBytes[offsets.bitmapOffset];
	
	if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol || mode == ScreenModeMLT) {

		char attribute = bitmapBytes[offsets.attrOffset];
		bool bright = attribute & (1 << 6);
		int ink = attribute & 0x7;
		int paper = (attribute & (0x7 << 3)) >> 3;
		if(bright) {
			if(ink) {
				ink += 7;
			}
			if(paper) {
				paper += 7;
			}
		}
		data.ink = ink;
		data.paper = paper;
	} else if(mode == ScreenModeTimexHiRes) {
	
		int outValue = bitmapBytes[SCREEN_TIMEX_HI_RES_BYTES - 1];		
                // Mask out the non-colour related bits
		outValue &= 0x38;

		switch(outValue) {
			case TimexHiResBlackWhite:
			data.ink = spectrumIndexFromRGB(SPEC_BLACK);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_WHITE);
			break;
			case TimexHiResBlueYellow:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_BLUE);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_YELLOW);
			break;
			case TimexHiResRedCyan:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_RED);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_CYAN);
			break;
			case TimexHiResMagentaGreen:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_MAGENTA);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_GREEN);
			break;
			case TimexHiResGreenMagenta:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_GREEN);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_MAGENTA);
			break;
			case TimexHiResCyanRed:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_CYAN);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_RED);
			break;
			case TimexHiResYellowBlue:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_YELLOW);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_BLUE);
			break;
			case TimexHiResWhiteBlack:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_WHITE);
			data.paper = spectrumIndexFromRGB(SPEC_BLACK);
			break;
			default:
                                NSLog(@"JWSpectrumScreen: unknown attribute:%d\n", outValue);
				assert(0);
		}
	} else {
		// WTF?
		assert(0);
	}
	return data;
}

- (BOOL)saveScrFile:(NSURL*)url
{
	BOOL success = NO;
	if([zxScreen length]) {
		success = [zxScreen writeToURL:url atomically:NO];
	}
	return success;
}

- (NSSize)canvasSize
{
	return canvasSize;
}

- (ScreenMode)mode
{
	return mode;
}

- (void)dealloc
{
	[zxScreen release];
	[super dealloc];
}

@end



BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode)
{
	BitmapOffsets offsets = {0, 0};
	
	int attrX = x / 8;
	int attrY = 0;
	int attrRows = 0;
	
	int screenThird = 0;
	int attrRowInThird = 0;
	int rowInAttr = 0;
	
	if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol || mode == ScreenModeMLT) {
		if(mode == ScreenModeSinclair) {
			attrY = y / 8;
			attrRows = SCREEN_STANDARD_HEIGHT / 8;
			screenThird = 3 * attrY / attrRows;
			attrRowInThird = attrY % 8;
		} else {
			attrY = y;
			attrRows = SCREEN_STANDARD_HEIGHT;
			screenThird = 3 * y / attrRows;
			attrRowInThird = y / 8 % 8;
		}

		rowInAttr = y % 8;
		offsets.bitmapOffset = 0x800 * screenThird;
		offsets.bitmapOffset += 0x20 * attrRowInThird;
		offsets.bitmapOffset += 0x100 * rowInAttr;
		offsets.bitmapOffset += attrX;
		
		if(mode == ScreenModeSinclair || mode == ScreenModeMLT) {
			offsets.attrOffset = SCREEN_BITMAP_SIZE + attrX + attrY * SCREEN_STANDARD_WIDTH / 8;
		} else {
			offsets.attrOffset = SCREEN_BITMAP_SIZE + offsets.bitmapOffset;
		}
	} else if(mode == ScreenModeTimexHiRes) {
		y /= 2;
		attrRows = SCREEN_STANDARD_HEIGHT;
		screenThird = 3 * y / attrRows;
		attrRowInThird = y / 8 % 8;
		rowInAttr = y % 8;
		
		offsets.bitmapOffset = 0x800 * screenThird;
		offsets.bitmapOffset += 0x20 * attrRowInThird;
		offsets.bitmapOffset += 0x100 * rowInAttr;
				
		if(attrX & 1) {
			offsets.bitmapOffset += SCREEN_BITMAP_SIZE;
			offsets.bitmapOffset += (attrX - 1) / 2;
		} else {
			offsets.bitmapOffset += attrX / 2;
		}
	} else {
		// WTF?
		assert(0);
	}
	
	return offsets;
}
