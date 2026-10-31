/* wav.c: Routines for handling WAV raw audio files
   Copyright (c) 2007-2026 Fredrick Meunier

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

   E-mail: fredm@spamcop.net

*/

#include "config.h"

#include <stdint.h>
#include <string.h>

#include "internals.h"
#include "tape_block.h"
#include "wav_internals.h"

libspectrum_error
libspectrum_wav_read( libspectrum_tape *tape, const char *filename )
{
  libspectrum_wav_reader *reader = NULL;
  libspectrum_signed_word *buffer = NULL;
  libspectrum_buffer *pulses = NULL;
  libspectrum_tape_block *block = NULL;
  size_t sample_rate, length, i;
  libspectrum_dword run;
  int high;
  size_t total_frames = 0, frames_read;
  libspectrum_error error;

  if( !filename ) {
    libspectrum_print_error(
      LIBSPECTRUM_ERROR_LOGIC,
      "libspectrum_wav_read: no filename provided - wav files can only be loaded from a file"
    );
    return LIBSPECTRUM_ERROR_LOGIC;
  }

  error = internal_wav_open( &reader, filename, &sample_rate, &length );
  if( error ) return error;

  if( !length ) {
    internal_wav_close( reader );
    libspectrum_print_error(
      LIBSPECTRUM_ERROR_CORRUPT,
      "libspectrum_wav_read: empty audio file, nothing to load"
    );
    return LIBSPECTRUM_ERROR_CORRUPT;
  }

  if( !sample_rate || sample_rate > UINT32_MAX ) {
    internal_wav_close( reader );
    libspectrum_print_error( LIBSPECTRUM_ERROR_INVALID,
                            "libspectrum_wav_read: invalid sample rate" );
    return LIBSPECTRUM_ERROR_INVALID;
  }

  buffer = libspectrum_new( libspectrum_signed_word, length );

  while( total_frames < length ) {
    error = internal_wav_read( reader, buffer + total_frames,
                               length - total_frames, &frames_read );
    if( error ) goto error;

    if( !frames_read ) {
      libspectrum_print_error(
        LIBSPECTRUM_ERROR_CORRUPT,
        "libspectrum_wav_read: audio file ended after %lu frames, expected %lu",
        (unsigned long)total_frames, (unsigned long)length
      );
      error = LIBSPECTRUM_ERROR_CORRUPT;
      goto error;
    }

    total_frames += frames_read;
  }

  /* Keep runs in samples: RLE playback carries fractional T-states from
     one run to the next, just as it does for CSW recordings. */
  pulses = libspectrum_buffer_alloc();
  high = buffer[0] > 0;
  run = 1;
  for( i = 1; i <= length; i++ ) {
    if( i < length && ( buffer[i] > 0 ) == high ) {
      if( run == UINT32_MAX ) {
        error = LIBSPECTRUM_ERROR_INVALID;
        libspectrum_print_error( error,
                                "libspectrum_wav_read: sample run too long" );
        goto error;
      }
      run++;
      continue;
    }
    if( run <= 0xff ) {
      libspectrum_buffer_write_byte( pulses, run );
    } else {
      libspectrum_buffer_write_byte( pulses, 0 );
      libspectrum_buffer_write_dword( pulses, run );
    }
    high = !high;
    run = 1;
  }

  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  block->types.rle_pulse.sample_rate = sample_rate;
  block->types.rle_pulse.scale = 3500000 / sample_rate;
  block->types.rle_pulse.length = libspectrum_buffer_get_data_size( pulses );
  block->types.rle_pulse.data =
    libspectrum_new( libspectrum_byte, block->types.rle_pulse.length );
  memcpy( block->types.rle_pulse.data, libspectrum_buffer_get_data( pulses ),
          block->types.rle_pulse.length );

  libspectrum_tape_block_set_level( block, buffer[0] > 0 );
  error = libspectrum_tape_append_block( tape, block );
  if( error ) goto error;
  block = NULL; /* tape owns the block now */

  internal_wav_close( reader );
  libspectrum_free( buffer );
  libspectrum_buffer_free( pulses );
  return LIBSPECTRUM_ERROR_NONE;

error:
  internal_wav_close( reader );
  libspectrum_free( buffer );
  if( pulses ) libspectrum_buffer_free( pulses );
  if( block ) libspectrum_tape_block_free( block );
  return error;
}
