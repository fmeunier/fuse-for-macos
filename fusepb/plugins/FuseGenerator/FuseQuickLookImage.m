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

#import <ImageIO/ImageIO.h>

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
  NSData *data;
  CGImageSourceRef image_source;
  CFDictionaryRef properties;
  NSNumber *pixel_width;
  NSNumber *pixel_height;
  NSSize size;

  switch( [self imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_SCR:
    current_screen = [self screen];
    if( !current_screen ) return NSZeroSize;

    return [current_screen canvasSize];

  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    data = [self imageData];
    if( !data ) return NSZeroSize;

    image_source = CGImageSourceCreateWithData( (CFDataRef)data, NULL );
    if( !image_source ) return NSZeroSize;

    properties = CGImageSourceCopyPropertiesAtIndex( image_source, 0, NULL );
    CFRelease( image_source );
    if( !properties ) return NSZeroSize;

    pixel_width = [(NSDictionary *)properties objectForKey:(NSString*)kCGImagePropertyPixelWidth];
    pixel_height = [(NSDictionary *)properties objectForKey:(NSString*)kCGImagePropertyPixelHeight];
    size = NSZeroSize;
    if( pixel_width && pixel_height ) {
      size = NSMakeSize( [pixel_width doubleValue], [pixel_height doubleValue] );
    }
    CFRelease( properties );

    return size;

  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    return NSZeroSize;
  }
}

- (JWSpectrumScreen*)screen
{
  if( screen || [self imageKind] != FUSE_QUICKLOOK_IMAGE_SCR ) return screen;

  screen = [[JWSpectrumScreen alloc] initFromData:[self imageData]
                                          mltHint:[self libspectrumType] == LIBSPECTRUM_ID_SCREEN_MLT];

  return screen;
}

@end
