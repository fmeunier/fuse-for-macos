/* FuseQuickLookPreviewTests.m: Tests for shared Quick Look previews
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
#import "FuseQuickLookPreview.h"

@interface FuseQuickLookPreviewTests : XCTestCase
@end

@implementation FuseQuickLookPreviewTests

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

- (FuseQuickLookPreview*)previewForFixture:(NSString*)relative_path
{
  FuseQuickLookImage *image;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:relative_path]] autorelease];

  return [[[FuseQuickLookPreview alloc] initWithQuickLookImage:image] autorelease];
}

- (void)test_scr_file_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"../fuse/lib/keyboard.scr"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width, 256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_snapshot_file_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"deps/libspectrum/test/plus3.z80"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width, 256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_tzx_without_art_returns_no_preview
{
  FuseQuickLookPreview *preview;

  preview = [self previewForFixture:@"deps/libspectrum/test/turbo-zeropilot.tzx"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_tzx_with_embedded_inlay_returns_jpeg_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"tests/fixtures/keyboard-inlay.tzx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.jpeg" );
  XCTAssertTrue( [preview contentSize].width > 0.0 );
  XCTAssertTrue( [preview contentSize].height > 0.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 4 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0xff );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0xd8 );
}

@end
