/* test/rle-recordings.c: Initial polarity and sampled recording round-trips
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

#include <string.h>

#include "internals.h"
#include "common.h"
#include "test.h"

static const libspectrum_byte runs[] = { 13, 17, 19, 0, 0x50, 0xc3, 0, 0 };
static const libspectrum_dword samples[] = { 13, 17, 19, 50000 };

static int
next_timed_edge( libspectrum_tape *tape, libspectrum_tape_edge *edge )
{
  for( size_t i = 0; i < 16; i++ ) {
    if( libspectrum_tape_get_next_edge( edge, tape ) ) return 0;
    if( edge->tstates ) return 1;
    if( edge->flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) return 0;
  }
  return 0;
}

static int
same_edge( const libspectrum_tape_edge *a, const libspectrum_tape_edge *b )
{
  return a->tstates == b->tstates && a->level == b->level &&
    a->flags == b->flags && a->transition == b->transition;
}

/* Check independent cumulative timing and cursor replay at every run. */
static int
check_runs( libspectrum_tape *tape, libspectrum_dword rate, int high,
             size_t count, int final )
{
  libspectrum_qword total = 0, elapsed = 0;
  libspectrum_tape_cursor *cursor;
  libspectrum_tape_edge edge, replay;
  size_t i;
  for( i = 0; i < count; i++ ) {
    libspectrum_qword end;
    cursor = libspectrum_tape_cursor_capture( tape );
    if( !cursor ) return 0;
    if( !next_timed_edge( tape, &edge ) ||
        libspectrum_tape_cursor_apply( tape, cursor ) ||
        !next_timed_edge( tape, &replay ) || !same_edge( &edge, &replay ) ) {
      libspectrum_tape_cursor_free( cursor );
      return 0;
    }
    libspectrum_tape_cursor_free( cursor );
    total += samples[i];
    end = rate ? total * 3500000 / rate : total * 7;
    if( edge.tstates != end - elapsed ||
        edge.level != ( high ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                               LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) return 0;
    elapsed = end;
    high = !high;
    if( i + 1 < count && ( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) )
      return 0;
  }
  if( final ) {
    for( i = 0; !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ); i++ ) {
      if( i == 16 || libspectrum_tape_get_next_edge( &edge, tape ) ||
          edge.tstates ) return 0;
    }
  }
  return 1;
}

static int
single_recording( libspectrum_tape *tape, libspectrum_dword rate, int high,
                   size_t size )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block = libspectrum_tape_iterator_init( &it, tape );
  return block &&
    libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE &&
    libspectrum_tape_block_level( block ) == high &&
    libspectrum_tape_block_sample_rate( block ) == rate &&
    libspectrum_tape_block_data_length( block ) == size &&
    !memcmp( libspectrum_tape_block_data( block ), runs, size ) &&
    !libspectrum_tape_iterator_next( &it );
}

test_return_t
rle_initial_level_playback( void )
{
  static const libspectrum_dword rates[] = { 0, 22050, 44100, 48000 };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_byte *data;
  int expected;
  test_return_t result = TEST_FAIL;

  for( size_t r = 0; r < sizeof( rates ) / sizeof( rates[0] ); r++ ) {
    for( int incoming = 0; incoming <= 1; incoming++ ) {
      for( int level = -1; level <= 1; level++ ) {
        block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
        libspectrum_tape_block_set_level( block, incoming );
        libspectrum_tape_append_block( tape, block );
        block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
        if( libspectrum_tape_block_level( block ) != -1 ||
            libspectrum_tape_block_set_level( block, 2 ) != LIBSPECTRUM_ERROR_INVALID ||
            libspectrum_tape_block_level( block ) != -1 ||
            libspectrum_tape_block_set_level( block, 1 ) ||
            libspectrum_tape_block_set_level( block, level ) ||
            libspectrum_tape_block_level( block ) != level ) {
          libspectrum_tape_block_free( block );
          goto done;
        }
        data = libspectrum_new( libspectrum_byte, sizeof( runs ) );
        memcpy( data, runs, sizeof( runs ) );
        libspectrum_tape_block_set_data( block, data );
        libspectrum_tape_block_set_data_length( block, sizeof( runs ) );
        libspectrum_tape_block_set_sample_rate( block, rates[r] );
        libspectrum_tape_block_set_scale( block, 7 );
        libspectrum_tape_append_block( tape, block );
        expected = level != -1 ? level : ( rates[r] ? incoming : !incoming );
        if( !check_runs( tape, rates[r], expected, 4, 1 ) ||
            libspectrum_tape_nth_block( tape, 0 ) ||
            !check_runs( tape, rates[r], expected, 4, 1 ) ) goto done;
        libspectrum_tape_clear( tape );
      }
    }
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

/* CSW v1/v2, both initial polarities, sole and extended runs, and all three
   waveform export formats. Check the CSW sample payload as well as playback. */
test_return_t
csw_recording_roundtrips( void )
{
  static const libspectrum_dword rates[] = { 22050, 44100, 48000 };
  static const libspectrum_id_t formats[] = {
    LIBSPECTRUM_ID_TAPE_CSW, LIBSPECTRUM_ID_TAPE_TZX, LIBSPECTRUM_ID_TAPE_PZX
  };
  libspectrum_tape *source = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape *back = libspectrum_tape_alloc();
  libspectrum_tape_cursor *position = NULL;
  libspectrum_tape_edge before, after;
  libspectrum_byte input[60], *output = NULL, *csw = NULL;
  size_t r, count, size, header, length = 0, csw_length = 0;
  int version, high;
  test_return_t result = TEST_FAIL;

  for( version = 1; version <= 2; version++ ) {
    for( r = 0; r < sizeof( rates ) / sizeof( rates[0] ); r++ ) {
      for( high = 0; high <= 1; high++ ) {
        for( count = 1; count <= 4; count += 3 ) {
          memset( input, 0, sizeof( input ) );
          memcpy( input, "Compressed Square Wave\x1a", 23 );
          input[23] = version;
          input[25] = rates[r]; input[26] = rates[r] >> 8;
          if( version == 1 ) {
            header = 32; input[27] = 1; input[28] = high;
          } else {
            header = 52; input[29] = count; input[33] = 1; input[34] = high;
          }
          size = count == 1 ? 1 : sizeof( runs );
          memcpy( input + header, runs, size );
          if( libspectrum_tape_read( source, input, header + size,
                                     LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
              !single_recording( source, rates[r], high, size ) ) goto done;
          /* Appending either header polarity must override either incoming
             level, without importing another signal-level block. */
          for( int incoming = 0; incoming <= 1; incoming++ ) {
            libspectrum_tape_block *prefix = libspectrum_tape_block_alloc(
              LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
            libspectrum_tape_block_set_level( prefix, incoming );
            libspectrum_tape_append_block( dest, prefix );
            if( libspectrum_tape_read( dest, input, header + size,
                                       LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
                !check_runs( dest, rates[r], high, count, 1 ) ) goto done;
            libspectrum_tape_clear( dest );
          }
          /* Export must preserve even a partially consumed recording. */
          if( !next_timed_edge( source, &before ) ) goto done;
          position = libspectrum_tape_cursor_capture( source );
          for( size_t f = 0; f < sizeof( formats ) / sizeof( formats[0] ); f++ ) {
            if( libspectrum_tape_write( &output, &length, source, formats[f] ) ||
                libspectrum_tape_read( dest, output, length, formats[f], NULL ) )
              goto done;
            if( formats[f] == LIBSPECTRUM_ID_TAPE_CSW &&
                ( length < 52 || libspectrum_read_dword_le( output + 25 ) != rates[r] ||
                  libspectrum_read_dword_le( output + 29 ) != count ||
                  output[34] != high ||
                  !single_recording( dest, rates[r], high, size ) ) ) goto done;
            if( !check_runs( dest, rates[r], high, count, 1 ) ||
                libspectrum_tape_write( &csw, &csw_length, dest,
                                        LIBSPECTRUM_ID_TAPE_CSW ) ||
                libspectrum_tape_read( back, csw, csw_length,
                                       LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
                !check_runs( back, rates[r], high, count, 1 ) ||
                ( formats[f] != LIBSPECTRUM_ID_TAPE_PZX &&
                  !single_recording( back, rates[r], high, size ) ) ||
                libspectrum_tape_get_next_edge( &before, source ) ||
                libspectrum_tape_cursor_apply( source, position ) ||
                libspectrum_tape_get_next_edge( &after, source ) ||
                !same_edge( &before, &after ) ||
                libspectrum_tape_cursor_apply( source, position ) ) goto done;
            libspectrum_free( output ); output = NULL; length = 0;
            libspectrum_free( csw ); csw = NULL; csw_length = 0;
            libspectrum_tape_clear( dest );
            libspectrum_tape_clear( back );
          }
          libspectrum_tape_cursor_free( position ); position = NULL;
          libspectrum_tape_clear( source );
        }
      }
    }
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: CSW round-trip: version %d, rate %lu, high %d, runs %lu\n",
             progname, version, (unsigned long)rates[r], high, (unsigned long)count );
  if( position ) libspectrum_tape_cursor_free( position );
  libspectrum_free( output );
  libspectrum_free( csw );
  libspectrum_tape_free( source );
  libspectrum_tape_free( dest );
  libspectrum_tape_free( back );
  return result;
}

/* Multiple explicitly levelled recordings must also work through rendering
   paths, not just the isolated-CSW copy optimisation. */
test_return_t
rle_initial_level_exports( void )
{
  static const libspectrum_id_t formats[] = {
    LIBSPECTRUM_ID_TAPE_CSW, LIBSPECTRUM_ID_TAPE_TZX, LIBSPECTRUM_ID_TAPE_PZX
  };
  libspectrum_tape *source = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t length = 0;
  test_return_t result = TEST_FAIL;

  for( int exact = 0; exact <= 1; exact++ ) {
    for( int high = 0; high <= 1; high++ ) {
      for( size_t i = 0; i < 2; i++ ) {
        libspectrum_tape_block *block = libspectrum_tape_block_alloc(
          LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
        libspectrum_byte *data = libspectrum_new( libspectrum_byte, sizeof( runs ) );
        memcpy( data, runs, sizeof( runs ) );
        libspectrum_tape_block_set_data( block, data );
        libspectrum_tape_block_set_data_length( block, sizeof( runs ) );
        libspectrum_tape_block_set_scale( block, 7 );
        libspectrum_tape_block_set_sample_rate( block, exact ? 44100 : 0 );
        libspectrum_tape_block_set_level( block, high );
        libspectrum_tape_append_block( source, block );
      }
      for( size_t f = 0; f < sizeof( formats ) / sizeof( formats[0] ); f++ ) {
        if( libspectrum_tape_write( &output, &length, source, formats[f] ) ||
            libspectrum_tape_read( dest, output, length, formats[f], NULL ) ||
            !check_runs( dest, exact ? 44100 : 0, high, 4, 0 ) ||
            !check_runs( dest, exact ? 44100 : 0, high, 4, 1 ) ) goto done;
        libspectrum_free( output ); output = NULL; length = 0;
        libspectrum_tape_clear( dest );
      }
      libspectrum_tape_clear( source );
    }
  }
  result = TEST_PASS;
done:
  libspectrum_free( output );
  libspectrum_tape_free( source );
  libspectrum_tape_free( dest );
  return result;
}

/* Native direct recording keeps its integer sample interval, used bits and
   pause exactly; it does not acquire the sampled RLE timing semantics. */
test_return_t
tzx_raw_recording_unchanged( void )
{
  static const libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x15,79,0,100,0,5,2,0,0,0xa5,0xb0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_tape_edge edge;
  libspectrum_byte *output = NULL;
  size_t length = 0, i = 0;
  test_return_t result = TEST_FAIL;

  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  block = libspectrum_tape_current_block( tape );
  if( !block || libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_RAW_DATA ||
      libspectrum_tape_block_bit_length( block ) != 79 ||
      libspectrum_tape_block_bits_in_last_byte( block ) != 5 ||
      libspectrum_tape_block_pause( block ) != 100 ||
      libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      length != sizeof( input ) || memcmp( output, input, length ) ) goto done;
  while( i < 13 ) {
    size_t start = i;
    int high = !!( input[19 + i / 8] & ( 0x80 >> ( i % 8 ) ) );
    do { i++; } while( i < 13 &&
      !!( input[19 + i / 8] & ( 0x80 >> ( i % 8 ) ) ) == high );
    if( !next_timed_edge( tape, &edge ) || edge.tstates != ( i - start ) * 79 ||
        edge.level != ( high ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                               LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( output );
  libspectrum_tape_free( tape );
  return result;
}
