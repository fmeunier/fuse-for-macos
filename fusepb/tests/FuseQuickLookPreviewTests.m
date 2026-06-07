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

- (NSURL*)writeSyntheticMDRScreenDump
{
  static const NSUInteger block_len = 543;
  static const NSUInteger header_len = 15;
  static const NSUInteger data_len = 512;
  static const NSUInteger screen_len = 6912;
  NSMutableData *mdr_data;
  NSMutableData *screen_data;
  NSURL *directory_url;
  NSURL *file_url;
  const char file_name[10] = { 'L', 'O', 'A', 'D', 'E', 'R', ' ', ' ', ' ', ' ' };
  NSUInteger i;
  NSError *error;

  mdr_data = [NSMutableData dataWithLength:block_len * 15];
  screen_data = [NSMutableData dataWithLength:screen_len];

  for( i = 0; i < screen_len; i++ ) {
    ((unsigned char *)[screen_data mutableBytes])[ i ] = (unsigned char)( i & 0xff );
  }

  {
    unsigned char *block = (unsigned char *)[mdr_data mutableBytes];
    unsigned char *data = block + header_len * 2;

    block[ header_len ] = 0x01;
    block[ header_len + 2 ] = 7;
    memcpy( block + header_len + 4, file_name, sizeof( file_name ) );

    data[0] = 3;
    data[1] = (unsigned char)( screen_len & 0xff );
    data[2] = (unsigned char)( screen_len >> 8 );
    data[3] = 0x00;
    data[4] = 0x40;
  }

  for( i = 0; i < 14; i++ ) {
    unsigned char *block;
    unsigned char *data;
    NSUInteger block_offset;
    NSUInteger offset;
    NSUInteger copy_len;

    block_offset = block_len * ( i + 1 );
    block = (unsigned char *)[mdr_data mutableBytes] + block_offset;
    data = block + header_len * 2;
    offset = i * data_len;
    copy_len = screen_len - offset;
    if( copy_len > data_len ) copy_len = data_len;

    block[ header_len + 1 ] = (unsigned char)i;
    block[ header_len + 2 ] = (unsigned char)( copy_len & 0xff );
    block[ header_len + 3 ] = (unsigned char)( copy_len >> 8 );
    memcpy( block + header_len + 4, file_name, sizeof( file_name ) );
    memcpy( data, (const unsigned char *)[screen_data bytes] + offset, copy_len );
  }

  directory_url = [NSURL fileURLWithPath:[NSTemporaryDirectory()
                           stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]
                             isDirectory:YES];
  error = nil;
  XCTAssertTrue( [[NSFileManager defaultManager] createDirectoryAtURL:directory_url
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:&error] );
  XCTAssertNil( error );

  file_url = [directory_url URLByAppendingPathComponent:@"screen-dump.mdr"];
  XCTAssertTrue( [mdr_data writeToURL:file_url options:0 error:&error] );
  XCTAssertNil( error );

  return file_url;
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

- (void)test_mdr_screen_dump_code_file_produces_png_preview
{
  FuseQuickLookPreview *preview;
  NSData *preview_data;
  NSURL *file_url;

  file_url = [self writeSyntheticMDRScreenDump];
  preview = [self previewForURL:file_url];
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

@end
