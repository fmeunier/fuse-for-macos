/* tzx_pzx.c: Exact GDB output for PZX-style waveform blocks
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
#include "pzx_internals.h"

/* Pilot symbols can express forced levels and continuation holds without
   Set Signal Level blocks. A two-pulse symbol compresses alternating repeats.
   Zero-time polarity changes use an empty symbol, not an inline terminator. */
typedef struct gdb_symbol {
  libspectrum_byte flags;
  libspectrum_word first, second;
} gdb_symbol;

typedef struct gdb_writer {
  libspectrum_buffer *out, *runs;
  gdb_symbol symbols[256];
  size_t symbol_count;
  libspectrum_dword run_count;
  int pending;
  size_t repeats;
} gdb_writer;

static void
flush_run( gdb_writer *writer )
{
  if( writer->pending < 0 ) return;
  libspectrum_buffer_write_byte( writer->runs, writer->pending );
  libspectrum_buffer_write_word( writer->runs, writer->repeats );
  writer->run_count++;
  writer->pending = -1;
  writer->repeats = 0;
}

static libspectrum_error
flush_gdb( gdb_writer *writer )
{
  size_t i, size;
  flush_run( writer );
  if( !writer->run_count ) return LIBSPECTRUM_ERROR_NONE;
  size = 14 + writer->symbol_count * 5 +
    libspectrum_buffer_get_data_size( writer->runs );
  if( size > UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
  libspectrum_buffer_write_byte( writer->out, LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA );
  libspectrum_buffer_write_dword( writer->out, size );
  libspectrum_buffer_write_word( writer->out, 0 ); /* No implicit pause. */
  libspectrum_buffer_write_dword( writer->out, writer->run_count );
  libspectrum_buffer_write_byte( writer->out, 2 );
  libspectrum_buffer_write_byte( writer->out, writer->symbol_count & 0xff );
  libspectrum_buffer_write_dword( writer->out, 0 ); /* No data alphabet. */
  libspectrum_buffer_write_byte( writer->out, 0 );
  libspectrum_buffer_write_byte( writer->out, 0 );
  for( i = 0; i < writer->symbol_count; i++ ) {
    libspectrum_buffer_write_byte( writer->out, writer->symbols[i].flags );
    libspectrum_buffer_write_word( writer->out, writer->symbols[i].first );
    libspectrum_buffer_write_word( writer->out, writer->symbols[i].second );
  }
  libspectrum_buffer_write_buffer( writer->out, writer->runs );
  libspectrum_buffer_clear( writer->runs );
  writer->symbol_count = 0;
  writer->run_count = 0;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
symbol_id( gdb_writer *writer, gdb_symbol symbol, int *id )
{
  size_t i;
  libspectrum_error error;
  for( i = 0; i < writer->symbol_count; i++ )
    if( writer->symbols[i].flags == symbol.flags &&
        writer->symbols[i].first == symbol.first &&
        writer->symbols[i].second == symbol.second ) {
      *id = i;
      return LIBSPECTRUM_ERROR_NONE;
    }
  if( writer->symbol_count == 256 ) {
    error = flush_gdb( writer );
    if( error ) return error;
  }
  *id = writer->symbol_count;
  writer->symbols[writer->symbol_count++] = symbol;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
emit_symbol( gdb_writer *writer, gdb_symbol symbol, size_t repeats )
{
  int id;
  libspectrum_error error = symbol_id( writer, symbol, &id );
  if( error ) return error;
  while( repeats ) {
    size_t n;
    if( writer->pending >= 0 &&
        ( writer->pending != id || writer->repeats == 65535 ) ) flush_run( writer );
    /* Bound the block before either its record count or length overflows. */
    if( writer->run_count >= ( UINT32_MAX - 1294 ) / 3 )
      return LIBSPECTRUM_ERROR_INVALID;
    writer->pending = id;
    n = 65535 - writer->repeats;
    if( n > repeats ) n = repeats;
    writer->repeats += n;
    repeats -= n;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
emit_hold( gdb_writer *writer, libspectrum_dword duration, int level )
{
  gdb_symbol symbol = { level ? LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_HIGH :
                               LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_LOW, 0, 0 };
  libspectrum_error error;
  symbol.first = duration > 65535 ? 65535 : duration;
  error = emit_symbol( writer, symbol, 1 );
  if( error ) return error;
  duration -= symbol.first;
  symbol.flags = LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_NO_EDGE;
  symbol.first = 65535;
  if( duration >= 65535 ) {
    error = emit_symbol( writer, symbol, duration / 65535 );
    if( error ) return error;
    duration %= 65535;
  }
  if( duration ) {
    symbol.first = duration;
    return emit_symbol( writer, symbol, 1 );
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
emit_repeated_pulse( gdb_writer *writer, libspectrum_dword duration,
                     size_t repeats, int *level )
{
  libspectrum_error error;
  gdb_symbol pair = { *level ? LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_HIGH :
                              LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_LOW, 0, 0 };
  if( !repeats || duration > PZX_VALUE_MASK ) return LIBSPECTRUM_ERROR_INVALID;
  if( !duration ) {
    error = emit_hold( writer, 0, *level ^ ( ( repeats - 1 ) & 1 ) );
    *level ^= repeats & 1;
    return error;
  }
  if( duration <= 65535 && repeats >= 2 ) {
    pair.first = pair.second = duration;
    error = emit_symbol( writer, pair, repeats / 2 );
    if( error ) return error;
    repeats &= 1;
  }
  while( repeats-- ) {
    error = emit_hold( writer, duration, *level );
    if( error ) return error;
    *level = !*level;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_pulses( gdb_writer *writer, libspectrum_tape_block *block )
{
  size_t i, count = libspectrum_tape_block_count( block );
  int level = 0;
  libspectrum_error error;
  if( !count ) return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < count; i++ ) {
    error = emit_repeated_pulse( writer,
      libspectrum_tape_block_pulse_lengths( block, i ),
      libspectrum_tape_block_pulse_repeats( block, i ), &level );
    if( error ) return error;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static size_t
compact_data_pulses( libspectrum_tape_block *block )
{
  size_t i, p0 = libspectrum_tape_block_bit0_pulse_count( block );
  size_t p1 = libspectrum_tape_block_bit1_pulse_count( block );
  if( !p0 || !p1 ) return 0;
  for( i = 0; i < p0; i++ )
    if( !libspectrum_tape_block_bit0_pulses( block, i ) ) return 0;
  for( i = 0; i < p1; i++ )
    if( !libspectrum_tape_block_bit1_pulses( block, i ) ) return 0;
  return p0 > p1 ? p0 : p1;
}

static void
write_data_alphabet( libspectrum_buffer *out, libspectrum_tape_block *block,
                     size_t max_pulses )
{
  size_t symbol, i;
  for( symbol = 0; symbol < 4; symbol++ ) {
    int one = symbol & 1;
    size_t count = one ? libspectrum_tape_block_bit1_pulse_count( block ) :
                        libspectrum_tape_block_bit0_pulse_count( block );
    libspectrum_buffer_write_byte( out, symbol & 2 ?
      LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_HIGH :
      LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_LOW );
    for( i = 0; i < max_pulses; i++ ) {
      libspectrum_word duration = 0;
      if( i < count ) duration = one ? libspectrum_tape_block_bit1_pulses( block, i ) :
                                      libspectrum_tape_block_bit0_pulses( block, i );
      libspectrum_buffer_write_word( out, duration );
    }
  }
}

static int
write_data_symbols( libspectrum_buffer *out, libspectrum_tape_block *block )
{
  size_t bit, bits = libspectrum_tape_block_count( block );
  libspectrum_byte *data = libspectrum_tape_block_data( block ), packed = 0;
  int level = libspectrum_tape_block_level( block );
  for( bit = 0; bit < bits; bit++ ) {
    int one = !!( data[bit / 8] & ( 0x80 >> ( bit % 8 ) ) );
    size_t count = one ? libspectrum_tape_block_bit1_pulse_count( block ) :
                        libspectrum_tape_block_bit0_pulse_count( block );
    packed |= ( ( level << 1 ) | one ) << ( 6 - 2 * ( bit % 4 ) );
    level ^= count & 1;
    if( bit % 4 == 3 ) { libspectrum_buffer_write_byte( out, packed ); packed = 0; }
  }
  if( bits % 4 ) libspectrum_buffer_write_byte( out, packed );
  return level;
}

static libspectrum_error
write_compact_data( gdb_writer *writer, libspectrum_tape_block *block,
                    size_t max_pulses )
{
  size_t bits = libspectrum_tape_block_count( block );
  libspectrum_qword size = 14 + 4 * ( 1 + 2 * max_pulses ) +
    ( (libspectrum_qword)bits * 2 + 7 ) / 8;
  int level;
  if( size > UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
  libspectrum_buffer_write_byte( writer->out, LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA );
  libspectrum_buffer_write_dword( writer->out, size );
  libspectrum_buffer_write_word( writer->out, 0 );
  libspectrum_buffer_write_dword( writer->out, 0 );
  libspectrum_buffer_write_byte( writer->out, 0 );
  libspectrum_buffer_write_byte( writer->out, 0 );
  libspectrum_buffer_write_dword( writer->out, bits );
  libspectrum_buffer_write_byte( writer->out, max_pulses );
  libspectrum_buffer_write_byte( writer->out, 4 );
  write_data_alphabet( writer->out, block, max_pulses );
  level = write_data_symbols( writer->out, block );
  if( libspectrum_tape_block_tail_length( block ) )
    return emit_hold( writer, libspectrum_tape_block_tail_length( block ), level );
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_data( gdb_writer *writer, libspectrum_tape_block *block )
{
  size_t bit, i, bits = libspectrum_tape_block_count( block );
  int level = libspectrum_tape_block_level( block );
  libspectrum_byte *data = libspectrum_tape_block_data( block );
  libspectrum_error error;
  if( level < 0 || level > 1 || bits > PZX_VALUE_MASK ||
      libspectrum_tape_block_data_length( block ) < ( bits + 7 ) / 8 ||
      ( bits && !data ) || libspectrum_tape_block_tail_length( block ) > 65535 )
    return LIBSPECTRUM_ERROR_INVALID;
  if( bits && compact_data_pulses( block ) )
    return write_compact_data( writer, block, compact_data_pulses( block ) );
  for( bit = 0; bit < bits; bit++ ) {
    int one = !!( data[bit / 8] & ( 0x80 >> ( bit % 8 ) ) );
    size_t count = one ? libspectrum_tape_block_bit1_pulse_count( block ) :
                        libspectrum_tape_block_bit0_pulse_count( block );
    for( i = 0; i < count; i++ ) {
      libspectrum_word duration = one ? libspectrum_tape_block_bit1_pulses( block, i ) :
                                       libspectrum_tape_block_bit0_pulses( block, i );
      error = emit_repeated_pulse( writer, duration, 1, &level );
      if( error ) return error;
    }
  }
  if( libspectrum_tape_block_tail_length( block ) )
    return emit_hold( writer, libspectrum_tape_block_tail_length( block ), level );
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_pause( gdb_writer *writer, libspectrum_tape_block *block )
{
  int level = libspectrum_tape_block_level( block );
  libspectrum_dword duration = libspectrum_tape_block_pause_tstates( block );
  if( level < 0 || level > 1 || duration > PZX_VALUE_MASK )
    return LIBSPECTRUM_ERROR_INVALID;
  /* Ordinary TZX pauses are low holds in whole milliseconds. */
  if( !duration ||
      ( !level && duration % 3500 == 0 && duration / 3500 <= 65535 ) ) {
    libspectrum_buffer_write_byte( writer->out, LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_buffer_write_word( writer->out, duration / 3500 );
    return LIBSPECTRUM_ERROR_NONE;
  }
  return emit_hold( writer, duration, level );
}

libspectrum_error
internal_tzx_write_pzx_block( libspectrum_buffer *out, libspectrum_tape_block *block )
{
  gdb_writer writer;
  libspectrum_error error;
  memset( &writer, 0, sizeof( writer ) );
  writer.out = out;
  writer.runs = libspectrum_buffer_alloc();
  writer.pending = -1;
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE: error = write_pulses( &writer, block ); break;
  case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK: error = write_data( &writer, block ); break;
  case LIBSPECTRUM_TAPE_BLOCK_PAUSE: error = write_pause( &writer, block ); break;
  default: error = LIBSPECTRUM_ERROR_LOGIC; break;
  }
  if( !error ) error = flush_gdb( &writer );
  libspectrum_buffer_free( writer.runs );
  return error;
}
