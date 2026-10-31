/* test/csw-write.c: Waveform-aware standalone CSW output tests
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

static libspectrum_tape_block *
pause_block( libspectrum_dword duration, int level )
{
  libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_set_pause_tstates( block, duration );
  libspectrum_tape_block_set_level( block, level );
  return block;
}

/* Inspect the actual RLE payload, independently of tape playback. */
static int
check_csw( const libspectrum_byte *output, size_t length, libspectrum_dword rate,
           int high, const libspectrum_dword *expected, size_t count )
{
  libspectrum_byte *inflated = NULL;
  const libspectrum_byte *data;
  size_t size, i = 0, pulse = 0;
  int result = 0;
  if( length < 52 || memcmp( output, "Compressed Square Wave\x1a\x02\0", 25 ) ||
      libspectrum_read_dword_le( output + 25 ) != rate ||
      libspectrum_read_dword_le( output + 29 ) != count || output[34] != high ||
      output[35] != 0 ) return 0;
  data = output + 52; size = length - 52;
  if( output[33] == 2 ) {
#ifdef HAVE_ZLIB_H
    if( libspectrum_zlib_inflate( data, size, &inflated, &size ) ) goto done;
    data = inflated;
#else
    goto done;
#endif
  } else if( output[33] != 1 ) goto done;
  while( i < size ) {
    libspectrum_dword samples = data[i++];
    if( !samples ) {
      if( size - i < 4 ) goto done;
      samples = libspectrum_read_dword_le( data + i ); i += 4;
    }
    if( !samples || pulse >= count || samples != expected[pulse++] ) goto done;
  }
  result = pulse == count;
done:
  libspectrum_free( inflated );
  return result;
}

test_return_t
csw_write_pzx_levels_holds_and_stop( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_byte *output = NULL, *data = libspectrum_new( libspectrum_byte, 1 );
  size_t length = 0;
  libspectrum_dword *pulses = libspectrum_new( libspectrum_dword, 2 );
  size_t *repeats = libspectrum_new( size_t, 2 );
  libspectrum_word *s0 = libspectrum_new( libspectrum_word, 2 );
  libspectrum_word *s1 = libspectrum_new( libspectrum_word, 2 );
  static const libspectrum_dword expected[] = { 110, 10, 20, 1000 };
  libspectrum_tape_edge edge;
  size_t i;
  test_return_t result = TEST_FAIL;
  char *text = libspectrum_new( char, 5 ); memcpy( text, "Here", 5 );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
  libspectrum_tape_block_set_text( block, text ); libspectrum_tape_append_block( tape, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  pulses[0] = 0; pulses[1] = 100; repeats[0] = repeats[1] = 1;
  libspectrum_tape_block_set_count( block, 2 );
  libspectrum_tape_block_set_pulse_lengths( block, pulses );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( tape, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  s0[0] = 10; s0[1] = 0; s1[0] = 0; s1[1] = 10; data[0] = 0x40;
  libspectrum_tape_block_set_count( block, 2 );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_block_set_bits_in_last_byte( block, 2 );
  libspectrum_tape_block_set_data( block, data );
  libspectrum_tape_block_set_level( block, 1 );
  libspectrum_tape_block_set_tail_length( block, 7 );
  libspectrum_tape_block_set_bit0_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit1_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit0_pulses( block, s0 );
  libspectrum_tape_block_set_bit1_pulses( block, s1 );
  libspectrum_tape_block *data_block = block;
  libspectrum_tape_append_block( tape, block );
  libspectrum_tape_append_block( tape, pause_block( 13, 1 ) );
  libspectrum_tape_append_block( tape, pause_block( 1000, 0 ) );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_STOP48 );
  libspectrum_tape_append_block( tape, block );
  libspectrum_tape_append_block( tape, pause_block( 0, 0 ) );
  libspectrum_tape_append_block( tape, pause_block( 999, 1 ) );
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 3500000, 1, expected, 4 ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_CSW, NULL ) )
    goto done;
  for( i = 0; i < 4; i++ ) {
    do {
      if( libspectrum_tape_get_next_edge( &edge, dest ) ) goto done;
    } while( !edge.tstates );
    if( edge.tstates != expected[i] || edge.level != ( i & 1 ?
        LIBSPECTRUM_TAPE_SIGNAL_LOW : LIBSPECTRUM_TAPE_SIGNAL_HIGH ) ) goto done;
  }
  /* Empty bit sequences are legal PZX and must not require native playback. */
  libspectrum_tape_block_set_bit0_pulse_count( data_block, 0 );
  libspectrum_free( output ); output = NULL; length = 0;
  static const libspectrum_dword empty_expected[] = { 100, 10, 20, 1000 };
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 3500000, 1, empty_expected, 4 ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
csw_write_empty_limits_and_atomic_errors( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t length = 0;
  static const libspectrum_dword expected[] = { 255, 256, 1, 0x7fffffff };
  static const libspectrum_dword maximum[] = { UINT32_MAX };
  libspectrum_tape_edge edge;
  test_return_t result = TEST_FAIL;
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      length != 52 || !check_csw( output, length, 3500000, 0, NULL, 0 ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
      libspectrum_tape_present( dest ) ) goto done;
  for( size_t i = 0; i < 4; i++ )
    libspectrum_tape_append_block( tape, pause_block( expected[i], i & 1 ) );
  libspectrum_free( output ); output = NULL; length = 0;
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 3500000, 0, expected, 4 ) ) goto done;
  libspectrum_tape_clear( tape );
  libspectrum_tape_append_block( tape, pause_block( 0x7fffffff, 1 ) );
  libspectrum_tape_append_block( tape, pause_block( 0x7fffffff, 1 ) );
  libspectrum_tape_append_block( tape, pause_block( 1, 1 ) );
  libspectrum_free( output ); output = NULL; length = 0;
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 3500000, 1, maximum, 1 ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
      libspectrum_tape_get_next_edge( &edge, dest ) ||
      libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates != UINT32_MAX ||
      edge.level != LIBSPECTRUM_TAPE_SIGNAL_HIGH ) goto done;
  libspectrum_tape_append_block( tape, pause_block( 1, 1 ) );
  libspectrum_free( output ); output = libspectrum_new( libspectrum_byte, 4 ); length = 4;
  libspectrum_byte *original = output;
  memcpy( output, "keep", 4 );
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) !=
      LIBSPECTRUM_ERROR_INVALID || output != original || length != 4 ||
      memcmp( output, "keep", 4 ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
csw_write_exact_recording_and_position( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_byte input[59] = { 0 }, *output = NULL;
  libspectrum_tape_cursor *before = NULL, *probe = NULL;
  libspectrum_tape_edge actual, expected_edge;
  size_t length = 0;
  static const libspectrum_dword expected[] = { 255, 256, 1 };
  test_return_t result = TEST_FAIL;
  memcpy( input, "Compressed Square Wave\x1a", 23 );
  input[23] = 2; input[25] = 0x44; input[26] = 0xac; input[29] = 3; input[33] = 1;
  input[52] = 255; input[53] = 0; input[54] = 0; input[55] = 1; input[58] = 1;
  for( int high = 0; high <= 1; high++ ) {
    input[34] = high;
    if( libspectrum_tape_read( tape, input, sizeof( input ), LIBSPECTRUM_ID_TAPE_CSW,
                               NULL ) ) goto done;
    do {
      if( libspectrum_tape_get_next_edge( &actual, tape ) ) goto done;
    } while( !actual.tstates );
    if( actual.level != ( high ? LIBSPECTRUM_TAPE_SIGNAL_HIGH : LIBSPECTRUM_TAPE_SIGNAL_LOW ) )
      goto done;
    before = libspectrum_tape_cursor_capture( tape );
    probe = libspectrum_tape_cursor_clone( before );
    if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
        !check_csw( output, length, 44100, high, expected, 3 ) ) goto done;
    for( size_t i = 0; i < 2; i++ )
      if( libspectrum_tape_cursor_get_next_edge( &expected_edge, probe ) ||
          libspectrum_tape_get_next_edge( &actual, tape ) ||
          actual.tstates != expected_edge.tstates || actual.level != expected_edge.level ||
          actual.flags != expected_edge.flags || actual.transition != expected_edge.transition )
        goto done;
    libspectrum_tape_cursor_free( before ); before = NULL;
    libspectrum_tape_cursor_free( probe ); probe = NULL;
    libspectrum_free( output ); output = NULL; length = 0;
    libspectrum_tape_clear( tape );
  }
  result = TEST_PASS;
done:
  if( before ) libspectrum_tape_cursor_free( before );
  if( probe ) libspectrum_tape_cursor_free( probe );
  libspectrum_free( output ); libspectrum_tape_free( tape );
  return result;
}

test_return_t
csw_write_malformed_recordings_and_extensions( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_byte input[55] = { 0 }, *output = NULL;
  size_t length = 0;
  test_return_t result = TEST_FAIL;
  memcpy( input, "Compressed Square Wave\x1a", 23 );
  input[23] = 2; input[25] = 0x44; input[26] = 0xac; input[33] = 1;
  input[35] = 4;
  if( libspectrum_tape_read( tape, input, sizeof( input ), LIBSPECTRUM_ID_TAPE_CSW,
                             NULL ) != LIBSPECTRUM_ERROR_CORRUPT ) goto done;
  input[35] = 2; input[52] = 0xab; input[53] = 0xcd; input[54] = 11;
  static const libspectrum_dword expected[] = { 11 };
  if( libspectrum_tape_read( tape, input, sizeof( input ), LIBSPECTRUM_ID_TAPE_CSW,
                             NULL ) ||
      libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 44100, 0, expected, 1 ) ) goto done;
  libspectrum_free( output ); output = NULL; length = 0;
  libspectrum_tape_clear( tape );
  for( size_t n = 1; n <= 5; n++ ) {
    libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, n ); memset( data, 0, n );
    libspectrum_tape_block_set_sample_rate( block, 44100 );
    libspectrum_tape_block_set_data( block, data ); libspectrum_tape_block_set_data_length( block, n );
    libspectrum_tape_append_block( tape, block );
    if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) !=
        LIBSPECTRUM_ERROR_CORRUPT || output || length ) goto done;
    libspectrum_tape_clear( tape );
  }
  /* A valid low recording rate is not rejected by a legacy scale limit. */
  libspectrum_tape_block *block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *sample = libspectrum_new( libspectrum_byte, 1 ); sample[0] = 1;
  libspectrum_tape_block_set_sample_rate( block, 1 );
  libspectrum_tape_block_set_data( block, sample ); libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_append_block( tape, block );
  static const libspectrum_dword slow_expected[] = { 1 };
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !check_csw( output, length, 1, 0, slow_expected, 1 ) ) goto done;
  libspectrum_tape_clear( tape );
  libspectrum_tape_edge edge;
  if( libspectrum_tape_read( tape, output, length, LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
      libspectrum_tape_get_next_edge( &edge, tape ) || edge.tstates != 3500000 ||
      edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) goto done;
  libspectrum_free( output ); output = NULL; length = 0;
  libspectrum_tape_clear( tape );
  /* Scale multiplication must return an error, not wrap a 7-billion-T-state run. */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  sample = libspectrum_new( libspectrum_byte, 5 );
  memcpy( sample, "\0\xd0\x07\0\0", 5 );
  libspectrum_tape_block_set_scale( block, 3500000 );
  libspectrum_tape_block_set_data( block, sample ); libspectrum_tape_block_set_data_length( block, 5 );
  libspectrum_tape_append_block( tape, block );
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) !=
      LIBSPECTRUM_ERROR_INVALID || output || length ) goto done;
  libspectrum_tape_clear( tape );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_LOOP_START );
  libspectrum_tape_append_block( tape, block );
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_CSW ) !=
      LIBSPECTRUM_ERROR_UNKNOWN || output || length ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape );
  return result;
}
