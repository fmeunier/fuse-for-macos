/* creator.c: simple type for storing creator information
   Copyright (c) 2003-2015 Philip Kendall

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

#include "internals.h"

struct libspectrum_creator {

  char program[32];
  libspectrum_word major, minor;

  libspectrum_dword competition_code;

  libspectrum_byte *custom;
  size_t custom_length;

};

libspectrum_creator*
libspectrum_creator_alloc( void )
{
  return libspectrum_new0( libspectrum_creator, 1 );
}

libspectrum_error
libspectrum_creator_free( libspectrum_creator *creator )
{
  if( creator->custom ) libspectrum_free( creator->custom );
  libspectrum_free( creator );

  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_error
libspectrum_creator_set_program( libspectrum_creator *creator,
				 const char *program )
{
  char *utf8;
  size_t length;
  internal_tape_text_convert( program, 2, &utf8 );
  length = strlen( utf8 );
  if( length >= sizeof( creator->program ) ) {
    length = sizeof( creator->program ) - 1;
    while( length && ( (unsigned char)utf8[length] & 0xc0 ) == 0x80 ) length--;
  }
  memset( creator->program, 0, sizeof( creator->program ) );
  memcpy( creator->program, utf8, length );
  libspectrum_free( utf8 );
  return LIBSPECTRUM_ERROR_NONE;
}

const char*
libspectrum_creator_program( const libspectrum_creator *creator )
{
  return creator->program;
}

libspectrum_error libspectrum_creator_set_major( libspectrum_creator *creator,
                                                 libspectrum_word major )
{
  creator->major = major;
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_word
libspectrum_creator_major( const libspectrum_creator *creator )
{
  return creator->major;
}

libspectrum_error libspectrum_creator_set_minor( libspectrum_creator *creator,
                                                 libspectrum_word minor )
{
  creator->minor = minor;
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_word
libspectrum_creator_minor( const libspectrum_creator *creator )
{
  return creator->minor;
}

libspectrum_error
libspectrum_creator_set_competition_code( libspectrum_creator *creator,
					  libspectrum_dword competition_code )
{
  creator->competition_code = competition_code;
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_dword
libspectrum_creator_competition_code( const libspectrum_creator *creator )
{
  return creator->competition_code;
}

libspectrum_error
libspectrum_creator_set_custom( libspectrum_creator *creator,
				libspectrum_byte *data, size_t length )
{
  creator->custom = data;
  creator->custom_length = length;
  return LIBSPECTRUM_ERROR_NONE;
}

libspectrum_byte*
libspectrum_creator_custom( const libspectrum_creator *creator )
{
  return creator->custom;
}

size_t
libspectrum_creator_custom_length( const libspectrum_creator *creator )
{
  return creator->custom_length;
}
