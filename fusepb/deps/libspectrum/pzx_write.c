/* pzx_write.c: Routines for writing PZX files
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
#include "pzx_write_internal.h"

static libspectrum_error
write_chunk( pzx_writer *writer, const char *tag )
{
  size_t size = libspectrum_buffer_get_data_size( writer->body );
  if( size > UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
  if( writer->bounded &&
      ( size > PZX_MAX_EXPANDED_SIZE - 8 ||
        libspectrum_buffer_get_data_size( writer->out ) >
          PZX_MAX_EXPANDED_SIZE - 8 - size ) )
    return LIBSPECTRUM_ERROR_INVALID;
  libspectrum_buffer_write( writer->out, (const libspectrum_byte *)tag, 4 );
  libspectrum_buffer_write_dword( writer->out, size );
  libspectrum_buffer_write_buffer( writer->out, writer->body );
  libspectrum_buffer_clear( writer->body );
  return LIBSPECTRUM_ERROR_NONE;
}

/* Durations above 65535 require a repeat prefix even for one pulse.
   0x8000 itself denotes extended duration, not a repeat count. */
libspectrum_error
internal_pzx_write_pulse( libspectrum_buffer *body, libspectrum_dword duration, size_t count )
{
  if( !count || duration > PZX_VALUE_MASK ) return LIBSPECTRUM_ERROR_INVALID;
  while( count ) {
    size_t n = count > PZX_REPEAT_MAX ? PZX_REPEAT_MAX : count;
    if( n != 1 || duration > 0xffff )
      libspectrum_buffer_write_word( body, PZX_DURATION_FLAG | n );
    if( duration < PZX_DURATION_FLAG ) {
      libspectrum_buffer_write_word( body, duration );
    } else {
      libspectrum_buffer_write_word( body, PZX_DURATION_FLAG | ( duration >> 16 ) );
      libspectrum_buffer_write_word( body, duration & 0xffff );
    }
    count -= n;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

/* Coalesce only within a block: new PULS blocks reset polarity. Keep zero
   pulses, including all-zero blocks whose final level can matter. */
static libspectrum_error
write_sequence( pzx_writer *writer, libspectrum_tape_block *block )
{
  size_t i, count = 0;
  libspectrum_dword duration = 0;
  libspectrum_error error;
  for( i = 0; i < libspectrum_tape_block_count( block ); i++ ) {
    libspectrum_dword next = libspectrum_tape_block_pulse_lengths( block, i );
    size_t repeats = libspectrum_tape_block_pulse_repeats( block, i );
    if( count && ( next != duration || repeats > SIZE_MAX - count ) ) {
      error = internal_pzx_write_pulse( writer->body, duration, count );
      if( error ) return error;
      count = 0;
    }
    duration = next;
    count += repeats;
  }
  error = internal_pzx_write_pulse( writer->body, duration, count );
  if( error ) return error;
  return write_chunk( writer, PZX_PULSE );
}

/* PULS starts low. A zero pulse selects high before the first timed pulse. */
static libspectrum_error
write_legacy_pulses( pzx_writer *writer, libspectrum_tape_block *block )
{
  size_t i;
  libspectrum_error error;
  if( writer->first ) {
    error = internal_pzx_write_pulse( writer->body, 0, 1 );
    if( error ) return error;
  }
  if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_PURE_TONE ) {
    error = internal_pzx_write_pulse( writer->body,
      libspectrum_tape_block_pulse_length( block ),
      libspectrum_tape_block_count( block ) );
    if( error ) return error;
  } else {
    for( i = 0; i < libspectrum_tape_block_count( block ); i++ ) {
      error = internal_pzx_write_pulse( writer->body,
        libspectrum_tape_block_pulse_lengths( block, i ), 1 );
      if( error ) return error;
    }
  }
  return write_chunk( writer, PZX_PULSE );
}

static void
write_string( libspectrum_buffer *body, const char *s )
{
  char *utf8;
  internal_tape_text_convert( s, 2, &utf8 );
  libspectrum_buffer_write( body, (const libspectrum_byte *)utf8,
                            strlen( utf8 ) + 1 );
  libspectrum_free( utf8 );
}

static libspectrum_error
write_pause( pzx_writer *writer, libspectrum_dword duration, int level )
{
  libspectrum_buffer_write_dword( writer->body,
    duration | ( level ? PZX_LEVEL_FLAG : 0 ) );
  return write_chunk( writer, PZX_PAUSE );
}

static void
write_data_header( libspectrum_buffer *body, size_t bits, int level,
                   libspectrum_dword tail, libspectrum_byte p0,
                   libspectrum_byte p1 )
{
  libspectrum_buffer_write_dword( body, bits | ( level ? PZX_LEVEL_FLAG : 0 ) );
  libspectrum_buffer_write_word( body, tail );
  libspectrum_buffer_write_byte( body, p0 );
  libspectrum_buffer_write_byte( body, p1 );
}

static libspectrum_error
write_native_data( pzx_writer *writer, libspectrum_tape_block *block )
{
  size_t i, bits = libspectrum_tape_block_count( block );
  libspectrum_byte p0 = libspectrum_tape_block_bit0_pulse_count( block );
  libspectrum_byte p1 = libspectrum_tape_block_bit1_pulse_count( block );
  write_data_header( writer->body, bits, libspectrum_tape_block_level( block ),
                    libspectrum_tape_block_tail_length( block ), p0, p1 );
  for( i = 0; i < p0; i++ )
    libspectrum_buffer_write_word( writer->body,
      libspectrum_tape_block_bit0_pulses( block, i ) );
  for( i = 0; i < p1; i++ )
    libspectrum_buffer_write_word( writer->body,
      libspectrum_tape_block_bit1_pulses( block, i ) );
  libspectrum_buffer_write( writer->body, libspectrum_tape_block_data( block ),
                            ( bits + 7 ) / 8 );
  return write_chunk( writer, PZX_DATA );
}

/* Two pulses per sample return to low, independently of the sample value. */
static libspectrum_error
write_raw_data( pzx_writer *writer, libspectrum_tape_block *block )
{
  size_t length = libspectrum_tape_block_data_length( block );
  size_t used = libspectrum_tape_block_bits_in_last_byte( block );
  size_t bits;
  libspectrum_dword duration = libspectrum_tape_block_bit_length( block );
  libspectrum_dword pause = libspectrum_tape_block_pause_tstates( block );
  const libspectrum_byte *data = libspectrum_tape_block_data( block );
  libspectrum_error error;
  int last;
  if( !used ) used = 8;
  bits = ( length - 1 ) * 8 + used;
  write_data_header( writer->body, bits, 0, 0, 2, 2 );
  libspectrum_buffer_write_word( writer->body, duration );
  libspectrum_buffer_write_word( writer->body, 0 );
  libspectrum_buffer_write_word( writer->body, 0 );
  libspectrum_buffer_write_word( writer->body, duration );
  libspectrum_buffer_write( writer->body, data, length );
  error = write_chunk( writer, PZX_DATA );
  if( error ) return error;
  /* Raw playback pauses at the opposite level to the final sample. */
  last = ( data[length - 1] >> ( 8 - used ) ) & 1;
  return pause ? write_pause( writer, pause, !last ) : LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_legacy_pilot( pzx_writer *writer, const pzx_legacy_data *data )
{
  libspectrum_error error;
  if( writer->first ) {
    error = internal_pzx_write_pulse( writer->body, 0, 1 );
    if( error ) return error;
  }
  if( data->pilot ) {
    error = internal_pzx_write_pulse( writer->body, data->pilot_length, data->pilot );
    if( error ) return error;
  }
  error = internal_pzx_write_pulse( writer->body, data->sync1, 1 );
  if( error ) return error;
  error = internal_pzx_write_pulse( writer->body, data->sync2, 1 );
  if( error ) return error;
  return write_chunk( writer, PZX_PULSE );
}

static libspectrum_error
write_legacy_data( pzx_writer *writer, libspectrum_tape_block *block )
{
  pzx_legacy_data data;
  libspectrum_error error = internal_pzx_get_legacy_data( block, &data );
  if( error ) return error;
  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PURE_DATA ) {
    error = write_legacy_pilot( writer, &data );
    if( error ) return error;
  }
  /* Consume existing post-data time in the tail, continuing at the same
     level in PAUS if necessary. Never add a synthetic terminating pulse. */
  write_data_header( writer->body, data.bits,
                    writer->first ^ ( data.pilot & 1 ), data.tail, 2, 2 );
  libspectrum_buffer_write_word( writer->body, data.bit0 );
  libspectrum_buffer_write_word( writer->body, data.bit0 );
  libspectrum_buffer_write_word( writer->body, data.bit1 );
  libspectrum_buffer_write_word( writer->body, data.bit1 );
  libspectrum_buffer_write( writer->body, libspectrum_tape_block_data( block ),
                            ( data.bits + 7 ) / 8 );
  error = write_chunk( writer, PZX_DATA );
  if( error ) return error;
  if( data.pause > data.tail )
    return write_pause( writer, data.pause - data.tail, writer->last );
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_archive( pzx_writer *writer, libspectrum_tape_block *block )
{
  size_t i, count = libspectrum_tape_block_count( block );
  libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MAJOR );
  libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MINOR );
  /* Title precedes all key/value pairs, even if absent in the source. */
  for( i = 0; i < count; i++ )
    if( libspectrum_tape_block_ids( block, i ) == 0 ) break;
  write_string( writer->body,
                i < count ? libspectrum_tape_block_texts( block, i ) : "" );
  for( i = 0; i < count; i++ ) {
    int id = libspectrum_tape_block_ids( block, i );
    if( id == 0 ) continue;
    write_string( writer->body, internal_pzx_archive_name( id ) );
    write_string( writer->body, libspectrum_tape_block_texts( block, i ) );
  }
  return write_chunk( writer, PZX_HEADER );
}

static libspectrum_error
write_stop( pzx_writer *writer, int flags )
{
  libspectrum_buffer_write_word( writer->body, flags );
  return write_chunk( writer, PZX_STOP );
}

static libspectrum_error
write_recording( pzx_writer *writer, libspectrum_tape_block *block )
{
  libspectrum_error error;
  if( libspectrum_buffer_get_data_size( writer->body ) ) {
    error = write_chunk( writer, PZX_PULSE );
    if( error ) return error;
  }
  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE &&
      libspectrum_tape_block_pause_tstates( block ) )
    return write_pause( writer, libspectrum_tape_block_pause_tstates( block ),
      libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ?
      0 : writer->last );
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_metadata( pzx_writer *writer, libspectrum_tape_block *block )
{
  libspectrum_dword pause;
  const char *text;
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
    /* Inspection carries this level into subsequent legacy blocks. */
  case LIBSPECTRUM_TAPE_BLOCK_JUMP:
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
  /* PZX intentionally omits these TZX-only metadata blocks. */
  case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
  case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
  case LIBSPECTRUM_TAPE_BLOCK_CUSTOM: return LIBSPECTRUM_ERROR_NONE;
  case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
    pause = libspectrum_tape_block_pause_tstates( block );
    if( !pause ) return write_stop( writer, PZX_STOP_ALWAYS );
    return write_pause( writer, pause, writer->first );
  case LIBSPECTRUM_TAPE_BLOCK_STOP48: return write_stop( writer, PZX_STOP_48K );
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
  case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
    {
      char *utf8;
      text = libspectrum_tape_block_text( block );
      internal_tape_text_convert( text, 2, &utf8 );
      libspectrum_buffer_write( writer->body,
        (const libspectrum_byte *)utf8, strlen( utf8 ) );
      libspectrum_free( utf8 );
      return write_chunk( writer, PZX_BROWSE );
    }
  case LIBSPECTRUM_TAPE_BLOCK_CONCAT:
    libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MAJOR );
    libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MINOR );
    return write_chunk( writer, PZX_HEADER );
  case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO: return write_archive( writer, block );
  default: return LIBSPECTRUM_ERROR_LOGIC;
  }
}

static libspectrum_error
write_block( pzx_writer *writer, libspectrum_tape_block *block )
{
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_PURE_TONE:
  case LIBSPECTRUM_TAPE_BLOCK_PULSES: return write_legacy_pulses( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE: return write_sequence( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_ROM:
  case LIBSPECTRUM_TAPE_BLOCK_TURBO:
  case LIBSPECTRUM_TAPE_BLOCK_PURE_DATA: return write_legacy_data( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK: return write_native_data( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_RAW_DATA: return write_raw_data( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
  case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
  case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA: return write_recording( writer, block );
  default: return write_metadata( writer, block );
  }
}

static libspectrum_error
write_header( pzx_writer *writer, libspectrum_tape *tape )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block = libspectrum_tape_iterator_init( &it, tape );
  /* Leading archive information supplies the initial title/header itself. */
  if( block && libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO )
    return LIBSPECTRUM_ERROR_NONE;
  libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MAJOR );
  libspectrum_buffer_write_byte( writer->body, PZX_VERSION_MINOR );
  return write_chunk( writer, PZX_HEADER );
}

static libspectrum_error
write_path_block( pzx_writer *writer, libspectrum_tape *tape,
                  libspectrum_tape_iterator current, libspectrum_tape_iterator next )
{
  libspectrum_tape_block *block = libspectrum_tape_iterator_current( current );
  if( writer->need_playback ) {
    libspectrum_error error;
    if( writer->state.current_block != current ) return LIBSPECTRUM_ERROR_LOGIC;
    error = internal_pzx_inspect_block( writer, tape, next );
    if( error ) return error;
  } else if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_PAUSE ) {
    writer->first = libspectrum_tape_block_level( block );
  }
  return write_block( writer, block );
}

static libspectrum_error
write_path( pzx_writer *writer, libspectrum_tape *tape,
            libspectrum_tape_iterator *plan, size_t visits )
{
  libspectrum_tape_iterator it;
  size_t i;
  libspectrum_tape_iterator_init( &it, tape );
  for( i = 0; i < visits; i++ ) {
    libspectrum_tape_iterator current = plan ? plan[i] : it;
    libspectrum_tape_iterator next = plan && i + 1 < visits ? plan[i + 1] : NULL;
    libspectrum_error error = write_path_block( writer, tape, current, next );
    if( error ) return error;
    if( !plan ) libspectrum_tape_iterator_next( &it );
  }
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_error
internal_pzx_write( libspectrum_buffer *out, libspectrum_tape *tape )
{
  libspectrum_tape_iterator *plan = NULL;
  size_t visits = 0;
  pzx_writer writer;
  libspectrum_error error;
  memset( &writer, 0, sizeof( writer ) );
  writer.out = out;
  writer.body = libspectrum_buffer_alloc();
  error = internal_pzx_validate_tape( &writer, tape );
  if( error ) goto done;
  error = internal_pzx_plan_blocks( &writer, tape, &plan, &visits );
  if( error ) goto done;
  error = internal_pzx_prepare_playback( &writer, tape, plan, visits );
  if( error ) goto done;
  error = write_header( &writer, tape );
  if( error ) goto done;
  error = write_path( &writer, tape, plan, visits );
done:
  libspectrum_free( plan );
  libspectrum_buffer_free( writer.body );
  return error;
}
