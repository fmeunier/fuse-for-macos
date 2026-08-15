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

#import <ImageIO/ImageIO.h>

#include <string.h>

#import "FuseQuickLookImage.h"
#import "FuseQuickLookPreview.h"

@interface FuseQuickLookPreviewTestImage : FuseQuickLookImage {
  NSData *test_image_data;
  NSDictionary *test_image_options;
}

- (id)initWithImageData:(NSData*)image_data options:(NSDictionary*)image_options;

@end

@implementation FuseQuickLookPreviewTestImage

- (id)initWithImageData:(NSData*)image_data options:(NSDictionary*)image_options
{
  self = [super init];
  if( !self ) return nil;

  test_image_data = [image_data retain];
  test_image_options = [image_options retain];

  return self;
}

- (void)dealloc
{
  [test_image_data release];
  [test_image_options release];

  [super dealloc];
}

- (FuseQuickLookImageKind)imageKind
{
  return FUSE_QUICKLOOK_IMAGE_IMAGEIO;
}

- (NSData*)imageData
{
  return test_image_data;
}

- (NSDictionary*)imageOptions
{
  return test_image_options;
}

@end

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

- (FuseQuickLookPreview*)previewForURL:(NSURL*)url
{
  FuseQuickLookImage *image;

  image = [[[FuseQuickLookImage alloc] initWithContentsOfURL:url] autorelease];

  return [[[FuseQuickLookPreview alloc] initWithQuickLookImage:image] autorelease];
}

- (NSData*)jpegDataWithPixelSize:(NSSize)pixel_size dpi:(CGFloat)dpi
{
  NSBitmapImageRep *bitmap;
  NSMutableData *data;
  CGImageDestinationRef destination;
  NSDictionary *properties;

  bitmap = [[[NSBitmapImageRep alloc]
               initWithBitmapDataPlanes:NULL
               pixelsWide:(NSInteger)pixel_size.width
               pixelsHigh:(NSInteger)pixel_size.height
               bitsPerSample:8
               samplesPerPixel:4
               hasAlpha:YES
               isPlanar:NO
               colorSpaceName:NSDeviceRGBColorSpace
               bytesPerRow:0
               bitsPerPixel:0] autorelease];
  XCTAssertNotNil( bitmap );

  data = [NSMutableData data];
  properties = @{
    (NSString*)kCGImagePropertyDPIWidth: @( dpi ),
    (NSString*)kCGImagePropertyDPIHeight: @( dpi ),
  };
  destination = CGImageDestinationCreateWithData( (CFMutableDataRef)data,
                                                  CFSTR( "public.jpeg" ),
                                                  1, NULL );
  XCTAssertNotEqual( destination, NULL );
  CGImageDestinationAddImage( destination, [bitmap CGImage], (CFDictionaryRef)properties );
  XCTAssertTrue( CGImageDestinationFinalize( destination ) );
  CFRelease( destination );

  return data;
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

- (void)test_mdr_real_formatted_screen_dump_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"tests/fixtures/test.mdr"];
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

- (void)test_tzx_with_embedded_inlay_returns_jpeg_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"tests/fixtures/keyboard-inlay.tzx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.jpeg" );
  XCTAssertEqual( [preview contentSize].width, 541.0 );
  XCTAssertEqual( [preview contentSize].height, 201.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 4 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0xff );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0xd8 );
}

- (void)test_scr_content_type_is_correct_when_checked_before_preview_data
{
  FuseQuickLookPreview *preview;

  /* Call -contentTypeIdentifier before -previewData to exercise the path where
     -buildBitmapPreviewIfNeeded sees a content_type_identifier already cached.
     Previously the method unconditionally overwrote the ivar, leaking the first
     copy under MRC. */
  preview = [self previewForFixture:@"../fuse/lib/keyboard.scr"];
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertNotNil( [preview previewData] );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
}

- (void)test_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  preview = [self previewForFixture:@"deps/libspectrum/test/random.szx"];
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

- (void)test_mdr_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Microdrive cartridge with no SCREEN$ — process_mdr stub returns nothing */
  preview = [self previewForFixture:@"deps/libspectrum/test/writeprotected.mdr"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_mdr_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* MDR with no SCREEN$ — content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/writeprotected.mdr"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_tap_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Plain TAP containing a BASIC program — no loading screen, content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/standard-tap.tap"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_tap_file_with_no_screen_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Plain TAP containing a BASIC program — no loading screen */
  preview = [self previewForFixture:@"deps/libspectrum/test/standard-tap.tap"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_tap_with_screen_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* TAP file with a SCREEN$-sized data block — content size should be 256×192 */
  preview = [self previewForFixture:@"tests/fixtures/tap-with-screen.tap"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_tap_with_screen_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* TAP file containing a 6912-byte data block — standard Spectrum screen */
  preview = [self previewForFixture:@"tests/fixtures/tap-with-screen.tap"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 4 );
}

- (void)test_pzx_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* PZX tape with no loading screen — content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/pzx-archive-info-tags.pzx"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_pzx_file_with_no_screen_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* PZX tape with no embedded loading screen */
  preview = [self previewForFixture:@"deps/libspectrum/test/pzx-archive-info-tags.pzx"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_trd_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* TRD disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.trd"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_trd_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* TRD disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.trd"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_scl_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* SCL disk archive — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.scl"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_scl_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* SCL disk archive — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.scl"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_dsk_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Plus3 DSK disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.dsk"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_dsk_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Plus3 DSK disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.dsk"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_empty_z80_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* Minimal 48K Z80 v2 snapshot with an all-zero screen — still a valid snapshot */
  preview = [self previewForFixture:@"deps/libspectrum/test/empty.z80"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_empty_sna_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* Minimal 48K SNA snapshot with an all-zero screen — still a valid snapshot */
  preview = [self previewForFixture:@"tests/fixtures/empty.sna"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_invalid_szx_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Truncated SZX (only 17 bytes — valid magic, no body) — must fail gracefully */
  preview = [self previewForFixture:@"deps/libspectrum/test/invalid.szx"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_szx_snapshot_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  preview = [self previewForFixture:@"deps/libspectrum/test/random.szx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_empty_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* Minimal 48K SZX with an all-zero (blank) screen — still a valid snapshot */
  preview = [self previewForFixture:@"deps/libspectrum/test/empty.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_tc2048_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* TC2048 SZX snapshot — exercises process_snap_timex via snapshot file.
     With all-zero registers the standard 256x192 screen is rendered as PNG. */
  preview = [self previewForFixture:@"tests/fixtures/tc2048.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_mdr_file_with_screen_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* Microdrive cartridge containing a SCREEN$ code file */
  preview = [self previewForFixture:@"tests/fixtures/test.mdr"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_no_image_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Tape with no loading screen — content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/turbo-zeropilot.tzx"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_imageio_preview_uses_pixel_dimensions_not_dpi_scaled_size
{
  FuseQuickLookPreviewTestImage *image;
  FuseQuickLookPreview *preview;

  image = [[[FuseQuickLookPreviewTestImage alloc]
              initWithImageData:[self jpegDataWithPixelSize:NSMakeSize( 281, 400 ) dpi:300.0]
              options:@{ (NSString*)kCGImageSourceTypeIdentifierHint: @"public.jpeg" }] autorelease];
  preview = [[[FuseQuickLookPreview alloc] initWithQuickLookImage:image] autorelease];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.jpeg" );
  XCTAssertEqual( [preview contentSize].width, 281.0 );
  XCTAssertEqual( [preview contentSize].height, 400.0 );
}

- (void)test_csw_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* CSW tape with no loading screen — content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/empty.csw"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_csw_tape_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* CSW (Compressed Square Wave) tape — no loading screen, no preview */
  preview = [self previewForFixture:@"deps/libspectrum/test/empty.csw"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_rzx_recording_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* RZX recording with no extractable snap — content size should be zero */
  preview = [self previewForFixture:@"deps/libspectrum/test/invalid-repeat-frame.rzx"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_rzx_recording_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* RZX with invalid repeat frame — no extractable snap, no preview */
  preview = [self previewForFixture:@"deps/libspectrum/test/invalid-repeat-frame.rzx"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}


- (void)test_opd_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Opus Discovery disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.opd"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_opd_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Opus Discovery disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.opd"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_mgt_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* DISCiPLE/+D MGT disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.mgt"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_mgt_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* DISCiPLE/+D MGT disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.mgt"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_hdf_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* HDF hard disk image — hard disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.hdf"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_hdf_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* HDF hard disk image — hard disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.hdf"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_dck_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Timex DCK cartridge image — cartridge types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.dck"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_dck_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Timex DCK cartridge image — cartridge types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.dck"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_img_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* PlusD/DISCiPLE .img disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.img"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_img_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* PlusD/DISCiPLE .img disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.img"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_opu_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Opus Discovery .opu disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.opu"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_opu_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Opus Discovery .opu disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.opu"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_d80_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Didaktik D80/D40 disk image — disk types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.d80"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_d80_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Didaktik D80/D40 disk image — disk types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.d80"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_timex_hicolour_scr_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* Timex HiColour .scr (12288 bytes) — renders as a 256x192 PNG preview */
  preview = [self previewForFixture:@"tests/fixtures/timex-hicolour.scr"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_timex_hires_scr_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* Timex HiRes .scr (12289 bytes) — renders as a 512x384 PNG preview */
  preview = [self previewForFixture:@"tests/fixtures/timex-hires.scr"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  512.0 );
  XCTAssertEqual( [preview contentSize].height, 384.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_mlt_multicolour_screen_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* MLT (MultiColour) .mlt — same canvas as a standard 256x192 screen */
  preview = [self previewForFixture:@"tests/fixtures/test.mlt"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_mlt_multicolour_screen_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* MLT (MultiColour) .mlt (12288 bytes) — renders as a 256x192 PNG preview */
  preview = [self previewForFixture:@"tests/fixtures/test.mlt"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_rom_without_screen_has_zero_content_size
{
  FuseQuickLookPreview *preview;

  /* Interface 2 ROM cartridge image — cartridge types have no content */
  preview = [self previewForFixture:@"tests/fixtures/empty.rom"];

  XCTAssertEqual( [preview contentSize].width,  0.0 );
  XCTAssertEqual( [preview contentSize].height, 0.0 );
}

- (void)test_rom_file_produces_no_preview
{
  FuseQuickLookPreview *preview;

  /* Interface 2 ROM cartridge image — cartridge types yield no preview */
  preview = [self previewForFixture:@"tests/fixtures/empty.rom"];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_NONE );
  XCTAssertNil( [preview contentTypeIdentifier] );
  XCTAssertNil( [preview previewData] );
}

- (void)test_tzx_turbo_block_with_screen_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* TZX with a turbo-speed block containing a SCREEN$-sized payload */
  preview = [self previewForFixture:@"tests/fixtures/tzx-with-turbo-screen.tzx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_tzx_turbo_block_with_screen_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* TZX turbo block with SCREEN$-sized payload — renders as a 256x192 PNG preview */
  preview = [self previewForFixture:@"tests/fixtures/tzx-with-turbo-screen.tzx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 4 );
}

- (void)test_se_szx_snapshot_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* SE machine SZX snapshot — exercises process_snap_se; content size must be 256x192 */
  preview = [self previewForFixture:@"tests/fixtures/se.szx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_se_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* SE machine SZX snapshot — exercises process_snap_se code path.
     With out_128_memoryport=0 the screen is read from page 5. */
  preview = [self previewForFixture:@"tests/fixtures/se.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_plus2_page7_szx_snapshot_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* 128k SZX snapshot with out_128_memoryport bit 3 set — page-7 screen path;
     content size must be 256x192. */
  preview = [self previewForFixture:@"tests/fixtures/plus2-page7.szx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_plus2_page7_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* 128k SZX snapshot with page-7 screen — exercises the page-7 branch of
     process_snap_sinclair128. */
  preview = [self previewForFixture:@"tests/fixtures/plus2-page7.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_tc2048_hicolour_szx_snapshot_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* TC2048 SZX with SCLD dec=0x02 (HiColour) — content size must be 256x192 */
  preview = [self previewForFixture:@"tests/fixtures/tc2048-hicolour.szx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_tc2048_hicolour_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* TC2048 SZX with SCLD dec=0x02 — HiColour mode.  Exercises the HICOLOUR
     branch of process_snap_timex:inPage: via a snapshot file. */
  preview = [self previewForFixture:@"tests/fixtures/tc2048-hicolour.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_tc2048_hires_szx_snapshot_content_size_is_hires_resolution
{
  FuseQuickLookPreview *preview;

  /* TC2048 SZX with SCLD dec=0x04 (HiRes) — content size must be 512x384 */
  preview = [self previewForFixture:@"tests/fixtures/tc2048-hires.szx"];

  XCTAssertEqual( [preview contentSize].width,  512.0 );
  XCTAssertEqual( [preview contentSize].height, 384.0 );
}

- (void)test_tc2048_hires_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* TC2048 SZX with SCLD dec=0x04 — HiRes mode.  Exercises the HIRES branch
     of process_snap_timex:inPage: via a snapshot file. */
  preview = [self previewForFixture:@"tests/fixtures/tc2048-hires.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  512.0 );
  XCTAssertEqual( [preview contentSize].height, 384.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}

- (void)test_plus2_szx_snapshot_content_size_is_standard_spectrum_resolution
{
  FuseQuickLookPreview *preview;

  /* 128k / Plus2 SZX snapshot — exercises process_snap_sinclair128; content size must be 256x192 */
  preview = [self previewForFixture:@"tests/fixtures/plus2.szx"];

  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
}

- (void)test_plus2_szx_snapshot_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;

  /* 128k / Plus2 SZX snapshot — exercises process_snap_sinclair128 code path.
     With out_128_memoryport=0 (bit 3 clear) the screen is read from RAM page 5. */
  preview = [self previewForFixture:@"tests/fixtures/plus2.szx"];
  preview_data = [preview previewData];

  XCTAssertEqual( [preview previewKind], FUSE_QUICKLOOK_PREVIEW_IMAGE_DATA );
  XCTAssertEqualObjects( [preview contentTypeIdentifier], @"public.png" );
  XCTAssertEqual( [preview contentSize].width,  256.0 );
  XCTAssertEqual( [preview contentSize].height, 192.0 );
  XCTAssertNotNil( preview_data );
  XCTAssertTrue( [preview_data length] > 8 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[0], 0x89 );
  XCTAssertEqual( ((const unsigned char *)[preview_data bytes])[1], 0x50 );
}
@end
