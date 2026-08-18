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

- (NSBitmapImageRep*)bitmapImageRepWithContentsOfURL:(NSURL*)url
{
  NSImage *image;
  NSData *tiff_data;

  image = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
  XCTAssertNotNil( image );

  tiff_data = [image TIFFRepresentation];
  XCTAssertNotNil( tiff_data );

  return [[[NSBitmapImageRep alloc] initWithData:tiff_data] autorelease];
}

- (NSBitmapImageRep*)bitmapImageRepWithImageData:(NSData*)image_data
{
  NSImage *image;
  NSData *tiff_data;

  image = [[[NSImage alloc] initWithData:image_data] autorelease];
  XCTAssertNotNil( image );

  tiff_data = [image TIFFRepresentation];
  XCTAssertNotNil( tiff_data );

  return [[[NSBitmapImageRep alloc] initWithData:tiff_data] autorelease];
}

- (NSColor*)sampleColorFromBitmap:(NSBitmapImageRep*)bitmap x:(double)x y:(double)y
{
  NSInteger pixel_x;
  NSInteger pixel_y;

  pixel_x = (NSInteger)( x * ( [bitmap pixelsWide] - 1 ) );
  pixel_y = (NSInteger)( y * ( [bitmap pixelsHigh] - 1 ) );

  return [[bitmap colorAtX:pixel_x y:pixel_y] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
}

- (void)assertBitmap:(NSBitmapImageRep*)bitmap matchesReferenceAtPoints:(NSArray<NSValue*>*)points tolerance:(CGFloat)tolerance
{
  NSBitmapImageRep *reference;
  NSUInteger i;

  reference = [self bitmapImageRepWithContentsOfURL:[self fixtureURL:@"../fuse/lib/keyboard.png"]];
  XCTAssertNotNil( reference );

  for( i = 0; i < [points count]; i++ ) {
    CGPoint point;
    NSColor *actual;
    NSColor *expected;

    point = [[points objectAtIndex:i] pointValue];
    actual = [self sampleColorFromBitmap:bitmap x:point.x y:point.y];
    expected = [self sampleColorFromBitmap:reference x:point.x y:point.y];

    XCTAssertNotNil( actual );
    XCTAssertNotNil( expected );
    XCTAssertEqualWithAccuracy( [actual redComponent], [expected redComponent], tolerance );
    XCTAssertEqualWithAccuracy( [actual greenComponent], [expected greenComponent], tolerance );
    XCTAssertEqualWithAccuracy( [actual blueComponent], [expected blueComponent], tolerance );
  }
}

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

- (NSDictionary*)plistAtRelativePath:(NSString*)relative_path
{
  NSDictionary *plist;

  plist = [NSDictionary dictionaryWithContentsOfURL:[self fixtureURL:relative_path]];
  XCTAssertNotNil( plist );

  return plist;
}

- (NSSet<NSString*>*)documentTypesFromImporterInfoPlist
{
  NSDictionary *plist;
  NSArray *document_types;
  NSDictionary *libspectrum_types;
  NSArray *content_types;

  plist = [self plistAtRelativePath:@"plugins/FuseImporter/Info.plist"];
  document_types = [plist objectForKey:@"CFBundleDocumentTypes"];
  XCTAssertEqual( [document_types count], 1u );

  libspectrum_types = [document_types objectAtIndex:0];
  content_types = [libspectrum_types objectForKey:@"LSItemContentTypes"];
  XCTAssertNotNil( content_types );

  return [NSSet setWithArray:content_types];
}

- (NSSet<NSString*>*)quickLookContentTypesAtRelativePath:(NSString*)relative_path
{
  NSDictionary *plist;
  NSDictionary *extension;
  NSDictionary *attributes;
  NSArray *content_types;

  plist = [self plistAtRelativePath:relative_path];
  extension = [plist objectForKey:@"NSExtension"];
  XCTAssertNotNil( extension );

  attributes = [extension objectForKey:@"NSExtensionAttributes"];
  XCTAssertNotNil( attributes );

  content_types = [attributes objectForKey:@"QLSupportedContentTypes"];
  XCTAssertNotNil( content_types );

  return [NSSet setWithArray:content_types];
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

  [self assertBitmap:bitmap
 matchesReferenceAtPoints:@[
   [NSValue valueWithPoint:NSMakePoint( 0.03, 0.97 )],
   [NSValue valueWithPoint:NSMakePoint( 0.92, 0.85 )],
   [NSValue valueWithPoint:NSMakePoint( 0.11, 0.18 )],
   [NSValue valueWithPoint:NSMakePoint( 0.95, 0.14 )],
 ]
             tolerance:0.25];
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
  NSBitmapImageRep *bitmap;

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

  bitmap = [self bitmapImageRepWithImageData:image_data];
  XCTAssertEqual( [bitmap pixelsWide], 541 );
  XCTAssertEqual( [bitmap pixelsHigh], 201 );
  [self assertBitmap:bitmap
 matchesReferenceAtPoints:@[
   [NSValue valueWithPoint:NSMakePoint( 0.03, 0.97 )],
   [NSValue valueWithPoint:NSMakePoint( 0.92, 0.85 )],
   [NSValue valueWithPoint:NSMakePoint( 0.11, 0.18 )],
   [NSValue valueWithPoint:NSMakePoint( 0.95, 0.14 )],
 ]
             tolerance:0.18];
}

- (void)test_tzx_with_embedded_inlay_canvas_size_matches_image_dimensions
{
  FuseQuickLookImage *image;
  NSSize canvas;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/keyboard-inlay.tzx"]] autorelease];
  canvas = [image canvasSize];

  /* Pixel dimensions of the embedded JPEG inlay, not DPI-scaled logical points */
  XCTAssertEqual( canvas.width,  541.0 );
  XCTAssertEqual( canvas.height, 201.0 );
}

- (void)test_importer_and_preview_extension_declare_matching_content_types
{
  NSSet<NSString*> *importer_types;
  NSSet<NSString*> *preview_types;

  importer_types = [self documentTypesFromImporterInfoPlist];
  preview_types = [self quickLookContentTypesAtRelativePath:@"plugins/FusePreviewExtension/Info.plist"];

  XCTAssertEqualObjects( preview_types, importer_types );
}

- (void)test_importer_and_thumbnail_extension_declare_matching_content_types
{
  NSSet<NSString*> *importer_types;
  NSSet<NSString*> *thumbnail_types;

  importer_types = [self documentTypesFromImporterInfoPlist];
  thumbnail_types = [self quickLookContentTypesAtRelativePath:@"plugins/FuseThumbnailExtension/Info.plist"];

  XCTAssertEqualObjects( thumbnail_types, importer_types );
}

- (void)test_scr_file_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"../fuse/lib/keyboard.scr"]] autorelease];
  canvas = [image canvasSize];

  /* Standard Spectrum screens are 256x192 pixels */
  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/plus3.z80"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_non_scr_file_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* A tape with no embedded screen has no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/turbo-zeropilot.tzx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/random.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/random.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_empty_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* Minimal 48K SZX with an all-zero (blank) screen — still a valid snapshot */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_empty_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Minimal 48K SZX with an all-zero screen — canvas size still 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_tc2048_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* TC2048 SZX snapshot — exercises process_snap_timex via a snapshot file.
     With all-zero registers out_scld_dec=0 selects the standard 256x192 screen. */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tc2048.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_tc2048_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* TC2048 SZX snapshot — canvas size should be the standard 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tc2048.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_mdr_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Microdrive cartridge with no SCREEN$ code file */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/writeprotected.mdr"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_MICRODRIVE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_mdr_file_with_screen_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* Microdrive cartridge containing a SCREEN$ code file */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/test.mdr"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_MICRODRIVE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_mdr_file_with_screen_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Microdrive cartridge containing a SCREEN$ code file */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/test.mdr"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_mdr_canvas_size_is_zero_without_screen
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* MDR with no SCREEN$ code file — canvas size should be zero.
     Remains valid for MDR files without a SCREEN$ even after
     process_mdr thumbnail extraction is implemented. */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/writeprotected.mdr"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_tap_file_with_no_screen_produces_no_image
{
  FuseQuickLookImage *image;

  /* Plain TAP containing a BASIC program — no loading screen */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/standard-tap.tap"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_tap_canvas_size_is_zero_without_screen
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Plain TAP containing a BASIC program — no loading screen, canvas size should be zero */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/standard-tap.tap"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_tap_with_screen_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* TAP file containing a 6912-byte data block — standard Spectrum screen */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tap-with-screen.tap"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_tap_with_screen_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* TAP file with a SCREEN$-sized data block — canvas should be standard 256×192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tap-with-screen.tap"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_pzx_file_with_no_screen_produces_no_image
{
  FuseQuickLookImage *image;

  /* PZX tape with no embedded loading screen */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/pzx-archive-info-tags.pzx"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_pzx_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* PZX tape with no loading screen — canvas size should be zero */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/pzx-archive-info-tags.pzx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_trd_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* TRD disk image with no SCREEN$ file — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.trd"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_TRDOS );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_trd_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* TRD disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.trd"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_scl_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* SCL disk archive with no files — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.scl"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_TRDOS );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_scl_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* SCL disk archive — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.scl"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_dsk_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Plus3 DSK disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.dsk"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_PLUS3 );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_dsk_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Plus3 DSK disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.dsk"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_empty_z80_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* Minimal 48K Z80 v2 snapshot with an all-zero screen — still a valid snapshot */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.z80"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_empty_z80_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Minimal 48K Z80 v2 snapshot — canvas size is always 256x192 for snapshots */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.z80"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_invalid_szx_produces_no_image
{
  FuseQuickLookImage *image;

  /* Truncated SZX (only 17 bytes — valid magic, no body) — must fail gracefully */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/invalid.szx"]] autorelease];

  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_invalid_szx_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Truncated SZX — parse failure should yield a zero canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/invalid.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_csw_tape_produces_no_image
{
  FuseQuickLookImage *image;

  /* CSW (Compressed Square Wave) tape — tape types with no loading screen yield no image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.csw"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_csw_tape_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* CSW tape with no loading screen — canvas size should be zero */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/empty.csw"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_rzx_recording_produces_no_image
{
  FuseQuickLookImage *image;

  /* RZX with an invalid repeat frame — recording with no extractable snap yields no image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/invalid-repeat-frame.rzx"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_RECORDING );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_rzx_recording_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* RZX recording with no extractable snap — canvas size should be zero */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"deps/libspectrum/test/invalid-repeat-frame.rzx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}


- (void)test_opd_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Opus Discovery disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.opd"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_OPUS );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_opd_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Opus Discovery disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.opd"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_mgt_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* DISCiPLE/+D MGT disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.mgt"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_PLUSD );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_mgt_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* DISCiPLE/+D MGT disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.mgt"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_hdf_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* HDF hard disk image — hard disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.hdf"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_HARDDISK );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_hdf_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* HDF hard disk image — hard disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.hdf"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_dck_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Timex DCK cartridge image — cartridge types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.dck"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_CARTRIDGE_TIMEX );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_dck_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Timex DCK cartridge image — cartridge types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.dck"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_img_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* PlusD/DISCiPLE .img disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.img"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_PLUSD );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_img_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* PlusD/DISCiPLE .img disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.img"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_opu_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Opus Discovery .opu disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.opu"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_OPUS );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_opu_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Opus Discovery .opu disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.opu"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_d80_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Didaktik D80/D40 disk image — disk types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.d80"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_DISK_DIDAKTIK );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_d80_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Didaktik D80/D40 disk image — disk types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.d80"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_timex_hicolour_scr_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* Timex HiColour .scr (12288 bytes) — two 6144-byte planes; renders as 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/timex-hicolour.scr"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SCREENSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_timex_hicolour_scr_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Timex HiColour .scr (12288 bytes) — same canvas dimensions as a standard 256x192 screen */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/timex-hicolour.scr"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_timex_hires_scr_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* Timex HiRes .scr (12289 bytes) — 512x384 mono display with one colour-mode byte */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/timex-hires.scr"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SCREENSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 512 );
  XCTAssertEqual( [bitmap pixelsHigh], 384 );
}

- (void)test_timex_hires_scr_canvas_size_is_hires_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Timex HiRes .scr (12289 bytes) — canvas is 512x384 (double the standard height) */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/timex-hires.scr"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  512.0 );
  XCTAssertEqual( canvas.height, 384.0 );
}

- (void)test_rom_file_produces_no_image
{
  FuseQuickLookImage *image;

  /* Interface 2 ROM cartridge image — cartridge types yield no Quick Look image */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.rom"]] autorelease];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_CARTRIDGE_IF2 );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_NONE );
  XCTAssertNil( [image imageData] );
  XCTAssertNil( [image bitmapImageRep] );
}

- (void)test_rom_canvas_size_is_zero
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* Interface 2 ROM cartridge image — cartridge types have no canvas */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/empty.rom"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  0.0 );
  XCTAssertEqual( canvas.height, 0.0 );
}

- (void)test_tzx_turbo_block_with_screen_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* TZX with a turbo-speed (0x11) block containing a SCREEN$-sized payload —
     the TURBO/DATA_BLOCK path in process_tape must extract it */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tzx-with-turbo-screen.tzx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_tzx_turbo_block_with_screen_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* TZX turbo block with SCREEN$-sized payload — canvas must be 256×192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/tzx-with-turbo-screen.tzx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_TAPE );
  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_se_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* SE machine SZX snapshot — exercises process_snap_se via a snapshot file.
     With out_128_memoryport=0 (bit 3 clear) the screen is read from page 5. */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/se.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_se_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* SE machine SZX snapshot — canvas size should be the standard 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/se.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_plus2_page7_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* 128k SZX snapshot with out_128_memoryport bit 3 set — exercises the
     page-7 branch of process_snap_sinclair128. */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/plus2-page7.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_plus2_page7_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* 128k SZX snapshot with page-7 screen — canvas should be standard 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/plus2-page7.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}

- (void)test_plus2_szx_snapshot_produces_bitmap_image
{
  FuseQuickLookImage *image;
  NSBitmapImageRep *bitmap;

  /* 128k / Plus2 SZX snapshot — exercises process_snap_sinclair128.
     Machine type SZX_MACHINE_PLUS2 (0x02); with out_128_memoryport=0
     (bit 3 clear) the screen is read from RAM page 5. */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/plus2.szx"]] autorelease];
  bitmap = [image bitmapImageRep];

  XCTAssertEqual( [image libspectrumClass], LIBSPECTRUM_CLASS_SNAPSHOT );
  XCTAssertEqual( [image imageKind], FUSE_QUICKLOOK_IMAGE_SCR );
  XCTAssertNotNil( bitmap );
  XCTAssertEqual( [bitmap pixelsWide], 256 );
  XCTAssertEqual( [bitmap pixelsHigh], 192 );
}

- (void)test_plus2_szx_snapshot_canvas_size_is_standard_spectrum_resolution
{
  FuseQuickLookImage *image;
  NSSize canvas;

  /* 128k / Plus2 SZX snapshot — canvas size should be the standard 256x192 */
  image = [[[FuseQuickLookImage alloc]
             initWithContentsOfURL:[self fixtureURL:@"tests/fixtures/plus2.szx"]] autorelease];
  canvas = [image canvasSize];

  XCTAssertEqual( canvas.width,  256.0 );
  XCTAssertEqual( canvas.height, 192.0 );
}
@end
