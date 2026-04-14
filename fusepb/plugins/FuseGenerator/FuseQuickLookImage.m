/* FuseQuickLookImage.m: Shared Quick Look image extraction and rendering
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "FuseQuickLookImage.h"

#import "JWSpectrumScreen/JWSpectrumScreen.h"
#import "LibspectrumSCRExtractor.h"

@interface FuseQuickLookImage () {
  LibspectrumSCRExtractor *extractor;
  JWSpectrumScreen *screen;
}

- (JWSpectrumScreen*)screen;

@end

@implementation FuseQuickLookImage

- (id)initWithContentsOfURL:(NSURL*)url
{
  self = [super init];
  if( !self ) return nil;

  extractor = [[LibspectrumSCRExtractor alloc] initWithContentsOfURL:url];

  return self;
}

- (void)dealloc
{
  [screen release];
  [extractor release];

  [super dealloc];
}

- (libspectrum_id_t)libspectrumType
{
  return [extractor type];
}

- (libspectrum_class_t)libspectrumClass
{
  return [extractor class];
}

- (FuseQuickLookImageKind)imageKind
{
  switch( [extractor image_type] ) {
  case TYPE_SCR:
    return FUSE_QUICKLOOK_IMAGE_SCR;
  case TYPE_IMAGEIO:
    return FUSE_QUICKLOOK_IMAGE_IMAGEIO;
  case TYPE_NONE:
  default:
    return FUSE_QUICKLOOK_IMAGE_NONE;
  }
}

- (NSData*)imageData
{
  return [extractor scrData];
}

- (NSDictionary*)imageOptions
{
  return [extractor scrOptions];
}

- (NSBitmapImageRep*)bitmapImageRep
{
  JWSpectrumScreen *current_screen;

  current_screen = [self screen];
  if( !current_screen ) return nil;

  return [current_screen imageRep];
}

- (NSSize)canvasSize
{
  JWSpectrumScreen *current_screen;

  current_screen = [self screen];
  if( !current_screen ) return NSZeroSize;

  return [current_screen canvasSize];
}

- (JWSpectrumScreen*)screen
{
  if( screen || [self imageKind] != FUSE_QUICKLOOK_IMAGE_SCR ) return screen;

  screen = [[JWSpectrumScreen alloc] initFromData:[self imageData]
                                          mltHint:[self libspectrumType] == LIBSPECTRUM_ID_SCREEN_MLT];

  return screen;
}

@end
