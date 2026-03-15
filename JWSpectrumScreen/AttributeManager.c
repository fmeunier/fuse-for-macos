/*
 *  AttributeManager.c
 *  Mac2Spec
 *
 *  Created by James on 5/12/2005.
 *  Copyright 2005 James Weatherley. All rights reserved.
 *
 */

#include <assert.h>
#include <string.h>

#include "AttributeManager.h"
#include "ColourMacros.h"

const static float brightnessThresholdValue = 0.5f;
const static int tolerance = 1;


static int floydSteinbergFlag = 1;

void floydSteinberg(int fs)
{
	floydSteinbergFlag = fs;
}


// Return a pointer to the first pixel of an attribute block.
const unsigned char* attribute(
							   const unsigned char* bitmap,
							   const PixelData* pixelData,
							   unsigned int x,
							   unsigned int y
							   )
{
    const unsigned char* block = bitmap + y * pixelData->bytesPerRow;
    return block + x * pixelData->samplesPerPixel;
}

unsigned char* mutableAttribute(
								unsigned char* bitmap,
								const PixelData* pixelData,
								unsigned int x,
								unsigned int y
								)
{
    unsigned char* block = bitmap + y * pixelData->bytesPerRow;
    return block + x * pixelData->samplesPerPixel;
}


// Return the RGB value of a pixel at a given index in an attribute block.
int pixelRGBFromBlock(
					  const unsigned char* block,
					  const PixelData* pixelData,
					  const unsigned int x,
					  unsigned int y
					  )
{
    //assert(y * pixelData->attrWidth + x  < pixelData->attrCount);
    
    unsigned int pixel;
    unsigned int rowOffset = y * pixelData->bytesPerRow;
    unsigned int colOffset = x * pixelData->samplesPerPixel;
    const unsigned char* pixelRGB = block + rowOffset + colOffset;
    
    if(x || y) {
        // Not first so no problem with underflow so point one char before R.
        // ????RGB???
        //    ^^^^ 
        pixel = CFSwapInt32HostToBig(*(unsigned int*)(pixelRGB - 1));
    } else {
        // Start of array so can't sneak back so point at R.
        // RGB?????
        // ^^^^
        pixel = CFSwapInt32HostToBig(*(unsigned int*)(pixelRGB));
        pixel >>= 8;
    }
	
    return (pixel & 0x00FFFFFF);
}

// Update a given attribute block of the transformed image.
void setPixelBlock(
				   unsigned char* block,
				   const PixelData* pixelData,
				   const int* newPixels
				   )
{
    int i = 0;
    unsigned int x, y;
    unsigned char* pixel;
    unsigned char* rowStart;
    
    for(y = 0; y < pixelData->attrHeight; ++y) {
        rowStart = block + y * pixelData->bytesPerRow;
        for(x = 0; x < pixelData->attrWidth; ++x) {
            pixel = rowStart + x * pixelData->samplesPerPixel; 
            pixel[0] = RED(newPixels[i]);
            pixel[1] = GREEN(newPixels[i]);
            pixel[2] = BLUE(newPixels[i++]);
        }
    }
}

// Set all the m_attribute* members - don't set them directly!
void setPixelData(
				 PixelData* pixelData,
				 int width,
				 int height,
				 int screenWidth
				 )
{
	// Div by zero is bad for x86...
	assert(width);
	
    // Start with a standard speccy.
    pixelData->attrHeight = height;
    pixelData->attrWidth = width;
    pixelData->attrCount = height * width;
    pixelData->attrPerRow = screenWidth / width;
}


// Run through all the pixels in an attribute block and set them to the nearest speccy colour.
void analyzeBlock(
				  unsigned char* bitmap,
				  PixelData* pixelData,
				  unsigned int x,
				  unsigned int y,
				  int* paperInk,
				  int* pixels,
				  int pixelCount
				  )
{
    // Pointer to first pixel in the block.
    unsigned char* block = mutableAttribute(bitmap, pixelData, x, y);
    
    // Fill an array with the pixel RGB values.
    int i = 0;
    unsigned int pixelX, pixelY;
    unsigned int width = pixelData->attrWidth;
    unsigned int height = pixelData->attrHeight;
    
    for(pixelY = 0; pixelY < height; ++pixelY) {
        for(pixelX = 0; pixelX < width; ++pixelX) {
            pixels[i++] = pixelRGBFromBlock(block, pixelData, pixelX, pixelY);
        }
    }
    
    // Determine the paper and ink values.
    float bright = commonColours(pixels, pixelCount, paperInk);
    int usingBright = bright > brightnessThresholdValue;
    
    assert(bright < 1.0001);

    for(i = 0; i < pixelCount; ++i) {
        int nearest_colour = nearestColour2(paperInk[PAPER], paperInk[INK], spectrumIndexFromRGB(pixels[i]));
		
        if(usingBright) {
            nearest_colour |= ((nearest_colour & 0x00404040) << 1);
            //}
        } else {
            nearest_colour &= ~0x00808080;
            nearest_colour = (nearest_colour & 0x00303030) << 2;
        }
		
        // Update the pixel array with paper / ink values only.       
        pixels[i] = nearest_colour;
    }

    // Set the pixels in the actual transformed image.
    setPixelBlock(block, pixelData, pixels);
}



// Find the commonest two colours in an attribute block.
// The block is already dithered to speccy colours.
// Returns fraction that are bright - not including black pixels.
float commonColours(int* block, int blockSize, int* paperInk)
{    
    int specColours[16];
    memset(specColours,0,sizeof(specColours));
    
    int i;
    for(i = 0; i < blockSize; ++i) {
        specColours[spectrumIndexFromRGB(block[i])]++;
    }
	
    int bright = 0;
    int most_freq = 0;
    int next_freq = 0;
    
    for(i = 0; i < 16; ++i) {
        if(i > 7) {
            bright += specColours[i];
        }
        if(specColours[i] > most_freq) {
            paperInk[INK] = paperInk[PAPER];
            paperInk[PAPER] = i;
            next_freq = most_freq;
            most_freq = specColours[i];
        } else if(specColours[i] > next_freq) {
            paperInk[INK] = i;
            next_freq = specColours[i];
        }
    }
    
    // Only want this for f/s dither.
    if(floydSteinbergFlag) {
        // If the most frequent colour isn't very frequent then f/s is usually attempting grey. 
        if(most_freq < blockSize / 4) {
            paperInk[PAPER] = 0;
            paperInk[INK] = 7;
        } else {
            if(tolerance > 1 && 
               next_freq && next_freq <=  ((blockSize - most_freq) / tolerance)) {
                int near_miss = 0;
                int fudge = next_freq / 2;
				
                // The next most frequent colour isn't that common - count how many
                // other colours are within the fudge factor.
                for(i = 0; i < 16; ++i) {
                    if(i == paperInk[PAPER]) {
                        continue;
                    }
                    if(specColours[i] >= next_freq - fudge) {
                        ++near_miss;
                    }
                }
                // It will count itself as a near miss.
                if(near_miss != 1) {
                    // Assume grey is wanted - this may need looking at...
                    if(paperInk[PAPER] == 7) {
                        paperInk[INK] = 0;
                    } else {
                        paperInk[PAPER] = 0;
                        paperInk[INK] = 7;
                    }
                }
            }
        }
    }
    
    static float retval = 0.0f;
    if(blockSize - specColours[0]) {
        retval = (float)bright / ((float)(blockSize - specColours[0]));
    }
    return retval;
}
