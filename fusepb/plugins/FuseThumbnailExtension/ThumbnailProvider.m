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

#import "FuseQuickLookImage.h"
#import "FuseQuickLookThumbnail.h"

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply * _Nullable,
                                                 NSError * _Nullable))handler
{
  FuseQuickLookImage *quicklook_image;
  FuseQuickLookThumbnail *thumbnail;
  NSImage *image;
  NSSize canvas_size;

  quicklook_image = [[[FuseQuickLookImage alloc] initWithContentsOfURL:[request fileURL]] autorelease];
  thumbnail = [[[FuseQuickLookThumbnail alloc] initWithQuickLookImage:quicklook_image] autorelease];

  if( [thumbnail thumbnailKind] == FUSE_QUICKLOOK_THUMBNAIL_NONE ) {
    handler( nil, nil );
    return;
  }

  image = [thumbnail image];
  if( !image ) {
    handler( nil, nil );
    return;
  }

  canvas_size = [thumbnail canvasSize];

  handler( [QLThumbnailReply replyWithContextSize:*(CGSize *)&canvas_size
                       currentContextDrawingBlock:^BOOL {
                         [image drawInRect:NSMakeRect( 0, 0,
                                                      canvas_size.width,
                                                      canvas_size.height )];
                         return YES;
                       }],
           nil );
}

@end
