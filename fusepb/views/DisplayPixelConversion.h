/* DisplayPixelConversion.h: Pixel conversion for display upload
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#ifndef FUSE_DISPLAY_PIXEL_CONVERSION_H
#define FUSE_DISPLAY_PIXEL_CONVERSION_H

#include <stddef.h>
#include <stdint.h>

/* Strides are bytes. Expand normalized RGB565 channels with rounding, retaining
   row padding and using opaque alpha for the existing display fragment shader. */
static inline void
display_rgb565_to_bgra8888( void *dest, size_t dest_stride, const void *src,
                          size_t src_stride, size_t width, size_t height )
{
  size_t x, y;

  for( y = 0; y < height; y++ ) {
    const uint16_t *source = (const uint16_t *)( (const uint8_t *)src +
                                               y * src_stride );
    uint8_t *target = (uint8_t *)dest + y * dest_stride;

    for( x = 0; x < width; x++ ) {
      uint16_t pixel = source[x];

      target[4 * x    ] = ( ( pixel & 31 ) * 255 + 15 ) / 31;
      target[4 * x + 1] = ( ( ( pixel >> 5 ) & 63 ) * 255 + 31 ) / 63;
      target[4 * x + 2] = ( ( pixel >> 11 ) * 255 + 15 ) / 31;
      target[4 * x + 3] = 255;
    }
  }
}

#endif
