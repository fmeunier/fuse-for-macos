#include "config.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "internals.h"
#include "common.h"

#ifndef O_BINARY
#define O_BINARY 0
#endif

int
read_file( libspectrum_byte **buffer, size_t *length, const char *filename )
{
  int fd;
  struct stat info;
  ssize_t bytes;

  fd = open( filename, O_RDONLY | O_BINARY );
  if( fd == -1 ) {
    fprintf( stderr, "%s: couldn't open `%s': %s\n", progname, filename,
	     strerror( errno ) );
    return errno;
  }

  if( fstat( fd, &info ) ) {
    fprintf( stderr, "%s: couldn't stat `%s': %s\n", progname, filename,
	     strerror( errno ) );
    return errno;
  }

  *length = info.st_size;
  *buffer = libspectrum_new( libspectrum_byte, *length );

  bytes = read( fd, *buffer, *length );
  if( bytes == -1 ) {
    fprintf( stderr, "%s: error reading from `%s': %s\n", progname, filename,
	     strerror( errno ) );
    return errno;
  } else if( (size_t)bytes < *length ) {
    fprintf( stderr, "%s: read only %lu of %lu bytes from `%s'\n", progname,
	     (unsigned long)bytes, (unsigned long)*length, filename );
    return 1;
  }

  if( close( fd ) ) {
    fprintf( stderr, "%s: error closing `%s': %s\n", progname, filename,
	     strerror( errno ) );
    return errno;
  }

  return 0;
}

test_return_t
load_tape( libspectrum_tape **tape, const char *filename,
           libspectrum_error expected_result )
{
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  *tape = libspectrum_tape_alloc();

  if( libspectrum_tape_read( *tape, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
			     filename ) != expected_result ) {
    fprintf( stderr, "%s: reading `%s' did not give expected result\n",
	     progname, filename );
    libspectrum_tape_free( *tape );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  return TEST_PASS;
}

test_return_t
read_tape( const char *filename, libspectrum_error expected_result )
{
  libspectrum_tape *tape;
  test_return_t r;

  r = load_tape( &tape, filename, expected_result );
  if( r != TEST_PASS ) return r;

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

test_return_t
read_snap( const char *filename, const char *filename_to_pass,
	   libspectrum_error expected_result )
{
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_snap *snap;

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  snap = libspectrum_snap_alloc();

  if( libspectrum_snap_read( snap, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
			     filename_to_pass ) != expected_result ) {
    fprintf( stderr, "%s: reading `%s' did not give expected result\n",
	     progname, filename );
    libspectrum_snap_free( snap );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  libspectrum_snap_free( snap );

  return TEST_PASS;
}

test_return_t
play_tape( const char *filename )
{
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  libspectrum_dword tstates;
  int flags;

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  tape = libspectrum_tape_alloc();

  if( libspectrum_tape_read( tape, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
			     filename ) ) {
    libspectrum_tape_free( tape );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  do {

    if( test_tape_get_next_edge( &tstates, &flags, tape ) ) {
      libspectrum_tape_free( tape );
      return TEST_INCOMPLETE;
    }

  } while( !( flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) );

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

static int
check_wav_exports( libspectrum_tape *source, const size_t *runs,
                    const libspectrum_tape_signal_level *levels,
                    size_t count, libspectrum_dword rate )
{
  static const libspectrum_id_t formats[] = {
    LIBSPECTRUM_ID_TAPE_CSW, LIBSPECTRUM_ID_TAPE_TZX, LIBSPECTRUM_ID_TAPE_PZX
  };
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t f, i, seen, length = 0;
  libspectrum_qword samples, elapsed;
  libspectrum_tape_edge edge;
  int result = 0;

  for( f = 0; f < sizeof( formats ) / sizeof( formats[0] ); f++ ) {
    if( libspectrum_tape_write( &output, &length, source, formats[f] ) ||
        libspectrum_tape_read( dest, output, length, formats[f], NULL ) ) goto done;
    samples = elapsed = seen = 0;
    for( i = 0; i < 64; i++ ) {
      if( libspectrum_tape_get_next_edge( &edge, dest ) ) goto done;
      if( edge.tstates ) {
        libspectrum_qword end;
        if( seen >= count || edge.level != levels[seen] ) goto done;
        samples += runs[seen++];
        end = samples * 3500000 / rate;
        if( edge.tstates != end - elapsed ) goto done;
        elapsed = end;
      }
      if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) break;
    }
    if( i == 64 || seen != count ) goto done;
    libspectrum_free( output ); output = NULL; length = 0;
    libspectrum_tape_clear( dest );
  }
  result = 1;
done:
  libspectrum_free( output );
  libspectrum_tape_free( dest );
  return result;
}

test_return_t
check_wav_block( const char *filename, libspectrum_dword sample_rate,
                 libspectrum_byte expected_byte, size_t samples_per_bit )
{
  libspectrum_tape *tape;
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  libspectrum_byte *data;
  size_t i, count = 0, samples = 0, run_count = 0;
  size_t runs[8];
  libspectrum_tape_signal_level levels[8];
  libspectrum_qword elapsed = 0;
  libspectrum_tape_edge edge;
  test_return_t r;

  r = load_tape( &tape, filename, LIBSPECTRUM_ERROR_NONE );
  if( r != TEST_PASS ) return r;

  block = libspectrum_tape_iterator_init( &it, tape );
  if( !block ) {
    fprintf( stderr, "%s: `%s' did not produce a tape block\n", progname,
             filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_block_type( block ) !=
        LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE ||
      libspectrum_tape_block_level( block ) != !!( expected_byte & 0x80 ) ) {
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }
  if( libspectrum_tape_block_sample_rate( block ) != sample_rate ) {
    fprintf( stderr, "%s: `%s' produced sample rate %lu, expected %lu\n",
             progname, filename,
             (unsigned long)libspectrum_tape_block_sample_rate( block ),
             (unsigned long)sample_rate );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  data = libspectrum_tape_block_data( block );
  for( i = 0; i < 8; ) {
    size_t start = i;
    int high = !!( expected_byte & ( 0x80 >> i ) );
    libspectrum_dword encoded;
    do { i++; } while( i < 8 &&
                       !!( expected_byte & ( 0x80 >> i ) ) == high );
    runs[run_count] = ( i - start ) * samples_per_bit;
    levels[run_count] = high ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                               LIBSPECTRUM_TAPE_SIGNAL_LOW;
    if( count >= libspectrum_tape_block_data_length( block ) ) {
      libspectrum_tape_free( tape );
      return TEST_FAIL;
    }
    encoded = data[count++];
    if( !encoded ) {
      if( libspectrum_tape_block_data_length( block ) - count < 4 ) {
        libspectrum_tape_free( tape );
        return TEST_FAIL;
      }
      encoded = libspectrum_read_dword_le( data + count );
      count += 4;
    }
    if( encoded != runs[run_count++] ) {
      libspectrum_tape_free( tape );
      return TEST_FAIL;
    }
  }

  if( libspectrum_tape_block_data_length( block ) != count ) {
    fprintf( stderr, "%s: `%s' has trailing RLE data\n", progname, filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  /* Playback must round cumulative samples, not each individual run. */
  count = 0;
  for( i = 0; i < 32; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ) {
      libspectrum_tape_free( tape );
      return TEST_FAIL;
    }
    if( edge.tstates ) {
      libspectrum_qword end;
      if( count >= run_count || edge.level != levels[count] ) {
        libspectrum_tape_free( tape );
        return TEST_FAIL;
      }
      samples += runs[count++];
      end = (libspectrum_qword)samples * 3500000 / sample_rate;
      if( edge.tstates != end - elapsed ) {
        libspectrum_tape_free( tape );
        return TEST_FAIL;
      }
      elapsed = end;
    }
    if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) break;
  }
  if( samples != 8 * samples_per_bit ||
      elapsed != (libspectrum_qword)8 * samples_per_bit * 3500000 / sample_rate ) {
    fprintf( stderr, "%s: `%s' has incorrect cumulative duration\n",
             progname, filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( count != run_count ) {
    fprintf( stderr, "%s: `%s' has incorrect pulse count\n", progname, filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_iterator_next( &it ) ) {
    fprintf( stderr, "%s: `%s' produced unexpected trailing tape blocks\n", progname,
             filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( !check_wav_exports( tape, runs, levels, run_count, sample_rate ) ) {
    fprintf( stderr, "%s: `%s' lost its waveform during export\n", progname,
             filename );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }
  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}
