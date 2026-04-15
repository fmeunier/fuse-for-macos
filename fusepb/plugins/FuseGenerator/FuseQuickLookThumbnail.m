/* FuseQuickLookThumbnail.m: Shared thumbnail generation for Quick Look
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

#import "FuseQuickLookThumbnail.h"

#import <ImageIO/ImageIO.h>

#import "FuseQuickLookImage.h"

@interface FuseQuickLookThumbnail () {
  FuseQuickLookImage *image;
  NSImage *thumbnail_image;
}

@end

@implementation FuseQuickLookThumbnail

- (id)initWithQuickLookImage:(FuseQuickLookImage*)quicklook_image
{
  self = [super init];
  if( !self ) return nil;

  image = [quicklook_image retain];

  return self;
}

- (void)dealloc
{
  [thumbnail_image release];
  [image release];

  [super dealloc];
}

- (FuseQuickLookThumbnailKind)thumbnailKind
{
  switch( [image imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_SCR:
    return FUSE_QUICKLOOK_THUMBNAIL_BITMAP;
  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    return FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA;
  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    return FUSE_QUICKLOOK_THUMBNAIL_NONE;
  }
}

- (NSBitmapImageRep*)bitmapImageRep
{
  if( [self thumbnailKind] != FUSE_QUICKLOOK_THUMBNAIL_BITMAP ) return nil;

  return [image bitmapImageRep];
}

- (NSSize)canvasSize
{
  NSBitmapImageRep *bitmap;
  NSData *data;
  CGImageSourceRef image_source;
  CFDictionaryRef properties;
  NSNumber *pixel_width;
  NSNumber *pixel_height;
  NSSize size;

  switch( [self thumbnailKind] ) {
  case FUSE_QUICKLOOK_THUMBNAIL_BITMAP:
    bitmap = [self bitmapImageRep];
    if( !bitmap ) return NSZeroSize;

    return NSMakeSize( [bitmap pixelsWide], [bitmap pixelsHigh] );

  case FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA:
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

  case FUSE_QUICKLOOK_THUMBNAIL_NONE:
  default:
    return NSZeroSize;
  }
}

- (NSImage*)image
{
  NSBitmapImageRep *bitmap;

  if( thumbnail_image ) return thumbnail_image;

  switch( [self thumbnailKind] ) {
  case FUSE_QUICKLOOK_THUMBNAIL_BITMAP:
    bitmap = [self bitmapImageRep];
    if( !bitmap ) return nil;

    thumbnail_image = [[NSImage alloc] initWithSize:NSMakeSize( [bitmap pixelsWide],
                                                                [bitmap pixelsHigh] )];
    [thumbnail_image addRepresentation:bitmap];
    return thumbnail_image;

  case FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA:
    thumbnail_image = [[NSImage alloc] initWithData:[self imageData]];
    return thumbnail_image;

  case FUSE_QUICKLOOK_THUMBNAIL_NONE:
  default:
    return nil;
  }
}

- (NSData*)imageData
{
  if( [self thumbnailKind] != FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA ) return nil;

  return [image imageData];
}

- (NSDictionary*)imageOptions
{
  if( [self thumbnailKind] != FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA ) return nil;

  return [image imageOptions];
}

@end
