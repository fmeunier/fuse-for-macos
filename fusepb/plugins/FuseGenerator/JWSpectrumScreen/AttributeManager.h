/*
 *  AttributeManager.h
 *  Mac2Spec
 *
 *  Created by James on 5/12/2005.
 *  Copyright 2005 James Weatherley. All rights reserved.
 *
 */
#ifndef ATTRIBUTE_MANAGER
#define ATTRIBUTE_MANAGER

#include "PixelData.h"

#define ATTRIBUTE_HEIGHT_SINCLAIR 8
#define ATTRIBUTE_HEIGHT_TIMEX_HI_COL 1
#define ATTRIBUTE_HEIGHT_TIMEX_HI_RES 8
#define ATTRIBUTE_WIDTH 8
#define ATTRIBUTE_WIDTH_TIMEX_HI_RES 256

#define ATTRIBUTE_ZX			0
#define ATTRIBUTE_TIMEX_HI_COL	1
#define ATTRIBUTE_TIMEX_HI_RES	2

const unsigned char* attribute(
							  const unsigned char* bitmap,
							  const PixelData* pixelData,
							  unsigned int x,
							  unsigned int y
							  );

unsigned char* mutableAttribute(
							   unsigned char* bitmap,
							   const PixelData* pixelData,
							   unsigned int x,
							   unsigned int y
							   );

int pixelRGBFromBlock(
					 const unsigned char* block,
					 const PixelData* pixelData,
					 const unsigned int x,
					 unsigned int y
					 );

void setPixelBlock(
				  unsigned char* block,
				  const PixelData* pixelData,
				  const int* newPixels
				  );

void setPixelData(
				PixelData* pixelData,
				int width,
				int height,
				int screenWidth
				);

void analyzeBlock(
				  unsigned char* bitmap,
				  PixelData* pixelData,
				  unsigned int x,
				  unsigned int y,
				  int* paperInk,
				  int* pixels,
				  int pixelCount
				  );

float commonColours(int* block, int blockSize, int *paperInk);

void setBrightnessThreshold(float f);
void setUseBright(int use);

void floydSteinberg(int fs);
void setTolerance(int tol);



#endif
