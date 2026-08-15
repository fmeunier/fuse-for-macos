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

/* Row-level cache: y-dependent parts of bitmap/attr offsets, computed once per
   row and reused across the 32 (Sinclair) or 64 (HiRes) columns in that row. */
typedef struct {
  int bitmapBase;   /* add attrX for Sinclair/MLT/HiCol; add attrX/2 for HiRes even cols */
  int attrBase;     /* add attrX for Sinclair/MLT/HiCol; unused for HiRes */
  int bitmapBase2;  /* HiRes odd-column plane: add (attrX-1)/2 */
} BitmapRowCache;

/* Internal helper: compute the byte offsets for a pixel's bitmap and
   attribute data in the Spectrum screen layout.  Declared static so the
   compiler can inline it into bitmapByteDataAt, eliminating the per-
   attribute-block function-call overhead in the tight rendering loop. */
static BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode);

/* Row-level cache of y-dependent offset components used by imageRep. */
static BitmapRowCache bitmapRowCache(int y, ScreenMode mode);

// C-level helper: extract bitmap byte and attribute from a raw screen buffer.
// Avoids ObjC message dispatch overhead in tight loops.
static BitmapByteData bitmapByteDataAt(const char *bitmapBytes, int x, int y,
                                       ScreenMode mode);


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
		const char* bitmapBytes = [zxScreen bytes];
		int x, y;

		if( mode == ScreenModeTimexHiRes ) {
			/* For HiRes the ink/paper is a single global attribute byte — precompute
			   the RGB colour pair once for the entire image instead of per attribute
			   block (saves 24,576 redundant switch dispatches on a 512x384 canvas). */
			int inkColour, paperColour;
			int outValue = bitmapBytes[SCREEN_TIMEX_HI_RES_BYTES - 1] & 0x38;
			switch( outValue ) {
			case TimexHiResBlackWhite:
				inkColour   = SPEC_BLACK;
				paperColour = SPEC_BRIGHT_WHITE;
				break;
			case TimexHiResBlueYellow:
				inkColour   = SPEC_BRIGHT_BLUE;
				paperColour = SPEC_BRIGHT_YELLOW;
				break;
			case TimexHiResRedCyan:
				inkColour   = SPEC_BRIGHT_RED;
				paperColour = SPEC_BRIGHT_CYAN;
				break;
			case TimexHiResMagentaGreen:
				inkColour   = SPEC_BRIGHT_MAGENTA;
				paperColour = SPEC_BRIGHT_GREEN;
				break;
			case TimexHiResGreenMagenta:
				inkColour   = SPEC_BRIGHT_GREEN;
				paperColour = SPEC_BRIGHT_MAGENTA;
				break;
			case TimexHiResCyanRed:
				inkColour   = SPEC_BRIGHT_CYAN;
				paperColour = SPEC_BRIGHT_RED;
				break;
			case TimexHiResYellowBlue:
				inkColour   = SPEC_BRIGHT_YELLOW;
				paperColour = SPEC_BRIGHT_BLUE;
				break;
			case TimexHiResWhiteBlack:
				inkColour   = SPEC_BRIGHT_WHITE;
				paperColour = SPEC_BLACK;
				break;
			default:
				NSLog( @"JWSpectrumScreen: imageRep: unknown HiRes attribute: %d\n", outValue );
				inkColour   = SPEC_BLACK;
				paperColour = SPEC_BRIGHT_WHITE;
				break;
			}

			for( y = 0; y < canvasSize.height; ++y ) {
				/* Hoist y-dependent bitmap offset calculation out of the x-loop. */
				BitmapRowCache rc = bitmapRowCache( y, mode );
				for( x = 0; x < canvasSize.width; x += 8 ) {
					int attrX = x / 8;
					int bitmapOffset = ( attrX & 1 )
						? rc.bitmapBase2 + ( attrX - 1 ) / 2
						: rc.bitmapBase  +   attrX      / 2;
					unsigned char bitmapByte = (unsigned char)bitmapBytes[bitmapOffset];
					int bit;
					for( bit = 0; bit < 8; ++bit ) {
						unsigned char mask = 1 << ( 7 - bit );
						int colour = ( bitmapByte & mask ) ? inkColour : paperColour;
						*imageBytes++ = RED( colour );
						*imageBytes++ = GREEN( colour );
						*imageBytes++ = BLUE( colour );
					}
				}
			}
		} else {
			/* Sinclair / MLT / HiCol: hoist y-dependent offset calculations out of
			   the inner x-loop.  For a 256x192 Sinclair screen this replaces 32
			   redundant sets of division/modulo per row with a single bitmapRowCache
			   call, amortising the cost across all 32 attribute columns. */
			for( y = 0; y < canvasSize.height; ++y ) {
				BitmapRowCache rc = bitmapRowCache( y, mode );
				for( x = 0; x < canvasSize.width; x += 8 ) {
					int attrX        = x / 8;
					int bitmapOffset = rc.bitmapBase + attrX;
					int attrOffset   = rc.attrBase   + attrX;
					unsigned char bitmapByte = (unsigned char)bitmapBytes[bitmapOffset];
					char attribute   = bitmapBytes[attrOffset];
					bool bright      = attribute & ( 1 << 6 );
					int ink   = attribute & 0x7;
					int paper = ( attribute & ( 0x7 << 3 ) ) >> 3;
					if( bright ) {
						if( ink )   ink   += 7;
						if( paper ) paper += 7;
					}
					int inkColour   = spectrumColourFromIndex( ink );
					int paperColour = spectrumColourFromIndex( paper );
					int bit;
					for( bit = 0; bit < 8; ++bit ) {
						unsigned char mask = 1 << ( 7 - bit );
						int colour = ( bitmapByte & mask ) ? inkColour : paperColour;
						*imageBytes++ = RED( colour );
						*imageBytes++ = GREEN( colour );
						*imageBytes++ = BLUE( colour );
					}
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

	return bitmapByteDataAt([zxScreen bytes], x, y, mode);
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



/* Compute the y-dependent base offsets for a screen row.  Call once per y;
   add attrX (or attrX/2 for even HiRes columns) inside the x-loop. */
static BitmapRowCache
bitmapRowCache( int y, ScreenMode mode )
{
  BitmapRowCache rc = { 0, 0, 0 };
  int screenThird, attrRowInThird, rowInAttr;

  if( mode == ScreenModeSinclair || mode == ScreenModeMLT ) {
    int attrY      = y / 8;
    screenThird    = attrY / 8;
    attrRowInThird = attrY % 8;
    rowInAttr      = y % 8;
    rc.bitmapBase  = 0x800 * screenThird + 0x20 * attrRowInThird + 0x100 * rowInAttr;
    rc.attrBase    = SCREEN_BITMAP_SIZE + attrY * ( SCREEN_STANDARD_WIDTH / 8 );
  } else if( mode == ScreenModeTimexHiCol ) {
    screenThird    = 3 * y / SCREEN_STANDARD_HEIGHT;
    attrRowInThird = y / 8 % 8;
    rowInAttr      = y % 8;
    rc.bitmapBase  = 0x800 * screenThird + 0x20 * attrRowInThird + 0x100 * rowInAttr;
    /* attrOffset = SCREEN_BITMAP_SIZE + bitmapOffset, so attrBase = SCREEN_BITMAP_SIZE + bitmapBase */
    rc.attrBase    = SCREEN_BITMAP_SIZE + rc.bitmapBase;
  } else { /* ScreenModeTimexHiRes */
    int yh         = y / 2;
    screenThird    = 3 * yh / SCREEN_STANDARD_HEIGHT;
    attrRowInThird = yh / 8 % 8;
    rowInAttr      = yh % 8;
    rc.bitmapBase  = 0x800 * screenThird + 0x20 * attrRowInThird + 0x100 * rowInAttr;
    rc.bitmapBase2 = rc.bitmapBase + SCREEN_BITMAP_SIZE;
  }
  return rc;
}


static BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode)
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

static BitmapByteData
bitmapByteDataAt( const char *bitmapBytes, int x, int y, ScreenMode mode )
{
  BitmapByteData data;
  BitmapOffsets offsets = bitmapOffsets( x, y, mode );
  data.bitmapByte = bitmapBytes[offsets.bitmapOffset];

  if( mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol ||
      mode == ScreenModeMLT ) {

    char attribute = bitmapBytes[offsets.attrOffset];
    bool bright = attribute & (1 << 6);
    int ink = attribute & 0x7;
    int paper = (attribute & (0x7 << 3)) >> 3;

    if( bright ) {
      if( ink ) ink += 7;
      if( paper ) paper += 7;
    }
    data.ink = ink;
    data.paper = paper;

  } else if( mode == ScreenModeTimexHiRes ) {

    int outValue = bitmapBytes[SCREEN_TIMEX_HI_RES_BYTES - 1];
    outValue &= 0x38;  /* mask out non-colour bits */

    switch( outValue ) {
    case TimexHiResBlackWhite:
      data.ink   = spectrumIndexFromRGB( SPEC_BLACK );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_WHITE );
      break;
    case TimexHiResBlueYellow:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_BLUE );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_YELLOW );
      break;
    case TimexHiResRedCyan:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_RED );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_CYAN );
      break;
    case TimexHiResMagentaGreen:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_MAGENTA );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_GREEN );
      break;
    case TimexHiResGreenMagenta:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_GREEN );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_MAGENTA );
      break;
    case TimexHiResCyanRed:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_CYAN );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_RED );
      break;
    case TimexHiResYellowBlue:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_YELLOW );
      data.paper = spectrumIndexFromRGB( SPEC_BRIGHT_BLUE );
      break;
    case TimexHiResWhiteBlack:
      data.ink   = spectrumIndexFromRGB( SPEC_BRIGHT_WHITE );
      data.paper = spectrumIndexFromRGB( SPEC_BLACK );
      break;
    default:
      NSLog( @"JWSpectrumScreen: unknown attribute:%d\n", outValue );
      assert( 0 );
    }

  } else {
    assert( 0 );
  }

  return data;
}
