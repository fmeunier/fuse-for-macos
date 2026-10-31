/* Portable WAV reader regression tests. Fixtures are generated in memory.
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.
*/
#include "config.h"

#include <stdio.h>
#include <string.h>

#include "test.h"
#include "wav_internals.h"

#ifdef WAV_INTERNAL_PCM
static void
put32( unsigned char *p, unsigned long n )
{
  unsigned i;
  for( i = 0; i < 4; i++ ) p[i] = ( n >> ( 8 * i ) ) & 255;
}

static void
put16( unsigned char *p, unsigned n )
{
  p[0] = n & 255; p[1] = n >> 8;
}

/* fmt follows data to exercise order independence. Include odd metadata. */
static size_t
fixture( unsigned char *p, unsigned bytes, unsigned channels, int extensible )
{
  unsigned n = 3 * bytes * channels, i, c;
  size_t f = 30 + n + ( n & 1 ), total = f + ( extensible ? 48 : 24 );
  memset( p, 0, 256 );
  memcpy( p, "RIFF", 4 ); put32( p + 4, total - 8 );
  memcpy( p + 8, "WAVEJUNK", 8 ); put32( p + 16, 1 ); p[20] = 42;
  memcpy( p + 22, "data", 4 ); put32( p + 26, n );
  for( i = 0; i < 3; i++ ) {
    for( c = 0; c < channels; c++ ) {
      unsigned char *s = p + 30 + ( i * channels + c ) * bytes;
      if( bytes == 1 ) s[0] = i == 0 ? 0 : i == 1 ? 128 : 255;
      else s[bytes - 1] = i == 0 ? 128 : i == 1 ? 0 : 64;
    }
  }
  memcpy( p + f, "fmt ", 4 ); put32( p + f + 4, extensible ? 40 : 16 );
  put16( p + f + 8, extensible ? 0xfffe : 1 );
  put16( p + f + 10, channels ); put32( p + f + 12, 12345 );
  put32( p + f + 16, 12345 * channels * bytes );
  put16( p + f + 20, channels * bytes ); put16( p + f + 22, bytes * 8 );
  if( extensible ) {
    static const unsigned char guid[16] = {
      1, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113
    };
    put16( p + f + 24, 22 ); put16( p + f + 26, bytes * 8 );
    memcpy( p + f + 32, guid, 16 );
  }
  return total;
}

static int
try_fixture( const unsigned char *p, size_t size,
             libspectrum_error expected_error, int empty, unsigned bytes )
{
  const char *name = "test-wav-reader.tmp";
  FILE *file = fopen( name, "wb" );
  libspectrum_wav_reader *reader = NULL;
  libspectrum_signed_word samples[4];
  libspectrum_error error;
  size_t rate, count, got;
  int ok;

  if( !file ) return 0;
  ok = fwrite( p, 1, size, file ) == size;
  if( fclose( file ) ) ok = 0;
  if( !ok ) { remove( name ); return 0; }
  error = internal_wav_open( &reader, name, &rate, &count );
  ok = error == expected_error;
  if( !ok )
    fprintf( stderr, "WAV fixture: expected error %d, got %d\n",
             (int)expected_error, (int)error );
  if( !expected_error && !error ) {
    ok = rate == 12345 && count == ( empty ? 0 : 3 );
    if( internal_wav_read( reader, samples, 1, &got ) ||
        got != ( empty ? 0 : 1 ) ) ok = 0;
    if( !empty && samples[0] != -32768 ) ok = 0;
    if( internal_wav_read( reader, samples, 4, &got ) ||
        got != ( empty ? 0 : 2 ) ) ok = 0;
    if( !empty && ( samples[0] != 0 ||
        samples[1] != ( bytes == 1 ? 32512 : 16384 ) ) ) ok = 0;
    if( internal_wav_read( reader, samples, 1, &got ) || got ) ok = 0;
  }
  internal_wav_close( reader );
  remove( name );
  return ok;
}
#endif

test_return_t
read_portable_wav_formats( void )
{
#ifndef WAV_INTERNAL_PCM
  return TEST_SKIPPED;
#else
  unsigned char p[256];
  unsigned bytes, channels, ext, mutation;
  size_t size, f, cut;
  libspectrum_error expected_error;

  for( bytes = 1; bytes <= 4; bytes++ )
    for( channels = 1; channels <= 3; channels++ )
      for( ext = 0; ext < 2; ext++ ) {
        size = fixture( p, bytes, channels, ext );
        if( !try_fixture( p, size, LIBSPECTRUM_ERROR_NONE, 0, bytes ) )
          return TEST_FAIL;
        /* Redundant byte rate may be zero or incorrectly expressed in bits. */
        for( mutation = 0; mutation < 2; mutation++ ) {
          f = 30 + 3 * bytes * channels + ( ( 3 * bytes * channels ) & 1 );
          put32( p + f + 16,
                 mutation ? 12345 * channels * bytes * 8 : 0 );
          if( !try_fixture( p, size, LIBSPECTRUM_ERROR_NONE, 0, bytes ) )
            return TEST_FAIL;
        }
      }

  /* Equal positive/negative channels cancel, including at full scale. */
  for( bytes = 1; bytes <= 4; bytes++ ) {
    size = fixture( p, bytes, 2, 0 );
    memset( p + 30, 0, 6 * bytes );
    if( bytes == 1 ) {
      p[30] = 0; p[31] = 0; /* Initial negative frame. */
      p[32] = 64; p[33] = 192; /* Exact cancellation. */
      p[34] = 255; p[35] = 255;
    } else {
      p[30 + bytes - 1] = p[30 + 2 * bytes - 1] = 128;
      p[30 + 3 * bytes - 1] = 192;
      p[30 + 4 * bytes - 1] = 64;
      p[30 + 5 * bytes - 1] = p[30 + 6 * bytes - 1] = 64;
    }
    if( !try_fixture( p, size, LIBSPECTRUM_ERROR_NONE, 0, bytes ) )
      return TEST_FAIL;
  }

  size = fixture( p, 2, 1, 1 );
  for( cut = 0; cut < size; cut++ )
    if( !try_fixture( p, cut, LIBSPECTRUM_ERROR_CORRUPT, 0, 2 ) )
      return TEST_FAIL;

  /* Header, boundaries, padding, format, alignment and extensible validation. */
  for( mutation = 0; mutation < 23; mutation++ ) {
    size = fixture( p, 2, 1, 1 ); f = 36;
    expected_error = LIBSPECTRUM_ERROR_CORRUPT;
    switch( mutation ) {
    case 0: p[0] = 'X'; expected_error = LIBSPECTRUM_ERROR_SIGNATURE; break;
    case 1: p[8] = 'X'; expected_error = LIBSPECTRUM_ERROR_SIGNATURE; break;
    case 2: put32( p + 4, 0xffffffffUL ); break;
    case 3: size--; break;
    case 4: put32( p + 26, 5 ); break;
    case 5: put32( p + 16, 0xffffffffUL ); break;
    case 6: /* IEEE float deliberately unsupported. */
      put16( p + f + 8, 3 ); expected_error = LIBSPECTRUM_ERROR_UNKNOWN; break;
    case 7: put16( p + f + 10, 0 ); break;
    case 8: put32( p + f + 12, 0 ); break;
    case 9: put16( p + f + 20, 3 ); break;
    case 10: /* Reduced valid bits: well-formed but unsupported. */
      put16( p + f + 26, 12 ); expected_error = LIBSPECTRUM_ERROR_UNKNOWN; break;
    case 11: /* Non-PCM extensible subformat. */
      p[f + 32] = 3; expected_error = LIBSPECTRUM_ERROR_UNKNOWN; break;
    case 12: /* Incorrect byte rate does not affect PCM decoding. */
      put32( p + f + 16, 1 ); expected_error = LIBSPECTRUM_ERROR_NONE; break;
    case 13: memcpy( p + 22, "JUNK", 4 ); break; /* Missing data. */
    case 14: memcpy( p + f, "JUNK", 4 ); break; /* Missing fmt. */
    case 15: put32( p + f + 4, 15 ); break;
    case 16: /* Duplicate data chunk, even when empty. */
      memcpy( p + size, "data", 4 ); put32( p + size + 4, 0 );
      size += 8; put32( p + 4, size - 8 ); break;
    case 17: /* Duplicate format chunk. */
      memcpy( p + size, p + f, 48 ); size += 48;
      put32( p + 4, size - 8 ); break;
    case 18: /* Unsupported container width. */
      put16( p + f + 22, 12 ); put16( p + f + 26, 12 );
      expected_error = LIBSPECTRUM_ERROR_UNKNOWN; break;
    case 19: put16( p + f + 26, 17 ); break; /* Too many valid bits. */
    case 20: put16( p + f + 26, 0 ); break;
    case 21: put16( p + f + 24, 21 ); break; /* Short extension. */
    case 22: put16( p + f + 24, 23 ); break; /* Extension exceeds fmt size. */
    }
    if( !try_fixture( p, size, expected_error, 0, 2 ) ) return TEST_FAIL;
  }
  size = fixture( p, 1, 1, 0 );
  /* Remove the final odd data padding by shortening the RIFF envelope. */
  put32( p + 4, size - 9 );
  if( !try_fixture( p, size, LIBSPECTRUM_ERROR_CORRUPT, 0, 1 ) ) return TEST_FAIL;

  size = fixture( p, 2, 1, 0 );
  memmove( p + 30, p + 36, size - 36 ); size -= 6;
  put32( p + 4, size - 8 ); put32( p + 26, 0 );
  if( !try_fixture( p, size, LIBSPECTRUM_ERROR_NONE, 1, 2 ) ) return TEST_FAIL;
  return TEST_PASS;
#endif
}
