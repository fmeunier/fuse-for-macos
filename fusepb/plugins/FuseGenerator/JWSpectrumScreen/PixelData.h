/*
 *  PixelData.h
 *  
 *
 *  Created by James on 4/12/2005.
 *  Copyright 2005 James Weatherley. All rights reserved.
 *
 */

#ifndef PIXEL_DATA
#define PIXEL_DATA

// Info about the screen layout.
typedef struct PixelData {
    unsigned int attrHeight;
    unsigned int attrWidth;
    unsigned int attrPerRow;
    unsigned int attrCount;
    unsigned int bytesPerRow;
    unsigned int samplesPerPixel;
} PixelData;

#endif
