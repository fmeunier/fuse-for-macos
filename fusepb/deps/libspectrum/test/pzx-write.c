/* test/pzx-write.c: Edge cases for PZX writing
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
#include <stdio.h>
#include <string.h>
#include "internals.h"
#include "pzx_internals.h"
#include "tape_block.h"
#include "common.h"
#include "test.h"

/* Compare timed waveform runs, ignoring zero-time encoding transitions. */
static int
collect_runs( libspectrum_tape *tape, libspectrum_dword *durations,
              int *levels, size_t *count )
{
  libspectrum_tape_edge edge;
  size_t i;
  *count = 0;
  for( i = 0; i < 1000; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ) return 0;
    if( edge.tstates ) {
      if( *count && levels[*count - 1] == (int)edge.level ) {
        durations[*count - 1] += edge.tstates;
      } else {
        if( *count == 64 ) return 0;
        levels[*count] = edge.level;
        durations[(*count)++] = edge.tstates;
      }
    }
    if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) return 1;
  }
  return 0;
}

static libspectrum_tape_block *
generalised_block( size_t alphabet, int pilot, int pause )
{
  libspectrum_tape_block *b = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA );
  libspectrum_tape_generalised_data_block *g = &b->types.generalised_data;
  libspectrum_tape_generalised_data_symbol_table *table = pilot ?
    &g->pilot_table : &g->data_table;
  size_t i;
  table->symbols_in_table = alphabet;
  table->symbols_in_block = 4;
  table->max_pulses = 3;
  table->symbols = libspectrum_new( libspectrum_tape_generalised_data_symbol,
                                  alphabet );
  for( i = 0; i < alphabet; i++ ) {
    table->symbols[i].edge_type = i % 4;
    table->symbols[i].lengths = libspectrum_new( libspectrum_word, 3 );
    table->symbols[i].lengths[0] = 100 + i;
    table->symbols[i].lengths[1] = 200 + i;
    table->symbols[i].lengths[2] = 0;
  }
  if( pilot ) {
    g->pilot_symbols = libspectrum_new( libspectrum_byte, 4 );
    g->pilot_repeats = libspectrum_new( libspectrum_word, 4 );
    for( i = 0; i < 4; i++ ) {
      g->pilot_symbols[i] = i % alphabet;
      g->pilot_repeats[i] = 1 + i;
    }
  } else {
    g->bits_per_data_symbol = alphabet == 1 ? 0 : alphabet == 2 ? 1 : 2;
    g->data = libspectrum_new( libspectrum_byte, 1 );
    g->data[0] = alphabet == 4 ? 0x1b : alphabet == 3 ? 0x18 : 0x50;
  }
  libspectrum_set_pause_tstates( b, pause ? 70000 : 0 );
  return b;
}

static libspectrum_tape_block *
group_block( const char *name )
{
  libspectrum_tape_block *b = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
  if( name ) {
    char *text = libspectrum_new( char, strlen( name ) + 1 );
    strcpy( text, name );
    libspectrum_tape_block_set_text( b, text );
  }
  return b;
}

test_return_t
pzx_write_groups( void )
{
  const char *name = "Level 1 \xc3\xa9 \xe2\x82\xac \xe2\x80\x9c";
  const char *expected_name = name;
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_tape_iterator it;
  libspectrum_byte *out = NULL;
  libspectrum_dword expected[64], actual[64];
  int expected_levels[64], actual_levels[64];
  size_t length = 0, a, e, browses = 0;
  test_return_t result = TEST_FAIL;
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
  libspectrum_tape_block_set_level( b, 1 );
  libspectrum_tape_append_block( tape, b );
  libspectrum_tape_append_block( tape, group_block( NULL ) );
  libspectrum_tape_append_block( tape,
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END ) );
  libspectrum_tape_append_block( tape, group_block( name ) );
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
  libspectrum_tape_block_set_count( b, 3 );
  libspectrum_tape_block_set_pulse_length( b, 100 );
  libspectrum_tape_append_block( tape, b );
  libspectrum_tape_append_block( tape,
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END ) );
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
  libspectrum_tape_block_set_count( b, 2 );
  libspectrum_tape_block_set_pulse_length( b, 300 );
  libspectrum_tape_append_block( tape, b );
  if( libspectrum_tape_nth_block( tape, 0 ) ||
      libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
      libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
    goto done;
  for( b = libspectrum_tape_iterator_init( &it, dest ); b;
       b = libspectrum_tape_iterator_next( &it ) ) {
    if( libspectrum_tape_block_type( b ) == LIBSPECTRUM_TAPE_BLOCK_COMMENT ) {
      const char *text = libspectrum_tape_block_text( b );
      if( browses >= 2 || !text || strcmp( text, browses ? expected_name : "" ) )
        goto done;
      browses++;
    } else if( libspectrum_tape_block_type( b ) != LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE ) {
      goto done;
    }
  }
  if( browses != 2 || !collect_runs( tape, expected, expected_levels, &e ) ||
      !collect_runs( dest, actual, actual_levels, &a ) || a != e || a != 5 ||
      memcmp( expected, actual, e * sizeof( expected[0] ) ) ||
      memcmp( expected_levels, actual_levels, e * sizeof( expected_levels[0] ) ) ||
      actual[0] != 100 || actual[3] != 300 ||
      actual_levels[0] != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
      actual_levels[3] != LIBSPECTRUM_TAPE_SIGNAL_HIGH ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_generalised_symbol_semantics( void )
{
  static const libspectrum_dword durations[] = { 303, 103, 300, 300 };
  static const int levels[] = { LIBSPECTRUM_TAPE_SIGNAL_LOW,
    LIBSPECTRUM_TAPE_SIGNAL_HIGH, LIBSPECTRUM_TAPE_SIGNAL_LOW,
    LIBSPECTRUM_TAPE_SIGNAL_HIGH };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  libspectrum_dword actual[64];
  int actual_levels[64];
  size_t n, i, count, length = 0;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 16; n++ ) {
    libspectrum_tape_block *b;
    libspectrum_tape_generalised_data_block *g;
    libspectrum_tape_generalised_data_symbol_table *table;
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( b, 1 );
    libspectrum_tape_append_block( tape, b );
    b = generalised_block( 4, n & 1, 0 );
    g = &b->types.generalised_data;
    table = n & 1 ? &g->pilot_table : &g->data_table;
    table->max_pulses = n & 2 ? 1 : 3;
    for( i = 0; i < 4; i++ ) {
      table->symbols[i].lengths[1] = 0;
      table->symbols[i].lengths[2] = 999; /* Must not play past a terminator. */
      if( n & 1 ) g->pilot_repeats[i] = 1;
    }
    libspectrum_tape_append_block( tape, b );
    b = generalised_block( 1, n & 1, 0 );
    g = &b->types.generalised_data;
    table = n & 1 ? &g->pilot_table : &g->data_table;
    table->symbols[0].edge_type = n / 4;
    table->symbols[0].lengths[0] = 0; /* Empty, irrespective of polarity. */
    table->symbols[0].lengths[1] = 999;
    table->symbols[0].lengths[2] = 999;
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_count( b, 2 );
    libspectrum_tape_block_set_pulse_length( b, 300 );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    for( i = 0; i < 2; i++ ) {
      if( !collect_runs( i ? dest : tape, actual, actual_levels, &count ) ||
          count != 4 || memcmp( actual, durations, sizeof( durations ) ) ||
          memcmp( actual_levels, levels, sizeof( levels ) ) ) goto done;
    }
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_terminal_cancelled_edge( void )
{
  static const libspectrum_byte data[] = {
    'P', 'Z', 'X', 'T', 2, 0, 0, 0, 1, 0,
    'P', 'U', 'L', 'S', 6, 0, 0, 0, 100, 0, 0, 0, 200, 0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  libspectrum_tape_signal_level level;
  size_t i;
  test_return_t result = TEST_FAIL;
  if( libspectrum_tape_read( tape, data, sizeof( data ),
                            LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
  for( i = 0; i < 2; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ||
        edge.tstates != 100 || edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
        edge.transition != LIBSPECTRUM_TAPE_TRANSITION_FORCE_LOW || edge.flags )
      goto done;
    if( libspectrum_tape_get_next_edge( &edge, tape ) ||
        edge.tstates != 200 || edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
        edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ||
        edge.flags != ( LIBSPECTRUM_TAPE_FLAGS_BLOCK |
                        LIBSPECTRUM_TAPE_FLAGS_STOP |
                        LIBSPECTRUM_TAPE_FLAGS_TAPE ) ) goto done;
    if( libspectrum_tape_signal_level_get( &level, tape ) ||
        level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_generalised( void )
{
  static const libspectrum_byte cancelled_edge[] = {
    'P', 'Z', 'X', 'T', 2, 0, 0, 0, 1, 0,
    'P', 'U', 'L', 'S', 8, 0, 0, 0, 100, 0, 0, 0, 200, 0, 50, 0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  libspectrum_dword expected[64], actual[64];
  int expected_levels[64], actual_levels[64];
  size_t length = 0, n, a, e;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 32; n++ ) {
    libspectrum_tape_block *b;
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( b, n & 1 );
    libspectrum_tape_append_block( tape, b );
    b = generalised_block( 1 + n % 4, n & 4, n & 8 );
    libspectrum_tape_append_block( tape, b );
    if( n & 16 ) {
      /* Exercise pilot-to-data switching within the same block. */
      libspectrum_tape_block *extra = generalised_block( 4, !( n & 4 ), 0 );
      libspectrum_tape_generalised_data_block *g = &b->types.generalised_data;
      libspectrum_tape_generalised_data_block *other = &extra->types.generalised_data;
      if( n & 4 ) {
        g->data_table = other->data_table;
        g->data = other->data;
        g->bits_per_data_symbol = other->bits_per_data_symbol;
        memset( &other->data_table, 0, sizeof( other->data_table ) );
        other->data = NULL;
      } else {
        g->pilot_table = other->pilot_table;
        g->pilot_symbols = other->pilot_symbols;
        g->pilot_repeats = other->pilot_repeats;
        memset( &other->pilot_table, 0, sizeof( other->pilot_table ) );
        other->pilot_symbols = NULL; other->pilot_repeats = NULL;
      }
      libspectrum_tape_block_free( extra );
    }
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_count( b, 2 );
    libspectrum_tape_block_set_pulse_length( b, 300 );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        !collect_runs( tape, expected, expected_levels, &e ) ||
        !collect_runs( dest, actual, actual_levels, &a ) || a != e ||
        memcmp( expected, actual, e * sizeof( expected[0] ) ) ||
        memcmp( expected_levels, actual_levels, e * sizeof( expected_levels[0] ) ) )
      goto done;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  libspectrum_tape_clear( dest );
  if( libspectrum_tape_read( dest, cancelled_edge, sizeof( cancelled_edge ),
                            LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
      !collect_runs( dest, actual, actual_levels, &a ) ||
      a != 2 || actual[0] != 300 || actual[1] != 50 ||
      actual_levels[0] != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
      actual_levels[1] != LIBSPECTRUM_TAPE_SIGNAL_HIGH ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_csw_initial_levels( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  libspectrum_tape_edge edge;
  size_t length = 0, count, i;
  int initial, following, pause, metadata;
  test_return_t result = TEST_FAIL;
  for( initial = 0; initial < 3; initial++ )
  for( count = 1; count <= 3; count++ )
  for( following = 0; following < 3; following++ )
  for( pause = 0; pause < 2; pause++ )
  for( metadata = 0; metadata < 2; metadata++ ) {
    libspectrum_tape_block *b;
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, count );
    int level = initial == 2 ? 0 : initial;
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    if( initial != 2 ) {
      b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
      libspectrum_tape_block_set_level( b, initial );
      libspectrum_tape_append_block( tape, b );
    }
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_TZX_CSW );
    for( i = 0; i < count; i++ ) data[i] = 101 + i;
    libspectrum_tape_block_set_data( b, data );
    libspectrum_tape_block_set_data_length( b, count );
    libspectrum_tape_block_set_sample_rate( b, 3500000 );
    libspectrum_tape_block_set_csw_pulses( b, count );
    libspectrum_set_pause_tstates( b, pause ? 3500 : 0 );
    libspectrum_tape_append_block( tape, b );
    if( metadata ) {
      char *text = libspectrum_new( char, sizeof( "CSW boundary" ) );
      strcpy( text, "CSW boundary" );
      b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
      libspectrum_tape_block_set_text( b, text );
      libspectrum_tape_append_block( tape, b );
    }
    if( following == 1 ) {
      b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
      libspectrum_tape_block_set_count( b, 2 );
      libspectrum_tape_block_set_pulse_length( b, 1000 );
      libspectrum_tape_append_block( tape, b );
    } else if( following == 2 ) {
      b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_ROM );
      data = libspectrum_new( libspectrum_byte, 1 ); data[0] = 0xff;
      libspectrum_tape_block_set_data( b, data );
      libspectrum_tape_block_set_data_length( b, 1 );
      libspectrum_tape_append_block( tape, b );
    }
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    if( initial != 2 && libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    for( i = 0; i < count; i++ ) {
      if( libspectrum_tape_get_next_edge( &edge, tape ) ||
          edge.tstates != 101 + i ||
          (int)edge.level != ( level ^ (int)( i & 1 ) ) ||
          ( !i && edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) ) goto done;
      if( libspectrum_tape_get_next_edge( &edge, dest ) ||
          edge.tstates != 101 + i ||
          (int)edge.level != ( level ^ (int)( i & 1 ) ) )
        goto done;
    }
    /* A zero pause adds no sample; a nonzero pause still finishes low. */
    if( libspectrum_tape_get_next_edge( &edge, tape ) ||
        edge.tstates != ( pause ? 3500U : 0 ) ||
        ( pause && edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) ||
        !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_BLOCK ) ) goto done;
    if( pause && ( libspectrum_tape_get_next_edge( &edge, dest ) ||
        edge.tstates != 3500 || edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) )
      goto done;
    if( metadata && ( libspectrum_tape_get_next_edge( &edge, tape ) ||
                      edge.tstates ) ) goto done;
    if( following ) {
      /* Preserve the existing nonzero-pause reset of the next block. */
      int next_level = pause ? 0 : level ^ ( count & 1 );
      libspectrum_dword duration = following == 1 ? 1000 : 2168;
      if( libspectrum_tape_get_next_edge( &edge, tape ) ||
          edge.tstates != duration || (int)edge.level != next_level ) {
        fprintf( stderr, "%s: source follower %u/%d expected %u/%d\n",
                 progname, edge.tstates, edge.level, duration, next_level );
        goto done;
      }
      for( i = 0; i < 10; i++ ) {
        if( libspectrum_tape_get_next_edge( &edge, dest ) ) goto done;
        if( edge.tstates ) break;
      }
      if( i == 10 || edge.tstates != duration || (int)edge.level != next_level ) {
        fprintf( stderr, "%s: PZX follower %u/%d expected %u/%d\n",
                 progname, edge.tstates, edge.level, duration, next_level );
        goto done;
      }
    }
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: CSW initial=%d count=%lu following=%d pause=%d metadata=%d failed\n",
             progname, initial, (unsigned long)count, following, pause, metadata );
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_recordings( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  libspectrum_dword expected[64], actual[64];
  int expected_levels[64], actual_levels[64];
  size_t length = 0, n, a, e;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 32; n++ ) {
    libspectrum_tape_block *b;
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, 7 );
    size_t size = n & 8 ? 7 : n & 16 ? 0 : 1;
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( b, n & 1 );
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( n & 2 ?
      LIBSPECTRUM_TAPE_BLOCK_TZX_CSW : LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
    data[0] = 13; data[1] = 0; data[2] = 0x34; data[3] = 0x12;
    data[4] = 0; data[5] = 0; data[6] = 19;
    libspectrum_tape_block_set_data( b, data );
    libspectrum_tape_block_set_data_length( b, size );
    libspectrum_tape_block_set_sample_rate( b, n & 4 ? 44100 : 0 );
    libspectrum_tape_block_set_scale( b, 79 );
    if( n & 2 ) {
      libspectrum_tape_block_set_csw_pulses( b, size == 7 ? 3 : size );
      libspectrum_set_pause_tstates( b, n & 1 ? 70000 : 0 );
    }
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_count( b, 2 );
    libspectrum_tape_block_set_pulse_length( b, 100 );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    /* Empty standalone RLE cannot be played by the source edge API. */
    if( !size && !( n & 2 ) ) {
      libspectrum_free( out ); out = NULL; length = 0;
      continue;
    }
    if( !collect_runs( tape, expected, expected_levels, &e ) ||
        !collect_runs( dest, actual, actual_levels, &a ) || a != e ||
        memcmp( expected, actual, e * sizeof( expected[0] ) ) ||
        memcmp( expected_levels, actual_levels, e * sizeof( expected_levels[0] ) ) )
      goto done;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_raw_recordings( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  libspectrum_dword expected[64], actual[64];
  int expected_levels[64], actual_levels[64];
  size_t length = 0, n, a, e;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 16; n++ ) {
    libspectrum_tape_block *b;
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, 2 );
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    data[0] = n & 1 ? 0xff : 0x00;
    data[1] = n & 2 ? 0xa5 : 0x5a;
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
    libspectrum_tape_block_set_data( b, data );
    libspectrum_tape_block_set_data_length( b, 2 );
    libspectrum_tape_block_set_bit_length( b, n & 4 ? 65535 : 79 );
    libspectrum_tape_block_set_bits_in_last_byte( b, n & 8 ? 3 : 0 );
    libspectrum_set_pause_tstates( b, n & 1 ? 70000 : 0 );
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_count( b, 2 );
    libspectrum_tape_block_set_pulse_length( b, 100 );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        !collect_runs( tape, expected, expected_levels, &e ) ||
        !collect_runs( dest, actual, actual_levels, &a ) || a != e ||
        memcmp( expected, actual, e * sizeof( expected[0] ) ) ||
        memcmp( expected_levels, actual_levels, e * sizeof( expected_levels[0] ) ) )
      goto done;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_legacy_pulses( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_byte *out = NULL;
  libspectrum_tape_edge expected, actual;
  size_t length = 0, n, i;
  test_return_t result = TEST_FAIL;
  for( n = 0; n < 4; n++ ) {
    libspectrum_dword *lengths = libspectrum_new( libspectrum_dword, 3 );
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    libspectrum_tape_block_set_level( b, n & 1 );
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
    libspectrum_tape_block_set_count( b, 1 + n );
    libspectrum_tape_block_set_pulse_length( b, 70000 );
    libspectrum_tape_append_block( tape, b );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSES );
    lengths[0] = 100; lengths[1] = 0x8000; lengths[2] = 0x10000;
    libspectrum_tape_block_set_count( b, 3 );
    libspectrum_tape_block_set_pulse_lengths( b, lengths );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_nth_block( tape, 0 ) ||
        libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    /* The signal-level instruction has no corresponding PZX block. */
    if( libspectrum_tape_get_next_edge( &expected, tape ) ) goto done;
    for( i = 0; i < n + 4; i++ ) {
      if( libspectrum_tape_get_next_edge( &expected, tape ) ||
          libspectrum_tape_get_next_edge( &actual, dest ) ||
          actual.tstates != expected.tstates || actual.level != expected.level )
        goto done;
    }
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_archive_mapping( void )
{
  static const char * const names[] = { "Publisher", "Author", "Year",
    "Language", "Type", "Price", "Protection", "Origin", "Comment" };
  static const int ids[] = { 1, 2, 3, 4, 5, 6, 7, 8, 0xff };
  size_t i;
  for( i = 0; i < sizeof( ids ) / sizeof( ids[0] ); i++ ) {
    const char *name = internal_pzx_archive_name( ids[i] );
    if( !name || strcmp( name, names[i] ) ||
        internal_pzx_archive_id( names[i] ) != ids[i] ) return TEST_FAIL;
  }
  if( internal_pzx_archive_id( "author" ) != -1 ||
      internal_pzx_archive_id( "Unknown" ) != -1 ||
      internal_pzx_archive_id( "" ) != -1 ||
      internal_pzx_archive_name( 0 ) || internal_pzx_archive_name( 9 ) ||
      internal_pzx_archive_name( -1 ) ) return TEST_FAIL;
  return TEST_PASS;
}

static libspectrum_tape_block *
pulses_block( libspectrum_dword duration, size_t repeats )
{
  libspectrum_tape_block *b = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_dword *p = libspectrum_new( libspectrum_dword, 1 );
  size_t *r = libspectrum_new( size_t, 1 );
  p[0] = duration; r[0] = repeats;
  libspectrum_tape_block_set_count( b, 1 );
  libspectrum_tape_block_set_pulse_lengths( b, p );
  libspectrum_tape_block_set_pulse_repeats( b, r );
  return b;
}

static libspectrum_tape_block *
data_block( int native )
{
  libspectrum_tape_block *b = libspectrum_tape_block_alloc( native ?
    LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK : LIBSPECTRUM_TAPE_BLOCK_TURBO );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
  data[0] = 0xa0;
  libspectrum_tape_block_set_data_length( b, 1 );
  libspectrum_tape_block_set_data( b, data );
  libspectrum_tape_block_set_bits_in_last_byte( b, 3 );
  if( native ) {
    libspectrum_word *p0 = libspectrum_new( libspectrum_word, 1 );
    libspectrum_word *p1 = libspectrum_new( libspectrum_word, 1 );
    p0[0] = 100; p1[0] = 200;
    libspectrum_tape_block_set_count( b, 3 );
    libspectrum_tape_block_set_level( b, 1 );
    libspectrum_tape_block_set_tail_length( b, 10 );
    libspectrum_tape_block_set_bit0_pulse_count( b, 1 );
    libspectrum_tape_block_set_bit1_pulse_count( b, 1 );
    libspectrum_tape_block_set_bit0_pulses( b, p0 );
    libspectrum_tape_block_set_bit1_pulses( b, p1 );
  } else {
    libspectrum_tape_block_set_pilot_length( b, 800 );
    libspectrum_tape_block_set_pilot_pulses( b, 2 );
    libspectrum_tape_block_set_sync1_length( b, 100 );
    libspectrum_tape_block_set_sync2_length( b, 150 );
    libspectrum_tape_block_set_bit0_length( b, 200 );
    libspectrum_tape_block_set_bit1_length( b, 400 );
    libspectrum_set_pause_tstates( b, 70000 );
  }
  return b;
}

static libspectrum_tape_block *
archive_block( const int *ids, const char * const *texts, size_t count )
{
  libspectrum_tape_block *b = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO );
  int *copy_ids = libspectrum_new( int, count );
  char **copy_texts = libspectrum_new( char *, count );
  size_t i;
  for( i = 0; i < count; i++ ) {
    copy_ids[i] = ids[i];
    copy_texts[i] = libspectrum_new( char, strlen( texts[i] ) + 1 );
    strcpy( copy_texts[i], texts[i] );
  }
  libspectrum_tape_block_set_count( b, count );
  libspectrum_tape_block_set_ids( b, copy_ids );
  libspectrum_tape_block_set_texts( b, copy_texts );
  return b;
}

/* Every rejection must preserve allocated output, its size, and playback. */
static int
rejected_format( libspectrum_tape *tape, libspectrum_error expected,
                 libspectrum_id_t format )
{
  libspectrum_byte *out = libspectrum_new( libspectrum_byte, 4 ), *original = out;
  size_t length = 4;
  int position_before, position_after, ok;
  libspectrum_tape_signal_level before, after;
  memcpy( out, "keep", 4 );
  libspectrum_tape_position( &position_before, tape );
  libspectrum_tape_signal_level_get( &before, tape );
  ok = libspectrum_tape_write( &out, &length, tape, format ) == expected && out == original && length == 4 && !memcmp( out, "keep", 4 );
  libspectrum_tape_position( &position_after, tape );
  libspectrum_tape_signal_level_get( &after, tape );
  ok = ok && position_before == position_after && before == after;
  libspectrum_free( out );
  return ok;
}

static int
rejected( libspectrum_tape *tape, libspectrum_error expected )
{
  return rejected_format( tape, expected, LIBSPECTRUM_ID_TAPE_PZX );
}

test_return_t
tape_text_encodings( void )
{
  static const libspectrum_byte tzx[] = {
    'Z', 'X', 'T', 'a', 'p', 'e', '!', 0x1a, 1, 20,
    0x32, 7, 0, 2, 0, 1, 0xe9, 2, 1, 0x80,
    0x30, 1, 0x93
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_tape_iterator it;
  libspectrum_byte *out = NULL;
  char *converted = NULL;
  size_t length = 0, n, archives, comments;
  test_return_t result = TEST_FAIL;
  if( internal_tape_text_convert( "\xe9\x80\x93", 1, &converted ) ||
      strcmp( converted, "\xc3\xa9\xe2\x82\xac\xe2\x80\x9c" ) ) goto done;
  libspectrum_free( converted ); converted = NULL;
  if( internal_tape_text_convert( "A\xc3", 2, &converted ) ||
      strcmp( converted, "A?" ) ) goto done;
  libspectrum_free( converted ); converted = NULL;
  /* Unsupported scalars must not prevent export; exact transliteration varies. */
  if( internal_tape_text_convert( "a\xc4\x81\xf0\x9f\x98\x80z", 0, &converted ) ||
      !*converted || converted[0] != 'a' ||
      converted[strlen( converted ) - 1] != 'z' ) goto done;
  libspectrum_free( converted ); converted = NULL;
  if( libspectrum_tape_read( tape, tzx, sizeof( tzx ),
                            LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( n = 0; n < 6; n++ ) {
    libspectrum_id_t format = n & 1 ? LIBSPECTRUM_ID_TAPE_TZX : LIBSPECTRUM_ID_TAPE_PZX;
    archives = comments = 0;
    for( b = libspectrum_tape_iterator_init( &it, tape ); b;
         b = libspectrum_tape_iterator_next( &it ) ) {
      if( libspectrum_tape_block_type( b ) == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ) {
        if( libspectrum_tape_block_count( b ) != 2 ||
            strcmp( libspectrum_tape_block_texts( b, 0 ), "\xc3\xa9" ) ||
            strcmp( libspectrum_tape_block_texts( b, 1 ), "\xe2\x82\xac" ) ) goto done;
        archives++;
      } else if( libspectrum_tape_block_type( b ) == LIBSPECTRUM_TAPE_BLOCK_COMMENT ) {
        if( strcmp( libspectrum_tape_block_text( b ), "\xe2\x80\x9c" ) ) goto done;
        comments++;
      }
    }
    if( archives != 1 || comments != 1 ||
        libspectrum_tape_write( &out, &length, tape, format ) ||
        libspectrum_tape_read( dest, out, length, format, NULL ) ) goto done;
    libspectrum_tape_free( tape ); tape = dest; dest = libspectrum_tape_alloc();
    libspectrum_free( out ); out = NULL; length = 0;
  }
  /* TZX byte limits apply after UTF-8-to-CP1252 conversion. */
  libspectrum_tape_clear( tape );
  {
    char *text = libspectrum_new( char, 513 );
    for( n = 0; n < 256; n++ ) { text[2*n] = '\xc3'; text[2*n+1] = '\xa9'; }
    text[400] = 0;
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
    libspectrum_tape_block_set_text( b, text );
    libspectrum_tape_append_block( tape, b );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
        strlen( text ) != 400 || length != 212 || out[11] != 200 ) goto done;
    text[400] = '\xc3'; text[512] = 0;
    if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) )
      goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( converted ); libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_groups_invalid( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 4; i++ ) {
    libspectrum_tape_clear( tape );
    if( i != 0 ) libspectrum_tape_append_block( tape, group_block( "Group" ) );
    if( i == 2 ) libspectrum_tape_append_block( tape, group_block( "Nested" ) );
    if( i != 1 ) libspectrum_tape_append_block( tape,
      libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END ) );
    if( i == 3 ) libspectrum_tape_append_block( tape,
      libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END ) );
    if( !rejected( tape, LIBSPECTRUM_ERROR_INVALID ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_generalised_invalid( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 7; i++ ) {
    libspectrum_tape_block *b = generalised_block( 3, i < 2, 0 );
    libspectrum_tape_generalised_data_block *g = &b->types.generalised_data;
    libspectrum_tape_clear( tape );
    switch( i ) {
    case 0: g->pilot_symbols[0] = 3; break;
    case 1: g->pilot_repeats[0] = 0; break;
    case 2: g->data[0] = 0xff; break;
    case 3: g->bits_per_data_symbol = 1; break;
    case 4: g->data_table.max_pulses = 0; break;
    case 5: g->data_table.symbols[0].edge_type = 4; break;
    case 6: libspectrum_set_pause_tstates( b, 0x80000000U ); break;
    }
    libspectrum_tape_append_block( tape, b );
    if( !rejected( tape, LIBSPECTRUM_ERROR_INVALID ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_recordings_invalid( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 6; i++ ) {
    libspectrum_tape_block *b = libspectrum_tape_block_alloc( i >= 4 ?
      LIBSPECTRUM_TAPE_BLOCK_TZX_CSW : LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, 5 );
    memset( data, 0, 5 );
    if( i >= 2 ) data[0] = 2;
    libspectrum_tape_clear( tape );
    libspectrum_tape_block_set_data( b, data );
    libspectrum_tape_block_set_data_length( b, i == 0 ? 4 : i == 1 ? 5 : 1 );
    libspectrum_tape_block_set_scale( b, i == 2 ? 0 : i == 3 ? UINT32_MAX : 79 );
    if( i >= 4 ) {
      libspectrum_tape_block_set_csw_pulses( b, i == 4 ? 2 : 1 );
      libspectrum_set_pause_tstates( b, i == 5 ? 0x80000000U : 0 );
    }
    libspectrum_tape_append_block( tape, b );
    if( !rejected( tape, i < 2 || i == 4 ? LIBSPECTRUM_ERROR_CORRUPT :
                   LIBSPECTRUM_ERROR_INVALID ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_raw_invalid( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 5; i++ ) {
    libspectrum_tape_block *b = libspectrum_tape_block_alloc(
      LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
    libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
    data[0] = 0xa0;
    libspectrum_tape_clear( tape );
    libspectrum_tape_block_set_data( b, data );
    libspectrum_tape_block_set_data_length( b, i == 0 ? 0 : 1 );
    libspectrum_tape_block_set_bit_length( b, i == 1 ? 0 : i == 2 ? 65536 : 79 );
    libspectrum_tape_block_set_bits_in_last_byte( b, i == 3 ? 9 : 8 );
    libspectrum_set_pause_tstates( b, i == 4 ? 0x80000000U : 0 );
    libspectrum_tape_append_block( tape, b );
    if( !rejected( tape, LIBSPECTRUM_ERROR_INVALID ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_legacy_pulses_invalid( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 6; i++ ) {
    libspectrum_tape_clear( tape );
    b = libspectrum_tape_block_alloc( i < 2 ?
      LIBSPECTRUM_TAPE_BLOCK_PURE_TONE : i < 4 ?
      LIBSPECTRUM_TAPE_BLOCK_PULSES :
      LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
    if( i < 2 ) {
      libspectrum_tape_block_set_count( b, i );
      libspectrum_tape_block_set_pulse_length( b, i ? 0x80000000U : 100 );
    } else if( i < 4 ) {
      libspectrum_dword *p = libspectrum_new( libspectrum_dword, 1 );
      p[0] = 0x80000000U;
      libspectrum_tape_block_set_count( b, i - 2 );
      libspectrum_tape_block_set_pulse_lengths( b, p );
    } else {
      libspectrum_tape_block_set_level( b, i == 4 ? -1 : 2 );
    }
    libspectrum_tape_append_block( tape, b );
    if( !rejected( tape, LIBSPECTRUM_ERROR_INVALID ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_empty_zero_and_buffers( void )
{
  static const libspectrum_byte header[] = "PZXT\x02\0\0\0\x01\0";
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_byte *out = NULL;
  size_t length = 0, n;
  test_return_t result = TEST_FAIL;
  libspectrum_tape_edge edge;
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
      length != 10 || memcmp( out, header, 10 ) ) goto done;
  libspectrum_free( out );
  out = libspectrum_new( libspectrum_byte, 32 ); length = 32;
  memset( out, 0x5a, length );
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
      length != 32 || memcmp( out, header, 10 ) || out[10] != 0x5a ) goto done;
  libspectrum_free( out );
  out = libspectrum_new( libspectrum_byte, 1 ); length = 1;
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
      length != 10 || memcmp( out, header, 10 ) ) goto done;
  for( n = 1; n <= 4; n++ ) {
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    libspectrum_tape_append_block( tape, pulses_block( 0, n ) );
    /* Following block inherits the all-zero block's final level. */
    libspectrum_tape_append_block( tape, data_block( 0 ) );
    libspectrum_free( out ); out = NULL; length = 0;
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates != 0 ||
        edge.level != ( n & 1 ? LIBSPECTRUM_TAPE_SIGNAL_LOW :
                               LIBSPECTRUM_TAPE_SIGNAL_HIGH ) ||
        libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates != 800 ||
        edge.level != ( n & 1 ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                               LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
  }
  /* Zero-bit DATA remains valid, including a tail-only block. */
  for( n = 0; n <= 1; n++ ) {
    libspectrum_tape_block *b = data_block( 1 );
    libspectrum_tape_block_set_count( b, 0 );
    libspectrum_tape_block_set_data_length( b, 0 );
    libspectrum_tape_block_set_tail_length( b, n ? 65535 : 0 );
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    libspectrum_tape_append_block( tape, b );
    libspectrum_free( out ); out = NULL; length = 0;
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        length != 30 ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    b = libspectrum_tape_current_block( dest );
    if( libspectrum_tape_block_count( b ) != 0 ||
        libspectrum_tape_block_data_length( b ) != 0 ||
        libspectrum_tape_block_tail_length( b ) != ( n ? 65535 : 0 ) ) goto done;
  }
  /* PAUS can represent its maximum 31-bit duration at either level. */
  for( n = 0; n <= 1; n++ ) {
    libspectrum_tape_block *b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_set_pause_tstates( b, 0x7fffffff );
    libspectrum_tape_block_set_level( b, n );
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    libspectrum_tape_append_block( tape, b );
    libspectrum_free( out ); out = NULL; length = 0;
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        length != 22 || out[18] != 0xff || out[19] != 0xff ||
        out[20] != 0xff || out[21] != ( n ? 0xff : 0x7f ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    b = libspectrum_tape_current_block( dest );
    if( libspectrum_tape_block_level( b ) != (int)n ||
        libspectrum_tape_block_pause_tstates( b ) != 0x7fffffff ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_unspecified_pauses_and_advanced_position( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_tape_cursor *probe = NULL;
  libspectrum_tape_edge expected, actual;
  libspectrum_byte *out = NULL;
  size_t length = 0, n, i;
  test_return_t result = TEST_FAIL;
  for( n = 1; n <= 2; n++ ) {
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    libspectrum_tape_append_block( tape, pulses_block( 100, n ) );
    b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_set_pause_tstates( b, 70000 );
    libspectrum_tape_block_set_level( b, -1 );
    libspectrum_tape_append_block( tape, b );
    libspectrum_tape_append_block( tape, data_block( 0 ) );
    libspectrum_tape_nth_block( tape, 0 );
    /* Advance into the turbo block, then verify several subsequent events. */
    for( i = 0; i < n + 3; i++ )
      if( libspectrum_tape_get_next_edge( &actual, tape ) ) goto done;
    probe = libspectrum_tape_cursor_capture( tape );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
      goto done;
    for( i = 0; i < 5; i++ ) {
      if( libspectrum_tape_cursor_get_next_edge( &expected, probe ) ||
          libspectrum_tape_get_next_edge( &actual, tape ) ||
          actual.tstates != expected.tstates || actual.level != expected.level ||
          actual.flags != expected.flags || actual.transition != expected.transition )
        goto done;
    }
    if( libspectrum_tape_nth_block( dest, 1 ) ) goto done;
    b = libspectrum_tape_current_block( dest );
    if( !b || libspectrum_tape_block_type( b ) != LIBSPECTRUM_TAPE_BLOCK_PAUSE ||
        libspectrum_tape_block_level( b ) != ( n & 1 ? 1 : 0 ) ||
        libspectrum_tape_block_pause_tstates( b ) != 70000 ) goto done;
    libspectrum_tape_cursor_free( probe ); probe = NULL;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  result = TEST_PASS;
done:
  if( probe ) libspectrum_tape_cursor_free( probe );
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_validation_matrix( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 22; i++ ) {
    libspectrum_tape_clear( tape );
    b = i < 6 ? data_block( 1 ) : i < 9 ? pulses_block( 100, 1 ) :
      i < 13 ? libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE ) :
      data_block( 0 );
    switch( i ) {
    case 0: libspectrum_tape_block_set_level( b, -1 ); break;
    case 1: libspectrum_tape_block_set_level( b, 2 ); break;
    case 2: libspectrum_tape_block_set_count( b, 0x80000000U ); break;
    case 3: libspectrum_tape_block_set_count( b, 9 ); break;
    case 4: libspectrum_tape_block_set_tail_length( b, 65536 ); break;
    case 5: libspectrum_tape_block_set_data_length( b, 0 ); break;
    case 6: libspectrum_tape_block_set_count( b, 0 ); break;
    case 7:
      libspectrum_tape_block_free( b ); b = pulses_block( 100, 0 ); break;
    case 8:
      libspectrum_tape_block_free( b ); b = pulses_block( 0x80000000U, 1 ); break;
    case 9: libspectrum_set_pause_tstates( b, 0x80000000U ); break;
    case 10: libspectrum_tape_block_set_level( b, -2 ); break;
    case 11: libspectrum_tape_block_set_level( b, 2 ); break;
    case 12: libspectrum_tape_block_set_level( b, 3 ); break;
    case 13: libspectrum_tape_block_set_pilot_length( b, 0x80000000U ); break;
    case 14: libspectrum_tape_block_set_sync1_length( b, 0x80000000U ); break;
    case 15: libspectrum_tape_block_set_sync2_length( b, 0x80000000U ); break;
    case 16: libspectrum_tape_block_set_bit0_length( b, 65536 ); break;
    case 17: libspectrum_tape_block_set_bit1_length( b, 65536 ); break;
    case 18: libspectrum_tape_block_set_bits_in_last_byte( b, 9 ); break;
    case 19: libspectrum_tape_block_set_data_length( b, 0 ); break;
    case 20: libspectrum_set_pause_tstates( b, 0x80000000U ); break;
    case 21: libspectrum_tape_block_set_data_length( b, (size_t)0x10000000U ); break;
    }
    libspectrum_tape_append_block( tape, b );
    if( !rejected( tape, LIBSPECTRUM_ERROR_INVALID ) ) {
      fprintf( stderr, "%s: PZX validation case %lu failed\n", progname, (unsigned long)i );
      goto done;
    }
    if( i < 13 ) {
      /* An explicit-level pause is PZX-style; unspecified pauses are legacy. */
      if( i == 9 ) libspectrum_tape_block_set_level( b, 0 );
      if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) ) {
        fprintf( stderr, "%s: TZX GDB validation case %lu failed\n", progname, (unsigned long)i );
        goto done;
      }
      if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_CSW ) ) {
        fprintf( stderr, "%s: CSW validation case %lu failed\n", progname, (unsigned long)i );
        goto done;
      }
    }
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_metadata_variations( void )
{
  static const int ids[] = { 2, 2, 0xff, 0xff };
  static const char * const texts[] = { "Alice", "Bob", "One", "Two" };
  static const int title_ids[] = { 2, 0, 3 };
  static const char * const title_texts[] = { "Author", "Later", "1984" };
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_tape_iterator it;
  libspectrum_byte *out = NULL;
  size_t length = 0, i;
  test_return_t result = TEST_FAIL;
  libspectrum_tape_append_block( tape, archive_block( ids, texts, 4 ) );
  libspectrum_tape_append_block( tape, pulses_block( 100, 1 ) );
  libspectrum_tape_append_block( tape, archive_block( title_ids, title_texts, 3 ) );
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_PZX ) ||
      libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
  b = libspectrum_tape_iterator_init( &it, dest );
  if( !b || libspectrum_tape_block_count( b ) != 5 ||
      libspectrum_tape_block_ids( b, 0 ) != 0 ||
      strcmp( libspectrum_tape_block_texts( b, 0 ), "" ) ) goto done;
  for( i = 0; i < 4; i++ )
    if( libspectrum_tape_block_ids( b, i + 1 ) != ids[i] ||
        strcmp( libspectrum_tape_block_texts( b, i + 1 ), texts[i] ) ) goto done;
  b = libspectrum_tape_iterator_next( &it );
  if( !b || libspectrum_tape_block_type( b ) != LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE )
    goto done;
  b = libspectrum_tape_iterator_next( &it );
  if( !b || libspectrum_tape_block_count( b ) != 3 ||
      libspectrum_tape_block_ids( b, 0 ) != 0 ||
      strcmp( libspectrum_tape_block_texts( b, 0 ), "Later" ) ||
      libspectrum_tape_block_ids( b, 1 ) != 2 ||
      strcmp( libspectrum_tape_block_texts( b, 1 ), "Author" ) ||
      libspectrum_tape_block_ids( b, 2 ) != 3 ||
      strcmp( libspectrum_tape_block_texts( b, 2 ), "1984" ) ||
      libspectrum_tape_iterator_next( &it ) ) goto done;
  for( i = 0; i < 4; i++ ) {
    const int bad_ids[] = { 0, 0 };
    const int unknown[] = { 9, 0xfe, -1 };
    libspectrum_tape_clear( tape );
    libspectrum_tape_append_block( tape, archive_block( i ? &unknown[i - 1] : bad_ids,
                                                       texts, i ? 1 : 2 ) );
    if( !rejected( tape, LIBSPECTRUM_ERROR_UNKNOWN ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( out ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
tzx_pzx_metadata_limits( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  char text[257];
  const char *texts[256];
  int ids[256];
  size_t i;
  test_return_t result = TEST_FAIL;
  memset( text, 'A', 256 ); text[256] = 0;
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
  char *copy = libspectrum_new( char, sizeof( text ) );
  memcpy( copy, text, sizeof( text ) );
  libspectrum_tape_block_set_text( block, copy );
  libspectrum_tape_append_block( tape, block );
  if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) )
    goto done;
  libspectrum_tape_clear( tape );
  for( i = 0; i < 256; i++ ) { ids[i] = 0xff; texts[i] = text; }
  libspectrum_tape_append_block( tape, archive_block( ids, texts, 1 ) );
  if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) )
    goto done;
  libspectrum_tape_clear( tape );
  text[255] = 0;
  libspectrum_tape_append_block( tape, archive_block( ids, texts, 255 ) );
  /* Each string fits, but the total archive body is 65536 bytes. */
  if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) )
    goto done;
  libspectrum_tape_clear( tape ); text[0] = 0;
  libspectrum_tape_append_block( tape, archive_block( ids, texts, 256 ) );
  if( !rejected_format( tape, LIBSPECTRUM_ERROR_INVALID, LIBSPECTRUM_ID_TAPE_TZX ) )
    goto done;
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_write_mixed_zero_pulse_data_rejected( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  size_t which;
  test_return_t result = TEST_FAIL;
  for( which = 0; which < 2; which++ ) {
    libspectrum_tape_block *b = data_block( 1 );
    if( which ) libspectrum_tape_block_set_bit1_pulse_count( b, 0 );
    else libspectrum_tape_block_set_bit0_pulse_count( b, 0 );
    libspectrum_tape_append_block( tape, b );
    libspectrum_tape_append_block( tape, data_block( 0 ) );
    if( !rejected( tape, LIBSPECTRUM_ERROR_UNKNOWN ) ) goto done;
    libspectrum_tape_clear( tape );
  }
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}
