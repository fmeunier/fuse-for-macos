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
#import "FuseQuickLookDrawing.h"
#import "FuseQuickLookThumbnail.h"

@interface FuseQuickLookThumbnailTests : XCTestCase
@end

@implementation FuseQuickLookThumbnailTests

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

- (NSData*)renderedPixelDataForImage:(CGImageRef)image
                             sourceSize:(NSSize)source_size
                            contextSize:(CGSize)context_size
{
  NSMutableData *pixel_data;
  CGColorSpaceRef color_space;
  CGContextRef context;
  size_t bytes_per_row;

  bytes_per_row = (size_t)context_size.width * 4;
  pixel_data = [NSMutableData dataWithLength:bytes_per_row * (size_t)context_size.height];

  color_space = CGColorSpaceCreateWithName( kCGColorSpaceSRGB );
  context = CGBitmapContextCreate( [pixel_data mutableBytes],
                                   (size_t)context_size.width,
                                   (size_t)context_size.height,
                                   8,
                                   bytes_per_row,
                                   color_space,
                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
  CGColorSpaceRelease( color_space );

  CGContextClearRect( context, CGRectMake( 0, 0, context_size.width, context_size.height ) );
  fuse_quicklook_draw_image( context, context_size, source_size, image );
  CGContextRelease( context );

  return pixel_data;
}

- (NSData*)renderedPixelDataForImage:(CGImageRef)image
                             sourceSize:(NSSize)source_size
                            contextSize:(CGSize)context_size
                           backingScale:(CGFloat)backing_scale
{
  NSMutableData *pixel_data;
  CGColorSpaceRef color_space;
  CGContextRef context;
  size_t pixel_width;
  size_t pixel_height;
  size_t bytes_per_row;

  pixel_width = (size_t)( context_size.width * backing_scale );
  pixel_height = (size_t)( context_size.height * backing_scale );
  bytes_per_row = pixel_width * 4;
  pixel_data = [NSMutableData dataWithLength:bytes_per_row * pixel_height];

  color_space = CGColorSpaceCreateWithName( kCGColorSpaceSRGB );
  context = CGBitmapContextCreate( [pixel_data mutableBytes],
                                   pixel_width,
                                   pixel_height,
                                   8,
                                   bytes_per_row,
                                   color_space,
                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
  CGColorSpaceRelease( color_space );

  CGContextScaleCTM( context, backing_scale, backing_scale );
  CGContextClearRect( context, CGRectMake( 0, 0, context_size.width, context_size.height ) );
  fuse_quicklook_draw_image( context, context_size, source_size, image );
  CGContextRelease( context );

  return pixel_data;
}

- (NSBitmapImageRep*)renderedBitmapForImage:(CGImageRef)image
                                 sourceSize:(NSSize)source_size
                                contextSize:(CGSize)context_size
{
  NSData *pixel_data;
  NSBitmapImageRep *bitmap;
  unsigned char *planes[5];

  pixel_data = [self renderedPixelDataForImage:image
                                    sourceSize:source_size
                                   contextSize:context_size];
  planes[0] = (unsigned char *)[pixel_data bytes];
  planes[1] = NULL;
  planes[2] = NULL;
  planes[3] = NULL;
  planes[4] = NULL;

  bitmap = [[[NSBitmapImageRep alloc]
               initWithBitmapDataPlanes:planes
               pixelsWide:(NSInteger)context_size.width
               pixelsHigh:(NSInteger)context_size.height
               bitsPerSample:8
               samplesPerPixel:4
               hasAlpha:YES
               isPlanar:NO
               colorSpaceName:NSDeviceRGBColorSpace
               bytesPerRow:(NSInteger)context_size.width * 4
               bitsPerPixel:32] autorelease];

  return bitmap;
}

- (CGImageRef)newOrientationFixtureImage
{
  CGColorSpaceRef color_space;
  CGContextRef context;
  CGImageRef image;
  unsigned char pixels[] = {
    255, 0, 0, 255,   255, 0, 0, 255,   0, 255, 0, 255,   0, 255, 0, 255,
    255, 0, 0, 255,   255, 0, 0, 255,   0, 255, 0, 255,   0, 255, 0, 255,
    0, 0, 255, 255,   0, 0, 255, 255,   255, 255, 0, 255, 255, 255, 0, 255,
    0, 0, 255, 255,   0, 0, 255, 255,   255, 255, 0, 255, 255, 255, 0, 255,
  };

  color_space = CGColorSpaceCreateWithName( kCGColorSpaceSRGB );
  context = CGBitmapContextCreate( pixels, 4, 4, 8, 16, color_space,
                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
  CGColorSpaceRelease( color_space );
  image = CGBitmapContextCreateImage( context );
  CGContextRelease( context );

  return image;
}

- (void)assertPixelData:(NSData*)pixel_data
                atWidth:(size_t)width
                      x:(size_t)x
                      y:(size_t)y
                      r:(unsigned char)r
                      g:(unsigned char)g
                      b:(unsigned char)b
                      a:(unsigned char)a
{
  const unsigned char *bytes;
  size_t offset;

  bytes = [pixel_data bytes];
  offset = ( y * width + x ) * 4;

  XCTAssertEqual( bytes[offset], r );
  XCTAssertEqual( bytes[offset + 1], g );
  XCTAssertEqual( bytes[offset + 2], b );
  XCTAssertEqual( bytes[offset + 3], a );
}

- (void)assertBitmap:(NSBitmapImageRep*)bitmap matchesReferenceAtPoints:(NSArray<NSValue*>*)points tolerance:(CGFloat)tolerance
{
  NSBitmapImageRep *reference;
  NSUInteger i;

  reference = [self bitmapImageRepWithContentsOfURL:[self fixtureURL:@"../fuse/lib/keyboard.png"]];
  XCTAssertNotNil( reference );

  for( i = 0; i < [points count]; i++ ) {
    CGPoint point;
    NSInteger actual_x;
    NSInteger actual_y;
    NSInteger expected_x;
    NSInteger expected_y;
    NSColor *actual;
    NSColor *expected;

    point = [[points objectAtIndex:i] pointValue];
    actual_x = (NSInteger)( point.x * ( [bitmap pixelsWide] - 1 ) );
    actual_y = (NSInteger)( point.y * ( [bitmap pixelsHigh] - 1 ) );
    expected_x = (NSInteger)( point.x * ( [reference pixelsWide] - 1 ) );
    expected_y = (NSInteger)( point.y * ( [reference pixelsHigh] - 1 ) );

    actual = [[bitmap colorAtX:actual_x y:actual_y] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    expected = [[reference colorAtX:expected_x y:expected_y] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];

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

- (void)test_tzx_with_embedded_inlay_returns_image_data_thumbnail
{
  FuseQuickLookThumbnail *thumbnail;
  NSData *image_data;

  thumbnail = [self thumbnailForFixture:@"tests/fixtures/keyboard-inlay.tzx"];
  image_data = [thumbnail imageData];

  XCTAssertEqual( [thumbnail thumbnailKind], FUSE_QUICKLOOK_THUMBNAIL_IMAGE_DATA );
  XCTAssertNotNil( image_data );
  XCTAssertTrue( [image_data length] > 4 );
  XCTAssertEqual( ((const unsigned char *)[image_data bytes])[0], 0xff );
  XCTAssertEqual( ((const unsigned char *)[image_data bytes])[1], 0xd8 );
  XCTAssertNil( [thumbnail bitmapImageRep] );
  XCTAssertNotNil( [thumbnail image] );
}

- (void)test_thumbnail_context_size_matches_requested_maximum_size
{
  CGSize context_size;

  context_size = fuse_quicklook_context_size( CGSizeMake( 128, 128 ),
                                              NSMakeSize( 256, 192 ) );

  XCTAssertEqual( context_size.width, 128.0 );
  XCTAssertEqual( context_size.height, 128.0 );
}

- (void)test_thumbnail_draw_rect_fills_matching_aspect_context
{
  CGRect draw_rect;

  draw_rect = fuse_quicklook_draw_rect( CGSizeMake( 128, 96 ),
                                        NSMakeSize( 256, 192 ) );

  XCTAssertEqual( draw_rect.origin.x, 0.0 );
  XCTAssertEqual( draw_rect.origin.y, 0.0 );
  XCTAssertEqual( draw_rect.size.width, 128.0 );
  XCTAssertEqual( draw_rect.size.height, 96.0 );
}

- (void)test_thumbnail_draw_image_fills_returned_canvas
{
  CGImageRef source;
  NSData *rendered;

  source = [self newOrientationFixtureImage];
  rendered = [self renderedPixelDataForImage:source
                                  sourceSize:NSMakeSize( 4, 4 )
                                 contextSize:CGSizeMake( 40, 40 )];
  CGImageRelease( source );

  [self assertPixelData:rendered atWidth:40 x:0 y:39 r:0 g:0 b:255 a:255];
  [self assertPixelData:rendered atWidth:40 x:39 y:39 r:255 g:255 b:0 a:255];
  [self assertPixelData:rendered atWidth:40 x:0 y:0 r:255 g:0 b:0 a:255];
  [self assertPixelData:rendered atWidth:40 x:39 y:0 r:0 g:255 b:0 a:255];
}

- (void)test_thumbnail_draw_image_fills_scaled_quicklook_canvas
{
  CGImageRef source;
  NSData *rendered;

  source = [self newOrientationFixtureImage];
  rendered = [self renderedPixelDataForImage:source
                                  sourceSize:NSMakeSize( 4, 4 )
                                 contextSize:CGSizeMake( 40, 40 )
                                backingScale:2.0];
  CGImageRelease( source );

  [self assertPixelData:rendered atWidth:80 x:0 y:79 r:0 g:0 b:255 a:255];
  [self assertPixelData:rendered atWidth:80 x:79 y:79 r:255 g:255 b:0 a:255];
  [self assertPixelData:rendered atWidth:80 x:0 y:0 r:255 g:0 b:0 a:255];
  [self assertPixelData:rendered atWidth:80 x:79 y:0 r:0 g:255 b:0 a:255];
}

- (void)test_thumbnail_draw_image_uses_live_context_bounds
{
  CGImageRef source;
  NSMutableData *pixel_data;
  CGColorSpaceRef color_space;
  CGContextRef context;
  size_t bytes_per_row;

  source = [self newOrientationFixtureImage];
  bytes_per_row = 80 * 4;
  pixel_data = [NSMutableData dataWithLength:bytes_per_row * 80];

  color_space = CGColorSpaceCreateWithName( kCGColorSpaceSRGB );
  context = CGBitmapContextCreate( [pixel_data mutableBytes], 80, 80, 8,
                                   bytes_per_row, color_space,
                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
  CGColorSpaceRelease( color_space );

  CGContextClearRect( context, CGRectMake( 0, 0, 80, 80 ) );
  XCTAssertTrue( fuse_quicklook_draw_image( context, CGSizeMake( 40, 40 ),
                                            NSMakeSize( 4, 4 ), source ) );
  CGContextRelease( context );
  CGImageRelease( source );

  [self assertPixelData:pixel_data atWidth:80 x:0 y:79 r:0 g:0 b:255 a:255];
  [self assertPixelData:pixel_data atWidth:80 x:79 y:79 r:255 g:255 b:0 a:255];
  [self assertPixelData:pixel_data atWidth:80 x:0 y:0 r:255 g:0 b:0 a:255];
  [self assertPixelData:pixel_data atWidth:80 x:79 y:0 r:0 g:255 b:0 a:255];
}

- (void)test_thumbnail_draw_image_preserves_orientation
{
  CGImageRef source;
  NSData *rendered;

  source = [self newOrientationFixtureImage];
  rendered = [self renderedPixelDataForImage:source
                                  sourceSize:NSMakeSize( 4, 4 )
                                 contextSize:CGSizeMake( 40, 40 )];
  CGImageRelease( source );

  [self assertPixelData:rendered atWidth:40 x:5 y:35 r:0 g:0 b:255 a:255];
  [self assertPixelData:rendered atWidth:40 x:35 y:35 r:255 g:255 b:0 a:255];
  [self assertPixelData:rendered atWidth:40 x:5 y:5 r:255 g:0 b:0 a:255];
  [self assertPixelData:rendered atWidth:40 x:35 y:5 r:0 g:255 b:0 a:255];
}

- (void)test_thumbnail_draw_image_matches_scr_fixture_orientation
{
  FuseQuickLookThumbnail *thumbnail;
  NSBitmapImageRep *bitmap;
  NSBitmapImageRep *rendered;

  thumbnail = [self thumbnailForFixture:@"../fuse/lib/keyboard.scr"];
  bitmap = [thumbnail bitmapImageRep];
  XCTAssertNotNil( bitmap );

  rendered = [self renderedBitmapForImage:[bitmap CGImage]
                               sourceSize:NSMakeSize( [bitmap pixelsWide], [bitmap pixelsHigh] )
                              contextSize:CGSizeMake( [bitmap pixelsWide], [bitmap pixelsHigh] )];

  [self assertBitmap:rendered
 matchesReferenceAtPoints:@[
   [NSValue valueWithPoint:NSMakePoint( 0.03, 0.97 )],
   [NSValue valueWithPoint:NSMakePoint( 0.92, 0.85 )],
   [NSValue valueWithPoint:NSMakePoint( 0.11, 0.18 )],
   [NSValue valueWithPoint:NSMakePoint( 0.95, 0.14 )],
 ]
             tolerance:0.25];
}

- (void)test_thumbnail_draw_image_matches_tzx_fixture_orientation
{
  FuseQuickLookThumbnail *thumbnail;
  NSImage *image;
  NSBitmapImageRep *bitmap;
  NSData *tiff_data;
  NSBitmapImageRep *rendered;

  thumbnail = [self thumbnailForFixture:@"tests/fixtures/keyboard-inlay.tzx"];
  image = [thumbnail image];
  XCTAssertNotNil( image );

  tiff_data = [image TIFFRepresentation];
  XCTAssertNotNil( tiff_data );
  bitmap = [[[NSBitmapImageRep alloc] initWithData:tiff_data] autorelease];
  XCTAssertNotNil( bitmap );

  rendered = [self renderedBitmapForImage:[bitmap CGImage]
                               sourceSize:NSMakeSize( [bitmap pixelsWide], [bitmap pixelsHigh] )
                              contextSize:CGSizeMake( [bitmap pixelsWide], [bitmap pixelsHigh] )];

  [self assertBitmap:rendered
 matchesReferenceAtPoints:@[
   [NSValue valueWithPoint:NSMakePoint( 0.03, 0.97 )],
   [NSValue valueWithPoint:NSMakePoint( 0.92, 0.85 )],
   [NSValue valueWithPoint:NSMakePoint( 0.11, 0.18 )],
   [NSValue valueWithPoint:NSMakePoint( 0.95, 0.14 )],
 ]
             tolerance:0.18];
}

@end
