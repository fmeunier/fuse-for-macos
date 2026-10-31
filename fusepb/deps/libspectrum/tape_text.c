/* tape_text.c: Tape metadata character-set conversion
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/
#include "config.h"
#include <errno.h>
#include <string.h>
#ifdef HAVE_ICONV
#include <iconv.h>
#endif
#include "internals.h"

/* Fallback when iconv is unavailable. Undefined CP1252 bytes become '?'. */
static const unsigned int cp1252_controls[32] = {
  0x20ac, '?', 0x201a, 0x192, 0x201e, 0x2026, 0x2020, 0x2021,
  0x2c6, 0x2030, 0x160, 0x2039, 0x152, '?', 0x17d, '?',
  '?', 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014,
  0x2dc, 0x2122, 0x161, 0x203a, 0x153, '?', 0x17e, 0x178
};

/* Consume a UTF-8 scalar, or one invalid byte and return '?'. */
static unsigned int
read_utf8( const unsigned char **input )
{
  const unsigned char *p = *input;
  unsigned int value, minimum;
  size_t n, i;
  if( *p < 0x80 ) { *input = p + 1; return *p; }
  if( *p >= 0xc2 && *p <= 0xdf ) { n = 2; value = *p & 0x1f; minimum = 0x80; }
  else if( *p >= 0xe0 && *p <= 0xef ) { n = 3; value = *p & 0x0f; minimum = 0x800; }
  else if( *p >= 0xf0 && *p <= 0xf4 ) { n = 4; value = *p & 7; minimum = 0x10000; }
  else { *input = p + 1; return '?'; }
  for( i = 1; i < n; i++ ) {
    if( ( p[i] & 0xc0 ) != 0x80 ) { *input = p + 1; return '?'; }
    value = ( value << 6 ) | ( p[i] & 0x3f );
  }
  if( value < minimum || value > 0x10ffff ||
      ( value >= 0xd800 && value <= 0xdfff ) ) {
    *input = p + 1; return '?';
  }
  *input = p + n;
  return value;
}

static void
write_utf8( libspectrum_buffer *out, unsigned int value )
{
  if( value < 0x80 ) libspectrum_buffer_write_byte( out, value );
  else if( value < 0x800 ) {
    libspectrum_buffer_write_byte( out, 0xc0 | ( value >> 6 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( value & 63 ) );
  } else if( value < 0x10000 ) {
    libspectrum_buffer_write_byte( out, 0xe0 | ( value >> 12 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( ( value >> 6 ) & 63 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( value & 63 ) );
  } else {
    libspectrum_buffer_write_byte( out, 0xf0 | ( value >> 18 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( ( value >> 12 ) & 63 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( ( value >> 6 ) & 63 ) );
    libspectrum_buffer_write_byte( out, 0x80 | ( value & 63 ) );
  }
}

/* Returns an owned, NUL-terminated string. mode: 0 UTF-8 -> CP1252,
   1 CP1252 -> UTF-8, 2 sanitise UTF-8, 3 UTF-8 -> ASCII.
   Character loss is never an error. */
libspectrum_error
internal_tape_text_convert( const char *text, int mode, char **result )
{
  libspectrum_buffer *out = libspectrum_buffer_alloc();
  const unsigned char *p = (const unsigned char *)( text ? text : "" );
#ifdef HAVE_ICONV
  iconv_t converter = mode == 2 ? (iconv_t)-1 :
    iconv_open( mode == 1 ? "UTF-8" : mode == 3 ? "ASCII//TRANSLIT" :
                "CP1252//TRANSLIT", mode == 1 ? "CP1252" : "UTF-8" );
  if( ( mode == 0 || mode == 3 ) && converter == (iconv_t)-1 )
    converter = iconv_open( mode == 3 ? "ASCII" : "CP1252", "UTF-8" );
  if( converter != (iconv_t)-1 ) {
    char *sanitised = NULL;
    ICONV_CONST char *input;
    size_t left;
    /* Validate scalars ourselves: some iconv implementations accept UTF-8
       values above U+10FFFF and replace an entire sequence at once. */
    if( mode == 0 || mode == 3 ) {
      internal_tape_text_convert( (const char *)p, 2, &sanitised );
      p = (const unsigned char *)sanitised;
    }
    input = (ICONV_CONST char *)p;
    left = strlen( (const char *)p );
    while( left ) {
      char chunk[128], *output = chunk;
      size_t available = sizeof( chunk ), status;
      int saved_errno;
      status = iconv( converter, &input, &left, &output, &available );
      saved_errno = errno;
      libspectrum_buffer_write( out, (const libspectrum_byte *)chunk,
                                sizeof( chunk ) - available );
      if( status != (size_t)-1 ) continue;
      if( saved_errno == E2BIG ) continue;
      p = (const unsigned char *)input;
      if( mode == 1 ) p++;
      else read_utf8( &p );
      left -= p - (const unsigned char *)input;
      input = (ICONV_CONST char *)p;
      libspectrum_buffer_write_byte( out, '?' );
    }
    iconv_close( converter ); /* UTF-8 and CP1252 have no shift state. */
    libspectrum_free( sanitised );
    p = (const unsigned char *)"";
  }
#endif
  while( *p ) {
    unsigned int value;
    size_t i;
    if( mode == 1 ) {
      value = *p++;
      if( value >= 0x80 && value < 0xa0 ) value = cp1252_controls[value - 0x80];
      write_utf8( out, value );
    } else {
      value = read_utf8( &p );
      if( mode == 2 ) write_utf8( out, value );
      else if( mode == 3 )
        libspectrum_buffer_write_byte( out, value < 0x80 ? value : '?' );
      else {
        if( value >= 0x80 && value < 0xa0 ) value = '?';
        if( value > 255 ) {
          for( i = 0; i < 32; i++ )
            if( cp1252_controls[i] == value ) break;
          value = i == 32 ? '?' : 0x80 + i;
        }
        libspectrum_buffer_write_byte( out, value );
      }
    }
  }
  libspectrum_buffer_write_byte( out, 0 );
  *result = libspectrum_new( char, libspectrum_buffer_get_data_size( out ) );
  memcpy( *result, libspectrum_buffer_get_data( out ),
          libspectrum_buffer_get_data_size( out ) );
  libspectrum_buffer_free( out );
  return LIBSPECTRUM_ERROR_NONE;
}
