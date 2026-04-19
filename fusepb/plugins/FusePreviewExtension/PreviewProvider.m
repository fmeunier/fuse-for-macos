/* PreviewProvider.m: Quick Look preview extension entry point
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

#import "PreviewProvider.h"

#import <ImageIO/ImageIO.h>

#import "FuseQuickLookDrawing.h"
#import "FuseQuickLookImage.h"
#import "FuseQuickLookPreview.h"

@implementation PreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply * _Nullable,
                                               NSError * _Nullable))handler
{
  NSBitmapImageRep *bitmap;
  FuseQuickLookImage *quicklook_image;
  FuseQuickLookPreview *preview;
  NSData *preview_data;
  NSSize content_size;

  quicklook_image = [[[FuseQuickLookImage alloc] initWithContentsOfURL:[request fileURL]] autorelease];
  preview = [[[FuseQuickLookPreview alloc] initWithQuickLookImage:quicklook_image] autorelease];

  if( [preview previewKind] == FUSE_QUICKLOOK_PREVIEW_NONE ) {
    handler( nil, nil );
    return;
  }

  content_size = [preview contentSize];
  if( NSEqualSizes( content_size, NSZeroSize ) ) {
    handler( nil, nil );
    return;
  }

  if( [quicklook_image imageKind] == FUSE_QUICKLOOK_IMAGE_SCR ) {
    bitmap = [quicklook_image bitmapImageRep];
    if( !bitmap ) {
      handler( nil, nil );
      return;
    }

    handler( [[[QLPreviewReply alloc]
                initWithContextSize:*(CGSize *)&content_size
                isBitmap:YES
                drawingBlock:^BOOL(CGContextRef context,
                                   QLPreviewReply *reply,
                                   NSError **error) {
                  return fuse_quicklook_draw_image( context,
                                                    *(CGSize *)&content_size,
                                                    content_size,
                                                    [bitmap CGImage] );
                }] autorelease],
             nil );
    return;
  }

  preview_data = [preview previewData];
  if( !preview_data ) {
    handler( nil, nil );
    return;
  }

  handler( [[[QLPreviewReply alloc]
              initWithContextSize:*(CGSize *)&content_size
              isBitmap:YES
              drawingBlock:^BOOL(CGContextRef context,
                                 QLPreviewReply *reply,
                                 NSError **error) {
                CGImageSourceRef image_source;
                CGImageRef image;
                BOOL success;

                image_source = CGImageSourceCreateWithData( (CFDataRef)preview_data, NULL );
                if( !image_source ) return NO;

                image = CGImageSourceCreateImageAtIndex( image_source, 0, NULL );
                CFRelease( image_source );
                if( !image ) return NO;

                success = fuse_quicklook_draw_image( context,
                                                     *(CGSize *)&content_size,
                                                     content_size,
                                                     image );
                CGImageRelease( image );
                return success;
              }] autorelease],
           nil );
}

@end
