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

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "FuseQuickLookImage.h"
#import "FuseQuickLookPreview.h"

@implementation PreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply * _Nullable,
                                               NSError * _Nullable))handler
{
  FuseQuickLookImage *quicklook_image;
  FuseQuickLookPreview *preview;
  NSString *content_type_identifier;
  NSSize content_size;

  quicklook_image = [[[FuseQuickLookImage alloc] initWithContentsOfURL:[request fileURL]] autorelease];
  preview = [[[FuseQuickLookPreview alloc] initWithQuickLookImage:quicklook_image] autorelease];

  if( [preview previewKind] == FUSE_QUICKLOOK_PREVIEW_NONE ) {
    handler( nil, nil );
    return;
  }

  content_type_identifier = [preview contentTypeIdentifier];
  if( !content_type_identifier ) {
    handler( nil, nil );
    return;
  }

  content_size = [preview contentSize];

  handler( [[[QLPreviewReply alloc]
              initWithDataOfContentType:[UTType typeWithIdentifier:content_type_identifier]
              contentSize:*(CGSize *)&content_size
              dataCreationBlock:^NSData * _Nullable(QLPreviewReply *reply, NSError **error) {
                return [preview previewData];
              }] autorelease],
           nil );
}

@end
