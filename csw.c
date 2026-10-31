/* csw.c: Routines for reading CSW raw audio files
   Copyright (c) 2002-2026 Darren Salt, Fredrick Meunier
   Based on tap.c, copyright (c) 2001 Philip Kendall

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

   Author contact information:

   E-mail: linux@youmustbejoking.demon.co.uk

*/

#include "config.h"
#include <string.h>

#include "internals.h"
#include "tape_block.h"

/* The .csw file signature (first 23 bytes) */
static const char * const csw_signature = "Compressed Square Wave\x1a";

libspectrum_error
libspectrum_csw_read( libspectrum_tape *tape,
                      const libspectrum_byte *buffer, size_t length )
{
  libspectrum_tape_block *block = NULL;
  libspectrum_tape_rle_pulse_block *csw_block;
  int compressed, initial_high = 0;
  size_t signature_length = strlen( csw_signature );

  if( length < signature_length + 2 ) goto csw_short;
  if( memcmp( csw_signature, buffer, signature_length ) ) {
    libspectrum_print_error( LIBSPECTRUM_ERROR_SIGNATURE,
                            "libspectrum_csw_read: wrong signature" );
    return LIBSPECTRUM_ERROR_SIGNATURE;
  }
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  csw_block = &block->types.rle_pulse;
  buffer += signature_length;
  length -= signature_length;
  switch( buffer[0] ) {
  case 1:
    if( length < 9 ) goto csw_short;
    csw_block->scale = buffer[2] | buffer[3] << 8;
    if( buffer[4] != 1 ) goto csw_bad_compress;
    initial_high = buffer[5] & 1;
    compressed = 0;
    buffer += 9;
    length -= 9;
    break;
  case 2:
    if( length < 29 ) goto csw_short;
    csw_block->scale = libspectrum_read_dword_le( buffer + 2 );
    compressed = buffer[10] - 1;
    initial_high = buffer[11] & 1;
    if( compressed != 0 && compressed != 1 ) goto csw_bad_compress;
    if( length < 29 + (size_t)buffer[12] ) goto csw_short;
    length -= 29 + buffer[12];
    buffer += 29 + buffer[12];
    break;
  default:
    libspectrum_free( block );
    libspectrum_print_error( LIBSPECTRUM_ERROR_MEMORY,
                            "libspectrum_csw_read: unknown CSW version" );
    return LIBSPECTRUM_ERROR_SIGNATURE;
  }
  csw_block->sample_rate = csw_block->scale;
  if( csw_block->scale )
    csw_block->scale = 3500000 / csw_block->scale; /* legacy scale accessor */
  if( !csw_block->sample_rate ) {
    libspectrum_free( block );
    libspectrum_print_error( LIBSPECTRUM_ERROR_MEMORY,
                            "libspectrum_csw_read: bad sample rate" );
    return LIBSPECTRUM_ERROR_UNKNOWN;
  }
  if( !length ) goto csw_empty;
  if( compressed ) {
#ifdef HAVE_ZLIB_H
    csw_block->data = NULL;
    csw_block->length = 0;
    libspectrum_error error = libspectrum_zlib_inflate( buffer, length,
      &csw_block->data, &csw_block->length );
    if( error ) {
      libspectrum_free( block );
      return error;
    }
#else
    libspectrum_free( block );
    libspectrum_print_error( LIBSPECTRUM_ERROR_UNKNOWN,
                            "zlib not available to decompress gzipped file" );
    return LIBSPECTRUM_ERROR_UNKNOWN;
#endif
  } else {
    csw_block->length = length;
    csw_block->data = libspectrum_new( libspectrum_byte, length );
    memcpy( csw_block->data, buffer, length );
  }
  if( !csw_block->length ) goto csw_empty;
  /* Unlike embedded TZX CSW, standalone CSW specifies its first run level. */
  libspectrum_tape_block_set_level( block, initial_high );
  {
    libspectrum_error error = libspectrum_tape_append_block( tape, block );
    if( error ) libspectrum_tape_block_free( block );
    return error;
  }

csw_bad_compress:
  libspectrum_free( block );
  libspectrum_print_error( LIBSPECTRUM_ERROR_MEMORY,
                          "libspectrum_csw_read: unknown compression type" );
  return LIBSPECTRUM_ERROR_CORRUPT;
csw_short:
  libspectrum_free( block );
  libspectrum_print_error( LIBSPECTRUM_ERROR_CORRUPT,
                          "libspectrum_csw_read: not enough data in buffer" );
  return LIBSPECTRUM_ERROR_CORRUPT;
csw_empty:
  libspectrum_tape_block_free( block );
  return LIBSPECTRUM_ERROR_NONE;
}
