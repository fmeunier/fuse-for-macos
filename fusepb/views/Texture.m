/* Texture.m: Implementation for the Texture class
   Copyright (c) 2007 Fredrick Meunier

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
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

   Author contact information:

   E-mail: fredm@spamcop.net

*/

#import "Texture.h"

@implementation Texture

-(id) initWithImageFile:(NSString*)filename withXOrigin:(int)x
                     withYOrigin:(int)y
{
  if( ( self = [super init] ) ) {
    NSString *textureName = [[NSBundle mainBundle] pathForImageResource:filename];
    if( !textureName )
      NSLog(@"in initWithImageFile no textureName for filename:%@", filename);
    NSURL *textureFile = [NSURL fileURLWithPath:textureName];

    CGImageSourceRef image_source =
      CGImageSourceCreateWithURL( (CFURLRef)textureFile, nil );

    CGImageRef image =
      CGImageSourceCreateImageAtIndex( image_source, 0, nil );
      
    CFRelease( image_source );

    texture.pixel_format = DISPLAY_FRAMEBUFFER_PIXEL_FORMAT_BGRA8888;
    texture.width = CGImageGetWidth( image );
    texture.height = CGImageGetHeight( image );
    texture.storage_width = texture.width;
    texture.storage_height = texture.height;
    texture.stride = texture.width * 4;
    texture.generation = 1;
    texture.synchronization = NULL;
    texture.ownership = DISPLAY_FRAMEBUFFER_OWNS_BACKING_STORAGE;

    texture.backing_storage = malloc( texture.width * texture.height * 4 );

    CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();

    CGContextRef context =
      CGBitmapContextCreate( texture.backing_storage,
                             texture.width,
                             texture.height,
                             8,
                             texture.width * 4,
                             color_space,
                             kCGImageAlphaPremultipliedFirst );

    CGContextDrawImage( context,
                        CGRectMake(0, 0, texture.width, texture.height),
                        image );

    CGColorSpaceRelease( color_space );

    CGImageRelease( image );

    CGContextRelease( context );

    texture.x_offset = x;
    texture.y_offset = y;

    [self uploadIconTexture];
  }

  return self;
}

-(void) dealloc
{
  glDeleteTextures(1, &textureId);
  if( texture.ownership & DISPLAY_FRAMEBUFFER_OWNS_BACKING_STORAGE ) {
    free( texture.backing_storage );
    texture.backing_storage = NULL;
  }
  texture.ownership = 0;
  [super dealloc];
}

-(DisplayFramebuffer*) getTexture
{
  return &texture;
}

@synthesize textureId;

-(void) uploadIconTexture;
{
  glGenTextures( 1, &textureId );

  /* Set memory alignment parameters for unpacking the bitmap. */
  glPixelStorei( GL_UNPACK_ROW_LENGTH, texture.width );
  glPixelStorei( GL_UNPACK_ALIGNMENT, 1 );

  /* Specify the texture's properties. */
  glBindTexture( GL_TEXTURE_RECTANGLE_ARB, textureId );
  glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
  glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
  glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
  glTexParameteri( GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );


  /* Upload the texture bitmap. */
  glTexImage2D( GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, texture.width,
                texture.height, 0, GL_BGRA_EXT,
#ifdef WORDS_BIGENDIAN
                GL_UNSIGNED_INT_8_8_8_8_REV,
#else                           /* #ifdef WORDS_BIGENDIAN */
                GL_UNSIGNED_INT_8_8_8_8,
#endif                          /* #ifdef WORDS_BIGENDIAN */
                texture.backing_storage );
}

@end
