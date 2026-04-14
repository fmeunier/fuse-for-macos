/* FuseQuickLookPreview.m: Shared preview generation for Quick Look
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

#import "FuseQuickLookPreview.h"

#import "FuseQuickLookImage.h"

@interface FuseQuickLookPreview () {
  FuseQuickLookImage *image;
  NSData *preview_data;
  NSString *content_type_identifier;
}

- (void)buildBitmapPreviewIfNeeded;

@end

@implementation FuseQuickLookPreview

- (id)initWithQuickLookImage:(FuseQuickLookImage*)quicklook_image
{
  self = [super init];
  if( !self ) return nil;

  image = [quicklook_image retain];

  return self;
}

- (void)dealloc
{
  [preview_data release];
  [content_type_identifier release];
  [image release];

  [super dealloc];
}

- (FuseQuickLookPreviewKind)previewKind
{
  switch( [image imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_SCR:
  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    return FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA;
  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    return FUSE_QUICKLOOK_PREVIEW_NONE;
  }
}

- (NSString*)contentTypeIdentifier
{
  NSDictionary *options;
  NSString *identifier;

  if( [self previewKind] != FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA ) return nil;

  if( content_type_identifier ) return content_type_identifier;

  switch( [image imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    options = [image imageOptions];
    identifier = [options objectForKey:(NSString*)kCGImageSourceTypeIdentifierHint];
    if( identifier ) {
      content_type_identifier = [identifier copy];
    } else {
      content_type_identifier = [@"public.image" copy];
    }
    break;

  case FUSE_QUICKLOOK_IMAGE_SCR:
    [self buildBitmapPreviewIfNeeded];
    break;

  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    break;
  }

  return content_type_identifier;
}

- (NSData*)previewData
{
  if( [self previewKind] != FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA ) return nil;

  switch( [image imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    return [image imageData];

  case FUSE_QUICKLOOK_IMAGE_SCR:
    [self buildBitmapPreviewIfNeeded];
    return preview_data;

  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    return nil;
  }
}

- (NSSize)contentSize
{
  switch( [image imageKind] ) {
  case FUSE_QUICKLOOK_IMAGE_SCR:
    return [image canvasSize];

  case FUSE_QUICKLOOK_IMAGE_IMAGEIO:
    {
      NSImage *ns_image;

      ns_image = [[[NSImage alloc] initWithData:[image imageData]] autorelease];
      if( !ns_image ) return NSZeroSize;

      return [ns_image size];
    }

  case FUSE_QUICKLOOK_IMAGE_NONE:
  default:
    return NSZeroSize;
  }
}

- (void)buildBitmapPreviewIfNeeded
{
  NSBitmapImageRep *bitmap;

  if( preview_data || [image imageKind] != FUSE_QUICKLOOK_IMAGE_SCR ) return;

  bitmap = [image bitmapImageRep];
  if( !bitmap ) return;

  preview_data = [[bitmap representationUsingType:NSBitmapImageFileTypePNG
                                       properties:[NSDictionary dictionary]] retain];
  content_type_identifier = [@"public.png" copy];
}

@end
