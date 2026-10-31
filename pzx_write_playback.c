/* pzx_write_playback.c: Private waveform inspection for PZX output
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
#include "pzx_write_internal.h"

int
internal_pzx_needs_playback( libspectrum_tape_block *block )
{
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA:
  case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
  case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
  case LIBSPECTRUM_TAPE_BLOCK_PURE_TONE:
  case LIBSPECTRUM_TAPE_BLOCK_PULSES:
  case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
  case LIBSPECTRUM_TAPE_BLOCK_ROM:
  case LIBSPECTRUM_TAPE_BLOCK_TURBO:
  case LIBSPECTRUM_TAPE_BLOCK_PURE_DATA: return 1;
  case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
    return libspectrum_tape_block_level( block ) == -1 &&
           libspectrum_tape_block_pause_tstates( block );
  default: return 0;
  }
}

libspectrum_error
internal_pzx_prepare_playback( pzx_writer *writer, libspectrum_tape *tape,
                               libspectrum_tape_iterator *plan, size_t visits )
{
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  size_t i;
  if( plan ) {
    writer->need_playback = 0;
    for( i = 0; i < visits; i++ )
      writer->need_playback |= internal_pzx_needs_playback(
        libspectrum_tape_iterator_current( plan[i] ) );
  }
  if( !writer->need_playback ) return LIBSPECTRUM_ERROR_NONE;
  /* Native-only writing accepts zero-pulse bit encodings, but playback
     inspection currently cannot handle them. */
  libspectrum_tape_iterator_init( &it, tape );
  for( i = 0; i < visits; i++ ) {
    block = libspectrum_tape_iterator_current( plan ? plan[i] : it );
    if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK &&
        libspectrum_tape_block_count( block ) &&
        ( !libspectrum_tape_block_bit0_pulse_count( block ) ||
          !libspectrum_tape_block_bit1_pulse_count( block ) ) )
      return LIBSPECTRUM_ERROR_UNKNOWN;
    if( !plan ) libspectrum_tape_iterator_next( &it );
  }
  writer->state.force_low_level = 1;
  if( libspectrum_tape_iterator_init( &it, tape ) &&
      !libspectrum_tape_block_internal_init( &writer->state, tape ) )
    return LIBSPECTRUM_ERROR_INVALID;
  return LIBSPECTRUM_ERROR_NONE;
}

static void
update_level( pzx_writer *writer, int flags )
{
  if( flags & LIBSPECTRUM_TAPE_FLAGS_LEVEL_LOW ) writer->level = 0;
  else if( flags & LIBSPECTRUM_TAPE_FLAGS_LEVEL_HIGH ) writer->level = 1;
  else if( !( flags & LIBSPECTRUM_TAPE_FLAGS_NO_EDGE ) )
    writer->level = !writer->level;
  writer->last = writer->level;
  writer->state.signal_level = writer->level;
}

static int
recording_pause_pending( pzx_writer *writer, libspectrum_tape_type type )
{
  switch( type ) {
  case LIBSPECTRUM_TAPE_BLOCK_TZX_CSW:
    return writer->state.block_state.rle_pulse.csw_pause_pending;
  case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA:
    return writer->state.block_state.generalised_data.state ==
           LIBSPECTRUM_TAPE_STATE_PAUSE;
  default: return 0;
  }
}

/* PULS begins low. Preserve zero-time transitions and split long runs
   without altering either the elapsed time or their held level. */
static libspectrum_error
write_recording_pulse( libspectrum_buffer *body, int *next_level,
                       int level, libspectrum_dword duration )
{
  libspectrum_error error;
  if( level != *next_level ) {
    error = internal_pzx_write_pulse( body, 0, 1 );
    if( error ) return error;
    *next_level = !*next_level;
  }
  while( duration > PZX_VALUE_MASK ) {
    error = internal_pzx_write_pulse( body, PZX_VALUE_MASK, 1 );
    if( error ) return error;
    error = internal_pzx_write_pulse( body, 0, 1 );
    if( error ) return error;
    duration -= PZX_VALUE_MASK;
  }
  error = internal_pzx_write_pulse( body, duration, 1 );
  if( error ) return error;
  *next_level = !*next_level;
  return LIBSPECTRUM_ERROR_NONE;
}

/* Keep inspection independent of the caller's cursor and polarity. */
libspectrum_error
internal_pzx_inspect_block( pzx_writer *writer, libspectrum_tape *tape,
                            libspectrum_tape_iterator next )
{
  libspectrum_error error;
  libspectrum_dword duration;
  libspectrum_tape_block *block = libspectrum_tape_iterator_current(
    writer->state.current_block );
  libspectrum_tape_type type = libspectrum_tape_block_type( block );
  int recording = type == LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE ||
                  type == LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ||
                  type == LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA;
  int flags, initial = 1, next_level = 0;
  if( type == LIBSPECTRUM_TAPE_BLOCK_JUMP ) {
    /* A jump is a zero-time, no-edge event. Preserve both the held level
       and any pending low reset; use the checked target without searching
       the source list again on every visit. */
    if( !next ) return LIBSPECTRUM_ERROR_LOGIC;
    writer->state.current_block = next;
    return libspectrum_tape_block_init(
      libspectrum_tape_iterator_current( next ), &writer->state );
  }
  if( type == LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE &&
      !libspectrum_tape_block_data_length( block ) ) {
    block = libspectrum_tape_iterator_next( &writer->state.current_block );
    return libspectrum_tape_block_init( block, &writer->state );
  }
  do {
    /* Check the phase before playback advances into the tail pause. */
    int pause = recording_pause_pending( writer, type );
    error = libspectrum_tape_get_next_edge_internal( &duration, &flags, tape,
                                                    &writer->state );
    if( error ) return error;
    update_level( writer, flags );
    if( initial ) { writer->first = writer->level; initial = 0; }
    if( recording && !pause &&
        ( duration || !( flags & LIBSPECTRUM_TAPE_FLAGS_NO_EDGE ) ) ) {
      error = write_recording_pulse( writer->body, &next_level,
                                    writer->level, duration );
      if( error ) return error;
    }
  } while( !( flags & LIBSPECTRUM_TAPE_FLAGS_BLOCK ) );
  return LIBSPECTRUM_ERROR_NONE;
}
