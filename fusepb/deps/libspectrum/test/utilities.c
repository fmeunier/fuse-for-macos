/* utilities.c: unit tests for libspectrum utility functions
   Copyright (c) 2026 Philip Kendall

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

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "internals.h"
#include "test.h"

static libspectrum_byte
mmc_command( libspectrum_mmc_card *card, libspectrum_byte command,
             libspectrum_dword argument )
{
  int shift;
  libspectrum_mmc_write( card, 0x40 | command );
  for( shift = 24; shift >= 0; shift -= 8 )
    libspectrum_mmc_write( card, ( argument >> shift ) & 0xff );
  libspectrum_mmc_write( card, 0xff );
  return libspectrum_mmc_read( card );
}

static int
mmc_initialise( libspectrum_mmc_card *card )
{
  int i;
  libspectrum_mmc_reset( card );
  if( mmc_command( card, 8, 0x1aa ) != 1 ) return 1;
  for( i = 0; i < 4; i++ ) libspectrum_mmc_read( card );
  return mmc_command( card, 55, 0 ) != 1 ||
         mmc_command( card, 41, 0x40000000 ) != 0;
}

test_return_t
mmc_high_bit_command_arguments( void )
{
  libspectrum_hdf_header header;
  libspectrum_mmc_card *card = NULL;
  const char *filename = "test-mmc-dword.hdf";
  FILE *file;
  int fd, flags = O_WRONLY | O_CREAT | O_EXCL;
  test_return_t r = TEST_INCOMPLETE;
  size_t i, j;
  static const libspectrum_dword arguments[] = { 0x80000001, 0xffffffff };

  /* Avoid overwriting an existing file, without relying on C11 fopen modes
     that older Windows runtimes do not support. */
#ifdef O_BINARY
  flags |= O_BINARY;
#endif
  fd = open( filename, flags, 0600 );
  if( fd < 0 ) {
    fprintf( stderr, "%s: unable to create %s: %s\n",
             progname, filename, strerror( errno ) );
    return r;
  }
  file = fdopen( fd, "wb" );
  if( !file ) {
    fprintf( stderr, "%s: unable to open stream for %s: %s\n",
             progname, filename, strerror( errno ) );
    close( fd );
    goto done;
  }
  memset( &header, 0, sizeof( header ) );
  memcpy( header.signature, "RS-IDE", 6 );
  header.id = 0x1a;
  header.datastart_low = sizeof( header );
  /* 1024 sectors; all tested accesses must be rejected before disk I/O. */
  header.drive_identity[3] = 4;
  header.drive_identity[6] = 1;
  header.drive_identity[12] = 1;
  if( fwrite( &header, 1, sizeof( header ), file ) != sizeof( header ) ) {
    fprintf( stderr, "%s: unable to write %s: %s\n",
             progname, filename, strerror( errno ) );
    fclose( file );
    goto done;
  }
  if( fclose( file ) ) {
    fprintf( stderr, "%s: unable to close %s: %s\n",
             progname, filename, strerror( errno ) );
    goto done;
  }
  card = libspectrum_mmc_alloc();
  if( libspectrum_mmc_insert( card, filename ) ) {
    fprintf( stderr, "%s: unable to insert MMC image %s\n",
             progname, filename );
    goto done;
  }
  r = TEST_FAIL;
  for( j = 0; j < sizeof( arguments ) / sizeof( arguments[0] ); j++ ) {
    libspectrum_dword argument = arguments[j];
    if( mmc_initialise( card ) || mmc_command( card, 17, argument ) != 0x40 ||
        mmc_command( card, 32, argument ) != 0x40 ||
        mmc_command( card, 32, 0 ) != 0 ||
        mmc_command( card, 33, argument ) != 0x40 ||
        mmc_command( card, 24, argument ) != 0 ) goto done;
    libspectrum_mmc_write( card, 0xfe );
    for( i = 0; i < 514; i++ ) libspectrum_mmc_write( card, 0 );
    if( libspectrum_mmc_read( card ) != 0x40 ||
        libspectrum_mmc_dirty( card ) ) goto done;
  }
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: MMC high-bit argument mismatch\n", progname );
  if( card ) libspectrum_mmc_free( card );
  if( remove( filename ) ) {
    fprintf( stderr, "%s: unable to remove %s\n", progname, filename );
    r = TEST_FAIL;
  }
  return r;
}

test_return_t
utilities_dword_decoders( void )
{
  static const libspectrum_dword values[] = {
    0, 0x12345678, 0x80000001, 0xffffffff
  };
  libspectrum_byte le[5], be[5];
  const libspectrum_byte *ptr;
  size_t i;

  for( i = 0; i < sizeof( values ) / sizeof( values[0] ); i++ ) {
    libspectrum_dword value = values[i];
    size_t j;

    /* Decode at an unaligned offset as well as checking the high bit. */
    for( j = 0; j < 4; j++ ) {
      le[j + 1] = ( value >> ( 8 * j ) ) & 0xff;
      be[4 - j] = le[j + 1];
    }
    ptr = le + 1;
    if( libspectrum_read_dword_le( ptr ) != value ||
        libspectrum_read_dword_be( be + 1 ) != value ||
        libspectrum_read_dword( &ptr ) != value || ptr != le + 5 ) {
      fprintf( stderr, "%s: dword decoder mismatch at %zu\n", progname, i );
      return TEST_FAIL;
    }
  }

  return TEST_PASS;
}

/* NULL source is invalid */
test_return_t
utilities_zx_string_to_utf8_null_source_is_invalid( void )
{
  char result[ 46 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), NULL, 5 ) !=
      LIBSPECTRUM_ERROR_INVALID ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_null_source_is_invalid: "
             "expected LIBSPECTRUM_ERROR_INVALID\n", progname );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* Plain ASCII text is passed through unchanged */
test_return_t
utilities_zx_string_to_utf8_plain_ascii( void )
{
  static const libspectrum_byte src[] = { 'H', 'E', 'L', 'L', 'O' };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_plain_ascii: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "HELLO" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_plain_ascii: "
             "expected \"HELLO\", got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* Trailing spaces are stripped before conversion */
test_return_t
utilities_zx_string_to_utf8_trailing_spaces_stripped( void )
{
  static const libspectrum_byte src[] = { 'H', 'I', ' ', ' ', ' ' };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_trailing_spaces_stripped: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "HI" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_trailing_spaces_stripped: "
             "expected \"HI\", got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* ZX Spectrum special characters convert to Unicode equivalents:
   0x5C (\) -> \\, 0x5E (^) -> U+2191 (↑), 0x60 (`) -> U+00A3 (£),
   0x7F -> U+00A9 (©) */
test_return_t
utilities_zx_string_to_utf8_special_chars( void )
{
  static const libspectrum_byte src[] = {
    '\\', '^', '`', 0x7f
  };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_special_chars: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  /* expected: "\\" + "↑" + "£" + "©" */
  if( strcmp( result, "\\\\" "\xe2\x86\x91" "\xc2\xa3" "\xc2\xa9" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_special_chars: "
             "unexpected result\n", progname );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* UDG characters (bytes 144–162) render as \a through \s */
test_return_t
utilities_zx_string_to_utf8_udg_char( void )
{
  /* 0x90 = 144 -> UDG 'a' -> rendered as \a */
  static const libspectrum_byte src[] = { 0x90 };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_udg_char: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "\\a" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_udg_char: "
             "expected \"\\\\a\", got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* Spectrum BASIC keyword tokens expand to keyword text.  128K-only
   tokens 0xA3 and 0xA4 are SPECTRUM and PLAY; 0xF7 is RUN and 0xF9
   is RANDOMIZE. */
test_return_t
utilities_zx_string_to_utf8_spectrum_token( void )
{
  static const libspectrum_byte src[] = {
    0xa3, ' ', 0xa4, ' ', 0xf7, ' ', 0xf9
  };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_spectrum_token: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "SPECTRUM PLAY RUN RANDOMIZE" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_spectrum_token: "
             "expected \"SPECTRUM PLAY RUN RANDOMIZE\", got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* A buffer without space for the terminating NUL is rejected */
test_return_t
utilities_zx_string_to_utf8_buffer_too_short_is_invalid( void )
{
  static const libspectrum_byte src[] = { 0xf9 };
  char result[ 9 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) != LIBSPECTRUM_ERROR_INVALID ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_buffer_too_short_is_invalid: "
             "expected LIBSPECTRUM_ERROR_INVALID\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_buffer_too_short_is_invalid: "
             "expected empty result\n", progname );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* libspectrum_version: returns a non-NULL, non-empty string */
test_return_t
utilities_version_returns_nonempty_string( void )
{
  const char *ver = libspectrum_version();
  if( !ver || ver[0] == '\0' ) {
    fprintf( stderr, "%s: utilities_version_returns_nonempty_string: "
             "expected non-empty version string\n", progname );
    return TEST_FAIL;
  }
  return TEST_PASS;
}

/* libspectrum_check_version: current version satisfies itself */
test_return_t
utilities_check_version_current_version_returns_true( void )
{
  const char *ver = libspectrum_version();
  if( !libspectrum_check_version( ver ) ) {
    fprintf( stderr, "%s: utilities_check_version_current_version_returns_true: "
             "expected 1 for version \"%s\"\n", progname, ver );
    return TEST_FAIL;
  }
  return TEST_PASS;
}

/* libspectrum_check_version: very old required version (0.0.0) is satisfied */
test_return_t
utilities_check_version_very_old_required_returns_true( void )
{
  if( !libspectrum_check_version( "0.0.0" ) ) {
    fprintf( stderr, "%s: utilities_check_version_very_old_required_returns_true: "
             "expected 1 for version \"0.0.0\"\n", progname );
    return TEST_FAIL;
  }
  return TEST_PASS;
}

/* libspectrum_check_version: future major version (99.0.0) is not satisfied */
test_return_t
utilities_check_version_future_major_returns_false( void )
{
  if( libspectrum_check_version( "99.0.0" ) ) {
    fprintf( stderr, "%s: utilities_check_version_future_major_returns_false: "
             "expected 0 for version \"99.0.0\"\n", progname );
    return TEST_FAIL;
  }
  return TEST_PASS;
}

/* Graphics block tokens (bytes 128-143) render as Unicode block elements. */
test_return_t
utilities_zx_string_to_utf8_graphics_token( void )
{
  static const libspectrum_byte src[] = {
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f
  };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_graphics_token: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result,
              " " "\xe2\x96\x9d" "\xe2\x96\x98" "\xe2\x96\x80"
              "\xe2\x96\x97" "\xe2\x96\x90" "\xe2\x96\x9a" "\xe2\x96\x9c"
              "\xe2\x96\x96" "\xe2\x96\x9e" "\xe2\x96\x8c" "\xe2\x96\x9b"
              "\xe2\x96\x84" "\xe2\x96\x9f" "\xe2\x96\x99" "\xe2\x96\x88" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_graphics_token: "
             "unexpected result\n", progname );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* Control characters (bytes 0-31, excluding handled specials) render as "?" */
test_return_t
utilities_zx_string_to_utf8_control_char( void )
{
  /* 0x01 is a control character, not specially handled */
  static const libspectrum_byte src[] = { 0x01 };
  char result[ sizeof( src ) * 9 + 1 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src,
                                     sizeof( src ) ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_control_char: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "?" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_control_char: "
             "expected \"?\", got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}

/* Empty source string produces empty output */
test_return_t
utilities_zx_string_to_utf8_empty_source( void )
{
  static const libspectrum_byte src[] = { 0 };
  char result[ 16 ];

  if( libspectrum_zx_string_to_utf8( result, sizeof( result ), src, 0 ) ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_empty_source: "
             "conversion failed\n", progname );
    return TEST_FAIL;
  }

  if( strcmp( result, "" ) != 0 ) {
    fprintf( stderr, "%s: utilities_zx_string_to_utf8_empty_source: "
             "expected empty string, got \"%s\"\n", progname, result );
    return TEST_FAIL;
  }

  return TEST_PASS;
}
