/* ThumbnailProvider.m: Quick Look thumbnail extension entry point
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

#import "ThumbnailProvider.h"

#import <ImageIO/ImageIO.h>

#import "FuseQuickLookDrawing.h"
#import "FuseQuickLookImage.h"
#import "FuseQuickLookThumbnail.h"

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply * _Nullable,
                                                 NSError * _Nullable))handler
{
  FuseQuickLookImage *quicklook_image;
  FuseQuickLookThumbnail *thumbnail;
  NSBitmapImageRep *bitmap;
  NSData *image_data;
  NSSize canvas_size;
  CGSize context_size;

  quicklook_image = [[[FuseQuickLookImage alloc] initWithContentsOfURL:[request fileURL]] autorelease];
  thumbnail = [[[FuseQuickLookThumbnail alloc] initWithQuickLookImage:quicklook_image] autorelease];

  if( [thumbnail thumbnailKind] == FUSE_QUICKLOOK_THUMBNAIL_NONE ) {
    handler( nil, nil );
    return;
  }

  canvas_size = [thumbnail canvasSize];
  if( NSEqualSizes( canvas_size, NSZeroSize ) ) {
    handler( nil, nil );
    return;
  }

  context_size = fuse_quicklook_context_size( [request maximumSize], canvas_size );

  switch( [thumbnail thumbnailKind] ) {
  case FUSE_QUICKLOOK_THUMBNAIL_BITMAP:
    bitmap = [thumbnail bitmapImageRep];
    if( !bitmap ) {
      handler( nil, nil );
      return;
    }

    handler( [QLThumbnailReply replyWithContextSize:context_size
                                       drawingBlock:^BOOL(CGContextRef context) {
                                         return fuse_quicklook_draw_image( context, context_size,
                                                                           canvas_size,
                                                                           [bitmap CGImage] );
                                       }],
             nil );
    return;

  case FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA:
    image_data = [thumbnail imageData];
    if( !image_data ) {
      handler( nil, nil );
      return;
    }

    handler( [QLThumbnailReply replyWithContextSize:context_size
                                       drawingBlock:^BOOL(CGContextRef context) {
                                         CGImageSourceRef image_source;
                                         CGImageRef image;
                                         BOOL success;

                                         image_source = CGImageSourceCreateWithData( (CFDataRef)image_data, NULL );
                                         if( !image_source ) return NO;

                                         image = CGImageSourceCreateImageAtIndex( image_source, 0, NULL );
                                         CFRelease( image_source );
                                         if( !image ) return NO;

                                         success = fuse_quicklook_draw_image( context, context_size,
                                                                              canvas_size, image );
                                         CGImageRelease( image );
                                         return success;
                                       }],
             nil );
    return;

  case FUSE_QUICKLOOK_THUMBNAIL_NONE:
  default:
    handler( nil, nil );
    return;
  }
}

@end
