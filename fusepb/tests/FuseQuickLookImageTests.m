/* FuseQuickLookImageTests.m: Tests for shared Quick Look image logic
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

#include <libspectrum.h>

#import "FuseQuickLookImage.h"

@interface FuseQuickLookImageTests : XCTestCase
@end

@implementation FuseQuickLookImageTests

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

- (void)test_scr_file_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"../fuse/lib/keyboard.scr"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SCREENSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_snapshot_file_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/plus3.z80"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_tzx_without_art_returns_no_image
{
  FuseQuickLookImage *image;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/turbo-zeropilot.tzx"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_tzx_with_embedded_inlay_returns_imageio_image
{
  FuseQuickLookImage *image;
  NSData *image_data;
  NSDictionary *image_options;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/keyboard-inlay.tzx"]] autorelease];
  image_data = [image imageData];
  image_options = [image imageOptions];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_IMAGEIO );
  XCTAssertNotNil( image_data );
  XCTAssertTrue( [image_data length] > 4 );
  XCTAssertEqual( ((const unsigned char *)[image_data bytes])[0], 0xff );
  XCTAssertEqual( ((const unsigned char *)[image_data bytes])[1], 0xd8 );
  XCTAssertEqualObjects( [image_options objectForKey:(NSString*)kCGImageSourceTypeIdentifierHint],
                         @"public.jpeg" );
  XCTAssertNil( [image bitmapImageRep] );
}

@end
