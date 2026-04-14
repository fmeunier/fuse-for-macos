/* FuseQuickLookThumbnail.h: Shared thumbnail generation for Quick Look
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

#import <Cocoa/Cocoa.h>

@class FuseQuickLookImage;

typedef enum FuseQuickLookThumbnailKind {
  FUSE_QUICKLOOK_THUMBNAIL_NONE,
  FUSE_QUICKLOOK_THUMBNAIL_BITMAP,
  FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA,
} FuseQuickLookThumbnailKind;

@interface FuseQuickLookThumbnail : NSObject

- (id)initWithQuickLookImage:(FuseQuickLookImage*)image;

- (FuseQuickLookThumbnailKind)thumbnailKind;
- (NSSize)canvasSize;
- (NSImage*)image;
- (NSBitmapImageRep*)bitmapImageRep;
- (NSData*)imageData;
- (NSDictionary*)imageOptions;

@end
