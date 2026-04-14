/* FuseQuickLookThumbnailTests.m: Tests for shared Quick Look thumbnails
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

#import <XCTest/XCTest.h>

#import "FuseQuickLookImage.h"
#import "FuseQuickLookThumbnail.h"

@interface FuseQuickLookThumbnailTests : XCTestCase
@end

@implementation FuseQuickLookThumbnailTests

- (NSURL*)fixtureURL:(NSString*)relative_path
{
  NSString *source_file;
  NSString *fusepb_root;
  NSString *path;

  source_file = [NSString stringWithUTF8String:__FILE__];
  fusepb_root = [[source_file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
  path = [[fusepb_root stringByAppendingPathComponent:relative_path] stringByStandardizingPath];

  return [NSURL fileURLWithPath:path];
}

- (FuseQuickLookThumbnail*)thumbnailForFixture:(NSString*)relative_path
{
  FuseQuickLookImage *image;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:relative_path]] autorelease];

  return [[[FuseQuickLookThumbnail alloc] initWithQuickLookImage:image] autorelease];
}

- (void)test_scr_file_produces_bitmap_thumbnail
{
  FuseQuickLookThumbnail *thumbnail;
  NSBitmapImageRep *bitmap;

  thumbnail = [self thumbnailForFixture:@"../fuse/lib/keyboard.scr"];
  bitmap = [thumbnail bitmapImageRep];

  XCTAssertEqual( [thumbnail thumbnailKind], FUSE_QUICKLOOK_THUMBNAIL_BITMAP );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_snapshot_file_produces_bitmap_thumbnail
{
  FuseQuickLookThumbnail *thumbnail;
  NSBitmapImageRep *bitmap;

  thumbnail = [self thumbnailForFixture:@"deps/libspectrum/test/plus3.z80"];
  bitmap = [thumbnail bitmapImageRep];

  XCTAssertEqual( [thumbnail thumbnailKind], FUSE_QUICKLOOK_THUMBNAIL_BITMAP );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_tzx_without_art_returns_no_thumbnail
{
  FuseQuickLookThumbnail *thumbnail;

  thumbnail = [self thumbnailForFixture:@"deps/libspectrum/test/turbo-zeropilot.tzx"];

  XCTAssertEqual( [thumbnail thumbnailKind], FUSE_QUICKLOOK_THUMBNAIL_NONE );
  XCTAssertNil( [thumbnail bitmapImageRep] );
  XCTAssertNil( [thumbnail imageData] );
}

@end
