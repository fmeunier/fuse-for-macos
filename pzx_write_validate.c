/* pzx_write_validate.c: Payload validation for PZX output
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
validate_native_data( libspectrum_tape_block *block )
{
  size_t bits = libspectrum_tape_block_count( block );
  int level = libspectrum_tape_block_level( block );
  if( bits > PZX_VALUE_MASK ||
      libspectrum_tape_block_data_length( block ) < ( bits + 7 ) / 8 ||
      libspectrum_tape_block_tail_length( block ) > 0xffff ||
      level < 0 || level > 1 ) return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

/* One description shared by validation and serialization. */
libspectrum_error
internal_pzx_get_legacy_data( libspectrum_tape_block *block, pzx_legacy_data *data )
{
  libspectrum_tape_type type = libspectrum_tape_block_type( block );
  size_t length = libspectrum_tape_block_data_length( block ), used = 8;
  memset( data, 0, sizeof( *data ) );
  if( type != LIBSPECTRUM_TAPE_BLOCK_ROM )
    used = libspectrum_tape_block_bits_in_last_byte( block );
  if( !used ) used = 8; /* TZX zero means a complete last byte. */
  if( !length || used > 8 || length > PZX_VALUE_MASK / 8 )
    return LIBSPECTRUM_ERROR_INVALID;
  data->bits = ( length - 1 ) * 8 + used;
  data->pause = libspectrum_tape_block_pause_tstates( block );
  data->tail = data->pause > 0xffff ? 0xffff : data->pause;
  if( type == LIBSPECTRUM_TAPE_BLOCK_ROM ) {
    data->bit0 = LIBSPECTRUM_TAPE_TIMING_DATA0;
    data->bit1 = LIBSPECTRUM_TAPE_TIMING_DATA1;
    data->pilot = libspectrum_tape_block_data( block )[0] < 128 ? 8063 : 3223;
    data->pilot_length = LIBSPECTRUM_TAPE_TIMING_PILOT;
    data->sync1 = LIBSPECTRUM_TAPE_TIMING_SYNC1;
    data->sync2 = LIBSPECTRUM_TAPE_TIMING_SYNC2;
  } else {
    data->bit0 = libspectrum_tape_block_bit0_length( block );
    data->bit1 = libspectrum_tape_block_bit1_length( block );
  }
  if( type == LIBSPECTRUM_TAPE_BLOCK_TURBO ) {
    data->pilot = libspectrum_tape_block_pilot_pulses( block );
    data->pilot_length = libspectrum_tape_block_pilot_length( block );
    data->sync1 = libspectrum_tape_block_sync1_length( block );
    data->sync2 = libspectrum_tape_block_sync2_length( block );
  }
  if( data->pause > PZX_VALUE_MASK || data->bit0 > 0xffff || data->bit1 > 0xffff ||
      data->pilot_length > PZX_VALUE_MASK || data->sync1 > PZX_VALUE_MASK ||
      data->sync2 > PZX_VALUE_MASK ) return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_sequence( libspectrum_tape_block *block )
{
  size_t i, count = libspectrum_tape_block_count( block );
  if( !count ) return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < count; i++ )
    if( !libspectrum_tape_block_pulse_repeats( block, i ) ||
        libspectrum_tape_block_pulse_lengths( block, i ) > PZX_VALUE_MASK )
      return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_pause( libspectrum_tape_block *block )
{
  int level = libspectrum_tape_block_level( block );
  libspectrum_dword pause = libspectrum_tape_block_pause_tstates( block );
  if( pause > PZX_VALUE_MASK || level < -1 || level > 1 )
    return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_archive( libspectrum_tape_block *block )
{
  size_t i, titles = 0;
  for( i = 0; i < libspectrum_tape_block_count( block ); i++ ) {
    int id = libspectrum_tape_block_ids( block, i );
    if( id == 0 ) titles++;
    if( id != 0 && !internal_pzx_archive_name( id ) )
      return LIBSPECTRUM_ERROR_UNKNOWN;
  }
  return titles > 1 ? LIBSPECTRUM_ERROR_UNKNOWN : LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_generalised_table( libspectrum_tape_generalised_data_symbol_table *table )
{
  size_t i;
  if( !table->symbols_in_block ) return LIBSPECTRUM_ERROR_NONE;
  if( !table->max_pulses || !table->symbols_in_table ||
      table->symbols_in_table > 256 || !table->symbols )
    return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < table->symbols_in_table; i++ ) {
    libspectrum_tape_generalised_data_symbol *symbol = &table->symbols[i];
    if( !symbol->lengths ||
        symbol->edge_type < LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_EDGE ||
        symbol->edge_type > LIBSPECTRUM_TAPE_GENERALISED_DATA_SYMBOL_HIGH )
      return LIBSPECTRUM_ERROR_INVALID;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_generalised( libspectrum_tape_block *block )
{
  libspectrum_tape_generalised_data_block *data = &block->types.generalised_data;
  libspectrum_error error;
  size_t i, bits = 0, offset = 0;
  error = validate_generalised_table( &data->pilot_table );
  if( error ) return error;
  error = validate_generalised_table( &data->data_table );
  if( error ) return error;
  if( data->pause_tstates > PZX_VALUE_MASK ) return LIBSPECTRUM_ERROR_INVALID;
  if( data->pilot_table.symbols_in_block &&
      ( !data->pilot_symbols || !data->pilot_repeats ) )
    return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < data->pilot_table.symbols_in_block; i++ )
    if( data->pilot_symbols[i] >= data->pilot_table.symbols_in_table ||
        !data->pilot_repeats[i] ) return LIBSPECTRUM_ERROR_INVALID;
  if( !data->data_table.symbols_in_block ) return LIBSPECTRUM_ERROR_NONE;
  while( ( (size_t)1 << bits ) < data->data_table.symbols_in_table ) bits++;
  if( data->bits_per_data_symbol != bits || !data->data ||
      ( bits && data->data_table.symbols_in_block > ( SIZE_MAX - 7 ) / bits ) )
    return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < data->data_table.symbols_in_block; i++ ) {
    size_t j, symbol = 0;
    for( j = 0; j < bits; j++, offset++ )
      symbol = ( symbol << 1 ) |
               ( ( data->data[offset / 8] >> ( 7 - offset % 8 ) ) & 1 );
    if( symbol >= data->data_table.symbols_in_table )
      return LIBSPECTRUM_ERROR_INVALID;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_recording_stream( libspectrum_tape_block *block, size_t *pulses )
{
  size_t i = 0;
  size_t length = libspectrum_tape_block_data_length( block );
  const libspectrum_byte *data = libspectrum_tape_block_data( block );
  libspectrum_dword rate = libspectrum_tape_block_sample_rate( block );
  libspectrum_dword scale = libspectrum_tape_block_scale( block );
  libspectrum_qword remainder = 0;
  *pulses = 0;
  if( length && !data ) return LIBSPECTRUM_ERROR_CORRUPT;
  if( length && !rate && !scale ) return LIBSPECTRUM_ERROR_INVALID;
  while( i < length ) {
    libspectrum_dword samples = data[i++];
    libspectrum_qword duration;
    if( !samples ) {
      if( length - i < 4 ) return LIBSPECTRUM_ERROR_CORRUPT;
      samples = libspectrum_read_dword_le( data + i );
      i += 4;
      if( !samples ) return LIBSPECTRUM_ERROR_CORRUPT;
    }
    if( rate ) {
      duration = (libspectrum_qword)samples * 3500000 + remainder;
      remainder = duration % rate;
      duration /= rate;
    } else {
      duration = (libspectrum_qword)samples * scale;
    }
    if( duration > UINT32_MAX ) return LIBSPECTRUM_ERROR_INVALID;
    (*pulses)++;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_recording( libspectrum_tape_block *block )
{
  size_t pulses;
  libspectrum_error error = validate_recording_stream( block, &pulses );
  if( error ) return error;
  if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ) {
    if( pulses != libspectrum_tape_block_csw_pulses( block ) )
      return LIBSPECTRUM_ERROR_CORRUPT;
    if( libspectrum_tape_block_pause_tstates( block ) > PZX_VALUE_MASK )
      return LIBSPECTRUM_ERROR_INVALID;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_raw_data( libspectrum_tape_block *block )
{
  size_t length = libspectrum_tape_block_data_length( block );
  size_t used = libspectrum_tape_block_bits_in_last_byte( block );
  if( !used ) used = 8;
  if( !length || length > PZX_VALUE_MASK / 8 || used > 8 ||
      !libspectrum_tape_block_data( block ) ||
      !libspectrum_tape_block_bit_length( block ) ||
      libspectrum_tape_block_bit_length( block ) > 0xffff ||
      libspectrum_tape_block_pause_tstates( block ) > PZX_VALUE_MASK )
    return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_legacy_pulses( libspectrum_tape_block *block )
{
  size_t i;
  if( !libspectrum_tape_block_count( block ) ) return LIBSPECTRUM_ERROR_INVALID;
  if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_PURE_TONE )
    return libspectrum_tape_block_pulse_length( block ) > PZX_VALUE_MASK ?
      LIBSPECTRUM_ERROR_INVALID : LIBSPECTRUM_ERROR_NONE;
  for( i = 0; i < libspectrum_tape_block_count( block ); i++ )
    if( libspectrum_tape_block_pulse_lengths( block, i ) > PZX_VALUE_MASK )
      return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
validate_metadata( pzx_writer *writer, libspectrum_tape_block *block )
{
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
    return libspectrum_tape_block_level( block ) < 0 ||
           libspectrum_tape_block_level( block ) > 1 ?
           LIBSPECTRUM_ERROR_INVALID : LIBSPECTRUM_ERROR_NONE;
  case LIBSPECTRUM_TAPE_BLOCK_PAUSE: return validate_pause( block );
  case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO: return validate_archive( block );
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
    if( writer->in_group ) return LIBSPECTRUM_ERROR_INVALID;
    writer->in_group = 1;
    return LIBSPECTRUM_ERROR_NONE;
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
    if( !writer->in_group ) return LIBSPECTRUM_ERROR_INVALID;
    writer->in_group = 0;
    return LIBSPECTRUM_ERROR_NONE;
  case LIBSPECTRUM_TAPE_BLOCK_JUMP:
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
    writer->bounded = 1;
    return LIBSPECTRUM_ERROR_NONE;
  case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
  case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
  case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
  case LIBSPECTRUM_TAPE_BLOCK_STOP48:
  case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
  case LIBSPECTRUM_TAPE_BLOCK_CONCAT: return LIBSPECTRUM_ERROR_NONE;
  default:
    libspectrum_print_error( LIBSPECTRUM_ERROR_UNKNOWN,
      "internal_pzx_write: unsupported tape block 0x%02x",
      libspectrum_tape_block_type( block ) );
    return LIBSPECTRUM_ERROR_UNKNOWN;
  }
}

static libspectrum_error
validate_block( pzx_writer *writer, libspectrum_tape_block *block )
{
  pzx_legacy_data data;
  writer->need_playback |= internal_pzx_needs_playback( block );
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA: return validate_generalised( block );
  case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
  case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW: return validate_recording( block );
  case LIBSPECTRUM_TAPE_BLOCK_RAW_DATA: return validate_raw_data( block );
  case LIBSPECTRUM_TAPE_BLOCK_PURE_TONE:
  case LIBSPECTRUM_TAPE_BLOCK_PULSES: return validate_legacy_pulses( block );
  case LIBSPECTRUM_TAPE_BLOCK_ROM:
  case LIBSPECTRUM_TAPE_BLOCK_TURBO:
  case LIBSPECTRUM_TAPE_BLOCK_PURE_DATA:
    return internal_pzx_get_legacy_data( block, &data );
  case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE: return validate_sequence( block );
  case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK: return validate_native_data( block );
  default: return validate_metadata( writer, block );
  }
}

libspectrum_error
internal_pzx_validate_tape( pzx_writer *writer, libspectrum_tape *tape )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  for( block = libspectrum_tape_iterator_init( &it, tape ); block;
       block = libspectrum_tape_iterator_next( &it ) ) {
    libspectrum_error error = validate_block( writer, block );
    if( error ) return error;
  }
  return writer->in_group ? LIBSPECTRUM_ERROR_INVALID : LIBSPECTRUM_ERROR_NONE;
}
