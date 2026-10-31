/* tzx_write.c: Routines for writing .tzx files
   Copyright (c) 2001-2026 Philip Kendall, Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

   Author contact information:

   E-mail: philip-fuse@shadowmagic.org.uk

*/

#include "config.h"

#include <stdio.h>
#include <string.h>

#include "tape_block.h"
#include "internals.h"

/*** Local function prototypes ***/

static void
tzx_write_rom( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_turbo( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
add_pure_tone_block( libspectrum_buffer *buffer, libspectrum_dword pulse_length,
                     size_t count );
static void
tzx_write_pure_tone( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_data( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_raw_data( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static libspectrum_error
tzx_write_generalised_data( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_pulses( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_pause( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_group_start( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_jump( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_loop_start( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_select( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_stop( libspectrum_buffer* buffer );
static void
add_set_signal_level_block( libspectrum_buffer* buffer, int level );
static void
add_initial_pulse_level_block( libspectrum_buffer* buffer, int level );
static void
tzx_write_set_signal_level( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_comment( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_message( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_archive_info( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static libspectrum_error
validate_archive_info( libspectrum_tape_block *block );
static void
tzx_write_hardware( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static void
tzx_write_custom( libspectrum_tape_block *block, libspectrum_buffer* buffer );
static libspectrum_error
tzx_write_csw( libspectrum_tape_block *block, libspectrum_buffer *buffer );
static libspectrum_error
tzx_write_rle( libspectrum_tape_block *block, libspectrum_buffer* buffer,
               libspectrum_tape *tape,
               libspectrum_tape_iterator iterator );
static void
tzx_write_empty_block( libspectrum_buffer* buffer, libspectrum_tape_type id );

static void
tzx_write_bytes( libspectrum_buffer* buffer, size_t length, size_t length_bytes,
                 libspectrum_byte *data );
static void
tzx_write_string( libspectrum_buffer* buffer, char *string );

/* Convert a shallow copy so export never changes caller-owned UTF-8 text.
   Length limits apply to the encoded CP1252 bytes, not the UTF-8 input. */
static libspectrum_error
write_text_block( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_tape_block copy = *block;
  libspectrum_tape_type type = libspectrum_tape_block_type( block );
  size_t count = type == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ||
                 type == LIBSPECTRUM_TAPE_BLOCK_SELECT ?
                 libspectrum_tape_block_count( block ) : 1;
  char **strings;
  size_t i, total = 1 + 3 * count;
  libspectrum_error error = LIBSPECTRUM_ERROR_NONE;
  if( count > 255 ) return LIBSPECTRUM_ERROR_INVALID;
  strings = libspectrum_new( char *, count );
  for( i = 0; i < count; i++ ) {
    const char *text = type == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ||
                       type == LIBSPECTRUM_TAPE_BLOCK_SELECT ?
                       libspectrum_tape_block_texts( block, i ) :
                       libspectrum_tape_block_text( block );
    if( !text && type != LIBSPECTRUM_TAPE_BLOCK_GROUP_START )
      error = LIBSPECTRUM_ERROR_INVALID;
    internal_tape_text_convert( text, 0, &strings[i] );
    if( strlen( strings[i] ) > 255 ) error = LIBSPECTRUM_ERROR_INVALID;
    total += strlen( strings[i] );
  }
  if( type == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ||
      type == LIBSPECTRUM_TAPE_BLOCK_SELECT )
    libspectrum_tape_block_set_texts( &copy, strings );
  else
    libspectrum_tape_block_set_text( &copy, strings[0] );
  if( !error ) {
    switch( type ) {
    case LIBSPECTRUM_TAPE_BLOCK_GROUP_START: tzx_write_group_start( &copy, buffer ); break;
    case LIBSPECTRUM_TAPE_BLOCK_COMMENT: tzx_write_comment( &copy, buffer ); break;
    case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
      if( libspectrum_tape_block_pause( &copy ) / 1000 > 255 )
        error = LIBSPECTRUM_ERROR_INVALID;
      else tzx_write_message( &copy, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_SELECT:
      if( total > 65535 ) error = LIBSPECTRUM_ERROR_INVALID;
      else tzx_write_select( &copy, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO:
      error = validate_archive_info( &copy );
      if( !error ) tzx_write_archive_info( &copy, buffer );
      break;
    default: error = LIBSPECTRUM_ERROR_LOGIC; break;
    }
  }
  for( i = 0; i < count; i++ ) libspectrum_free( strings[i] );
  libspectrum_free( strings );
  return error;
}

/*** Function definitions ***/

/* The main write function */

libspectrum_error
internal_tzx_write( libspectrum_buffer* buffer, libspectrum_tape *tape )
{
  libspectrum_error error;
  libspectrum_tape_iterator iterator;
  libspectrum_tape_block *block;

  size_t signature_length = strlen( libspectrum_tzx_signature );

  /* First, write the .tzx signature and the version numbers */
  libspectrum_buffer_write( buffer, libspectrum_tzx_signature, signature_length );

  libspectrum_buffer_write_byte( buffer, 1  ); /* Major version number */
  libspectrum_buffer_write_byte( buffer, 20 ); /* Minor version number */

  for( block = libspectrum_tape_iterator_init( &iterator, tape );
       block;
       block = libspectrum_tape_iterator_next( &iterator )       )
  {
    switch( libspectrum_tape_block_type( block ) ) {

    case LIBSPECTRUM_TAPE_BLOCK_ROM:
      tzx_write_rom( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_TURBO:
      tzx_write_turbo( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PURE_TONE:
      tzx_write_pure_tone( block, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_PULSES:
      tzx_write_pulses( block, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_PURE_DATA:
      tzx_write_data( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_RAW_DATA:
      tzx_write_raw_data( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA:
      error = tzx_write_generalised_data( block, buffer );
      if( error != LIBSPECTRUM_ERROR_NONE ) { return error; }
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
      if( libspectrum_tape_block_level( block ) != -1 ) {
        error = internal_tzx_write_pzx_block( buffer, block );
        if( error ) return error;
      } else {
        tzx_write_pause( block, buffer );
      }
      break;
    case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
    case LIBSPECTRUM_TAPE_BLOCK_SELECT:
    case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
    case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
    case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO:
      error = write_text_block( block, buffer );
      if( error ) return error;
      break;

    case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
      tzx_write_empty_block( buffer, libspectrum_tape_block_type( block ) );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_JUMP:
      tzx_write_jump( block, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
      tzx_write_loop_start( block, buffer );
      break;
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
      tzx_write_empty_block( buffer, libspectrum_tape_block_type( block ) );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_STOP48:
      tzx_write_stop( buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
      tzx_write_set_signal_level( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
      tzx_write_hardware( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
      tzx_write_custom( block, buffer );
      break;

    case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
      error = tzx_write_csw( block, buffer );
      if( error ) return error;
      break;

    case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
      if( block->types.rle_pulse.sample_rate ) {
        /* A CSW file supplied an exact rate and an RLE stream. Keep both
           instead of converting it to a sampled Direct Recording block. */
        libspectrum_tape_block csw = { 0 };
        csw.type = LIBSPECTRUM_TAPE_BLOCK_TZX_CSW;
        csw.types.tzx_csw.rle = block->types.rle_pulse;
        csw.types.tzx_csw.compression = 1;
        if( block->types.rle_pulse.has_initial_level ) {
          libspectrum_tape_block level = { 0 };
          level.type = LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL;
          level.types.set_signal_level.level = block->types.rle_pulse.initial_level;
          tzx_write_set_signal_level( &level, buffer );
        }
        error = tzx_write_csw( &csw, buffer );
      } else {
        error = tzx_write_rle( block, buffer, tape, iterator );
      }
      if( error != LIBSPECTRUM_ERROR_NONE ) { return error; }
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE:
    case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK:
      error = internal_tzx_write_pzx_block( buffer, block );
      if( error != LIBSPECTRUM_ERROR_NONE ) { return error; }
      break;

    default:
      libspectrum_print_error(
        LIBSPECTRUM_ERROR_LOGIC,
	"libspectrum_tzx_write: unknown block type 0x%02x",
	libspectrum_tape_block_type( block )
      );
      return LIBSPECTRUM_ERROR_LOGIC;
    }
  }

  return LIBSPECTRUM_ERROR_NONE;
}

static void
tzx_write_rom( libspectrum_tape_block *block, libspectrum_buffer* buffer )
{
  /* Write the ID byte and the pause */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_ROM );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pause( block ) );

  /* Copy the data across */
  tzx_write_bytes( buffer, libspectrum_tape_block_data_length( block ), 2,
                   libspectrum_tape_block_data( block ) );
}

static void
tzx_write_turbo( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  /* Write the ID byte and the metadata */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_TURBO );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pilot_length( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_sync1_length( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_sync2_length( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_bit0_length ( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_bit1_length ( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pilot_pulses( block ) );
  libspectrum_buffer_write_byte( buffer,
                     libspectrum_tape_block_bits_in_last_byte( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pause       ( block ) );

  tzx_write_bytes( buffer, libspectrum_tape_block_data_length( block ), 3,
                   libspectrum_tape_block_data( block ) );
}

static void
add_pure_tone_block( libspectrum_buffer *buffer, libspectrum_dword pulse_length,
                     size_t count )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
  libspectrum_buffer_write_word( buffer, pulse_length );
  libspectrum_buffer_write_word( buffer, count );
}

static void
tzx_write_pure_tone( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  add_pure_tone_block( buffer, libspectrum_tape_block_pulse_length( block ),
                       libspectrum_tape_block_count( block ) );
}

static void
tzx_write_pulses( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  size_t i;
  size_t count = libspectrum_tape_block_count( block );

  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_PULSES );
  libspectrum_buffer_write_byte( buffer, count );
  for( i = 0; i < count; i++ )
    libspectrum_buffer_write_word(
                            buffer,
			    libspectrum_tape_block_pulse_lengths( block, i ) );
}

static void
tzx_write_data( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  /* Write the ID byte and the metadata */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_PURE_DATA );
  libspectrum_buffer_write_word( buffer,
                                 libspectrum_tape_block_bit0_length( block ) );
  libspectrum_buffer_write_word( buffer,
                                 libspectrum_tape_block_bit1_length( block ) );
  libspectrum_buffer_write_byte( buffer,
                     libspectrum_tape_block_bits_in_last_byte( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pause( block ) );

  tzx_write_bytes( buffer, libspectrum_tape_block_data_length( block ), 3,
                   libspectrum_tape_block_data( block ) );
}

static void
tzx_write_raw_data( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  /* Write the ID byte and the metadata */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
  libspectrum_buffer_write_word( buffer,
                                 libspectrum_tape_block_bit_length( block ) );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_pause( block ) );
  libspectrum_buffer_write_byte( buffer,
                     libspectrum_tape_block_bits_in_last_byte( block ) );

  tzx_write_bytes( buffer, libspectrum_tape_block_data_length( block ), 3,
                   libspectrum_tape_block_data( block ) );
}

static size_t
generalised_data_length( libspectrum_tape_generalised_data_symbol_table *pilot,
                         libspectrum_tape_generalised_data_symbol_table *data,
                         size_t data_bits_per_symbol )
{
  size_t data_length = 14;	/* Minimum if no tables or symbols present */

  if( pilot->symbols_in_block ) {

    data_length += ( 2 * pilot->max_pulses + 1 ) * pilot->symbols_in_table;
    data_length += 3 * pilot->symbols_in_block;

  }

  if( data->symbols_in_block ) {

    data_length += ( 2 * data->max_pulses + 1 ) * data->symbols_in_table;
    data_length +=
      libspectrum_bits_to_bytes( data_bits_per_symbol * data->symbols_in_block );

  }

  return data_length;
}

static libspectrum_error
serialise_generalised_data_table( libspectrum_buffer *buffer,
                                  libspectrum_tape_generalised_data_symbol_table *table )
{
  libspectrum_dword symbols_in_block;
  libspectrum_word symbols_in_table;

  symbols_in_block = libspectrum_tape_generalised_data_symbol_table_symbols_in_block( table );

  libspectrum_buffer_write_dword( buffer, symbols_in_block );
  libspectrum_buffer_write_byte( buffer, libspectrum_tape_generalised_data_symbol_table_max_pulses( table ) );

  symbols_in_table = libspectrum_tape_generalised_data_symbol_table_symbols_in_table( table );

  if( symbols_in_block != 0 &&
      ( symbols_in_table == 0 || symbols_in_table > 256 ) ) {
    libspectrum_print_error( LIBSPECTRUM_ERROR_INVALID, "%s: invalid number of symbols in table: %d", __func__, symbols_in_table );
    return LIBSPECTRUM_ERROR_INVALID;
  } else if( symbols_in_table == 256 ) {
    symbols_in_table = 0;
  }

  libspectrum_buffer_write_byte( buffer, symbols_in_table );

  return LIBSPECTRUM_ERROR_NONE;
}

static void
serialise_generalised_data_symbols( libspectrum_buffer *buffer, libspectrum_tape_generalised_data_symbol_table *table )
{
  libspectrum_word symbols_in_table = libspectrum_tape_generalised_data_symbol_table_symbols_in_table( table );
  libspectrum_byte max_pulses = libspectrum_tape_generalised_data_symbol_table_max_pulses( table );

  libspectrum_word i;
  libspectrum_byte j;

  if( !libspectrum_tape_generalised_data_symbol_table_symbols_in_block( table ) ) return;

  for( i = 0; i < symbols_in_table; i++ ) {

    libspectrum_tape_generalised_data_symbol *symbol = libspectrum_tape_generalised_data_symbol_table_symbol( table, i );

    libspectrum_buffer_write_byte( buffer, libspectrum_tape_generalised_data_symbol_type( symbol ) );

    for( j = 0; j < max_pulses; j++ )
      libspectrum_buffer_write_word( buffer, libspectrum_tape_generalised_data_symbol_pulse( symbol, j ) );

  }
}

static libspectrum_error
write_generalised_data_block( libspectrum_tape_block *block,
                              libspectrum_buffer *buffer, size_t bits_per_symbol,
                              libspectrum_tape_generalised_data_symbol_table *pilot_table,
                              libspectrum_tape_generalised_data_symbol_table *data_table,
                              libspectrum_word pause_ms )
{
  size_t data_length;
  libspectrum_error error;
  libspectrum_dword pilot_symbol_count, data_symbol_count, i;

  data_length = generalised_data_length( pilot_table, data_table,
                                         bits_per_symbol );

  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA );
  libspectrum_buffer_write_dword( buffer, data_length );

  libspectrum_buffer_write_word( buffer, pause_ms );

  error = serialise_generalised_data_table( buffer, pilot_table );
  if( error != LIBSPECTRUM_ERROR_NONE ) return error;

  error = serialise_generalised_data_table( buffer, data_table );
  if( error != LIBSPECTRUM_ERROR_NONE ) return error;

  serialise_generalised_data_symbols( buffer, pilot_table );

  pilot_symbol_count = libspectrum_tape_generalised_data_symbol_table_symbols_in_block( pilot_table );

  for( i = 0; i < pilot_symbol_count; i++ ) {
    libspectrum_buffer_write_byte( buffer, libspectrum_tape_block_pilot_symbols( block, i ) );
    libspectrum_buffer_write_word( buffer, libspectrum_tape_block_pilot_repeats( block, i ) );
  }

  serialise_generalised_data_symbols( buffer, data_table );

  data_symbol_count = libspectrum_tape_generalised_data_symbol_table_symbols_in_block( data_table );

  data_length =
    libspectrum_bits_to_bytes( bits_per_symbol * data_symbol_count );

  libspectrum_buffer_write( buffer, libspectrum_tape_block_data( block ), data_length );

  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
tzx_write_generalised_data( libspectrum_tape_block *block,
                            libspectrum_buffer *buffer )
{ 
  size_t bits_per_symbol;
  libspectrum_tape_generalised_data_symbol_table *pilot_table, *data_table;

  pilot_table = libspectrum_tape_block_pilot_table( block );
  data_table = libspectrum_tape_block_data_table( block );

  bits_per_symbol = libspectrum_tape_block_bits_per_data_symbol( block );

  return write_generalised_data_block( block, buffer,
                                       bits_per_symbol, pilot_table, data_table,
                                       libspectrum_tape_block_pause( block ) );
}

static void
tzx_write_pause( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  /* A zero-duration pause is a stop, regardless of unspecified polarity. */
  if( !libspectrum_tape_block_pause_tstates( block ) ) {
    libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_buffer_write_word( buffer, 0 );
    return;
  }

  /* High pause when represented in the TZX format is really a set signal level
     1 and then a pulse as TZX format says that all pauses are low, a don't care
     pause is a pulse too */
  if( libspectrum_tape_block_level( block ) != 0 ) {
    if( libspectrum_tape_block_level( block ) == 1 ) {
      add_initial_pulse_level_block( buffer, 1 );
    }

    add_pure_tone_block( buffer,
                         libspectrum_tape_block_pause_tstates( block ), 1 );

    return;
  }

  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_buffer_write_word( buffer, libspectrum_tape_block_pause( block ) );
}

static void
tzx_write_group_start( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
  tzx_write_string( buffer, libspectrum_tape_block_text( block ) );
}

static void
tzx_write_jump( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  int u_offset;

  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_JUMP );

  u_offset = libspectrum_tape_block_offset( block );
  if( u_offset < 0 ) u_offset += 65536;
  libspectrum_buffer_write_word( buffer, u_offset );
}

static void
tzx_write_loop_start( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_LOOP_START );
  libspectrum_buffer_write_word( buffer,
                                   libspectrum_tape_block_count( block ) );
}

static void
tzx_write_select( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  size_t count, total_length, i;

  /* The length excludes the ID and its own two bytes. */
  count = libspectrum_tape_block_count( block );
  total_length = 1 + 3 * count;

  for( i = 0; i < count; i++ )
    total_length += strlen( (char*)libspectrum_tape_block_texts( block, i ) );

  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_SELECT );
  libspectrum_buffer_write_word( buffer, total_length );
  libspectrum_buffer_write_byte( buffer, count );

  for( i = 0; i < count; i++ ) {
    libspectrum_buffer_write_word( buffer, libspectrum_tape_block_offsets( block, i ) );
    tzx_write_string( buffer, libspectrum_tape_block_texts( block, i ) );
  }
}

static void
tzx_write_stop( libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_STOP48 );
  libspectrum_buffer_write_dword( buffer, 0 );
}

static void
add_set_signal_level_block( libspectrum_buffer *buffer, int level )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
  libspectrum_buffer_write_dword( buffer, 1 );
  libspectrum_buffer_write_byte( buffer, level );
}

/* TZX pulse-producing blocks start by making an edge from the current signal
   level.  PZX-style blocks instead store the level of their first pulse, so
   set the TZX current level to its opposite before serialising one. */
static void
add_initial_pulse_level_block( libspectrum_buffer *buffer, int level )
{
  add_set_signal_level_block( buffer, !level );
}

static void
tzx_write_set_signal_level( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  add_set_signal_level_block( buffer, libspectrum_tape_block_level( block ) );
}

static void
tzx_write_comment( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_COMMENT );
  tzx_write_string( buffer, libspectrum_tape_block_text( block ) );
}

static void
tzx_write_message( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
  libspectrum_buffer_write_byte( buffer,
                                libspectrum_tape_block_pause( block ) / 1000 );
  tzx_write_string( buffer, libspectrum_tape_block_text( block ) );
}

static libspectrum_error
validate_archive_info( libspectrum_tape_block *block )
{
  size_t i, count = libspectrum_tape_block_count( block ), size = 1;
  if( count > 255 ) return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < count; i++ ) {
    const char *text = libspectrum_tape_block_texts( block, i );
    int id = libspectrum_tape_block_ids( block, i );
    if( !text || strlen( text ) > 255 || id < 0 || id > 255 )
      return LIBSPECTRUM_ERROR_INVALID;
    size += 2 + strlen( text );
  }
  return size > 65535 ? LIBSPECTRUM_ERROR_INVALID : LIBSPECTRUM_ERROR_NONE;
}

static void
tzx_write_archive_info( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  size_t i, count, total_length;

  count = libspectrum_tape_block_count( block );

  /* 1 count byte, 2 bytes (ID and length) for every string */
  total_length = 1 + 2 * count;
  /* And then the length of all the strings */
  for( i = 0; i < count; i++ )
    total_length += strlen( (char*)libspectrum_tape_block_texts( block, i ) );

  /* Write out the metadata */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO );
  libspectrum_buffer_write_word( buffer, total_length );
  libspectrum_buffer_write_byte( buffer, count );

  /* And the strings */
  for( i = 0; i < count; i++ ) {
    libspectrum_buffer_write_byte( buffer, libspectrum_tape_block_ids( block, i ) );
    tzx_write_string( buffer, libspectrum_tape_block_texts( block, i ) );
  }
}

static void
tzx_write_hardware( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  size_t i;
  size_t count = libspectrum_tape_block_count( block );

  /* Write out the metadata */
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_HARDWARE );
  libspectrum_buffer_write_byte( buffer, count );

  /* And the info */
  for( i = 0; i < count; i++ ) {
    libspectrum_buffer_write_byte( buffer, libspectrum_tape_block_types( block, i ) );
    libspectrum_buffer_write_byte( buffer, libspectrum_tape_block_ids  ( block, i ) );
    libspectrum_buffer_write_byte( buffer, libspectrum_tape_block_values( block, i ) );
  }
}

static void
tzx_write_custom( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_CUSTOM );
  libspectrum_buffer_write( buffer, libspectrum_tape_block_text( block ), 16 );
  tzx_write_bytes( buffer, libspectrum_tape_block_data_length( block ), 4,
		   libspectrum_tape_block_data( block ) );
}

typedef struct {
  short bits_used; /* The bits used in the current byte in progress */
  short level; /* The last level output to this block */
  libspectrum_byte *tape_buffer; /* The buffer we are writing into */
  size_t tape_length; /* size of the buffer allocated so far */
  size_t length; /* size of the buffer used so far */
} rle_write_state;

static rle_write_state rle_state;

/* write a pulse of pulse_length bits into the tape_buffer */
static void
write_pulse( libspectrum_dword pulse_length )
{
  int i;
  size_t target_size = rle_state.length + pulse_length/8;

  if( rle_state.tape_length <= target_size ) {
    rle_state.tape_length = target_size * 2;
    rle_state.tape_buffer = libspectrum_renew( libspectrum_byte,
					       rle_state.tape_buffer,
					       rle_state.tape_length );
  }

  for( i = pulse_length; i > 0; i-- ) {
    if( rle_state.level ) 
      *(rle_state.tape_buffer + rle_state.length) |=
        1 << (7 - rle_state.bits_used);
    rle_state.bits_used++;

    if( rle_state.bits_used == 8 ) {
      rle_state.length++;
      *(rle_state.tape_buffer + rle_state.length) = 0;
      rle_state.bits_used = 0;
    }
  }

  rle_state.level = !rle_state.level;
}

/* Write an actual TZX CSW recording, preserving its rate and pause. */
static libspectrum_error
tzx_write_csw( libspectrum_tape_block *block, libspectrum_buffer *buffer )
{
  libspectrum_tape_tzx_csw_block *csw = &block->types.tzx_csw;
  libspectrum_byte *compressed = NULL, *data = csw->rle.data;
  size_t length = csw->rle.length, i;
  libspectrum_dword count = 0;
  libspectrum_byte compression = csw->compression;

  if( !csw->rle.sample_rate || csw->rle.sample_rate > 0xffffff ||
      (compression != 1 && compression != 2) )
    return LIBSPECTRUM_ERROR_INVALID;
  for( i = 0; i < length; ) {
    if( !data || (data[i] == 0 && length - i < 5) )
      return LIBSPECTRUM_ERROR_CORRUPT;
    i += data[i] ? 1 : 5;
    count++;
  }
  if( compression == 2 && !length ) compression = 1;
  if( compression == 2 ) {
#ifdef HAVE_ZLIB_H
    libspectrum_error error = libspectrum_zlib_compress( data, length,
                                                         &compressed, &length );
    if( error ) return error;
    data = compressed;
#else
    compression = 1; /* Produce a readable RLE block without zlib. */
#endif
  }
  if( length > 0xffffffffUL - 10 ) {
    libspectrum_free( compressed );
    return LIBSPECTRUM_ERROR_INVALID;
  }
  libspectrum_buffer_write_byte( buffer, LIBSPECTRUM_TAPE_BLOCK_TZX_CSW );
  libspectrum_buffer_write_dword( buffer, length + 10 );
  libspectrum_buffer_write_word( buffer, csw->pause );
  libspectrum_buffer_write_byte( buffer, csw->rle.sample_rate );
  libspectrum_buffer_write_byte( buffer, csw->rle.sample_rate >> 8 );
  libspectrum_buffer_write_byte( buffer, csw->rle.sample_rate >> 16 );
  libspectrum_buffer_write_byte( buffer, compression );
  libspectrum_buffer_write_dword( buffer, count );
  if( length ) libspectrum_buffer_write( buffer, data, length );
  libspectrum_free( compressed );
  return LIBSPECTRUM_ERROR_NONE;
}

/* Convert generic RLE blocks to a TZX direct recording block. */
static libspectrum_error
tzx_write_rle( libspectrum_tape_block *block, libspectrum_buffer *buffer,
               libspectrum_tape *tape,
               libspectrum_tape_iterator iterator )
{
  libspectrum_error error;
  libspectrum_tape_block_state it;
  libspectrum_dword scale = libspectrum_tape_block_scale( block );
  libspectrum_dword pulse_tstates = 0;
  libspectrum_dword balance_tstates = 0;
  int flags = 0;

  libspectrum_tape_block *raw_block = 
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );

  libspectrum_tape_block_set_bit_length( raw_block, scale );
  libspectrum_set_pause_ms( raw_block, 0 );

  rle_state.bits_used = 0;
  rle_state.level = block->types.rle_pulse.has_initial_level ?
    block->types.rle_pulse.initial_level : 0;
  rle_state.length = 0;
  rle_state.tape_length = 8192;
  rle_state.tape_buffer = libspectrum_new( libspectrum_byte, rle_state.tape_length );

  *rle_state.tape_buffer = 0;

  it.current_block = iterator;
  error = libspectrum_tape_block_init( block, &it );
  if( error != LIBSPECTRUM_ERROR_NONE ) {
    libspectrum_free( rle_state.tape_buffer );
    libspectrum_tape_block_free( raw_block );
    return error;
  }

  while( !(flags & LIBSPECTRUM_TAPE_FLAGS_BLOCK) ) {
    libspectrum_dword pulse_length = 0;

    /* Use internal version of this that doesn't bugger up the
       external tape status */
    error = libspectrum_tape_get_next_edge_internal( &pulse_tstates, &flags,
                                                     tape, &it );
    if( error != LIBSPECTRUM_ERROR_NONE ) {
      libspectrum_free( rle_state.tape_buffer );
      libspectrum_tape_block_free( raw_block );
      return error;
    }

    balance_tstates += pulse_tstates;

    /* next set of pulses is: balance_tstates / scale; */
    pulse_length = balance_tstates / scale;
    balance_tstates = balance_tstates % scale;

    /* write pulse_length bits of the current level into the buffer */
    write_pulse( pulse_length );
  }

  if( rle_state.length || rle_state.bits_used ) {
    if( rle_state.bits_used ) {
      rle_state.length++;
    } else {
      rle_state.bits_used = 8;
    }

    error = libspectrum_tape_block_set_bits_in_last_byte( raw_block,
                                                          rle_state.bits_used );
    if( error != LIBSPECTRUM_ERROR_NONE ) {
      libspectrum_free( rle_state.tape_buffer );
      libspectrum_tape_block_free( raw_block );
      return error;
    }

    error = libspectrum_tape_block_set_data_length( raw_block,
                                                    rle_state.length );
    if( error != LIBSPECTRUM_ERROR_NONE ) {
      libspectrum_free( rle_state.tape_buffer );
      libspectrum_tape_block_free( raw_block );
      return error;
    }

    error = libspectrum_tape_block_set_data( raw_block, rle_state.tape_buffer );
    if( error != LIBSPECTRUM_ERROR_NONE ) {
      libspectrum_free( rle_state.tape_buffer );
      libspectrum_tape_block_free( raw_block );
      return error;
    }

    /* now have tzx_write_raw_data finish the job */
    tzx_write_raw_data( raw_block, buffer );
  } else {
    libspectrum_free( rle_state.tape_buffer );
  }

  return libspectrum_tape_block_free( raw_block );
}

static void
tzx_write_empty_block( libspectrum_buffer *buffer, libspectrum_tape_type id )
{
  libspectrum_buffer_write_byte( buffer, id );
}

static void
tzx_write_bytes( libspectrum_buffer* buffer, size_t length, size_t length_bytes,
                 libspectrum_byte *data )
{
  size_t i, shifter;

  /* Write out the appropriate number of length bytes */
  for( i=0, shifter = length; i<length_bytes; i++, shifter >>= 8 )
    libspectrum_buffer_write_byte( buffer, shifter & 0xff );

  /* And then the actual data */
  libspectrum_buffer_write( buffer, data, length );
}

static void
tzx_write_string( libspectrum_buffer *buffer, char *string )
{
  size_t length = strlen( (char*)string ) & 0xff;
  const char *p = string;
  const char *end = string + length;
  const char *segment = p;

  libspectrum_buffer_write_byte( buffer, length );

  /* Write bulk segments between line-ending translations (\n -> \r).
     TZX strings rarely contain newlines, so the common case is one
     single libspectrum_buffer_write call for the whole string. */
  while( p < end ) {
    if( *p == '\x0a' ) {
      libspectrum_buffer_write( buffer, segment, p - segment );
      libspectrum_buffer_write_byte( buffer, '\x0d' );
      segment = p + 1;
    }
    p++;
  }
  libspectrum_buffer_write( buffer, segment, p - segment );
}
