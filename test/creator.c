#include "config.h"

#include <stdio.h>
#include <string.h>

#include "internals.h"
#include "test.h"

test_return_t
creator_alloc_free_and_program_getter_setter( void )
{
  /* libspectrum_creator: alloc/free and program getter/setter */
  libspectrum_creator *creator = libspectrum_creator_alloc();
  test_return_t r = TEST_FAIL;

  if( !creator ) {
    fprintf( stderr, "%s: creator_alloc_free_and_program_getter_setter: creator_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  libspectrum_creator_set_program( creator, "TestApp" );

  if( strcmp( (const char *)libspectrum_creator_program( creator ), "TestApp" ) != 0 ) {
    fprintf( stderr, "%s: creator_alloc_free_and_program_getter_setter: expected program \"TestApp\", got \"%s\"\n",
             progname, (const char *)libspectrum_creator_program( creator ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_creator_free( creator );
  return r;
}

test_return_t
creator_utf8_boundaries( void )
{
  static const char * const characters[] = {
    "\xc3\xa9", "\xe2\x82\xac", "\xf0\x9f\x98\x80"
  };
  libspectrum_creator *creator = libspectrum_creator_alloc();
  char text[40];
  size_t i, length, prefix;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 3; i++ ) {
    length = strlen( characters[i] );
    prefix = 32 - length;
    memset( text, 'A', prefix );
    strcpy( text + prefix, characters[i] );
    if( libspectrum_creator_set_program( creator, text ) ||
        strlen( libspectrum_creator_program( creator ) ) != prefix ||
        memcmp( libspectrum_creator_program( creator ), text, prefix ) ) goto done;
    prefix--;
    strcpy( text + prefix, characters[i] );
    if( libspectrum_creator_set_program( creator, text ) ||
        strcmp( libspectrum_creator_program( creator ), text ) ) goto done;
  }
  if( libspectrum_creator_set_program( creator, "A\xc3" ) ||
      strcmp( libspectrum_creator_program( creator ), "A?" ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_creator_free( creator );
  return result;
}

test_return_t
creator_format_encodings( void )
{
  static const char name[] = "Tool \xc3\xa9 \xf4\x8f\xbf\xbf";
  static const libspectrum_byte custom[] = { 0, 0x80, 0xff, '\r' };
  static const libspectrum_byte invalid_rzx[] = {
    'R', 'Z', 'X', '!', 0, 13, 0, 0, 0, 0,
    0x10, 29, 0, 0, 0,
    0xe9, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0
  };
  libspectrum_creator *creator = libspectrum_creator_alloc();
  libspectrum_rzx *rzx = libspectrum_rzx_alloc(), *read = libspectrum_rzx_alloc();
  libspectrum_snap *snap = libspectrum_snap_alloc();
  const libspectrum_creator *loaded;
  libspectrum_byte *out = NULL, *data = libspectrum_new( libspectrum_byte, sizeof( custom ) );
  libspectrum_byte expected_ascii[20] = { 0 }, expected_utf8[32] = { 0 };
  char *ascii = NULL;
  size_t length = 0, i, offset;
  int flags, found = 0;
  test_return_t result = TEST_FAIL;
  memcpy( data, custom, sizeof( custom ) );
  libspectrum_creator_set_custom( creator, data, sizeof( custom ) );
  libspectrum_creator_set_program( creator, name );
  libspectrum_creator_set_major( creator, 1 );
  libspectrum_creator_set_minor( creator, 2 );
  if( internal_tape_text_convert( name, 3, &ascii ) || strlen( ascii ) > 20 ) goto done;
  for( i = 0; ascii[i]; i++ ) if( (unsigned char)ascii[i] >= 0x80 ) goto done;
  if( !strchr( ascii, '?' ) ) goto done;
  memcpy( expected_ascii, ascii, strlen( ascii ) );
  memcpy( expected_utf8, name, strlen( name ) );
  if( libspectrum_rzx_write( &out, &length, rzx, LIBSPECTRUM_ID_SNAPSHOT_SZX,
                            creator, 0, NULL ) ||
      length < 43 || memcmp( out + 15, expected_ascii, 20 ) ||
      memcmp( out + 39, custom, sizeof( custom ) ) ||
      strcmp( libspectrum_creator_program( creator ), name ) ||
      libspectrum_rzx_read( read, out, length ) ) goto done;
  loaded = libspectrum_rzx_creator( read );
  if( !loaded || strcmp( libspectrum_creator_program( loaded ), ascii ) ||
      libspectrum_creator_custom_length( loaded ) != sizeof( custom ) ||
      memcmp( libspectrum_creator_custom( loaded ), custom, sizeof( custom ) ) ) goto done;
  libspectrum_free( out ); out = NULL; length = 0;
  /* Apply the RZX width limit after transliteration, not to UTF-8 bytes. */
  libspectrum_creator_set_program( creator, "1234567890123456789\xc3\xa9" "ABC" );
  if( libspectrum_rzx_write( &out, &length, rzx, LIBSPECTRUM_ID_SNAPSHOT_SZX,
                            creator, 0, NULL ) ||
      memcmp( out + 15, "1234567890123456789", 19 ) ||
      !out[34] || out[34] >= 0x80 ||
      strcmp( libspectrum_creator_program( creator ),
              "1234567890123456789\xc3\xa9" "ABC" ) ) goto done;
  libspectrum_free( out ); out = NULL; length = 0;
  libspectrum_creator_set_program( creator, name );
  libspectrum_snap_set_machine( snap, LIBSPECTRUM_MACHINE_48 );
  if( libspectrum_snap_write( &out, &length, &flags, snap,
                             LIBSPECTRUM_ID_SNAPSHOT_SZX, creator, 0 ) ) goto done;
  for( offset = 8; offset + 8 <= length; ) {
    size_t size = libspectrum_read_dword_le( out + offset + 4 );
    if( size > length - offset - 8 ) goto done;
    if( !memcmp( out + offset, "CRTR", 4 ) ) {
      if( size != 36 + sizeof( custom ) ||
          memcmp( out + offset + 8, expected_utf8, 32 ) ||
          memcmp( out + offset + 44, custom, sizeof( custom ) ) ) goto done;
      found++;
    }
    offset += 8 + size;
  }
  if( found != 1 || strcmp( libspectrum_creator_program( creator ), name ) ) goto done;
  libspectrum_rzx_free( read ); read = libspectrum_rzx_alloc();
  if( libspectrum_rzx_read( read, invalid_rzx, sizeof( invalid_rzx ) ) ||
      !libspectrum_rzx_creator( read ) ||
      strcmp( libspectrum_creator_program( libspectrum_rzx_creator( read ) ), "?" ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( ascii ); libspectrum_free( out );
  libspectrum_creator_free( creator );
  libspectrum_snap_free( snap );
  libspectrum_rzx_free( rzx ); libspectrum_rzx_free( read );
  return result;
}

test_return_t
creator_major_and_minor_version_getter_setter( void )
{
  /* libspectrum_creator: major and minor version getter/setter */
  libspectrum_creator *creator = libspectrum_creator_alloc();
  test_return_t r = TEST_FAIL;

  if( !creator ) {
    fprintf( stderr, "%s: creator_major_and_minor_version_getter_setter: creator_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  libspectrum_creator_set_major( creator, 2 );
  libspectrum_creator_set_minor( creator, 7 );

  if( libspectrum_creator_major( creator ) != 2 ) {
    fprintf( stderr, "%s: creator_major_and_minor_version_getter_setter: expected major 2, got %d\n",
             progname, libspectrum_creator_major( creator ) );
    goto done;
  }

  if( libspectrum_creator_minor( creator ) != 7 ) {
    fprintf( stderr, "%s: creator_major_and_minor_version_getter_setter: expected minor 7, got %d\n",
             progname, libspectrum_creator_minor( creator ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_creator_free( creator );
  return r;
}

test_return_t
creator_competition_code_and_custom_data_getter_setter( void )
{
  /* libspectrum_creator: competition_code and custom data getter/setter */
  libspectrum_creator *creator = libspectrum_creator_alloc();
  libspectrum_byte *custom_data;
  const libspectrum_byte *got_custom;
  test_return_t r = TEST_FAIL;

  if( !creator ) {
    fprintf( stderr, "%s: creator_competition_code_and_custom_data_getter_setter: creator_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  libspectrum_creator_set_competition_code( creator, 0x1234 );

  if( libspectrum_creator_competition_code( creator ) != 0x1234 ) {
    fprintf( stderr, "%s: creator_competition_code_and_custom_data_getter_setter: expected competition_code 0x1234, got 0x%04x\n",
             progname, libspectrum_creator_competition_code( creator ) );
    goto done;
  }

  custom_data = libspectrum_new( libspectrum_byte, 4 );
  custom_data[0] = 0xde; custom_data[1] = 0xad;
  custom_data[2] = 0xbe; custom_data[3] = 0xef;

  libspectrum_creator_set_custom( creator, custom_data, 4 );

  if( libspectrum_creator_custom_length( creator ) != 4 ) {
    fprintf( stderr, "%s: creator_competition_code_and_custom_data_getter_setter: expected custom_length 4, got %lu\n",
             progname, (unsigned long)libspectrum_creator_custom_length( creator ) );
    goto done;
  }

  got_custom = libspectrum_creator_custom( creator );
  if( got_custom[0] != 0xde || got_custom[1] != 0xad ||
      got_custom[2] != 0xbe || got_custom[3] != 0xef ) {
    fprintf( stderr, "%s: creator_competition_code_and_custom_data_getter_setter: custom data mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_creator_free( creator );
  return r;
}
