/* test/tape-text.c: Tape metadata encoding tests
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
#include "test.h"

static char *
copy_text( const char *text )
{
  char *copy = libspectrum_new( char, strlen( text ) + 1 );
  strcpy( copy, text );
  return copy;
}

test_return_t
tape_text_cp1252_mappings( void )
{
  /* Independent expected UTF-8 spellings for the CP1252 extension range. */
  static const char * const extensions[] = {
    "\xe2\x82\xac", "?", "\xe2\x80\x9a", "\xc6\x92",
    "\xe2\x80\x9e", "\xe2\x80\xa6", "\xe2\x80\xa0", "\xe2\x80\xa1",
    "\xcb\x86", "\xe2\x80\xb0", "\xc5\xa0", "\xe2\x80\xb9",
    "\xc5\x92", "?", "\xc5\xbd", "?",
    "?", "\xe2\x80\x98", "\xe2\x80\x99", "\xe2\x80\x9c",
    "\xe2\x80\x9d", "\xe2\x80\xa2", "\xe2\x80\x93", "\xe2\x80\x94",
    "\xcb\x9c", "\xe2\x84\xa2", "\xc5\xa1", "\xe2\x80\xba",
    "\xc5\x93", "?", "\xc5\xbe", "\xc5\xb8"
  };
  char *utf8 = NULL, *encoded = NULL;
  char all[256], expected_all[768], *end = expected_all;
  size_t i;
  test_return_t result = TEST_FAIL;
  for( i = 1; i < 256; i++ ) {
    char source[2] = { (char)i, 0 }, expected[3];
    const char *value;
    int undefined = i == 0x81 || i == 0x8d || i == 0x8f ||
                    i == 0x90 || i == 0x9d;
    if( i >= 0x80 && i < 0xa0 ) value = extensions[i - 0x80];
    else {
      if( i < 0x80 ) { expected[0] = i; expected[1] = 0; }
      else { expected[0] = 0xc0 | ( i >> 6 ); expected[1] = 0x80 | ( i & 63 ); expected[2] = 0; }
      value = expected;
    }
    if( internal_tape_text_convert( source, 1, &utf8 ) ) goto done;
    if( undefined ) {
      /* Native converters may preserve controls or substitute undefined
         bytes. Require valid UTF-8, not a particular replacement. */
      if( internal_tape_text_convert( utf8, 2, &encoded ) ||
          strcmp( utf8, encoded ) ) goto done;
    } else {
      if( strcmp( utf8, value ) ||
          internal_tape_text_convert( utf8, 0, &encoded ) ||
          (unsigned char)encoded[0] != i || encoded[1] ) goto done;
    }
    all[i - 1] = i;
    memcpy( end, utf8, strlen( utf8 ) ); end += strlen( utf8 );
    libspectrum_free( utf8 ); utf8 = NULL;
    libspectrum_free( encoded ); encoded = NULL;
  }
  all[255] = 0; *end = 0;
  /* Exercise iconv's output-buffer refill, not just single characters. */
  if( internal_tape_text_convert( all, 1, &utf8 ) ||
      strcmp( utf8, expected_all ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( utf8 ); libspectrum_free( encoded );
  return result;
}

test_return_t
tape_text_malformed_and_substitution( void )
{
  static const char * const input[] = {
    "", "A\x80" "Z", "A\xff" "Z", "A\xc0\xaf" "Z",
    "A\xed\xa0\x80" "Z", "A\xf4\x90\x80\x80" "Z",
    "A\xf0\x80\x80\x80" "Z", "A\xe2(\xa1" "Z",
    "A\xc3", "A\xe2\x82", "A\xf0\x9f\x98"
  };
  static const char * const expected[] = {
    "", "A?Z", "A?Z", "A??Z", "A???Z", "A????Z",
    "A????Z", "A?(?Z", "A?", "A??", "A???"
  };
  static const libspectrum_byte header[] = {
    'P', 'Z', 'X', 'T', 2, 0, 0, 0, 1, 0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_buffer *file = libspectrum_buffer_alloc();
  libspectrum_byte *out = NULL;
  char *converted = NULL;
  size_t i, mode, length = 0;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < sizeof( input ) / sizeof( input[0] ); i++ ) {
    for( mode = 0; mode <= 2; mode += 2 ) {
      if( internal_tape_text_convert( input[i], mode, &converted ) ||
          strcmp( converted, expected[i] ) ) goto done;
      libspectrum_free( converted ); converted = NULL;
    }
    libspectrum_tape_clear( tape ); libspectrum_tape_clear( dest );
    libspectrum_buffer_clear( file );
    libspectrum_buffer_write( file, header, sizeof( header ) );
    libspectrum_buffer_write( file, (const libspectrum_byte *)"BRWS", 4 );
    libspectrum_buffer_write_dword( file, strlen( input[i] ) );
    libspectrum_buffer_write( file, (const libspectrum_byte *)input[i], strlen( input[i] ) );
    if( libspectrum_tape_read( tape, libspectrum_buffer_get_data( file ),
          libspectrum_buffer_get_data_size( file ), LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
        strcmp( libspectrum_tape_block_text( libspectrum_tape_current_block( tape ) ), expected[i] ) )
      goto done;
    /* Writers must also sanitise malformed UTF-8 supplied directly by callers. */
    {
      libspectrum_tape_block *block = libspectrum_tape_current_block( tape );
      libspectrum_free( libspectrum_tape_block_text( block ) );
      libspectrum_tape_block_set_text( block, copy_text( input[i] ) );
    }
    for( mode = 0; mode < 2; mode++ ) {
      libspectrum_id_t format = mode ? LIBSPECTRUM_ID_TAPE_PZX : LIBSPECTRUM_ID_TAPE_TZX;
      libspectrum_tape_clear( dest );
      if( libspectrum_tape_write( &out, &length, tape, format ) ||
          libspectrum_tape_read( dest, out, length, format, NULL ) ||
          strcmp( libspectrum_tape_block_text( libspectrum_tape_current_block( dest ) ), expected[i] ) )
        goto done;
      libspectrum_free( out ); out = NULL; length = 0;
    }
  }
  /* An unassigned scalar has no near-equivalent: use the default character. */
  if( internal_tape_text_convert( "A\xf4\x8f\xbf\xbfZ", 0, &converted ) ||
      strcmp( converted, "A?Z" ) ) goto done;
  libspectrum_free( converted ); converted = NULL;
  if( internal_tape_text_convert( "A\xc4\x81Z", 0, &converted ) ||
      !*converted || converted[0] != 'A' ||
      converted[strlen( converted ) - 1] != 'Z' ) goto done;
  /* Accent transliteration may differ, but must be nonempty ASCII here. */
  if( strlen( converted ) < 3 ) goto done;
  for( i = 0; converted[i]; i++ ) if( (unsigned char)converted[i] >= 0x80 ) goto done;
#ifndef HAVE_ICONV
  if( strcmp( converted, "A?Z" ) ) goto done;
#endif
  result = TEST_PASS;
done:
  libspectrum_free( converted ); libspectrum_free( out );
  libspectrum_buffer_free( file );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
tape_text_metadata_and_binary_roundtrips( void )
{
  static const char text[] = "\xc3\xa9 \xe2\x82\xac \xe2\x80\x9c\nline";
  static const libspectrum_byte payload[] = { 0, 0x80, 0x81, 0xff, 0xc3, 0, '\r', '\n' };
  static const char identifier[] = "Binary\x80\xff\r\n      ";
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *b;
  libspectrum_tape_iterator it;
  libspectrum_byte *out = NULL, *data;
  char **strings;
  int *offsets;
  size_t length = 0, n, count;
  test_return_t result = TEST_FAIL;
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
  libspectrum_tape_block_set_text( b, copy_text( text ) );
  libspectrum_tape_append_block( tape, b );
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
  libspectrum_tape_block_set_text( b, copy_text( text ) );
  libspectrum_set_pause_ms( b, 3000 );
  libspectrum_tape_append_block( tape, b );
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SELECT );
  strings = libspectrum_new( char *, 1 ); strings[0] = copy_text( text );
  offsets = libspectrum_new( int, 1 ); offsets[0] = 1;
  libspectrum_tape_block_set_count( b, 1 );
  libspectrum_tape_block_set_texts( b, strings );
  libspectrum_tape_block_set_offsets( b, offsets );
  libspectrum_tape_append_block( tape, b );
  libspectrum_tape_append_block( tape,
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_END ) );
  b = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_CUSTOM );
  libspectrum_tape_block_set_text( b, copy_text( identifier ) );
  data = libspectrum_new( libspectrum_byte, sizeof( payload ) );
  memcpy( data, payload, sizeof( payload ) );
  libspectrum_tape_block_set_data( b, data );
  libspectrum_tape_block_set_data_length( b, sizeof( payload ) );
  libspectrum_tape_append_block( tape, b );
  for( n = 0; n < 3; n++ ) {
    count = 0;
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
    for( b = libspectrum_tape_iterator_init( &it, dest ); b;
         b = libspectrum_tape_iterator_next( &it ), count++ ) {
      switch( libspectrum_tape_block_type( b ) ) {
      case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
      case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
        if( strcmp( libspectrum_tape_block_text( b ), text ) ) goto done;
        if( libspectrum_tape_block_type( b ) == LIBSPECTRUM_TAPE_BLOCK_MESSAGE &&
            libspectrum_tape_block_pause( b ) != 3000 ) goto done;
        break;
      case LIBSPECTRUM_TAPE_BLOCK_SELECT:
        if( libspectrum_tape_block_count( b ) != 1 ||
            libspectrum_tape_block_offsets( b, 0 ) != 1 ||
            strcmp( libspectrum_tape_block_texts( b, 0 ), text ) ) goto done;
        break;
      case LIBSPECTRUM_TAPE_BLOCK_GROUP_END: break;
      case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
        if( memcmp( libspectrum_tape_block_text( b ), identifier, 16 ) ||
            libspectrum_tape_block_data_length( b ) != sizeof( payload ) ||
            memcmp( libspectrum_tape_block_data( b ), payload, sizeof( payload ) ) ) goto done;
        break;
      default: goto done;
      }
    }
    if( count != 5 ) goto done;
    libspectrum_free( out ); out = NULL; length = 0;
    libspectrum_tape_free( tape ); tape = dest; dest = libspectrum_tape_alloc();
  }
  /* Message seconds must fit one byte without wrapping. */
  if( libspectrum_tape_nth_block( tape, 1 ) ) goto done;
  b = libspectrum_tape_current_block( tape );
  libspectrum_set_pause_ms( b, 255000 );
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) ||
      libspectrum_tape_nth_block( dest, 1 ) ||
      libspectrum_tape_block_pause( libspectrum_tape_current_block( dest ) ) != 255000 )
    goto done;
  libspectrum_free( out ); out = NULL; length = 0;
  libspectrum_set_pause_ms( b, 256000 );
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) !=
      LIBSPECTRUM_ERROR_INVALID || out || length ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}
