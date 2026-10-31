/* csw_write.c: Waveform-aware CSW v2 writing
   Copyright (c) 2002-2026 Darren Salt, Fredrick Meunier

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
#include "tape_block.h"
#include "pzx_internals.h"

typedef struct csw_writer {
  libspectrum_buffer *body;
  libspectrum_tape_block_state state;
  libspectrum_dword pulses, duration;
  int level, pending_level, initial_high, stop;
} csw_writer;

static libspectrum_error
flush_run( csw_writer *writer )
{
  if( !writer->duration ) return LIBSPECTRUM_ERROR_NONE;
  if( writer->pulses == UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
  if( writer->duration <= 255 ) {
    libspectrum_buffer_write_byte( writer->body, writer->duration );
  } else {
    libspectrum_buffer_write_byte( writer->body, 0 );
    libspectrum_buffer_write_dword( writer->body, writer->duration );
  }
  writer->pulses++;
  writer->duration = 0;
  return LIBSPECTRUM_ERROR_NONE;
}

/* CSW describes alternating runs, not events. Zero-time transitions affect
   subsequent levels; adjacent durations at the same level form one run. */
static libspectrum_error
add_duration( csw_writer *writer, libspectrum_dword duration, int level )
{
  libspectrum_error error;
  writer->level = level;
  if( !duration ) return LIBSPECTRUM_ERROR_NONE;
  if( writer->duration && writer->pending_level != level ) {
    error = flush_run( writer );
    if( error ) return error;
  }
  if( !writer->pulses && !writer->duration ) writer->initial_high = level;
  if( duration > UINT32_MAX - writer->duration ) return LIBSPECTRUM_ERROR_INVALID;
  writer->pending_level = level;
  writer->duration += duration;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_native_pulses( csw_writer *writer, libspectrum_tape_block *block )
{
  size_t i, count = libspectrum_tape_block_count( block );
  int level = 0;
  libspectrum_error error;
  if( !count ) return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < count; i++ ) {
    size_t repeats = libspectrum_tape_block_pulse_repeats( block, i );
    libspectrum_dword duration = libspectrum_tape_block_pulse_lengths( block, i );
    if( !repeats || duration > PZX_VALUE_MASK ) return LIBSPECTRUM_ERROR_INVALID;
    if( !duration ) {
      writer->level = level ^ ( ( repeats - 1 ) & 1 );
      level ^= repeats & 1;
      continue;
    }
    if( repeats > UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
    while( repeats-- ) {
      error = add_duration( writer, duration, level );
      if( error ) return error;
      level = !level;
    }
  }
  writer->state.force_low_level = 0;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_bit( csw_writer *writer, libspectrum_tape_block *block, int one, int *level )
{
  size_t i, count = one ? libspectrum_tape_block_bit1_pulse_count( block ) :
                        libspectrum_tape_block_bit0_pulse_count( block );
  for( i = 0; i < count; i++ ) {
    libspectrum_word duration = one ? libspectrum_tape_block_bit1_pulses( block, i ) :
                                     libspectrum_tape_block_bit0_pulses( block, i );
    libspectrum_error error = add_duration( writer, duration, *level );
    if( error ) return error;
    *level = !*level;
    writer->state.force_low_level = 0;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

/* Render DATA directly, including empty bit sequences which native playback
   does not yet handle. The count and initial level are authoritative. */
static libspectrum_error
write_native_data( csw_writer *writer, libspectrum_tape_block *block )
{
  size_t bit, bits = libspectrum_tape_block_count( block );
  libspectrum_byte *data = libspectrum_tape_block_data( block );
  int level = libspectrum_tape_block_level( block );
  libspectrum_dword tail = libspectrum_tape_block_tail_length( block );
  if( bits > PZX_VALUE_MASK || level < 0 || level > 1 || tail > 65535 ||
      libspectrum_tape_block_data_length( block ) < ( bits + 7 ) / 8 ||
      ( bits && !data ) ) return LIBSPECTRUM_ERROR_INVALID;
  for( bit = 0; bit < bits; bit++ ) {
    int one = !!( data[bit / 8] & ( 0x80 >> ( bit % 8 ) ) );
    libspectrum_error error = write_bit( writer, block, one, &level );
    if( error ) return error;
  }
  if( tail ) {
    writer->state.force_low_level = 1;
    return add_duration( writer, tail, level );
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_native_pause( csw_writer *writer, libspectrum_tape_block *block )
{
  int level = libspectrum_tape_block_level( block );
  libspectrum_dword duration = libspectrum_tape_block_pause_tstates( block );
  if( level < 0 || level > 1 || duration > PZX_VALUE_MASK )
    return LIBSPECTRUM_ERROR_INVALID;
  if( !duration ) { writer->stop = 1; return LIBSPECTRUM_ERROR_NONE; }
  writer->state.force_low_level = 1;
  return add_duration( writer, duration, level );
}

static int
is_native( libspectrum_tape_block *block )
{
  libspectrum_tape_type type = libspectrum_tape_block_type( block );
  return type == LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE ||
    type == LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK ||
    ( type == LIBSPECTRUM_TAPE_BLOCK_PAUSE &&
      libspectrum_tape_block_level( block ) != -1 );
}

static libspectrum_error
write_native( csw_writer *writer, libspectrum_tape_block *block )
{
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE: return write_native_pulses( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK: return write_native_data( writer, block );
  case LIBSPECTRUM_TAPE_BLOCK_PAUSE: return write_native_pause( writer, block );
  default: return LIBSPECTRUM_ERROR_LOGIC;
  }
}

static libspectrum_error
write_event( csw_writer *writer, libspectrum_tape *tape )
{
  libspectrum_dword duration;
  int flags;
  libspectrum_error error = libspectrum_tape_get_next_edge_internal(
    &duration, &flags, tape, &writer->state );
  if( error ) return error;
  int level = writer->level;
  if( flags & LIBSPECTRUM_TAPE_FLAGS_LEVEL_LOW ) level = 0;
  else if( flags & LIBSPECTRUM_TAPE_FLAGS_LEVEL_HIGH ) level = 1;
  else if( !( flags & LIBSPECTRUM_TAPE_FLAGS_NO_EDGE ) ) level = !level;
  writer->stop = !!( flags & LIBSPECTRUM_TAPE_FLAGS_STOP );
  return add_duration( writer, duration, level );
}

static int
is_empty_rle( libspectrum_tape_block *block )
{
  return libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE &&
    !libspectrum_tape_block_data_length( block );
}

static libspectrum_error
write_native_and_advance( csw_writer *writer, libspectrum_tape_block *block )
{
  libspectrum_error error = is_empty_rle( block ) ? LIBSPECTRUM_ERROR_NONE :
                                                 write_native( writer, block );
  if( error || writer->stop ) return error;
  block = libspectrum_tape_iterator_next( &writer->state.current_block );
  if( !block ) { writer->stop = 1; return LIBSPECTRUM_ERROR_NONE; }
  writer->state.signal_level = writer->level;
  return libspectrum_tape_block_init( block, &writer->state );
}

static libspectrum_error
render_body( csw_writer *writer, libspectrum_tape *tape )
{
  libspectrum_tape_block *block;
  writer->state.force_low_level = 1;
  if( !libspectrum_tape_block_internal_init( &writer->state, tape ) )
    return libspectrum_tape_present( tape ) ? LIBSPECTRUM_ERROR_INVALID :
                                            LIBSPECTRUM_ERROR_NONE;
  while( !writer->stop &&
         ( block = libspectrum_tape_iterator_current( writer->state.current_block ) ) ) {
    libspectrum_error error;
    if( is_native( block ) || is_empty_rle( block ) )
      error = write_native_and_advance( writer, block );
    else
      error = write_event( writer, tape );
    if( error ) return error;
    writer->state.signal_level = writer->level;
  }
  return flush_run( writer );
}

/* Only an isolated exact-rate recording can be copied without resampling.
   All other tapes use 3.5 MHz: one sample per T-state, with no quantisation. */
static libspectrum_tape_block *
find_recording( libspectrum_tape *tape, int *initial_high )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block, *recording = NULL;
  for( block = libspectrum_tape_iterator_init( &it, tape ); block;
       block = libspectrum_tape_iterator_next( &it ) ) {
    switch( libspectrum_tape_block_type( block ) ) {
    case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
      if( !recording ) *initial_high = !!libspectrum_tape_block_level( block );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
    case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO:
    case LIBSPECTRUM_TAPE_BLOCK_CONCAT: break;
    case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
    case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
      if( recording || !libspectrum_tape_block_sample_rate( block ) ) return NULL;
      if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_TZX_CSW &&
          libspectrum_tape_block_pause_tstates( block ) ) return NULL;
      recording = block;
      if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE &&
          libspectrum_tape_block_level( block ) != -1 )
        *initial_high = libspectrum_tape_block_level( block );
      break;
    default: return NULL;
    }
  }
  return recording;
}

static libspectrum_error
copy_recording( csw_writer *writer, libspectrum_tape_block *block )
{
  size_t i = 0, length = libspectrum_tape_block_data_length( block );
  libspectrum_byte *data = libspectrum_tape_block_data( block );
  if( length && !data ) return LIBSPECTRUM_ERROR_CORRUPT;
  while( i < length ) {
    libspectrum_dword samples = data[i++];
    if( !samples ) {
      if( length - i < 4 ) return LIBSPECTRUM_ERROR_CORRUPT;
      samples = libspectrum_read_dword_le( data + i ); i += 4;
      if( !samples ) return LIBSPECTRUM_ERROR_CORRUPT;
    }
    if( writer->pulses == UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
    writer->pulses++;
  }
  if( length ) libspectrum_buffer_write( writer->body, data, length );
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_rle( libspectrum_tape_block *block )
{
  size_t i = 0, length = libspectrum_tape_block_data_length( block );
  libspectrum_byte *data = libspectrum_tape_block_data( block );
  if( !length ) return LIBSPECTRUM_ERROR_NONE;
  if( !data ) return LIBSPECTRUM_ERROR_CORRUPT;
  if( !libspectrum_tape_block_sample_rate( block ) && !libspectrum_tape_block_scale( block ) )
    return LIBSPECTRUM_ERROR_INVALID;
  while( i < length ) {
    if( data[i++] ) continue;
    if( length - i < 4 || !libspectrum_read_dword_le( data + i ) )
      return LIBSPECTRUM_ERROR_CORRUPT;
    i += 4;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_rendering( libspectrum_tape *tape )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  libspectrum_error error;
  for( block = libspectrum_tape_iterator_init( &it, tape ); block;
       block = libspectrum_tape_iterator_next( &it ) ) {
    switch( libspectrum_tape_block_type( block ) ) {
    case LIBSPECTRUM_TAPE_BLOCK_JUMP:
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
    case LIBSPECTRUM_TAPE_BLOCK_SELECT: return LIBSPECTRUM_ERROR_UNKNOWN;
    case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
    case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
      error = validate_rle( block );
      if( error ) return error;
      break;
    case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
      if( !libspectrum_tape_block_pause_tstates( block ) ) return LIBSPECTRUM_ERROR_NONE;
      break;
    default: break;
    }
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
write_file( libspectrum_buffer *out, csw_writer *writer, libspectrum_dword rate )
{
  libspectrum_byte compression = 1;
#ifdef HAVE_ZLIB_H
  if( writer->pulses ) {
    libspectrum_byte *compressed = NULL;
    size_t length;
    libspectrum_error error = libspectrum_zlib_compress(
      libspectrum_buffer_get_data( writer->body ),
      libspectrum_buffer_get_data_size( writer->body ), &compressed, &length );
    if( error ) return error;
    libspectrum_buffer_clear( writer->body );
    libspectrum_buffer_write( writer->body, compressed, length );
    libspectrum_free( compressed );
    compression = 2;
  }
#endif
  libspectrum_buffer_write( out, (const libspectrum_byte *)"Compressed Square Wave\x1a", 23 );
  libspectrum_buffer_write_byte( out, 2 );
  libspectrum_buffer_write_byte( out, 0 );
  libspectrum_buffer_write_dword( out, rate );
  libspectrum_buffer_write_dword( out, writer->pulses );
  libspectrum_buffer_write_byte( out, compression );
  libspectrum_buffer_write_byte( out, writer->initial_high );
  libspectrum_buffer_write_byte( out, 0 );
  static const libspectrum_byte application[16] = { 0 };
  libspectrum_buffer_write( out, application, sizeof( application ) );
  libspectrum_buffer_write_buffer( out, writer->body );
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_error
libspectrum_csw_write( libspectrum_buffer *out, libspectrum_tape *tape )
{
  csw_writer writer;
  libspectrum_dword rate = 3500000;
  memset( &writer, 0, sizeof( writer ) );
  writer.pending_level = -1;
  writer.body = libspectrum_buffer_alloc();
  libspectrum_error error = validate_rendering( tape );
  if( error ) goto done;
  libspectrum_tape_block *recording = find_recording( tape, &writer.initial_high );
  if( recording ) {
    rate = libspectrum_tape_block_sample_rate( recording );
    error = copy_recording( &writer, recording );
  } else {
    writer.initial_high = 0;
    error = render_body( &writer, tape );
  }
  if( !error ) error = write_file( out, &writer, rate );
done:
  libspectrum_buffer_free( writer.body );
  return error;
}
