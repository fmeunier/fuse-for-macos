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

#import "FuseQuickLookImage.h"
#import "FuseQuickLookThumbnail.h"

static CGSize
thumbnail_context_size( QLFileThumbnailRequest *request, NSSize source_size )
{
  CGSize maximum_size;

  maximum_size = [request maximumSize];
  if( maximum_size.width > 0 && maximum_size.height > 0 ) return maximum_size;

  return CGSizeMake( source_size.width, source_size.height );
}

static CGRect
thumbnail_draw_rect( CGSize context_size, NSSize source_size )
{
  CGFloat scale;
  CGSize scaled_size;

  if( source_size.width <= 0 || source_size.height <= 0 ) {
    return CGRectZero;
  }

  scale = MIN( context_size.width / source_size.width,
               context_size.height / source_size.height );
  if( scale <= 0 ) scale = 1;

  scaled_size = CGSizeMake( source_size.width * scale, source_size.height * scale );

  return CGRectMake( ( context_size.width - scaled_size.width ) / 2,
                     ( context_size.height - scaled_size.height ) / 2,
                     scaled_size.width,
                     scaled_size.height );
}

static BOOL
draw_thumbnail_image( CGContextRef context, CGSize context_size, NSSize source_size,
                      CGImageRef image )
{
  CGRect draw_rect;

  if( !image ) return NO;

  draw_rect = thumbnail_draw_rect( context_size, source_size );
  if( CGRectIsEmpty( draw_rect ) ) return NO;

  CGContextSaveGState( context );
  CGContextTranslateCTM( context, 0, context_size.height );
  CGContextScaleCTM( context, 1, -1 );
  CGContextDrawImage( context,
                      CGRectMake( draw_rect.origin.x,
                                  context_size.height - CGRectGetMaxY( draw_rect ),
                                  draw_rect.size.width,
                                  draw_rect.size.height ),
                      image );
  CGContextRestoreGState( context );

  return YES;
}

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

  NSLog( @"FuseThumbnailExtension: %@ kind=%d", [[request fileURL] path],
         [thumbnail thumbnailKind] );

  if( [thumbnail thumbnailKind] == FUSE_QUICKLOOK_THUMBNAIL_NONE ) {
    NSLog( @"FuseThumbnailExtension: no thumbnail kind" );
    handler( nil, nil );
    return;
  }

  canvas_size = [thumbnail canvasSize];
  if( NSEqualSizes( canvas_size, NSZeroSize ) ) {
    NSLog( @"FuseThumbnailExtension: zero canvas size" );
    handler( nil, nil );
    return;
  }

  context_size = thumbnail_context_size( request, canvas_size );

  switch( [thumbnail thumbnailKind] ) {
  case FUSE_QUICKLOOK_THUMBNAIL_BITMAP:
    bitmap = [thumbnail bitmapImageRep];
    if( !bitmap ) {
      NSLog( @"FuseThumbnailExtension: bitmap image rep missing" );
      handler( nil, nil );
      return;
    }

    handler( [QLThumbnailReply replyWithContextSize:context_size
                                       drawingBlock:^BOOL(CGContextRef context) {
                                         return draw_thumbnail_image( context, context_size,
                                                                      canvas_size, [bitmap CGImage] );
                                       }],
             nil );
    return;

  case FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA:
    image_data = [thumbnail imageData];
    if( !image_data ) {
      NSLog( @"FuseThumbnailExtension: image data missing" );
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

                                         success = draw_thumbnail_image( context, context_size,
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
