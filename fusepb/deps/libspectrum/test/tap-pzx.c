/* test/tap-pzx.c: Conservative recorded-pulse TAP export tests
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

/* Recorded in Fuse with tape traps disabled; expected TAP was manually
   exported from the same recording. Preserve the original files verbatim. */
test_return_t
tap_pzx_fuse_recording_fixture( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_byte *pzx = NULL, *expected = NULL, *output = NULL;
  size_t pzx_length = 0, expected_length = 0, length = 0;
  test_return_t result = TEST_INCOMPLETE;
  if( read_file( &pzx, &pzx_length, STATIC_TEST_PATH( "fuse-rom-recording.pzx" ) ) ||
      read_file( &expected, &expected_length, STATIC_TEST_PATH( "fuse-rom-recording.tap" ) ) )
    goto done;
  result = TEST_FAIL;
  if( libspectrum_tape_read( tape, pzx, pzx_length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
      libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TAP ) ||
      length != expected_length || memcmp( output, expected, length ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( pzx ); libspectrum_free( expected ); libspectrum_free( output );
  libspectrum_tape_free( tape );
  return result;
}

typedef struct {
  libspectrum_dword lengths[1024];
  size_t repeats[1024], count;
} recording;

static void
emit( recording *r, libspectrum_dword duration, size_t count )
{
  if( r->count && r->lengths[r->count - 1] == duration ) {
    r->repeats[r->count - 1] += count;
  } else {
    r->lengths[r->count] = duration;
    r->repeats[r->count++] = count;
  }
}

static void
encode( recording *r, const libspectrum_byte *bytes, size_t length )
{
  size_t i;
  unsigned bit;
  emit( r, 2168, 3223 ); emit( r, 667, 1 ); emit( r, 735, 1 );
  for( i = 0; i < length; i++ )
    for( bit = 0x80; bit; bit >>= 1 )
      emit( r, bytes[i] & bit ? 1710 : 855, 2 );
}

static void
append( libspectrum_tape *tape, recording *r, size_t first, size_t end, int high )
{
  size_t count = end - first + high;
  libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_dword *lengths = libspectrum_new( libspectrum_dword, count );
  size_t *repeats = libspectrum_new( size_t, count );
  if( high ) { lengths[0] = 0; repeats[0] = 1; }
  memcpy( lengths + high, r->lengths + first, ( end - first ) * sizeof( *lengths ) );
  memcpy( repeats + high, r->repeats + first, ( end - first ) * sizeof( *repeats ) );
  libspectrum_tape_block_set_count( block, count );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( tape, block );
}

static void
pause( libspectrum_tape *tape )
{
  libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_set_pause_tstates( block, 100000 );
  libspectrum_tape_block_set_level( block, 1 );
  libspectrum_tape_append_block( tape, block );
}

test_return_t
tap_pzx_recorded_rom_blocks( void )
{
  libspectrum_byte header[19] = { 0, 3 }, data[] = { 0xff, 0x12, 0xed };
  libspectrum_byte expected[26], *pzx = NULL, *tap = NULL;
  libspectrum_tape *source = libspectrum_tape_alloc(), *loaded = libspectrum_tape_alloc();
  libspectrum_tape_edge expected_edge, actual_edge;
  libspectrum_tape_cursor *cursor = NULL;
  recording r = { 0 };
  size_t i, pzx_length = 0, tap_length = 0;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 18; i++ ) header[18] ^= header[i];
  expected[0] = 19; expected[1] = 0; memcpy( expected + 2, header, 19 );
  expected[21] = 3; expected[22] = 0; memcpy( expected + 23, data, 3 );
  emit( &r, 350000, 1 ); encode( &r, header, 19 );
  emit( &r, 945, 1 ); emit( &r, 350000, 1 ); encode( &r, data, 3 );
  /* Small timing variation, and a chunk boundary inside data. */
  for( i = 0; i < r.count; i++ ) if( r.lengths[i] < 3500 ) r.lengths[i] += 7;
  int second_level = 1;
  for( i = 0; i < 17; i++ ) second_level ^= r.repeats[i] & 1;
  append( source, &r, 0, 17, 1 ); append( source, &r, 17, r.count, second_level );
  pause( source );
  if( libspectrum_tape_write( &pzx, &pzx_length, source, LIBSPECTRUM_ID_TAPE_PZX ) ||
      libspectrum_tape_read( loaded, pzx, pzx_length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
  cursor = libspectrum_tape_cursor_capture( loaded );
  if( libspectrum_tape_cursor_get_next_edge( &expected_edge, cursor ) ||
      libspectrum_tape_write( &tap, &tap_length, loaded, LIBSPECTRUM_ID_TAPE_TAP ) ||
      tap_length != sizeof( expected ) || memcmp( tap, expected, sizeof( expected ) ) ||
      libspectrum_tape_get_next_edge( &actual_edge, loaded ) ||
      actual_edge.tstates != expected_edge.tstates || actual_edge.level != expected_edge.level ||
      actual_edge.flags != expected_edge.flags ) goto done;
  result = TEST_PASS;
done:
  libspectrum_tape_cursor_free( cursor );
  libspectrum_free( pzx ); libspectrum_free( tap );
  libspectrum_tape_free( source ); libspectrum_tape_free( loaded );
  return result;
}

static int
rejected( libspectrum_tape *tape )
{
  libspectrum_byte *output = libspectrum_new( libspectrum_byte, 4 ), *original = output;
  size_t length = 4;
  int ok;
  memcpy( output, "keep", 4 );
  ok = libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TAP ) ==
       LIBSPECTRUM_ERROR_INVALID && output == original && length == 4 &&
       !memcmp( output, "keep", 4 );
  libspectrum_free( output );
  return ok;
}

test_return_t
tap_pzx_rejects_ambiguous_recordings( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_byte bytes[] = { 0xff, 0x12, 0xed };
  recording r;
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 15; i++ ) {
    libspectrum_tape_clear( tape ); memset( &r, 0, sizeof( r ) );
    encode( &r, bytes, 3 );
    switch( i ) {
    case 0: r.repeats[0] = 255; break;
    case 1: r.lengths[1] = 1000; break;
    case 2: r.lengths[2] = 1000; break;
    case 3: r.repeats[3]--; break; /* unmatched data half */
    case 4: r.repeats[r.count - 1] -= 2; break; /* partial byte */
    case 5: r.lengths[r.count - 1] = r.lengths[r.count - 1] == 855 ? 1710 : 855; break;
    case 6: emit( &r, 100, 1 ); break;
    case 7: emit( &r, 0, 1 ); break;
    case 8: r.repeats[0] = 0; break;
    case 9: r.repeats[0] = (size_t)-1; r.lengths[1] = 1000; break;
    case 10: r.count = 0; encode( &r, bytes, 1 ); emit( &r, 855, 65535 * 16U ); break;
    case 11: r.count = 0; break;
    case 12: emit( &r, 350000, 1 ); emit( &r, 350001, 1 ); break;
    case 13: r.repeats[3] = (size_t)-1; break;
    }
    if( i == 14 ) {
      /* A wrong chunk polarity removes an edge inside the data waveform. */
      append( tape, &r, 0, 4, 0 ); append( tape, &r, 4, r.count, 0 );
    } else {
      append( tape, &r, 0, r.count, 0 );
    }
    if( !rejected( tape ) ) {
      fprintf( stderr, "%s: TAP recognition rejection case %lu failed\n", progname, (unsigned long)i );
      goto done;
    }
  }
  /* Errors after a valid block must not expose a partial TAP. */
  for( i = 0; i < 3; i++ ) {
    libspectrum_tape_clear( tape ); memset( &r, 0, sizeof( r ) ); encode( &r, bytes, 3 );
    append( tape, &r, 0, r.count, 0 ); pause( tape );
    libspectrum_tape_type type = i == 0 ? LIBSPECTRUM_TAPE_BLOCK_JUMP :
      i == 1 ? LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK : LIBSPECTRUM_TAPE_BLOCK_ROM;
    libspectrum_tape_append_block( tape, libspectrum_tape_block_alloc( type ) );
    if( !rejected( tape ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

/* All-zero payload bounded by flag/checksum FF: seven pulse runs suffice
   even for the largest TAP block, without a waveform-sized fixture. */
test_return_t
tap_pzx_terminal_and_size_boundaries( void )
{
  static const libspectrum_dword timings[] = { 2168, 667, 735, 1710, 855, 1710, 945 };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t length = 0, test, i;
  test_return_t result = TEST_FAIL;
  for( test = 0; test < 6; test++ ) {
    libspectrum_free( output ); output = NULL; length = 0;
    libspectrum_tape_clear( tape );
    libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
    libspectrum_dword *durations = libspectrum_new( libspectrum_dword, 7 );
    size_t *repeats = libspectrum_new( size_t, 7 );
    for( i = 0; i < 7; i++ ) { durations[i] = timings[i]; repeats[i] = 1; }
    repeats[0] = test == 3 ? (size_t)-1 : 256;
    repeats[3] = repeats[5] = 16;
    repeats[4] = test == 4 ? 65533 * 16U : 16;
    if( test == 1 || test == 2 )
      for( i = 0; i < 7; i++ )
        durations[i] = test == 1 ? timings[i] + timings[i] / 20 : timings[i] - timings[i] / 20;
    libspectrum_tape_block_set_count( block, test == 5 ? 7 : 6 );
    libspectrum_tape_block_set_pulse_lengths( block, durations );
    libspectrum_tape_block_set_pulse_repeats( block, repeats );
    libspectrum_tape_append_block( tape, block );
    if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TAP ) ||
        length != ( test == 4 ? 65537 : 5 ) || output[2] != 0xff || output[length - 1] != 0xff ||
        output[0] + 256U * output[1] != length - 2 ) goto done;
    for( i = 3; i + 1 < length; i++ ) if( output[i] ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape );
  return result;
}
