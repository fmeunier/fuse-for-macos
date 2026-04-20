/* FuseQuickLookDrawing.h: Shared Quick Look drawing helpers
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

#import <Cocoa/Cocoa.h>

static inline CGSize
fuse_quicklook_context_size( CGSize maximum_size, NSSize source_size )
{
  if( maximum_size.width > 0 && maximum_size.height > 0 ) {
    return maximum_size;
  }

  return CGSizeMake( source_size.width, source_size.height );
}

static inline CGRect
fuse_quicklook_draw_rect( CGSize context_size, NSSize source_size )
{
  CGFloat scale;
  CGSize scaled_size;

  if( source_size.width <= 0 || source_size.height <= 0 ) {
    return CGRectZero;
  }

  scale = MIN( context_size.width / source_size.width,
               context_size.height / source_size.height );
  if( scale <= 0 ) scale = 1;

  scaled_size = CGSizeMake( source_size.width * scale, source_size.height * scale );

  return CGRectMake( ( context_size.width - scaled_size.width ) / 2,
                     ( context_size.height - scaled_size.height ) / 2,
                     scaled_size.width,
                     scaled_size.height );
}

static inline BOOL
fuse_quicklook_draw_image( CGContextRef context, CGSize context_size,
                           NSSize source_size, CGImageRef image )
{
  CGRect context_bounds;
  CGRect draw_rect;

  if( !image ) return NO;

  context_bounds = CGContextGetClipBoundingBox( context );
  if( CGRectIsEmpty( context_bounds ) ) {
    context_bounds = CGRectMake( 0, 0, context_size.width, context_size.height );
  }

  draw_rect = fuse_quicklook_draw_rect( context_bounds.size, source_size );
  if( CGRectIsEmpty( draw_rect ) ) return NO;

  draw_rect.origin.x += context_bounds.origin.x;
  draw_rect.origin.y += context_bounds.origin.y;

  CGContextSaveGState( context );
  CGContextSetInterpolationQuality( context, kCGInterpolationNone );
  CGContextDrawImage( context, draw_rect, image );
  CGContextRestoreGState( context );

  return YES;
}
