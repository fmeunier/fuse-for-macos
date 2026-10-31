/* test/pzx-flow.c: Bounded PZX control-flow conversion tests
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
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "internals.h"
#include "test.h"

enum flow_type {
  FLOW_DONE, FLOW_TONE, FLOW_JUMP, FLOW_LOOP, FLOW_END, FLOW_COMMENT,
  FLOW_GROUP, FLOW_GROUP_END, FLOW_STOP, FLOW_STOP48, FLOW_LEVEL,
  FLOW_RAW, FLOW_CSW, FLOW_MESSAGE, FLOW_HARDWARE, FLOW_CUSTOM
};

typedef struct flow_block {
  enum flow_type type;
  int value, count;
} flow_block;

static libspectrum_tape_block *
flow_block_alloc( flow_block description )
{
  libspectrum_tape_block *block;
  libspectrum_byte *data;
  char *text;
  size_t length;
  switch( description.type ) {
  case FLOW_TONE:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_pulse_length( block, description.value );
    libspectrum_tape_block_set_count( block, description.count );
    break;
  case FLOW_JUMP:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_JUMP );
    libspectrum_tape_block_set_offset( block, description.value );
    break;
  case FLOW_LOOP:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_LOOP_START );
    libspectrum_tape_block_set_count( block, description.value );
    break;
  case FLOW_END:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_LOOP_END );
    break;
  case FLOW_COMMENT:
  case FLOW_GROUP:
    block = libspectrum_tape_block_alloc( description.type == FLOW_COMMENT ?
      LIBSPECTRUM_TAPE_BLOCK_COMMENT : LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
    length = description.value ? description.value : 4;
    text = libspectrum_new( char, length + 1 );
    memset( text, 'x', length ); text[length] = 0;
    libspectrum_tape_block_set_text( block, text );
    break;
  case FLOW_GROUP_END:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END );
    break;
  case FLOW_STOP:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    break;
  case FLOW_STOP48:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_STOP48 );
    break;
  case FLOW_LEVEL:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( block, description.value );
    break;
  case FLOW_MESSAGE:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
    text = libspectrum_new( char, 14 );
    memcpy( text, "Line 1\nLine 2", 14 );
    libspectrum_tape_block_set_text( block, text );
    libspectrum_tape_block_set_pause( block, description.value );
    break;
  case FLOW_HARDWARE:
    {
      int *types = libspectrum_new( int, 1 );
      int *ids = libspectrum_new( int, 1 );
      int *values = libspectrum_new( int, 1 );
      types[0] = 0; ids[0] = 255; values[0] = 3;
      block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_HARDWARE );
      libspectrum_tape_block_set_count( block, 1 );
      libspectrum_tape_block_set_types( block, types );
      libspectrum_tape_block_set_ids( block, ids );
      libspectrum_tape_block_set_values( block, values );
      break;
    }
  case FLOW_CUSTOM:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_CUSTOM );
    text = libspectrum_new( char, 17 );
    memcpy( text, "Custom binary id", 17 );
    data = libspectrum_new( libspectrum_byte, 4 );
    data[0] = 0; data[1] = 0xff; data[2] = 0x80; data[3] = 0x1a;
    libspectrum_tape_block_set_text( block, text );
    libspectrum_tape_block_set_data( block, data );
    libspectrum_tape_block_set_data_length( block, 4 );
    break;
  case FLOW_RAW:
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
    data = libspectrum_new( libspectrum_byte, 1 ); data[0] = 0xa0;
    libspectrum_tape_block_set_data( block, data );
    libspectrum_tape_block_set_data_length( block, 1 );
    libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
    libspectrum_tape_block_set_bit_length( block, 79 );
    break;
  default: /* FLOW_CSW */
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_TZX_CSW );
    data = libspectrum_new( libspectrum_byte, 2 );
    data[0] = 101; data[1] = 102;
    libspectrum_tape_block_set_data( block, data );
    libspectrum_tape_block_set_data_length( block, 2 );
    libspectrum_tape_block_set_sample_rate( block, 3500000 );
    libspectrum_tape_block_set_csw_pulses( block, 2 );
    break;
  }
  return block;
}

static void
append_path( libspectrum_tape *tape, const flow_block *path, int initial )
{
  if( initial < 2 ) {
    libspectrum_tape_block *block = libspectrum_tape_block_alloc(
      LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( block, initial );
    libspectrum_tape_append_block( tape, block );
  }
  for( ; path->type != FLOW_DONE; path++ )
    libspectrum_tape_append_block( tape, flow_block_alloc( *path ) );
}

/* Check complete cursor state, not just the current block or held level. */
static int
playback_unchanged( libspectrum_tape *tape, libspectrum_tape_cursor *cursor )
{
  libspectrum_tape_edge expected, actual;
  size_t i;
  for( i = 0; i < 8; i++ ) {
    libspectrum_error a = libspectrum_tape_cursor_get_next_edge( &expected, cursor );
    libspectrum_error b = libspectrum_tape_get_next_edge( &actual, tape );
    if( a != b ) return 0;
    if( a ) return 1;
    if( expected.tstates != actual.tstates || expected.level != actual.level ||
        expected.transition != actual.transition || expected.flags != actual.flags )
      return 0;
  }
  return 1;
}

static void
append_run( libspectrum_dword *times, int *levels, size_t *count,
            libspectrum_dword time, int level )
{
  if( *count && levels[*count - 1] == level ) times[*count - 1] += time;
  else { times[*count] = time; levels[(*count)++] = level; }
}

static int
waveform_matches( libspectrum_tape *tape, const libspectrum_dword *times,
                  const int *levels, size_t count )
{
  libspectrum_dword actual_times[32];
  int actual_levels[32];
  size_t events, actual_count = 0;
  libspectrum_tape_edge edge;
  for( events = 0; events < 200; events++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ) return 0;
    if( edge.tstates ) {
      if( actual_count == 32 ) return 0;
      append_run( actual_times, actual_levels, &actual_count,
                  edge.tstates, edge.level );
    }
    if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE )
      return actual_count == count &&
        !memcmp( actual_times, times, count * sizeof( *times ) ) &&
        !memcmp( actual_levels, levels, count * sizeof( *levels ) );
  }
  return 0;
}

/* Independently specified paths and pulse durations, rather than using
   source playback alone as the oracle. Metadata counts in jump offsets. */
test_return_t
pzx_write_control_flow( void )
{
  static const struct {
    flow_block path[12];
    libspectrum_dword times[16];
    size_t count, browse, stops;
    int recording;
  } cases[] = {
    { { { FLOW_JUMP, 1, 0 }, { FLOW_COMMENT, 0, 0 },
        { FLOW_TONE, 100, 2 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 1, 0, 0 },
    { { { FLOW_JUMP, 3, 0 }, { FLOW_COMMENT, 0, 0 },
        { FLOW_TONE, 999, 1 }, { FLOW_TONE, 100, 2 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 0, 0, 0 },
    { { { FLOW_JUMP, 3, 0 }, { FLOW_TONE, 100, 2 }, { FLOW_JUMP, 2, 0 },
        { FLOW_JUMP, -2, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 0, 0, 0 },
    { { { FLOW_LOOP, 2, 0 }, { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 200 }, 1, 0, 0, 0 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_TONE, 100, 2 }, { FLOW_END, 0, 0 },
        { FLOW_TONE, 200, 1 } },
      { 100, 100, 100, 100, 100, 100, 200 }, 7, 0, 0, 0 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_JUMP, 2, 0 },
        { FLOW_TONE, 999, 1 }, { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 100, 200 }, 4, 0, 0, 0 },
    { { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 },
        { FLOW_LOOP, 3, 0 }, { FLOW_TONE, 200, 1 }, { FLOW_END, 0, 0 },
        { FLOW_TONE, 300, 1 } },
      { 100, 100, 200, 200, 200, 300 }, 6, 0, 0, 0 },
    { { { FLOW_JUMP, 4, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 999, 1 },
        { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 200 }, 1, 0, 0, 0 },
    { { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_STOP, 0, 0 },
        { FLOW_STOP48, 0, 0 }, { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 0, 4, 0 },
    { { { FLOW_LOOP, 2, 0 }, { FLOW_GROUP, 0, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_GROUP_END, 0, 0 }, { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 2, 0, 0 },
    { { { FLOW_GROUP, 0, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_END, 0, 0 }, { FLOW_GROUP_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 200 }, 3, 1, 0, 0 },
    { { { FLOW_JUMP, 3, 0 }, { FLOW_STOP, 0, 0 }, { FLOW_STOP48, 0, 0 },
        { FLOW_TONE, 100, 1 } },
      { 100 }, 1, 0, 0, 0 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_JUMP, 3, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_JUMP, 2, 0 }, { FLOW_JUMP, -2, 0 }, { FLOW_END, 0, 0 },
        { FLOW_TONE, 200, 1 } },
      { 100, 100, 100, 200 }, 4, 0, 0, 0 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_RAW, 0, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 79, 79, 79, 100, 79, 79, 79, 100, 79, 79, 79, 100, 200 },
      13, 0, 0, 1 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_LEVEL, 1, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 100, 100, 100, 200 }, 4, 0, 0, 3 },
    { { { FLOW_LOOP, 3, 0 }, { FLOW_CSW, 0, 0 }, { FLOW_TONE, 100, 1 },
        { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
      { 101, 102, 100, 101, 102, 100, 101, 102, 100, 200 },
      10, 0, 0, 2 }
  };
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_cursor *cursor = NULL;
  libspectrum_byte *out = NULL;
  libspectrum_dword times[32];
  int levels[32], initial;
  size_t length = 0, n, i, count, pos, browse, stops;
  libspectrum_tape_edge edge;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < sizeof( cases ) / sizeof( cases[0] ); n++ )
  for( initial = 0; initial < 3; initial++ ) {
    int first = initial < 2 ? !initial : 0;
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    append_path( tape, cases[n].path, initial );
    count = 0;
    for( i = 0; i < cases[n].count; i++ ) {
      int level = first ^ ( i & 1 );
      if( cases[n].recording == 1 ) level = i < 12 ? !( i % 2 ) : 1;
      if( cases[n].recording == 2 )
        level = ( initial < 2 ? initial : 0 ) ^ ( i < 9 ? i % 3 == 1 : 1 );
      if( cases[n].recording == 3 ) level = i == 3;
      append_run( times, levels, &count, cases[n].times[i], level );
    }
    if( libspectrum_tape_nth_block( tape, 0 ) ) goto done;
    /* In loop cases this captures a partially consumed body and loop count. */
    for( i = 0; i < 3; i++ )
      if( libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    cursor = libspectrum_tape_cursor_capture( tape );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        !playback_unchanged( tape, cursor ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        libspectrum_tape_nth_block( tape, 0 ) ||
        !waveform_matches( tape, times, levels, count ) ||
        !waveform_matches( dest, times, levels, count ) ) goto done;
    browse = stops = 0;
    for( pos = 0; pos < length; ) {
      size_t size;
      if( length - pos < 8 ) goto done;
      size = libspectrum_read_dword_le( out + pos + 4 );
      if( size > length - pos - 8 ) goto done;
      if( !memcmp( out + pos, "BRWS", 4 ) ) browse++;
      if( !memcmp( out + pos, "STOP", 4 ) ) {
        if( size != 2 || out[pos + 8] != ( stops & 1 ) || out[pos + 9] ) goto done;
        stops++;
      }
      pos += size + 8;
    }
    if( browse != cases[n].browse || stops != cases[n].stops ) goto done;
    libspectrum_tape_cursor_free( cursor ); cursor = NULL;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: PZX flow case %lu initial=%d failed\n",
             progname, (unsigned long)n, initial );
  if( cursor ) libspectrum_tape_cursor_free( cursor );
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_control_flow_invalid( void )
{
  static const flow_block paths[][10] = {
    { { FLOW_JUMP, 0, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_JUMP, -1, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_JUMP, 2, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_JUMP, INT_MAX, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_JUMP, INT_MIN, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_TONE, 100, 1 }, { FLOW_JUMP, -1, 0 } },
    { { FLOW_JUMP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_JUMP, -2, 0 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 },
      { FLOW_END, 0, 0 }, { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 0, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 1, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 65536, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 65535, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 } },
    { { FLOW_JUMP, 2, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 },
      { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_JUMP, 2, 0 }, { FLOW_END, 0, 0 },
      { FLOW_TONE, 100, 1 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_JUMP, -2, 0 },
      { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_JUMP, -1, 0 },
      { FLOW_END, 0, 0 } },
    { { FLOW_GROUP, 0, 0 }, { FLOW_JUMP, 2, 0 }, { FLOW_GROUP_END, 0, 0 },
      { FLOW_TONE, 100, 1 } },
    { { FLOW_JUMP, 2, 0 }, { FLOW_GROUP, 0, 0 }, { FLOW_GROUP_END, 0, 0 },
      { FLOW_TONE, 100, 1 } },
    { { FLOW_GROUP, 0, 0 }, { FLOW_JUMP, -1, 0 }, { FLOW_GROUP_END, 0, 0 } },
    { { FLOW_JUMP, 4, 0 }, { FLOW_LOOP, 1, 0 }, { FLOW_TONE, 100, 1 },
      { FLOW_END, 0, 0 }, { FLOW_TONE, 200, 1 } },
    { { FLOW_JUMP, 2, 0 }, { FLOW_JUMP, INT_MAX, 0 }, { FLOW_TONE, 100, 1 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_JUMP, 3, 0 },
      { FLOW_END, 0, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_TONE, 200, 1 },
      { FLOW_END, 0, 0 } },
    { { FLOW_GROUP, 0, 0 }, { FLOW_LOOP, 2, 0 }, { FLOW_GROUP_END, 0, 0 },
      { FLOW_TONE, 100, 1 }, { FLOW_END, 0, 0 } },
    { { FLOW_LOOP, 2, 0 }, { FLOW_GROUP, 0, 0 }, { FLOW_END, 0, 0 },
      { FLOW_GROUP_END, 0, 0 } },
    /* Fits the visit bound but exceeds the 64 MiB expanded-output bound. */
    { { FLOW_LOOP, 2048, 0 }, { FLOW_COMMENT, 65536, 0 }, { FLOW_END, 0, 0 } }
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_cursor *cursor = NULL;
  libspectrum_byte *out = NULL, *original;
  size_t n, length;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < sizeof( paths ) / sizeof( paths[0] ); n++ ) {
    libspectrum_tape_clear( tape ); append_path( tape, paths[n], 2 );
    if( libspectrum_tape_nth_block( tape, 0 ) ) goto done;
    if( n == sizeof( paths ) / sizeof( paths[0] ) - 1 ) {
      libspectrum_tape_edge edge;
      size_t i;
      for( i = 0; i < 3; i++ )
        if( libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    }
    cursor = libspectrum_tape_cursor_capture( tape );
    original = out = libspectrum_new( libspectrum_byte, 4 ); length = 4;
    memcpy( out, "keep", 4 );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) !=
          LIBSPECTRUM_ERROR_INVALID || out != original || length != 4 ||
        memcmp( out, "keep", 4 ) || !playback_unchanged( tape, cursor ) ) goto done;
    libspectrum_tape_cursor_free( cursor ); cursor = NULL;
    libspectrum_free( out ); out = NULL;
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: PZX invalid flow case %lu failed\n", progname, (unsigned long)n );
  if( cursor ) libspectrum_tape_cursor_free( cursor );
  libspectrum_free( out ); libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_control_flow_visit_limit( void )
{
  flow_block path[] = {
    { FLOW_JUMP, 1, 0 }, { FLOW_LOOP, 32767, 0 },
    { FLOW_COMMENT, 4, 0 }, { FLOW_END, 0, 0 }, { FLOW_DONE, 0, 0 }
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_cursor *cursor = NULL;
  libspectrum_tape_edge edge;
  libspectrum_byte *out = NULL;
  size_t length = 0, n, i;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 2; n++ ) {
    libspectrum_error error;
    libspectrum_tape_clear( tape );
    path[1].value = 32767 + n;
    append_path( tape, path, 2 );
    if( libspectrum_tape_nth_block( tape, 0 ) ) goto done;
    for( i = 0; i < 3; i++ )
      if( libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    cursor = libspectrum_tape_cursor_capture( tape );
    error = libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX );
    if( n ) {
      if( error != LIBSPECTRUM_ERROR_INVALID || out || length ) goto done;
    } else {
      /* Jump + start + 32767 * (comment + end) is exactly 65536 visits. */
      if( error || length != 10 + 32767 * 12 ) goto done;
      for( i = 10; i < length; i += 12 )
        if( memcmp( out + i, "BRWS\x04\0\0\0xxxx", 12 ) ) goto done;
    }
    if( !playback_unchanged( tape, cursor ) ) goto done;
    libspectrum_tape_cursor_free( cursor ); cursor = NULL;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  if( cursor ) libspectrum_tape_cursor_free( cursor );
  libspectrum_free( out ); libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_dropped_metadata( void )
{
  static const flow_block paths[][9] = {
    { { FLOW_MESSAGE, 0, 0 }, { FLOW_HARDWARE, 0, 0 }, { FLOW_CUSTOM, 0, 0 } },
    { { FLOW_TONE, 100, 2 }, { FLOW_MESSAGE, 3000, 0 }, { FLOW_HARDWARE, 0, 0 },
      { FLOW_CUSTOM, 0, 0 }, { FLOW_TONE, 200, 1 } },
    { { FLOW_JUMP, 4, 0 }, { FLOW_MESSAGE, 3000, 0 }, { FLOW_HARDWARE, 0, 0 },
      { FLOW_CUSTOM, 0, 0 }, { FLOW_TONE, 200, 1 } },
    { { FLOW_LOOP, 3, 0 }, { FLOW_TONE, 100, 1 }, { FLOW_MESSAGE, 3000, 0 },
      { FLOW_HARDWARE, 0, 0 }, { FLOW_CUSTOM, 0, 0 }, { FLOW_END, 0, 0 },
      { FLOW_TONE, 200, 1 } }
  };
  static const libspectrum_dword times[][4] = {
    { 0 }, { 100, 100, 200 }, { 200 }, { 100, 100, 100, 200 }
  };
  static const int levels[][4] = { { 0 }, { 0, 1, 0 }, { 0 }, { 0, 1, 0, 1 } };
  static const size_t counts[] = { 0, 3, 1, 4 }, blocks[] = { 0, 2, 1, 4 };
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_cursor *cursor = NULL;
  libspectrum_byte *out = NULL;
  size_t length = 0, n;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 4; n++ ) {
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    append_path( tape, paths[n], 2 );
    if( libspectrum_tape_nth_block( tape, 0 ) ) goto done;
    cursor = libspectrum_tape_cursor_capture( tape );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        !playback_unchanged( tape, cursor ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        libspectrum_tape_count( dest ) != blocks[n] ) goto done;
    {
      static const libspectrum_byte payload[] = { 0, 0xff, 0x80, 0x1a };
      libspectrum_tape_iterator it;
      libspectrum_tape_block *block;
      for( block = libspectrum_tape_iterator_init( &it, tape ); block;
           block = libspectrum_tape_iterator_next( &it ) ) {
        switch( libspectrum_tape_block_type( block ) ) {
        case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
          if( strcmp( libspectrum_tape_block_text( block ), "Line 1\nLine 2" ) ||
              libspectrum_tape_block_pause( block ) != ( n ? 3000 : 0 ) ) goto done;
          break;
        case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
          if( libspectrum_tape_block_count( block ) != 1 ||
              libspectrum_tape_block_types( block, 0 ) != 0 ||
              libspectrum_tape_block_ids( block, 0 ) != 255 ||
              libspectrum_tape_block_values( block, 0 ) != 3 ) goto done;
          break;
        case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
          if( strcmp( libspectrum_tape_block_text( block ), "Custom binary id" ) ||
              libspectrum_tape_block_data_length( block ) != sizeof( payload ) ||
              memcmp( libspectrum_tape_block_data( block ), payload,
                      sizeof( payload ) ) ) goto done;
          break;
        default: break;
        }
      }
    }
    if( n ) {
      if( libspectrum_tape_nth_block( tape, 0 ) ||
          !waveform_matches( tape, times[n], levels[n], counts[n] ) ||
          !waveform_matches( dest, times[n], levels[n], counts[n] ) ) goto done;
    } else if( length != 10 ) goto done;
    libspectrum_tape_cursor_free( cursor ); cursor = NULL;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: dropped metadata case %lu failed\n", progname, (unsigned long)n );
  if( cursor ) libspectrum_tape_cursor_free( cursor );
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

static libspectrum_tape_block *
zero_pulse_data( void )
{
  libspectrum_tape_block *block = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  libspectrum_tape_block_set_data( block, libspectrum_new0( libspectrum_byte, 1 ) );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_level( block, 1 );
  return block;
}

test_return_t
pzx_write_control_flow_native_data( void )
{
  flow_block jump = { FLOW_JUMP, 1, 0 }, loop = { FLOW_LOOP, 2, 0 };
  flow_block tone = { FLOW_TONE, 100, 1 }, end = { FLOW_END, 0, 0 };
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_byte *out = NULL;
  libspectrum_tape_signal_level level;
  size_t length = 0, i, n;
  int position;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 3; n++ ) {
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    jump.value = n ? 2 : 1;
    libspectrum_tape_append_block( tape, flow_block_alloc( jump ) );
    if( n ) libspectrum_tape_append_block( tape, n == 1 ?
      flow_block_alloc( tone ) : zero_pulse_data() );
    libspectrum_tape_append_block( tape, flow_block_alloc( loop ) );
    libspectrum_tape_append_block( tape, n == 2 ?
      flow_block_alloc( tone ) : zero_pulse_data() );
    libspectrum_tape_append_block( tape, flow_block_alloc( end ) );
    /* Playback requirements follow the executed path: native zero-pulse
       DATA needs no inspection; skipped blocks must not force or prevent it. */
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_position( &position, tape ) || position != 0 ||
        libspectrum_tape_signal_level_get( &level, tape ) || level != 0 ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        libspectrum_tape_count( dest ) != 2 ) goto done;
    if( n == 2 ) {
      static const libspectrum_dword times[] = { 100, 100 };
      static const int levels[] = { 0, 1 };
      if( !waveform_matches( tape, times, levels, 2 ) ||
          !waveform_matches( dest, times, levels, 2 ) ) goto done;
    } else {
      for( i = 0; i < 2; i++ ) {
        if( libspectrum_tape_nth_block( dest, i ) ) goto done;
        block = libspectrum_tape_current_block( dest );
        if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK ||
            libspectrum_tape_block_count( block ) != 1 ||
            libspectrum_tape_block_level( block ) != 1 ||
            libspectrum_tape_block_bit0_pulse_count( block ) ||
            libspectrum_tape_block_bit1_pulse_count( block ) ) goto done;
      }
    }
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}
