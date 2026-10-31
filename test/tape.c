#include "config.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "internals.h"
#include "common.h"
#include "test.h"

test_return_t
tzx_write_pause_representation( void )
{
  static const struct {
    int level;
    libspectrum_dword duration;
    int ordinary;
  } cases[] = {
    { 0, 3500, 1 }, { 0, 65535U * 3500, 1 },
    { 0, 3501, 0 }, { 1, 3500, 0 }, { 0, 65536U * 3500, 0 },
    { 0, 1, 0 }, { -1, 0, 1 }, { 0, 0, 1 }, { 1, 0, 1 }
  };
  libspectrum_tape *source = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t length = 0, i;
  test_return_t result = TEST_FAIL;
  for( i = 0; i < sizeof( cases ) / sizeof( cases[0] ); i++ ) {
    libspectrum_tape_block *block;
    libspectrum_tape_edge edge;
    libspectrum_qword duration = 0;
    size_t events = 0;
    libspectrum_free( output ); output = NULL; length = 0;
    libspectrum_tape_clear( source ); libspectrum_tape_clear( dest );
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_tape_block_set_level( block, cases[i].level );
    libspectrum_set_pause_tstates( block, cases[i].duration );
    libspectrum_tape_append_block( source, block );
    if( libspectrum_tape_write( &output, &length, source, LIBSPECTRUM_ID_TAPE_TZX ) ||
        length < 13 || output[10] != ( cases[i].ordinary ?
          LIBSPECTRUM_TAPE_BLOCK_PAUSE : LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA ) )
      goto done;
    if( cases[i].ordinary && ( length != 13 ||
        output[11] + 256U * output[12] != cases[i].duration / 3500 ) ) goto done;
    if( libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) )
      goto done;
    do {
      if( ++events > 10000 || libspectrum_tape_get_next_edge( &edge, dest ) ) goto done;
      duration += edge.tstates;
      if( edge.tstates && edge.level != ( cases[i].level ?
          LIBSPECTRUM_TAPE_SIGNAL_HIGH : LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
    } while( !( edge.flags & ( LIBSPECTRUM_TAPE_FLAGS_TAPE | LIBSPECTRUM_TAPE_FLAGS_STOP ) ) );
    if( duration != cases[i].duration ||
        ( !duration && !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) ) ) goto done;
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: TZX pause representation case %lu failed\n", progname, (unsigned long)i );
  libspectrum_free( output ); libspectrum_tape_free( source ); libspectrum_tape_free( dest );
  return result;
}

/* Compare time spent at each level, not representation-specific zero-time
   edges or block boundaries. Adjacent pulses at the same level are merged. */
typedef struct pzx_test_run {
  libspectrum_qword duration;
  libspectrum_tape_signal_level level;
} pzx_test_run;

static int
pzx_test_waveform( libspectrum_tape *tape, pzx_test_run *runs, size_t *count )
{
  libspectrum_tape_edge edge;
  size_t events = 0;
  *count = 0;
  do {
    if( ++events > 1000000 || libspectrum_tape_get_next_edge( &edge, tape ) )
      return 0;
    if( edge.tstates ) {
      if( *count && runs[*count - 1].level == edge.level ) {
        runs[*count - 1].duration += edge.tstates;
      } else {
        if( *count == 500000 ) return 0;
        runs[*count].duration = edge.tstates;
        runs[(*count)++].level = edge.level;
      }
    }
  } while( !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) );
  return 1;
}

static int
pzx_test_roundtrip_format( libspectrum_tape *source, libspectrum_id_t format )
{
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_byte *output = NULL;
  size_t length = 0, n = 0, m = 0, i;
  pzx_test_run *a = libspectrum_new( pzx_test_run, 500000 );
  pzx_test_run *b = libspectrum_new( pzx_test_run, 500000 );
  int result = 0;
  /* Writing must not move the caller's playback position. */
  libspectrum_tape_cursor *before = libspectrum_tape_cursor_capture( source );
  libspectrum_tape_cursor *probe = libspectrum_tape_cursor_clone( before );
  libspectrum_tape_edge expected, actual;
  if( libspectrum_tape_cursor_get_next_edge( &expected, probe ) ) goto done;
  {
    libspectrum_error error = libspectrum_tape_write( &output, &length, source,
                                                     format );
    if( error ) {
      fprintf( stderr, "%s: PZX write error %d\n", progname, error );
      goto done;
    }
    if( libspectrum_tape_read( dest, output, length, format, NULL ) ) goto done;
  }
  if( libspectrum_tape_get_next_edge( &actual, source ) ||
      actual.tstates != expected.tstates || actual.level != expected.level ||
      actual.transition != expected.transition || actual.flags != expected.flags ) {
    fprintf( stderr, "%s: PZX writer changed position: %u/%d/%d/%d vs %u/%d/%d/%d\n",
      progname, actual.tstates, actual.level, actual.transition, actual.flags,
      expected.tstates, expected.level, expected.transition, expected.flags );
    goto done;
  }
  libspectrum_tape_cursor_apply( source, before );
  if( !pzx_test_waveform( source, a, &n ) ||
      !pzx_test_waveform( dest, b, &m ) ) {
    fprintf( stderr, "%s: PZX run counts %lu/%lu\n", progname,
             (unsigned long)n, (unsigned long)m );
    goto done;
  }
  for( i = 0; i < n && i < m; i++ )
    if( a[i].duration != b[i].duration || a[i].level != b[i].level ) {
      fprintf( stderr, "%s: PZX waveform differs at run %lu: %llu/%d vs %llu/%d (counts %lu/%lu)\n", progname,
               (unsigned long)i, (unsigned long long)a[i].duration, a[i].level,
               (unsigned long long)b[i].duration, b[i].level,
               (unsigned long)n, (unsigned long)m );
      goto done;
    }
  result = n == m;
done:
  libspectrum_tape_cursor_free( probe );
  libspectrum_tape_cursor_free( before );
  libspectrum_free( a ); libspectrum_free( b ); libspectrum_free( output );
  libspectrum_tape_free( dest );
  return result;
}

static int
pzx_test_roundtrip( libspectrum_tape *source )
{
  return pzx_test_roundtrip_format( source, LIBSPECTRUM_ID_TAPE_PZX );
}

test_return_t
pzx_write_waveforms( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_dword *pulses;
  size_t *repeats;
  libspectrum_word *s0, *s1;
  libspectrum_byte *data;
  size_t i;
  test_return_t result = TEST_FAIL;
  /* Prefix ambiguity boundaries, split repeat counts, zero-pulse parity. */
  static const libspectrum_dword lengths[] = {
    0, 32767, 32768, 65535, 65536, 0x7fffffff, 0, 100
  };
  pulses = libspectrum_new( libspectrum_dword, 8 );
  repeats = libspectrum_new( size_t, 8 );
  for( i = 0; i < 8; i++ ) { pulses[i] = lengths[i]; repeats[i] = 1; }
  repeats[0] = 3; repeats[6] = 2; repeats[7] = 32768;
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_tape_block_set_count( block, 8 );
  libspectrum_tape_block_set_pulse_lengths( block, pulses );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( tape, block );

  for( i = 0; i < 2; i++ ) {
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
    s0 = libspectrum_new( libspectrum_word, 2 );
    s1 = libspectrum_new( libspectrum_word, 2 );
    data = libspectrum_new( libspectrum_byte, 1 );
    s0[0] = 0; s0[1] = 79; s1[0] = 79; s1[1] = 0; data[0] = 0xa0;
    libspectrum_tape_block_set_count( block, 3 );
    libspectrum_tape_block_set_data_length( block, 1 );
    libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
    libspectrum_tape_block_set_data( block, data );
    libspectrum_tape_block_set_level( block, i );
    libspectrum_tape_block_set_tail_length( block, i ? 945 : 0 );
    libspectrum_tape_block_set_bit0_pulse_count( block, 2 );
    libspectrum_tape_block_set_bit1_pulse_count( block, 2 );
    libspectrum_tape_block_set_bit0_pulses( block, s0 );
    libspectrum_tape_block_set_bit1_pulses( block, s1 );
    libspectrum_tape_append_block( tape, block );
  }
  libspectrum_tape_nth_block( tape, 0 );
  if( !pzx_test_roundtrip( tape ) ) goto done;
  for( i = 0; i < 6; i++ ) {
    libspectrum_tape_type type = i < 2 ? LIBSPECTRUM_TAPE_BLOCK_ROM :
      i < 4 ? LIBSPECTRUM_TAPE_BLOCK_TURBO : LIBSPECTRUM_TAPE_BLOCK_PURE_DATA;
    block = libspectrum_tape_block_alloc( type );
    data = libspectrum_new( libspectrum_byte, 2 );
    data[0] = i & 1 ? 0xff : 0; data[1] = 0xa5;
    libspectrum_tape_block_set_data_length( block, 2 );
    libspectrum_tape_block_set_data( block, data );
    libspectrum_set_pause_tstates( block, i & 1 ? 3500000 : 0 );
    if( type != LIBSPECTRUM_TAPE_BLOCK_ROM ) {
      libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
      libspectrum_tape_block_set_bit0_length( block, 200 );
      libspectrum_tape_block_set_bit1_length( block, 400 );
    }
    if( type == LIBSPECTRUM_TAPE_BLOCK_TURBO ) {
      libspectrum_tape_block_set_pilot_pulses( block, i & 1 ? 3 : 0 );
      libspectrum_tape_block_set_pilot_length( block, 800 );
      libspectrum_tape_block_set_sync1_length( block, 100 );
      libspectrum_tape_block_set_sync2_length( block, 150 );
    }
    libspectrum_tape_append_block( tape, block );
  }
  for( i = 0; i < 2; i++ ) {
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_set_pause_tstates( block, 70000 );
    libspectrum_tape_block_set_level( block, i );
    libspectrum_tape_append_block( tape, block );
  }
  libspectrum_tape_nth_block( tape, 0 );
  if( pzx_test_roundtrip( tape ) &&
      pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_CSW ) ) result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

/* Exact PZX-style waveform export uses GDB only, without CSW or 0x2B. */
static int
tzx_test_only_gdb( libspectrum_tape *source, pzx_test_run *expected,
                   size_t expected_count )
{
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  libspectrum_byte *output = NULL;
  pzx_test_run *runs = libspectrum_new( pzx_test_run, 500000 );
  size_t length = 0, count, i;
  int result = 0;
  if( libspectrum_tape_write( &output, &length, source, LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) )
    goto done;
  for( block = libspectrum_tape_iterator_init( &it, dest ); block;
       block = libspectrum_tape_iterator_next( &it ) )
    if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA )
      goto done;
  if( !pzx_test_waveform( dest, runs, &count ) || count != expected_count ) goto done;
  for( i = 0; i < count; i++ )
    if( runs[i].duration != expected[i].duration || runs[i].level != expected[i].level )
      goto done;
  result = 1;
done:
  libspectrum_free( runs ); libspectrum_free( output ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
tzx_pzx_gdb_holds_and_zero_pulses( void )
{
  pzx_test_run expected[] = {
    { 65536, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 65536, LIBSPECTRUM_TAPE_SIGNAL_HIGH },
    { 65553, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 0x7fffffff, LIBSPECTRUM_TAPE_SIGNAL_HIGH },
    { 65535, LIBSPECTRUM_TAPE_SIGNAL_LOW }
  };
  pzx_test_run data_expected[] = {
    { 65535, LIBSPECTRUM_TAPE_SIGNAL_HIGH },
    { 65535, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 65535, LIBSPECTRUM_TAPE_SIGNAL_HIGH },
    { 7, LIBSPECTRUM_TAPE_SIGNAL_LOW }
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_dword *lengths = libspectrum_new( libspectrum_dword, 1 );
  size_t *repeats = libspectrum_new( size_t, 1 ), i;
  libspectrum_word *s0, *s1;
  libspectrum_byte *data;
  test_return_t result = TEST_FAIL;
  lengths[0] = 65536; repeats[0] = 3;
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( tape, block );
  for( i = 0; i < 3; i++ ) {
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
    libspectrum_tape_block_set_level( block, i == 1 );
    libspectrum_set_pause_tstates( block, i == 0 ? 17 : i == 1 ? 0x7fffffff : 65535 );
    libspectrum_tape_append_block( tape, block );
  }
  libspectrum_tape_nth_block( tape, 0 );
  if( !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !tzx_test_only_gdb( tape, expected, 5 ) ) goto done;
  libspectrum_tape_clear( tape );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  s0 = libspectrum_new( libspectrum_word, 2 );
  s1 = libspectrum_new( libspectrum_word, 2 );
  data = libspectrum_new( libspectrum_byte, 1 );
  s0[0] = 65535; s0[1] = 0; s1[0] = 0; s1[1] = 65535; data[0] = 0xa0;
  libspectrum_tape_block_set_count( block, 3 );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
  libspectrum_tape_block_set_data( block, data );
  libspectrum_tape_block_set_level( block, 0 );
  libspectrum_tape_block_set_tail_length( block, 7 );
  libspectrum_tape_block_set_bit0_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit1_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit0_pulses( block, s0 );
  libspectrum_tape_block_set_bit1_pulses( block, s1 );
  libspectrum_tape_append_block( tape, block );
  libspectrum_tape_nth_block( tape, 0 );
  if( !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_CSW ) ||
      !tzx_test_only_gdb( tape, data_expected, 4 ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
tzx_pzx_gdb_compact_data_and_empty_sequences( void )
{
  pzx_test_run expected[] = {
    { 1, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 2, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 3, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 855, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 855, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 1, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 2, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 3, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 945, LIBSPECTRUM_TAPE_SIGNAL_HIGH }
  };
  pzx_test_run empty_expected[] = {
    { 1, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 2, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 3, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 1, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 2, LIBSPECTRUM_TAPE_SIGNAL_HIGH }, { 3, LIBSPECTRUM_TAPE_SIGNAL_LOW },
    { 945, LIBSPECTRUM_TAPE_SIGNAL_HIGH }
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_word *s0 = libspectrum_new( libspectrum_word, 2 );
  libspectrum_word *s1 = libspectrum_new( libspectrum_word, 3 );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
  test_return_t result = TEST_FAIL;
  s0[0] = s0[1] = 855; s1[0] = 1; s1[1] = 2; s1[2] = 3; data[0] = 0xa0;
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  libspectrum_tape_block_set_count( block, 3 );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
  libspectrum_tape_block_set_data( block, data );
  libspectrum_tape_block_set_level( block, 1 );
  libspectrum_tape_block_set_tail_length( block, 945 );
  libspectrum_tape_block_set_bit0_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit1_pulse_count( block, 3 );
  libspectrum_tape_block_set_bit0_pulses( block, s0 );
  libspectrum_tape_block_set_bit1_pulses( block, s1 );
  libspectrum_tape_append_block( tape, block );
  libspectrum_tape_nth_block( tape, 0 );
  if( !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      !tzx_test_only_gdb( tape, expected, 9 ) ) goto done;
  /* Empty bit sequences are valid PZX. Test against literal expectations,
     since the native DATA playback engine does not support this case yet. */
  libspectrum_tape_block_set_bit0_pulse_count( block, 0 );
  if( !tzx_test_only_gdb( tape, empty_expected, 7 ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_tape_free( tape );
  return result;
}

test_return_t
tzx_pzx_gdb_control_boundaries( void )
{
  libspectrum_tape *source = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_tape_iterator it;
  libspectrum_byte *output = NULL;
  libspectrum_tape_edge edge;
  char *text = libspectrum_new( char, 5 );
  libspectrum_dword *lengths = libspectrum_new( libspectrum_dword, 1 );
  size_t *repeats = libspectrum_new( size_t, 1 ), i, length = 0;
  test_return_t result = TEST_FAIL;
  static const libspectrum_tape_type types[] = {
    LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA, LIBSPECTRUM_TAPE_BLOCK_COMMENT,
    LIBSPECTRUM_TAPE_BLOCK_STOP48, LIBSPECTRUM_TAPE_BLOCK_PAUSE,
    LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA
  };
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_tape_block_set_level( block, 0 );
  libspectrum_set_pause_tstates( block, 16 );
  libspectrum_tape_append_block( source, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
  memcpy( text, "Here", 5 ); libspectrum_tape_block_set_text( block, text );
  libspectrum_tape_append_block( source, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_STOP48 );
  libspectrum_tape_append_block( source, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_tape_block_set_level( block, 0 ); libspectrum_set_pause_tstates( block, 0 );
  libspectrum_tape_append_block( source, block );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  lengths[0] = 20; repeats[0] = 1;
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( source, block );
  if( libspectrum_tape_write( &output, &length, source, LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) )
    goto done;
  block = libspectrum_tape_iterator_init( &it, dest );
  for( i = 0; i < sizeof( types ) / sizeof( types[0] ); i++ ) {
    if( !block || libspectrum_tape_block_type( block ) != types[i] ) goto done;
    block = libspectrum_tape_iterator_next( &it );
  }
  if( block || libspectrum_tape_get_next_edge( &edge, dest ) ||
      edge.tstates != 16 || edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) goto done;
  do {
    if( libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates ) goto done;
  } while( !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP48 ) );
  if( edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
      libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates ||
      !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_STOP ) ||
      ( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) ||
      libspectrum_tape_get_next_edge( &edge, dest ) || edge.tstates != 20 ||
      edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( source ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
tzx_pzx_gdb_repeat_splitting( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc(), *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_dword *lengths = libspectrum_new( libspectrum_dword, 1 );
  size_t *repeats = libspectrum_new( size_t, 1 ), length = 0;
  libspectrum_byte *output = NULL;
  libspectrum_tape_generalised_data_symbol_table *table;
  test_return_t result = TEST_FAIL;
  lengths[0] = 100; repeats[0] = 131073; /* 65536 pairs plus one pulse. */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( tape, block );
  libspectrum_tape_nth_block( tape, 0 );
  if( !pzx_test_roundtrip_format( tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) )
    goto done;
  block = libspectrum_tape_current_block( dest );
  table = libspectrum_tape_block_pilot_table( block );
  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA ||
      libspectrum_tape_generalised_data_symbol_table_symbols_in_block( table ) != 3 ||
      libspectrum_tape_block_pilot_repeats( block, 0 ) != 65535 ||
      libspectrum_tape_block_pilot_repeats( block, 1 ) != 1 ||
      libspectrum_tape_block_pilot_repeats( block, 2 ) != 1 ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_legacy_tails( void )
{
  static const libspectrum_dword pauses[] = { 0, 1, 65535, 65536, 3500000 };
  static const libspectrum_tape_type types[] = {
    LIBSPECTRUM_TAPE_BLOCK_ROM, LIBSPECTRUM_TAPE_BLOCK_TURBO,
    LIBSPECTRUM_TAPE_BLOCK_PURE_DATA
  };
  libspectrum_tape *source = NULL, *dest = NULL;
  libspectrum_byte *output = NULL;
  size_t t, p, polarity, length = 0;
  test_return_t result = TEST_FAIL;

  for( t = 0; t < sizeof( types ) / sizeof( types[0] ); t++ ) {
    for( p = 0; p < sizeof( pauses ) / sizeof( pauses[0] ); p++ ) {
      for( polarity = 0; polarity < 2; polarity++ ) {
        libspectrum_tape_block *block, *data_block;
        libspectrum_tape_iterator it;
        libspectrum_dword *pulses = libspectrum_new( libspectrum_dword, 1 );
        size_t *repeats = libspectrum_new( size_t, 1 );
        libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
        libspectrum_dword tail = pauses[p] > 65535 ? 65535 : pauses[p];
        libspectrum_tape_edge edge;
        int pause_level = -1;
        source = libspectrum_tape_alloc(); dest = libspectrum_tape_alloc();
        /* Precede conversion with either level, without a forced-low boundary. */
        pulses[0] = 50; repeats[0] = polarity ? 1 : 2;
        block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
        libspectrum_tape_block_set_count( block, 1 );
        libspectrum_tape_block_set_pulse_lengths( block, pulses );
        libspectrum_tape_block_set_pulse_repeats( block, repeats );
        libspectrum_tape_append_block( source, block );
        block = libspectrum_tape_block_alloc( types[t] );
        data[0] = polarity ? 0xff : 0;
        libspectrum_tape_block_set_data_length( block, 1 );
        libspectrum_tape_block_set_data( block, data );
        libspectrum_set_pause_tstates( block, pauses[p] );
        if( types[t] != LIBSPECTRUM_TAPE_BLOCK_ROM ) {
          libspectrum_tape_block_set_bits_in_last_byte( block, 3 );
          libspectrum_tape_block_set_bit0_length( block, 100 );
          libspectrum_tape_block_set_bit1_length( block, 200 );
        }
        if( types[t] == LIBSPECTRUM_TAPE_BLOCK_TURBO ) {
          libspectrum_tape_block_set_pilot_pulses( block, polarity ? 3 : 2 );
          libspectrum_tape_block_set_pilot_length( block, 800 );
          libspectrum_tape_block_set_sync1_length( block, 200 );
          libspectrum_tape_block_set_sync2_length( block, 300 );
        }
        libspectrum_tape_append_block( source, block );
        libspectrum_tape_nth_block( source, 0 );
        /* Record the actual post-data pulse's level independently. */
        do {
          if( libspectrum_tape_get_next_edge( &edge, source ) ) goto done;
          if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) pause_level = edge.level;
        } while( !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) );
        libspectrum_tape_nth_block( source, 0 );
        if( !pzx_test_roundtrip( source ) ||
            libspectrum_tape_write( &output, &length, source,
                                     LIBSPECTRUM_ID_TAPE_PZX ) ||
            libspectrum_tape_read( dest, output, length,
                                    LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
        data_block = libspectrum_tape_iterator_init( &it, dest );
        while( data_block && libspectrum_tape_block_type( data_block ) !=
               LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK )
          data_block = libspectrum_tape_iterator_next( &it );
        if( !data_block || libspectrum_tape_block_tail_length( data_block ) != tail )
          goto done;
        block = libspectrum_tape_iterator_next( &it );
        if( pauses[p] > tail ) {
          if( !block || libspectrum_tape_block_type( block ) !=
                LIBSPECTRUM_TAPE_BLOCK_PAUSE ||
              libspectrum_tape_block_pause_tstates( block ) != pauses[p] - tail ||
              libspectrum_tape_block_level( block ) != pause_level ||
              libspectrum_tape_iterator_next( &it ) ) goto done;
        } else if( block ) goto done;
        libspectrum_free( output ); output = NULL; length = 0;
        libspectrum_tape_free( source ); source = NULL;
        libspectrum_tape_free( dest ); dest = NULL;
      }
    }
  }
  result = TEST_PASS;
done:
  if( result != TEST_PASS )
    fprintf( stderr, "%s: PZX legacy tail mismatch (type %lu, pause %lu, polarity %lu)\n",
             progname, (unsigned long)t, (unsigned long)p, (unsigned long)polarity );
  libspectrum_free( output );
  if( source ) libspectrum_tape_free( source );
  if( dest ) libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_coalesces_pulses( void )
{
  static const libspectrum_dword lengths[] = { 100, 100, 100, 0, 0, 65536, 65536 };
  static const size_t counts[] = { 1, 32766, 2, 3, 2, 1, 2 };
  static const libspectrum_dword expected_lengths[] = { 100, 100, 0, 65536 };
  static const size_t expected_counts[] = { 32767, 2, 5, 3 };
  libspectrum_tape *source = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_tape_iterator it;
  libspectrum_byte *output = NULL;
  size_t i, length = 0;
  test_return_t result = TEST_FAIL;
  libspectrum_dword *pulses = libspectrum_new( libspectrum_dword, 7 );
  size_t *repeats = libspectrum_new( size_t, 7 );
  memcpy( pulses, lengths, sizeof( lengths ) );
  memcpy( repeats, counts, sizeof( counts ) );
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_tape_block_set_count( block, 7 );
  libspectrum_tape_block_set_pulse_lengths( block, pulses );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( source, block );
  /* Equal duration in the next block must not be merged across its reset. */
  pulses = libspectrum_new( libspectrum_dword, 1 );
  repeats = libspectrum_new( size_t, 1 );
  pulses[0] = 65536; repeats[0] = 1;
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_pulse_lengths( block, pulses );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  libspectrum_tape_append_block( source, block );
  libspectrum_tape_nth_block( source, 0 );
  if( !pzx_test_roundtrip( source ) ||
      libspectrum_tape_write( &output, &length, source, LIBSPECTRUM_ID_TAPE_PZX ) ||
      libspectrum_tape_read( dest, output, length, LIBSPECTRUM_ID_TAPE_PZX, NULL ) )
    goto done;
  /* Header (10), coalesced PULS (8+18), separate PULS (8+6). */
  if( length != 50 || memcmp( output + 10, "PULS\x12\0\0\0", 8 ) ||
      memcmp( output + 36, "PULS\x06\0\0\0", 8 ) ) goto done;
  block = libspectrum_tape_iterator_init( &it, dest );
  if( !block || libspectrum_tape_block_count( block ) != 4 ) goto done;
  for( i = 0; i < 4; i++ )
    if( libspectrum_tape_block_pulse_lengths( block, i ) != expected_lengths[i] ||
        libspectrum_tape_block_pulse_repeats( block, i ) != expected_counts[i] )
      goto done;
  block = libspectrum_tape_iterator_next( &it );
  if( !block || libspectrum_tape_block_count( block ) != 1 ||
      libspectrum_tape_block_pulse_lengths( block, 0 ) != 65536 ||
      libspectrum_tape_block_pulse_repeats( block, 0 ) != 1 ||
      libspectrum_tape_iterator_next( &it ) ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output );
  libspectrum_tape_free( source ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_metadata_and_stops( void )
{
  static const libspectrum_byte input[] =
    "PZXT\x1f\0\0\0\x01\0Title\0Author\0Alice\0Comment\0X\0"
    "BRWS\x04\0\0\0Here"
    "STOP\x02\0\0\0\x01\0"
    "STOP\x02\0\0\0\0\0"
    /* Valid PZX encoding with zero pulses for both bit values. */
    "DATA\x09\0\0\0\x01\0\0\x80\0\0\0\0\x80";
  libspectrum_tape *source = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_iterator a, b;
  libspectrum_tape_block *x, *y;
  libspectrum_byte *output = NULL;
  size_t length = 0, i;
  test_return_t result = TEST_FAIL;
  if( libspectrum_tape_read( source, input, sizeof( input ) - 1,
                             LIBSPECTRUM_ID_TAPE_PZX, NULL ) ||
      libspectrum_tape_write( &output, &length, source,
                              LIBSPECTRUM_ID_TAPE_PZX ) ||
      libspectrum_tape_read( dest, output, length,
                             LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
  /* The titled archive must be the first PZXT, not follow an empty header. */
  if( length != sizeof( input ) - 1 || memcmp( output, input, length ) ) goto done;
  x = libspectrum_tape_iterator_init( &a, source );
  y = libspectrum_tape_iterator_init( &b, dest );
  while( x && y ) {
    libspectrum_tape_type type = libspectrum_tape_block_type( x );
    if( type != libspectrum_tape_block_type( y ) ) goto done;
    if( type == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ) {
      if( libspectrum_tape_block_count( x ) != libspectrum_tape_block_count( y ) )
        goto done;
      for( i = 0; i < libspectrum_tape_block_count( x ); i++ )
        if( libspectrum_tape_block_ids( x, i ) !=
            libspectrum_tape_block_ids( y, i ) ||
            strcmp( libspectrum_tape_block_texts( x, i ),
                    libspectrum_tape_block_texts( y, i ) ) ) goto done;
    } else if( type == LIBSPECTRUM_TAPE_BLOCK_COMMENT ) {
      if( strcmp( libspectrum_tape_block_text( x ),
                  libspectrum_tape_block_text( y ) ) ) goto done;
    } else if( type == LIBSPECTRUM_TAPE_BLOCK_PAUSE ) {
      if( libspectrum_tape_block_pause_tstates( y ) != 0 ) goto done;
    } else if( type == LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK ) {
      if( libspectrum_tape_block_count( y ) != 1 ||
          libspectrum_tape_block_bit0_pulse_count( y ) != 0 ||
          libspectrum_tape_block_bit1_pulse_count( y ) != 0 ||
          libspectrum_tape_block_level( y ) != 1 ||
          libspectrum_tape_block_data( y )[0] != 0x80 ) goto done;
    }
    x = libspectrum_tape_iterator_next( &a );
    y = libspectrum_tape_iterator_next( &b );
  }
  if( x || y ) goto done;
  /* Genuine concatenation boundaries must still emit their own PZXT. */
  x = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_CONCAT );
  libspectrum_tape_append_block( source, x );
  libspectrum_free( output ); output = NULL; length = 0;
  if( libspectrum_tape_write( &output, &length, source,
                              LIBSPECTRUM_ID_TAPE_PZX ) ||
      length != sizeof( input ) - 1 + 10 ||
      memcmp( output, input, sizeof( input ) - 1 ) ||
      memcmp( output + sizeof( input ) - 1, "PZXT\x02\0\0\0\x01\0", 10 ) )
    goto done;
  result = TEST_PASS;
done:
  libspectrum_free( output );
  libspectrum_tape_free( source ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
tzx_message_duration( void )
{
  static const libspectrum_dword durations[] = { 0, 3000, 255000 };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *dest = libspectrum_tape_alloc();
  libspectrum_tape_block *block = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
  libspectrum_byte *out = NULL;
  char *text = libspectrum_new( char, 5 );
  size_t length = 0, i;
  test_return_t result = TEST_FAIL;
  strcpy( text, "Test" );
  libspectrum_tape_block_set_text( block, text );
  libspectrum_tape_append_block( tape, block );
  for( i = 0; i < sizeof( durations ) / sizeof( durations[0] ); i++ ) {
    libspectrum_set_pause_ms( block, durations[i] );
    libspectrum_tape_clear( dest );
    if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ||
        length != 17 || out[10] != 0x31 || out[11] != durations[i] / 1000 ||
        libspectrum_tape_block_pause( block ) != durations[i] ||
        libspectrum_tape_read( dest, out, length, LIBSPECTRUM_ID_TAPE_TZX, NULL ) ||
        libspectrum_tape_block_pause( libspectrum_tape_current_block( dest ) ) != durations[i] )
      goto done;
    libspectrum_free( out ); out = NULL; length = 0;
  }
  libspectrum_set_pause_ms( block, 256000 );
  if( libspectrum_tape_write( &out, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) !=
      LIBSPECTRUM_ERROR_INVALID || out || length ) goto done;
  result = TEST_PASS;
done:
  libspectrum_free( out );
  libspectrum_tape_free( tape ); libspectrum_tape_free( dest );
  return result;
}

test_return_t
pzx_write_rejects_unsupported( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_byte *output = NULL;
  size_t length = 0, i;
  test_return_t result = TEST_FAIL;
  static const libspectrum_tape_type types[] = {
    LIBSPECTRUM_TAPE_BLOCK_SELECT
  };
  for( i = 0; i < sizeof( types ) / sizeof( types[0] ); i++ ) {
    block = libspectrum_tape_block_alloc( types[i] );
    libspectrum_tape_append_block( tape, block );
    if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_PZX )
        != LIBSPECTRUM_ERROR_UNKNOWN || output != NULL ) goto done;
    libspectrum_tape_clear( tape );
  }
  {
    libspectrum_dword *pulses = libspectrum_new( libspectrum_dword, 1 );
    size_t *repeats = libspectrum_new( size_t, 1 );
    libspectrum_byte *original;
    pulses[0] = 0x80000000U; repeats[0] = 1;
    block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
    libspectrum_tape_block_set_count( block, 1 );
    libspectrum_tape_block_set_pulse_lengths( block, pulses );
    libspectrum_tape_block_set_pulse_repeats( block, repeats );
    libspectrum_tape_append_block( tape, block );
    output = libspectrum_new( libspectrum_byte, 4 ); length = 4;
    memcpy( output, "keep", 4 ); original = output;
    if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_PZX )
        != LIBSPECTRUM_ERROR_INVALID || output != original || length != 4 ||
        memcmp( output, "keep", 4 ) ) goto done;
  }
  result = TEST_PASS;
done:
  libspectrum_free( output ); libspectrum_tape_free( tape );
  return result;
}

test_return_t
pzx_large_payload_bounds( void )
{
  libspectrum_byte input[286] = { 0 };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  test_return_t r = TEST_FAIL;
  size_t i;

  if( !tape ) return TEST_INCOMPLETE;
  memcpy( input, "PZXT\x02\0\0\0\x01\0DATA", 14 );
  /* 268-byte DATA body: metadata, two pulses, 256 payload bytes. */
  input[14] = 12; input[15] = 1;
  input[19] = 8; input[21] = 0x80; /* 2048 bits, initial high */
  input[24] = input[25] = 1;
  input[26] = 100; input[28] = 200;
  memset( input + 30, 0xa5, 256 );
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
  block = libspectrum_tape_current_block( tape );
  if( !block || libspectrum_tape_block_data_length( block ) != 256 ||
      libspectrum_tape_block_count( block ) != 2048 ||
      libspectrum_tape_block_level( block ) != 1 ) goto done;
  for( i = 0; i < 256; i++ )
    if( libspectrum_tape_block_data( block )[i] != 0xa5 ) goto done;
  if( libspectrum_tape_clear( tape ) ) goto done;

  /* Keep the chunk length consistent so the payload helper rejects it. */
  input[14] = 11;
  if( libspectrum_tape_read( tape, input, sizeof( input ) - 1,
                             LIBSPECTRUM_ID_TAPE_PZX, NULL ) !=
      LIBSPECTRUM_ERROR_CORRUPT ) goto done;
  if( libspectrum_tape_clear( tape ) ) goto done;
  input[14] = 12;
  memset( input + 18, 0xff, 4 ); /* Maximum bit count, tiny payload */
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_PZX, NULL ) !=
      LIBSPECTRUM_ERROR_CORRUPT ) goto done;
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: PZX payload bounds mismatch\n", progname );
  libspectrum_tape_free( tape );
  return r;
}

test_return_t
tape_dword_high_bit_callers( void )
{
  libspectrum_byte csw[57] = { 0 };
  /* One uncompressed sample block followed by the EOF block. */
  static const libspectrum_byte warajevo[] = {
    12,0,0,0, 30,0,0,0, 255,255,255,255,
    255,255,255,255, 30,0,0,0, 254,255,0, 1,0,1,0,0,0, 0xaa,
    12,0,0,0, 255,255,255,255
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block;
  libspectrum_tape_edge edge;
  test_return_t r = TEST_FAIL;

  if( !tape ) return TEST_INCOMPLETE;
  if( libspectrum_tape_read( tape, warajevo, sizeof( warajevo ),
                             LIBSPECTRUM_ID_TAPE_WARAJEVO, NULL ) ) goto done;
  block = libspectrum_tape_current_block( tape );
  if( !block || libspectrum_tape_block_type( block ) !=
      LIBSPECTRUM_TAPE_BLOCK_RAW_DATA ||
      libspectrum_tape_block_data_length( block ) != 1 ||
      libspectrum_tape_block_data( block )[0] != 0xaa ) goto done;
  libspectrum_tape_clear( tape );

  memcpy( csw, "Compressed Square Wave\x1a", 23 );
  csw[23] = 2;
  /* Rate and extended pulse length both 0x80000001: exactly one second.
     Literal bytes keep the expected value independent of the decoder. */
  csw[25] = 1; csw[28] = 0x80;
  csw[33] = 1;
  csw[53] = 1; csw[56] = 0x80;
  if( libspectrum_tape_read( tape, csw, sizeof( csw ),
                             LIBSPECTRUM_ID_TAPE_CSW, NULL ) ) goto done;
  block = libspectrum_tape_current_block( tape );
  if( !block || libspectrum_tape_block_sample_rate( block ) != 0x80000001 ||
      libspectrum_tape_block_length( block ) != 3500000 ||
      libspectrum_tape_get_next_edge( &edge, tape ) ||
      edge.tstates != 3500000 ) goto done;
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: high-bit tape dword caller mismatch\n", progname );
  libspectrum_tape_free( tape );
  return r;
}

test_return_t
tape_with_unknown_block( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid.tzx" ), LIBSPECTRUM_ERROR_UNKNOWN );
}

/* Test for bugs #84: TZX turbo blocks with zero pilot pulses and #85: freeing
   a turbo block with no data produces segfault */
test_return_t
tzx_turbo_data_with_zero_pilot_pulses_and_zero_data( void )
{
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  const char *filename = STATIC_TEST_PATH( "turbo-zeropilot.tzx" );
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

  if( test_tape_get_next_edge( &tstates, &flags, tape ) ) {
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  if( flags != TEST_TAPE_FLAGS_LEVEL_LOW ) {
    fprintf( stderr,
             "%s: reading first edge of `%s' gave unexpected flags 0x%04x; expected 0x%04x\n",
	     progname, filename, flags, TEST_TAPE_FLAGS_LEVEL_LOW );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( tstates != 667 ) {
    fprintf( stderr, "%s: first edge of `%s' was %u tstates; expected 667\n",
	     progname, filename, tstates );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

/* Test for bug #519: a one-byte TZX pure data block with zero used bits
   must not produce endless tape edges. */
test_return_t
tzx_pure_data_with_zero_used_bits( void )
{
  return play_tape( STATIC_TEST_PATH( "pure-data-usedbits-zero.tzx" ) );
}

/* Test for bug #88: writing empty .tap file causes crash */
test_return_t
writing_empty_tap_file( void )
{
  libspectrum_tape *tape;
  libspectrum_byte *buffer = (libspectrum_byte*)1;
  size_t length = 0;

  tape = libspectrum_tape_alloc();

  if( libspectrum_tape_write( &buffer, &length, tape, LIBSPECTRUM_ID_TAPE_TAP ) ) {
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  /* `buffer' should now have been set to NULL */
  if( buffer ) {
    fprintf( stderr, "%s: `buffer' was not NULL after libspectrum_tape_write()\n", progname );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

/* Test for bug #105: lack of sanity check in GDB code */
test_return_t
invalid_tzx_gdb( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid-gdb.tzx" ), LIBSPECTRUM_ERROR_CORRUPT );
}

/* Test for bug #106: empty DRB causes segfault */
test_return_t
empty_tzx_drb( void )
{
  return read_tape( STATIC_TEST_PATH( "empty-drb.tzx" ), LIBSPECTRUM_ERROR_NONE );
}

/* Test for bug #107: problems with invalid archive info block */
test_return_t
invalid_tzx_archive_info_block( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid-archiveinfo.tzx" ), LIBSPECTRUM_ERROR_CORRUPT );
}

/* Test for bug #108: invalid hardware info blocks can leak memory */
test_return_t
invalid_hardware_info_block_causes_memory_leak( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid-hardwareinfo.tzx" ), LIBSPECTRUM_ERROR_CORRUPT );
}

/* Test for bug #111: invalid Warajevo tape block offset causes segfault */
test_return_t
invalid_warajevo_tape_file( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid-warajevo-blockoffset.tap" ), LIBSPECTRUM_ERROR_CORRUPT );
}

/* Test for bug #112: invalid custom info block causes memory leak */
test_return_t
invalid_tzx_custom_info_block_causes_memory_leak( void )
{
  return read_tape( STATIC_TEST_PATH( "invalid-custominfo.tzx" ), LIBSPECTRUM_ERROR_CORRUPT );
}

/* Test for bug #113: loop end without a loop start block accesses uninitialised
   memory */
test_return_t
tzx_loop_end_block_with_loop_start_block( void )
{
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  const char *filename = STATIC_TEST_PATH( "loopend.tzx" );
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

  if( test_tape_get_next_edge( &tstates, &flags, tape ) ) {
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

/* Test for bug #113: TZX loop blocks broken */
test_return_t
tzx_loop_blocks( void )
{
  return play_tape( STATIC_TEST_PATH( "loop.tzx" ) );
}

/* Test for bug #118: TZX loop blocks still broken */
test_return_t
tzx_loop_blocks_2( void )
{
  return play_tape( STATIC_TEST_PATH( "loop2.tzx" ) );
}

/* Test for bug #119: TZX jump blocks broken */
test_return_t
tzx_jump_blocks( void )
{
  return play_tape( STATIC_TEST_PATH( "jump.tzx" ) );
}

/* Test for bug #121: crashes writing and reading empty CSW files */
test_return_t
csw_empty_file( void )
{
  return play_tape( STATIC_TEST_PATH( "empty.csw" ) );
}

/* Test for bug #125: .tap writing code does not handle all block types */
test_return_t
complete_tzx_to_tap_conversion( void )
{
  libspectrum_byte *buffer = NULL;
  size_t length = 0;
  libspectrum_tape *tape;
  const char *filename = DYNAMIC_TEST_PATH( "complete-tzx.tzx" );
  test_return_t r;

  r = load_tape( &tape, filename, LIBSPECTRUM_ERROR_NONE );
  if( r ) return r;

  if( libspectrum_tape_write( &buffer, &length, tape,
                              LIBSPECTRUM_ID_TAPE_TAP ) ) {
    fprintf( stderr, "%s: writing `%s' to a .tap file was not successful\n",
             progname, filename );
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

test_return_t
complete_tzx_timings( void )
{
  const char *filename = DYNAMIC_TEST_PATH( "complete-tzx.tzx" );
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  libspectrum_dword expected_sizes[20] = {
    15216886,	/* ROM */
    3493371,	/* Turbo */
    356310,	/* Pure tone */
    1761,	/* Pulses */
    1993724,	/* Pure data */
    2163000,	/* Pause */
    0,		/* Group start */
    0,		/* Group end */
    0,		/* Jump */
    205434,	/* Pure tone */
    0,		/* Loop start */
    154845,	/* Pure tone */
    0,		/* Loop end */
    0,		/* Stop tape if in 48K mode */
    0,		/* Comment */
    0,		/* Message */
    0,		/* Archive info */
    0,		/* Hardware */
    0,		/* Custom info */
    771620,	/* Pure tone */
  };
  libspectrum_dword *next_size = &expected_sizes[ 0 ];
  test_return_t r = TEST_PASS;

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  tape = libspectrum_tape_alloc();

  if( libspectrum_tape_read( tape, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
			     filename ) ) {
    libspectrum_tape_free( tape );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  block = libspectrum_tape_iterator_init( &it, tape );

  while( block )
  {
    libspectrum_dword actual_size = libspectrum_tape_block_length( block );

    if( actual_size != *next_size )
    {
      fprintf( stderr, "%s: block had length %lu, but expected %lu\n", progname, (unsigned long)actual_size, (unsigned long)*next_size );
      r = TEST_FAIL;
      break;
    }

    block = libspectrum_tape_iterator_next( &it );
    next_size++;
  }

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return r;
}

/* Test for bug #379: converting .tap file to .csw causes crash */
test_return_t
csw_conversion( void )
{
  libspectrum_byte *buffer = NULL;
  size_t length = 0;
  libspectrum_tape *tape;
  const char *filename = STATIC_TEST_PATH( "standard-tap.tap" );
  test_return_t r;

  r = load_tape( &tape, filename, LIBSPECTRUM_ERROR_NONE );
  if( r ) return r;

  if( libspectrum_tape_write( &buffer, &length, tape,
                              LIBSPECTRUM_ID_TAPE_CSW ) ) {
    fprintf( stderr, "%s: writing `%s' to a .csw file was not successful\n",
             progname, filename );
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return TEST_PASS;
}

/* CSW at 44.1 kHz must carry fractional t-states across pulses and retain
   its header rate when written again. */
test_return_t
csw_sample_rate_precision( void )
{
  libspectrum_byte input[ 55 ] = { 0 }, *output = NULL;
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  libspectrum_tape_block *block;
  size_t length = 0;
  libspectrum_dword rate;
  const libspectrum_dword expected[] = { 7936, 7937, 7936 };
  size_t i;
  test_return_t r = TEST_FAIL;

  if( !tape ) return TEST_INCOMPLETE;
  memcpy( input, "Compressed Square Wave\x1a", 23 );
  input[ 23 ] = 2; /* CSW v2 */
  input[ 25 ] = 0x44; input[ 26 ] = 0xac; /* 44100 Hz */
  input[ 33 ] = 1; /* uncompressed RLE */
  input[ 52 ] = input[ 53 ] = input[ 54 ] = 100;

  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_CSW, NULL ) ) goto done;
  block = libspectrum_tape_current_block( tape );
  if( !block || libspectrum_tape_block_length( block ) != 23809 ) {
    fprintf( stderr, "%s: CSW 44.1 kHz block duration incorrect\n", progname );
    goto done;
  }
  for( i = 0; i < 3; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ||
        edge.tstates != expected[i] ) {
      fprintf( stderr, "%s: CSW 44.1 kHz edge %lu incorrect\n",
               progname, (unsigned long)i );
      goto done;
    }
  }
  if( libspectrum_tape_write( &output, &length, tape,
                              LIBSPECTRUM_ID_TAPE_CSW ) || length < 29 )
    goto done;
  rate = libspectrum_read_dword_le( output + 25 );
  if( rate != 44100 ) {
    fprintf( stderr, "%s: CSW write-back rate %" PRIu32 ", expected 44100\n",
             progname, rate );
    goto done;
  }
  r = TEST_PASS;
done:
  libspectrum_free( output );
  libspectrum_tape_free( tape );
  return r;
}

/* A Fuse-style RLE pulse block with an exact sample rate (bug #530) keeps
   the rate through a TZX and CSW round trip and plays back with exact
   cumulative duration over a substantial number of pulses. */
test_return_t
rle_pulse_sample_rate_precision( void )
{
  const size_t pulses = 44100, pulse_samples = 100;
  const libspectrum_dword rate = 44100;
  /* 44100 pulses of 100 samples: the remainder carry must make the whole
     stream add up to exactly 4410000 * 3500000 / 44100 t-states */
  const libspectrum_qword expected_total =
    (libspectrum_qword)pulses * pulse_samples * 3500000 / rate;
  static const libspectrum_dword first_edges[] = { 7936, 7937, 7936 };
  libspectrum_tape_edge edge;
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *roundtrip = NULL;
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, pulses );
  libspectrum_byte *output = NULL, *csw_output = NULL;
  size_t length = 0, csw_length = 0, i, seen = 0;
  libspectrum_qword total = 0;
  libspectrum_dword csw_rate;
  test_return_t r = TEST_FAIL;

  if( !tape || !block || !data ) {
    r = TEST_INCOMPLETE;
    libspectrum_free( data );
    if( block ) libspectrum_tape_block_free( block );
    goto done;
  }

  memset( data, pulse_samples, pulses );
  libspectrum_tape_block_set_scale( block, 3500000 / rate );
  libspectrum_tape_block_set_sample_rate( block, rate );
  libspectrum_tape_block_set_data_length( block, pulses );
  libspectrum_tape_block_set_data( block, data );

  if( libspectrum_tape_append_block( tape, block ) ) {
    libspectrum_tape_block_free( block );
    goto done;
  }
  data = NULL; /* the appended block owns the data now */

  /* Writing TZX must keep the exact rate: the block becomes a native TZX
     CSW recording rather than a sampled Direct Recording block */
  if( libspectrum_tape_write( &output, &length, tape,
                              LIBSPECTRUM_ID_TAPE_TZX ) ||
      length < 11 || output[ 10 ] != LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ) {
    goto done;
  }

  roundtrip = libspectrum_tape_alloc();
  if( !roundtrip ||
      libspectrum_tape_read( roundtrip, output, length,
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;

  block = libspectrum_tape_current_block( roundtrip );
  if( !block || libspectrum_tape_block_type( block ) !=
        LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ||
      libspectrum_tape_block_sample_rate( block ) != rate ||
      libspectrum_tape_block_csw_pulses( block ) != pulses ||
      libspectrum_tape_block_length( block ) != expected_total ) goto done;

  /* Every edge carries the fractional remainder, so the cumulative
     playback duration is exact across the whole stream */
  memset( &edge, 0, sizeof( edge ) );
  for( i = 0; i < pulses + 8; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, roundtrip ) ) goto done;
    if( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) break;
    if( !edge.tstates ) continue;
    if( seen < 3 && edge.tstates != first_edges[ seen ] ) goto done;
    total += edge.tstates;
    seen++;
  }
  if( seen != pulses || total != expected_total ) goto done;

  /* Writing the round-tripped tape back to CSW keeps the exact rate */
  if( libspectrum_tape_write( &csw_output, &csw_length, roundtrip,
                              LIBSPECTRUM_ID_TAPE_CSW ) || csw_length < 29 )
    goto done;
  csw_rate = libspectrum_read_dword_le( csw_output + 25 );
  if( csw_rate != rate ) goto done;

  r = TEST_PASS;

done:
  if( r == TEST_FAIL )
    fprintf( stderr,
             "%s: exact-rate RLE pulse round trip or playback precision failed\n",
             progname );
  libspectrum_free( output );
  libspectrum_free( csw_output );
  libspectrum_free( data );
  if( tape ) libspectrum_tape_free( tape );
  if( roundtrip ) libspectrum_tape_free( roundtrip );
  return r;
}

/* The last CSW pulse does not generate a spurious edge at its end. */
test_return_t
tzx_csw_roundtrip_and_levels( void )
{
  static const libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x2b,1,0,0,0,1, /* start high */
    0x18,12,0,0,0,0,0,0x44,0xac,0,1,2,0,0,0,1,1,
    0x12,10,0,1,0 /* next pulse must inherit the final CSW level */
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *again = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  libspectrum_tape_block *block;
  libspectrum_tape_iterator iterator;
  libspectrum_byte *output = NULL;
  size_t length = 0, i, seen = 0;
  const libspectrum_dword durations[] = { 79, 79, 10 };
  /* The first pulse keeps the level the 0x2b block set; the second alternates */
  const libspectrum_tape_signal_level levels[] = { LIBSPECTRUM_TAPE_SIGNAL_HIGH,
                         LIBSPECTRUM_TAPE_SIGNAL_LOW,
                         LIBSPECTRUM_TAPE_SIGNAL_HIGH };
  test_return_t r = TEST_FAIL;
  if( !tape || !again ) { r = TEST_INCOMPLETE; goto done; }
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  block = libspectrum_tape_iterator_init( &iterator, tape );
  if( block ) block = libspectrum_tape_iterator_next( &iterator );
  if( !block || libspectrum_tape_block_type( block ) !=
      LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ||
      libspectrum_tape_block_sample_rate( block ) != 44100 ||
      libspectrum_tape_block_csw_pulses( block ) != 2 ||
      libspectrum_tape_block_length( block ) != 158 ) goto done;
  if( libspectrum_tape_write( &output, &length, tape,
                              LIBSPECTRUM_ID_TAPE_TZX ) ||
      length != sizeof( input ) || memcmp( input, output, length ) ||
      libspectrum_tape_read( again, output, length,
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( i = 0; i < 8 && seen < 3; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, again ) ) goto done;
    if( !edge.tstates ) continue;
    if( edge.tstates != durations[seen] || edge.level != levels[seen] ||
        ( seen == 0 && edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) )
      goto done;
    seen++;
  }
  if( seen != 3 ) goto done;
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: TZX CSW round-trip or level continuity failed\n",
             progname );
  libspectrum_free( output );
  if( tape ) libspectrum_tape_free( tape );
  if( again ) libspectrum_tape_free( again );
  return r;
}

/* Z-RLE preserves the pause, and only a nonzero pause forces the next
   block to start low. */
test_return_t
tzx_csw_compressed_pause( void )
{
#ifdef HAVE_ZLIB_H
  static const libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x2b,1,0,0,0,1,
    0x18,20,0,0,0,1,0,0x44,0xac,0,2,2,0,0,0,
    0x78,0x9c,0x63,0x64,0x04,0x00,0x00,0x05,0x00,0x03,
    0x12,10,0,1,0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape *again = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  libspectrum_byte *output = NULL;
  size_t length = 0, i, seen = 0;
  const libspectrum_dword durations[] = { 79, 79, 3500, 10 };
  /* The first pulse keeps the level the 0x2b block set; the second alternates */
  const libspectrum_tape_signal_level levels[] = {
    LIBSPECTRUM_TAPE_SIGNAL_HIGH, LIBSPECTRUM_TAPE_SIGNAL_LOW,
    LIBSPECTRUM_TAPE_SIGNAL_LOW, LIBSPECTRUM_TAPE_SIGNAL_LOW };
  test_return_t r = TEST_FAIL;
  if( !tape || !again ) { r = TEST_INCOMPLETE; goto done; }
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  block = libspectrum_tape_iterator_init( &it, tape );
  if( block ) block = libspectrum_tape_iterator_next( &it );
  if( !block || libspectrum_tape_block_csw_compression( block ) != 2 ||
      libspectrum_tape_block_pause( block ) != 1 ||
      libspectrum_tape_block_length( block ) != 3658 ) goto done;
  if( libspectrum_tape_write( &output, &length, tape,
                              LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( again, output, length,
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( i = 0; i < 9 && seen < 4; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, again ) ) goto done;
    if( !edge.tstates ) continue;
    if( edge.tstates != durations[seen] || edge.level != levels[seen] ||
        ( seen == 2 && edge.transition != LIBSPECTRUM_TAPE_TRANSITION_FORCE_LOW ) ||
        ( seen == 3 && edge.transition != LIBSPECTRUM_TAPE_TRANSITION_FORCE_LOW ) )
      goto done;
    seen++;
  }
  if( seen != 4 ) goto done;
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: compressed TZX CSW or pause playback failed\n",
             progname );
  libspectrum_free( output );
  if( tape ) libspectrum_tape_free( tape );
  if( again ) libspectrum_tape_free( again );
  return r;
#else
  return TEST_PASS;
#endif
}

/* With a single pulse, its closing edge occurs at the pulse's end. */
test_return_t
tzx_csw_single_pulse_level( void )
{
  static const libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x2b,1,0,0,0,1,
    0x18,11,0,0,0,0,0,0x44,0xac,0,1,1,0,0,0,1,
    0x12,10,0,1,0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  size_t i, seen = 0;
  test_return_t r = TEST_FAIL;
  if( !tape ) return TEST_INCOMPLETE;
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( i = 0; i < 7 && seen < 2; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    if( !edge.tstates ) continue;
    if( seen == 0 && ( edge.tstates != 79 ||
         edge.level != LIBSPECTRUM_TAPE_SIGNAL_HIGH ||
         edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) ) goto done;
    if( seen == 1 && ( edge.tstates != 10 ||
         edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
    seen++;
  }
  if( seen == 2 ) r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: single-pulse TZX CSW level failed\n", progname );
  libspectrum_tape_free( tape );
  return r;
}

/* A pause-free CSW closes its last pulse at the recorded duration. */
test_return_t
tzx_csw_final_pulse_edge( void )
{
  static const libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x18,12,0,0,0,0,0,0x44,0xac,0,1,2,0,0,0,1,1,
    0x12,10,0,1,0
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  size_t i;
  test_return_t r = TEST_FAIL;
  if( !tape ) return TEST_INCOMPLETE;
  if( libspectrum_tape_read( tape, input, sizeof( input ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( i = 0; i < 4; i++ ) {
    if( libspectrum_tape_get_next_edge( &edge, tape ) ) goto done;
    if( i < 2 && edge.tstates != 79 ) goto done;
    if( i == 0 && ( edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ||
                    edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) )
      goto done;
    if( i == 1 && ( edge.level != LIBSPECTRUM_TAPE_SIGNAL_HIGH ||
                    edge.transition != LIBSPECTRUM_TAPE_TRANSITION_TOGGLE ) )
      goto done;
    if( i == 2 && ( edge.tstates != 0 ||
                    edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) )
      goto done;
    if( i == 3 && ( edge.tstates != 10 ||
                    edge.level != LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
  }
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: pause-free CSW lost its closing edge\n", progname );
  libspectrum_tape_free( tape );
  return r;
}

/* A sole CSW pulse holds the incoming level. The terminal zero-time event
   closes it after its recorded duration without adding elapsed time. */
test_return_t
tzx_csw_single_final_pulse_edge( void )
{
  static libspectrum_byte input[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x2b,1,0,0,0,0,
    0x18,11,0,0,0,0,0,0x44,0xac,0,1,1,0,0,0,1
  };
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_edge edge;
  size_t i;
  test_return_t r = TEST_FAIL;
  if( !tape ) return TEST_INCOMPLETE;
  for( i = 0; i < 2; i++ ) {
    input[15] = i;
    if( libspectrum_tape_read( tape, input, sizeof( input ),
                               LIBSPECTRUM_ID_TAPE_TZX, NULL ) ||
        libspectrum_tape_get_next_edge( &edge, tape ) ||
        libspectrum_tape_get_next_edge( &edge, tape ) ||
        edge.tstates != 79 ||
        edge.level != ( i ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                             LIBSPECTRUM_TAPE_SIGNAL_LOW ) ||
        edge.transition != LIBSPECTRUM_TAPE_TRANSITION_NONE ) goto done;
    if( libspectrum_tape_get_next_edge( &edge, tape ) || edge.tstates ||
        edge.transition != LIBSPECTRUM_TAPE_TRANSITION_TOGGLE ||
        edge.level != ( i ? LIBSPECTRUM_TAPE_SIGNAL_LOW :
                             LIBSPECTRUM_TAPE_SIGNAL_HIGH ) ||
        !( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) ) goto done;
    libspectrum_tape_clear( tape );
  }
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: single CSW pulse lost its closing edge\n", progname );
  libspectrum_tape_free( tape );
  return r;
}

/* Return timed samples without confusing metadata and tail events with
   recorded pulses. A timed event may itself carry end-of-tape. */
static int
csw_test_next_sample( libspectrum_tape *tape, libspectrum_tape_edge *edge,
                      int *ended )
{
  size_t i;
  if( *ended ) return 0;
  for( i = 0; i < 16; i++ ) {
    if( libspectrum_tape_get_next_edge( edge, tape ) ) return -1;
    if( edge->flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) *ended = 1;
    if( edge->tstates ) return 1;
    if( *ended ) return 0;
  }
  return -1;
}

/* Synthetic coverage of bug #528: three short pulses followed by a long
   pulse, with no program content. At 44100 Hz, pulses of 13, 17, 19 and
   50000 samples total 3972142 T-states with the timing remainder carried.
   The final transition must occur before the long pulse, not at end-of-tape. */
test_return_t
tzx_csw_bug_528_waveform( void )
{
  static const libspectrum_byte pulses[] = {
    13, 17, 19, 0, 0x50, 0xc3, 0, 0
  };
  static const libspectrum_byte tzx[] = {
    'Z','X','T','a','p','e','!',0x1a,1,20,
    0x18,18,0,0,0,0,0,0x44,0xac,0,1,4,0,0,0,
    13,17,19,0,0x50,0xc3,0,0
  };
  static const libspectrum_dword durations[] = { 1031, 1349, 1508, 3968254 };
  libspectrum_byte csw[60] = { 0 };
  libspectrum_tape *tapes[4];
  libspectrum_tape_edge edges[4];
  libspectrum_byte *output = NULL;
  size_t output_length = 0, i, count = 0;
  libspectrum_qword duration = 0;
  int ended[4] = { 0, 0, 0, 0 }, next[4];
  test_return_t result = TEST_FAIL;
  for( i = 0; i < 4; i++ ) tapes[i] = libspectrum_tape_alloc();
  memcpy( csw, "Compressed Square Wave\x1a", 23 );
  csw[23] = 2;
  csw[25] = 0x44; csw[26] = 0xac;
  csw[29] = 4; csw[33] = 1;
  memcpy( csw + 52, pulses, sizeof( pulses ) );
  if( libspectrum_tape_read( tapes[0], csw, sizeof( csw ),
                             LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
      libspectrum_tape_read( tapes[1], tzx, sizeof( tzx ),
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
  for( i = 0; i < 2; i++ ) {
    if( libspectrum_tape_write( &output, &output_length, tapes[i],
                                LIBSPECTRUM_ID_TAPE_PZX ) ||
        libspectrum_tape_read( tapes[i + 2], output, output_length,
                               LIBSPECTRUM_ID_TAPE_PZX, NULL ) ) goto done;
    libspectrum_free( output ); output = NULL; output_length = 0;
  }
  for( ;; ) {
    for( i = 0; i < 4; i++ ) {
      next[i] = csw_test_next_sample( tapes[i], &edges[i], &ended[i] );
      if( next[i] < 0 || next[i] != next[0] ) goto done;
    }
    if( !next[0] ) break;
    if( ++count > 4 ) goto done;
    for( i = 0; i < 4; i++ ) {
      if( edges[i].tstates != durations[count - 1] ||
          edges[i].level != ( count & 1 ? LIBSPECTRUM_TAPE_SIGNAL_LOW :
                                        LIBSPECTRUM_TAPE_SIGNAL_HIGH ) ) goto done;
      /* PZX may encode the same edge as an explicit forced high level. */
      if( count == 4 &&
          ( i < 2 ? edges[i].transition != LIBSPECTRUM_TAPE_TRANSITION_TOGGLE :
                    edges[i].transition == LIBSPECTRUM_TAPE_TRANSITION_NONE ) ) {
        fprintf( stderr, "%s: final sample tape %lu: %u tstates, transition %d\n",
                 progname, (unsigned long)i, edges[i].tstates,
                 edges[i].transition );
        goto done;
      }
    }
    duration += edges[0].tstates;
  }
  if( count == 4 && duration == 3972142 ) result = TEST_PASS;
  else fprintf( stderr, "%s: synthetic total %llu tstates in %lu samples\n",
                progname, (unsigned long long)duration, (unsigned long)count );
done:
  if( result == TEST_FAIL )
    fprintf( stderr, "%s: bug #528 CSW waveform differs at sample %lu\n",
             progname, (unsigned long)count );
  libspectrum_free( output );
  for( i = 0; i < 4; i++ ) libspectrum_tape_free( tapes[i] );
  return result;
}

/* Standalone CSW's exact rate and initial polarity survive TZX export. */
test_return_t
csw_to_tzx_csw_with_polarity( void )
{
  libspectrum_byte input[54] = { 0 }, *output = NULL, *csw_output = NULL;
  libspectrum_tape *source = libspectrum_tape_alloc();
  libspectrum_tape *roundtrip = libspectrum_tape_alloc();
  libspectrum_tape_iterator iterator;
  libspectrum_tape_block *block;
  libspectrum_tape_edge edge;
  size_t length = 0, csw_length = 0, offset, i;
  test_return_t r = TEST_FAIL;
  if( !source || !roundtrip ) { r = TEST_INCOMPLETE; goto done; }
  memcpy( input, "Compressed Square Wave\x1a", 23 );
  input[23] = 2;
  input[25] = 0x44; input[26] = 0xac;
  input[33] = 1;
  input[52] = input[53] = 100;

  for( i = 0; i < 2; i++ ) {
    input[34] = i; /* CSW initial polarity: low, then high. */
    if( libspectrum_tape_read( source, input, sizeof( input ),
                               LIBSPECTRUM_ID_TAPE_CSW, NULL ) ||
        libspectrum_tape_write( &csw_output, &csw_length, source,
                                LIBSPECTRUM_ID_TAPE_CSW ) ||
        csw_length < 35 || ( csw_output[34] & 1 ) != i ||
        libspectrum_tape_write( &output, &length, source,
                                LIBSPECTRUM_ID_TAPE_TZX ) ) goto done;
    offset = 16;
    if( length != offset + 17 ||
        output[10] != 0x2b || output[15] != i ||
        output[offset] != 0x18 || output[offset + 1] != 12 ||
        output[offset + 7] != 0x44 || output[offset + 8] != 0xac ||
        output[offset + 10] != 1 || output[offset + 11] != 2 ||
        output[offset + 15] != 100 || output[offset + 16] != 100 ||
        libspectrum_tape_read( roundtrip, output, length,
                               LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;
    block = libspectrum_tape_iterator_init( &iterator, roundtrip );
    block = libspectrum_tape_iterator_next( &iterator );
    if( !block || libspectrum_tape_block_type( block ) !=
        LIBSPECTRUM_TAPE_BLOCK_TZX_CSW ||
        libspectrum_tape_block_sample_rate( block ) != 44100 ) goto done;
    /* Explicit low must be preserved too when following a high block. */
    if( libspectrum_tape_get_next_edge( &edge, roundtrip ) ) goto done;
    if( libspectrum_tape_get_next_edge( &edge, roundtrip ) ) goto done;
    /* The conversion plays the first pulse at the CSW file's own polarity */
    if( edge.level != ( i ? LIBSPECTRUM_TAPE_SIGNAL_HIGH :
                            LIBSPECTRUM_TAPE_SIGNAL_LOW ) ) goto done;
    libspectrum_free( output ); output = NULL; length = 0;
    libspectrum_free( csw_output ); csw_output = NULL; csw_length = 0;
    libspectrum_tape_clear( source );
    libspectrum_tape_clear( roundtrip );
  }
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: CSW to TZX conversion lost rate or polarity\n",
             progname );
  libspectrum_free( output );
  libspectrum_free( csw_output );
  if( source ) libspectrum_tape_free( source );
  if( roundtrip ) libspectrum_tape_free( roundtrip );
  return r;
}

/* A Fuse-style block has only integer tstates/sample; do not invent a
   sample rate for it by writing a TZX CSW block. */
test_return_t
scale_only_rle_to_tzx_direct_recording( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, 2 );
  libspectrum_byte *output = NULL;
  size_t length = 0;
  test_return_t r = TEST_FAIL;
  if( !tape || !block || !data ) {
    r = TEST_INCOMPLETE;
    libspectrum_free( data );
    if( block ) libspectrum_tape_block_free( block );
    goto done;
  }
  data[0] = data[1] = 100;
  libspectrum_tape_block_set_scale( block, 79 );
  libspectrum_tape_block_set_data_length( block, 2 );
  libspectrum_tape_block_set_data( block, data );
  if( libspectrum_tape_append_block( tape, block ) ) {
    libspectrum_tape_block_free( block );
    goto done;
  }
  if( libspectrum_tape_write( &output, &length, tape,
                              LIBSPECTRUM_ID_TAPE_TZX ) ||
      length < 11 || output[10] != LIBSPECTRUM_TAPE_BLOCK_RAW_DATA )
    goto done;
  r = TEST_PASS;
done:
  if( r == TEST_FAIL )
    fprintf( stderr, "%s: scale-only RLE did not use Direct Recording\n",
             progname );
  libspectrum_free( output );
  if( tape ) libspectrum_tape_free( tape );
  return r;
}

/* Test for bug #461: writing a recorded RLE pulse block as CSW crashed. */
test_return_t
csw_rle_pulse_conversion( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
  libspectrum_byte *buffer = NULL;
  size_t length = 0;
  libspectrum_dword sample_rate;
  test_return_t r = TEST_FAIL;

  data[ 0 ] = 1;
  libspectrum_tape_block_set_scale( block, 79 );
  libspectrum_tape_block_set_data( block, data );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_append_block( tape, block );

  if( libspectrum_tape_write( &buffer, &length, tape,
                              LIBSPECTRUM_ID_TAPE_CSW ) ) {
    fprintf( stderr, "%s: writing an RLE pulse block to a .csw file was not successful\n",
             progname );
    goto done;
  }

  if( length < 29 ) {
    fprintf( stderr, "%s: CSW output was shorter than its header\n", progname );
    goto done;
  }

  sample_rate = libspectrum_read_dword_le( buffer + 25 );
  /* Scale-only recordings have exact T-state durations, not a known rate. */
  if( sample_rate != 3500000 ) {
    fprintf( stderr, "%s: CSW sample rate was %" PRIu32 ", expected %d\n",
             progname, sample_rate, 3500000 );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( buffer );
  libspectrum_tape_free( tape );
  return r;
}

test_return_t
tape_peek_next_block( void )
{
  const char *filename = DYNAMIC_TEST_PATH( "complete-tzx.tzx" );
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  libspectrum_tape_iterator it;
  libspectrum_tape_type expected_next_block_types[19] = {
    LIBSPECTRUM_TAPE_BLOCK_TURBO,       /* ROM */
    LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,   /* Turbo */
    LIBSPECTRUM_TAPE_BLOCK_PULSES,      /* Pure tone */
    LIBSPECTRUM_TAPE_BLOCK_PURE_DATA,   /* Pulses */
    LIBSPECTRUM_TAPE_BLOCK_PAUSE,       /* Pure data */
    LIBSPECTRUM_TAPE_BLOCK_GROUP_START, /* Pause */
    LIBSPECTRUM_TAPE_BLOCK_GROUP_END,   /* Group start */
    LIBSPECTRUM_TAPE_BLOCK_JUMP,        /* Group end */
    LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,   /* Jump */
    LIBSPECTRUM_TAPE_BLOCK_LOOP_START,  /* Pure tone */
    LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,   /* Loop start */
    LIBSPECTRUM_TAPE_BLOCK_LOOP_END,    /* Pure tone */
    LIBSPECTRUM_TAPE_BLOCK_STOP48,      /* Loop end */
    LIBSPECTRUM_TAPE_BLOCK_COMMENT,     /* Stop tape if in 48K mode */
    LIBSPECTRUM_TAPE_BLOCK_MESSAGE,     /* Comment */
    LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO,/* Message */
    LIBSPECTRUM_TAPE_BLOCK_HARDWARE,    /* Archive info */
    LIBSPECTRUM_TAPE_BLOCK_CUSTOM,      /* Hardware */
    LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,   /* Custom info */
  };
  libspectrum_tape_type *next_block_type = &expected_next_block_types[ 0 ];
  test_return_t r = TEST_PASS;
  int blocks_processed = 0;
  /* Expect to check the next block type of 19 of the 20 blocks in the test
     tzx */
  int expected_block_count = ARRAY_SIZE( expected_next_block_types );

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  tape = libspectrum_tape_alloc();

  if( libspectrum_tape_read( tape, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
			     filename ) )
  {
    libspectrum_tape_free( tape );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  libspectrum_tape_iterator_init( &it, tape );

  while( libspectrum_tape_iterator_peek_next( it ) )
  {
    libspectrum_tape_type actual_next_block_type =
      libspectrum_tape_block_type( libspectrum_tape_iterator_peek_next( it ) );

    if( actual_next_block_type != *next_block_type )
    {
      r = TEST_FAIL;
      break;
    }

    libspectrum_tape_iterator_next( &it );
    next_block_type++;
    blocks_processed++;
  }

  if( blocks_processed != expected_block_count )
  {
      r = TEST_FAIL;
  }

  if( libspectrum_tape_free( tape ) ) return TEST_INCOMPLETE;

  return r;
}

test_return_t
read_mono_wav_threshold_fixture( void )
{
  return check_wav_block( DYNAMIC_TEST_PATH( "wav-mono-threshold.wav" ),
                          22050, 0xa9, 1 );
}

test_return_t
read_stereo_wav_mixdown_fixture( void )
{
  return check_wav_block( DYNAMIC_TEST_PATH( "wav-stereo-mixdown.wav" ),
                          22050, 0x8d, 1 );
}

test_return_t
read_wav_exact_sample_timing( void )
{
  return check_wav_block( DYNAMIC_TEST_PATH( "wav-exact-timing.wav" ),
                          48000, 0x69, 301 );
}

/* Test that PZX archive info tags (title + author) are correctly parsed.
   Regression test for the pzx_read_string bug where *ptr was set to end,
   causing all tag-value pairs after the title to be silently ignored. */
test_return_t
pzx_archive_info_tags_title_and_author_correctly_parsed( void )
{
  const char *filename = STATIC_TEST_PATH( "pzx-archive-info-tags.pzx" );
  libspectrum_tape *tape = NULL;
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  test_return_t r = TEST_INCOMPLETE;

  if( load_tape( &tape, filename, LIBSPECTRUM_ERROR_NONE ) ) return TEST_INCOMPLETE;

  /* Find the ARCHIVE_INFO block */
  for( block = libspectrum_tape_iterator_init( &it, tape );
       block;
       block = libspectrum_tape_iterator_next( &it ) ) {
    if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO )
      break;
  }

  if( !block ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: no ARCHIVE_INFO block found\n", progname );
    goto done;
  }

  /* Expect: title (ID 0x00, "Test Game") and Author (ID 0x02, "Joe Bloggs") */
  if( libspectrum_tape_block_count( block ) != 2 ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected 2 archive info entries, got %zu\n",
             progname, libspectrum_tape_block_count( block ) );
    r = TEST_FAIL;
    goto done;
  }

  if( libspectrum_tape_block_ids( block, 0 ) != 0x00 ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected ID 0x00 for entry 0, got 0x%02x\n",
             progname, libspectrum_tape_block_ids( block, 0 ) );
    r = TEST_FAIL;
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 0 ), "Test Game" ) != 0 ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected title 'Test Game', got '%s'\n",
             progname, libspectrum_tape_block_texts( block, 0 ) );
    r = TEST_FAIL;
    goto done;
  }

  if( libspectrum_tape_block_ids( block, 1 ) != 0x02 ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected ID 0x02 (Author) for entry 1, got 0x%02x\n",
             progname, libspectrum_tape_block_ids( block, 1 ) );
    r = TEST_FAIL;
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 1 ), "Joe Bloggs" ) != 0 ) {
    fprintf( stderr, "%s: snap_ay_registers_array_getter_setter_all_16_registers: expected author 'Joe Bloggs', got '%s'\n",
             progname, libspectrum_tape_block_texts( block, 1 ) );
    r = TEST_FAIL;
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_free( tape );
  return r;
}

test_return_t
tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter( void )
{
  /* tape block: TURBO block pilot_length, sync1_length, sync2_length getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_TURBO );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_TURBO ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: expected TURBO block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_pilot_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: default pilot_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pilot_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pilot_length( block, 2168 );
  if( libspectrum_tape_block_pilot_length( block ) != 2168 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: expected pilot_length=2168, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pilot_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_sync1_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: default sync1_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_sync1_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_sync1_length( block, 667 );
  if( libspectrum_tape_block_sync1_length( block ) != 667 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: expected sync1_length=667, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_sync1_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_sync2_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: default sync2_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_sync2_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_sync2_length( block, 735 );
  if( libspectrum_tape_block_sync2_length( block ) != 735 ) {
    fprintf( stderr, "%s: tape_turbo_block_pilot_length_sync1_length_sync2_length_getter_setter: expected sync2_length=735, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_sync2_length( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter( void )
{
  /* tape block: TURBO block bit0_length, bit1_length, pilot_pulses, pause getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_TURBO );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_bit0_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: default bit0_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit0_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_bit0_length( block, 855 );
  if( libspectrum_tape_block_bit0_length( block ) != 855 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: expected bit0_length=855, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit0_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_bit1_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: default bit1_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit1_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_bit1_length( block, 1710 );
  if( libspectrum_tape_block_bit1_length( block ) != 1710 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: expected bit1_length=1710, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit1_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_pilot_pulses( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: default pilot_pulses should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pilot_pulses( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pilot_pulses( block, 8063 );
  if( libspectrum_tape_block_pilot_pulses( block ) != 8063 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: expected pilot_pulses=8063, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pilot_pulses( block ) );
    goto done;
  }

  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pause( block, 1000 );
  if( libspectrum_tape_block_pause( block ) != 1000 ) {
    fprintf( stderr, "%s: tape_turbo_block_bit0_length_bit1_length_pilot_pulses_pause_getter_setter: expected pause=1000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_pure_tone_block_pulse_length_and_count_getter_setter( void )
{
  /* tape block: PURE_TONE block pulse_length and count getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PURE_TONE ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: expected PURE_TONE block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_pulse_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: default pulse_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pulse_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pulse_length( block, 2168 );
  if( libspectrum_tape_block_pulse_length( block ) != 2168 ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: expected pulse_length=2168, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pulse_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }
  libspectrum_tape_block_set_count( block, 3223 );
  if( libspectrum_tape_block_count( block ) != 3223 ) {
    fprintf( stderr, "%s: tape_pure_tone_block_pulse_length_and_count_getter_setter: expected count=3223, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter( void )
{
  /* tape block: PURE_DATA block bit0_length, bit1_length, bits_in_last_byte, pause getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_DATA );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PURE_DATA ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: expected PURE_DATA block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_bit0_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: default bit0_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit0_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_bit0_length( block, 855 );
  if( libspectrum_tape_block_bit0_length( block ) != 855 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: expected bit0_length=855, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit0_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_bit1_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: default bit1_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit1_length( block ) );
    goto done;
  }
  libspectrum_tape_block_set_bit1_length( block, 1710 );
  if( libspectrum_tape_block_bit1_length( block ) != 1710 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: expected bit1_length=1710, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit1_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_bits_in_last_byte( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: default bits_in_last_byte should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }
  libspectrum_tape_block_set_bits_in_last_byte( block, 8 );
  if( libspectrum_tape_block_bits_in_last_byte( block ) != 8 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: expected bits_in_last_byte=8, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }

  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pause( block, 500 );
  if( libspectrum_tape_block_pause( block ) != 500 ) {
    fprintf( stderr, "%s: tape_pure_data_block_bit0_length_bit1_length_bits_in_last_byte_pause_getter_setter: expected pause=500, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_pause_block_pause_length_and_level_getter_setter( void )
{
  /* tape block: PAUSE block pause length and level getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PAUSE ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: expected PAUSE block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }
  libspectrum_tape_block_set_pause( block, 2000 );
  if( libspectrum_tape_block_pause( block ) != 2000 ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: expected pause=2000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  if( libspectrum_tape_block_level( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: default level should be 0, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }
  libspectrum_tape_block_set_level( block, 1 );
  if( libspectrum_tape_block_level( block ) != 1 ) {
    fprintf( stderr, "%s: tape_pause_block_pause_length_and_level_getter_setter: expected level=1, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_rom_block_data_data_length_and_pause_getter_setter( void )
{
  /* tape block: ROM block data, data_length, and pause getter/setter */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_ROM );
  test_return_t r = TEST_FAIL;
  libspectrum_byte *data;

  if( !block ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_ROM ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: expected ROM block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) != NULL ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: default data should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: default data_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  data = libspectrum_malloc( 3 );
  data[0] = 0x00; data[1] = 0x01; data[2] = 0x02;
  libspectrum_tape_block_set_data_length( block, 3 );
  libspectrum_tape_block_set_data( block, data );

  if( libspectrum_tape_block_data_length( block ) != 3 ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: expected data_length=3, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) != data ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: data pointer mismatch\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  libspectrum_tape_block_set_pause( block, 1000 );
  if( libspectrum_tape_block_pause( block ) != 1000 ) {
    fprintf( stderr, "%s: tape_rom_block_data_data_length_and_pause_getter_setter: expected pause=1000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_pulses_block_count_and_pulse_lengths_getter_setter( void )
{
  /* tape block: PULSES block count and pulse_lengths getter/setter (round-trip) */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSES );
  libspectrum_dword *lengths = NULL;
  test_return_t r = TEST_FAIL;
  size_t i;

  if( !block ) {
    fprintf( stderr, "%s: tape_pulses_block_count_and_pulse_lengths_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PULSES ) {
    fprintf( stderr, "%s: tape_pulses_block_count_and_pulse_lengths_getter_setter: expected PULSES block type\n", progname );
    goto done;
  }

  /* Default count should be 0 */
  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pulses_block_count_and_pulse_lengths_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  /* Set up 4 pulse lengths and round-trip through the accessors */
  lengths = libspectrum_new( libspectrum_dword, 4 );
  lengths[0] = 667;
  lengths[1] = 735;
  lengths[2] = 855;
  lengths[3] = 1710;

  libspectrum_tape_block_set_count( block, 4 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  lengths = NULL; /* block owns the array now */

  if( libspectrum_tape_block_count( block ) != 4 ) {
    fprintf( stderr, "%s: tape_pulses_block_count_and_pulse_lengths_getter_setter: expected count=4, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  {
    libspectrum_dword expected[] = { 667, 735, 855, 1710 };
    for( i = 0; i < 4; i++ ) {
      if( libspectrum_tape_block_pulse_lengths( block, i ) != expected[i] ) {
        fprintf( stderr, "%s: tape_pulses_block_count_and_pulse_lengths_getter_setter: pulse_lengths[%lu] expected %lu, got %lu\n",
                 progname, (unsigned long)i, (unsigned long)expected[i],
                 (unsigned long)libspectrum_tape_block_pulse_lengths( block, i ) );
        goto done;
      }
    }
  }

  r = TEST_PASS;

done:
  libspectrum_free( lengths );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter( void )
{
  /* tape block: RAW_DATA block accessor getter/setter round-trip test */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
  test_return_t r = TEST_FAIL;
  libspectrum_byte *data;

  if( !block ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_RAW_DATA ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: expected RAW_DATA block type\n", progname );
    goto done;
  }

  /* bit_length default should be 0 */
  if( libspectrum_tape_block_bit_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: default bit_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit_length( block ) );
    goto done;
  }

  libspectrum_tape_block_set_bit_length( block, 3500 );
  if( libspectrum_tape_block_bit_length( block ) != 3500 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: expected bit_length=3500, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bit_length( block ) );
    goto done;
  }

  /* bits_in_last_byte default should be 0 */
  if( libspectrum_tape_block_bits_in_last_byte( block ) != 0 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: default bits_in_last_byte should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }

  libspectrum_tape_block_set_bits_in_last_byte( block, 8 );
  if( libspectrum_tape_block_bits_in_last_byte( block ) != 8 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: expected bits_in_last_byte=8, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }

  /* data default should be NULL; data_length default should be 0 */
  if( libspectrum_tape_block_data( block ) != NULL ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: default data should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: default data_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  data = libspectrum_malloc( 2 );
  data[0] = 0xaa; data[1] = 0x55;
  libspectrum_tape_block_set_data_length( block, 2 );
  libspectrum_tape_block_set_data( block, data );

  if( libspectrum_tape_block_data_length( block ) != 2 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: expected data_length=2, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) != data ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: data pointer mismatch\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data( block )[0] != 0xaa ||
      libspectrum_tape_block_data( block )[1] != 0x55 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: data content mismatch\n", progname );
    goto done;
  }

  /* pause default should be 0 */
  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  libspectrum_tape_block_set_pause( block, 1000 );
  if( libspectrum_tape_block_pause( block ) != 1000 ) {
    fprintf( stderr, "%s: tape_raw_data_block_bit_length_bits_in_last_byte_data_data_length_and_pause_getter_setter: expected pause=1000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter( void )
{
  /* tape block: PULSE_SEQUENCE block count, pulse_lengths, and pulse_repeats
     getter/setter (round-trip) */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  libspectrum_dword *lengths = NULL;
  size_t *repeats = NULL;
  test_return_t r = TEST_FAIL;
  size_t i;

  if( !block ) {
    fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE ) {
    fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: expected PULSE_SEQUENCE block type\n", progname );
    goto done;
  }

  /* Default count should be 0 */
  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  /* Set up 3 pulses (lengths and repeat counts) and round-trip */
  lengths = libspectrum_new( libspectrum_dword, 3 );
  lengths[0] = 2168;
  lengths[1] = 667;
  lengths[2] = 735;

  repeats = libspectrum_new( size_t, 3 );
  repeats[0] = 8063;
  repeats[1] = 1;
  repeats[2] = 1;

  libspectrum_tape_block_set_count( block, 3 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  lengths = NULL; /* block owns the array now */
  repeats = NULL; /* block owns the array now */

  if( libspectrum_tape_block_count( block ) != 3 ) {
    fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: expected count=3, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  {
    libspectrum_dword expected_lengths[] = { 2168, 667, 735 };
    size_t expected_repeats[] = { 8063, 1, 1 };
    for( i = 0; i < 3; i++ ) {
      if( libspectrum_tape_block_pulse_lengths( block, i ) != expected_lengths[i] ) {
        fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: pulse_lengths[%lu] expected %lu, got %lu\n",
                 progname, (unsigned long)i, (unsigned long)expected_lengths[i],
                 (unsigned long)libspectrum_tape_block_pulse_lengths( block, i ) );
        goto done;
      }
      if( libspectrum_tape_block_pulse_repeats( block, i ) != expected_repeats[i] ) {
        fprintf( stderr, "%s: tape_pulse_sequence_block_count_pulse_lengths_and_pulse_repeats_getter_setter: pulse_repeats[%lu] expected %lu, got %lu\n",
                 progname, (unsigned long)i, (unsigned long)expected_repeats[i],
                 (unsigned long)libspectrum_tape_block_pulse_repeats( block, i ) );
        goto done;
      }
    }
  }

  r = TEST_PASS;

done:
  libspectrum_free( lengths );
  libspectrum_free( repeats );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter( void )
{
  /* tape block: DATA_BLOCK accessor getter/setter round-trip test */
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  libspectrum_word *bit0_pulses = NULL, *bit1_pulses = NULL;
  libspectrum_byte *data = NULL;
  test_return_t r = TEST_FAIL;
  size_t i;

  if( !block ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected DATA_BLOCK block type\n", progname );
    goto done;
  }

  /* Default count should be 0 */
  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  libspectrum_tape_block_set_count( block, 16 );
  if( libspectrum_tape_block_count( block ) != 16 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected count=16, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  /* Default tail_length should be 0 */
  if( libspectrum_tape_block_tail_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default tail_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_tail_length( block ) );
    goto done;
  }

  libspectrum_tape_block_set_tail_length( block, 945 );
  if( libspectrum_tape_block_tail_length( block ) != 945 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected tail_length=945, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_tail_length( block ) );
    goto done;
  }

  /* Default level should be 0 */
  if( libspectrum_tape_block_level( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default level should be 0, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  libspectrum_tape_block_set_level( block, 1 );
  if( libspectrum_tape_block_level( block ) != 1 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected level=1, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  /* Default bits_in_last_byte should be 0; data and data_length should
     default to NULL/0 */
  if( libspectrum_tape_block_bits_in_last_byte( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default bits_in_last_byte should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) != NULL ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default data should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default data_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  data = libspectrum_malloc( 2 );
  data[0] = 0x5a; data[1] = 0xa5;
  libspectrum_tape_block_set_bits_in_last_byte( block, 8 );
  libspectrum_tape_block_set_data_length( block, 2 );
  libspectrum_tape_block_set_data( block, data );
  data = NULL; /* block owns the array now */

  if( libspectrum_tape_block_bits_in_last_byte( block ) != 8 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected bits_in_last_byte=8, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_bits_in_last_byte( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data_length( block ) != 2 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected data_length=2, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) == NULL ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: data should not be NULL after set\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data( block )[0] != 0x5a ||
      libspectrum_tape_block_data( block )[1] != 0xa5 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: data content mismatch\n", progname );
    goto done;
  }

  /* Default bit pulse counts should be 0 */
  if( libspectrum_tape_block_bit0_pulse_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default bit0_pulse_count should be 0, got %u\n",
             progname, (unsigned)libspectrum_tape_block_bit0_pulse_count( block ) );
    goto done;
  }

  if( libspectrum_tape_block_bit1_pulse_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: default bit1_pulse_count should be 0, got %u\n",
             progname, (unsigned)libspectrum_tape_block_bit1_pulse_count( block ) );
    goto done;
  }

  /* Set bit0 pulses: 2 pulses of 855 T-states each */
  bit0_pulses = libspectrum_new( libspectrum_word, 2 );
  bit0_pulses[0] = 855; bit0_pulses[1] = 855;
  libspectrum_tape_block_set_bit0_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit0_pulses( block, bit0_pulses );
  bit0_pulses = NULL; /* block owns the array now */

  if( libspectrum_tape_block_bit0_pulse_count( block ) != 2 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected bit0_pulse_count=2, got %u\n",
             progname, (unsigned)libspectrum_tape_block_bit0_pulse_count( block ) );
    goto done;
  }

  {
    libspectrum_word expected_bit0[] = { 855, 855 };
    for( i = 0; i < 2; i++ ) {
      if( libspectrum_tape_block_bit0_pulses( block, i ) != expected_bit0[i] ) {
        fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: bit0_pulses[%lu] expected %u, got %u\n",
                 progname, (unsigned long)i, (unsigned)expected_bit0[i],
                 (unsigned)libspectrum_tape_block_bit0_pulses( block, i ) );
        goto done;
      }
    }
  }

  /* Set bit1 pulses: 2 pulses of 1710 T-states each */
  bit1_pulses = libspectrum_new( libspectrum_word, 2 );
  bit1_pulses[0] = 1710; bit1_pulses[1] = 1710;
  libspectrum_tape_block_set_bit1_pulse_count( block, 2 );
  libspectrum_tape_block_set_bit1_pulses( block, bit1_pulses );
  bit1_pulses = NULL; /* block owns the array now */

  if( libspectrum_tape_block_bit1_pulse_count( block ) != 2 ) {
    fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: expected bit1_pulse_count=2, got %u\n",
             progname, (unsigned)libspectrum_tape_block_bit1_pulse_count( block ) );
    goto done;
  }

  {
    libspectrum_word expected_bit1[] = { 1710, 1710 };
    for( i = 0; i < 2; i++ ) {
      if( libspectrum_tape_block_bit1_pulses( block, i ) != expected_bit1[i] ) {
        fprintf( stderr, "%s: tape_data_block_count_tail_length_level_data_and_bit_pulses_getter_setter: bit1_pulses[%lu] expected %u, got %u\n",
                 progname, (unsigned long)i, (unsigned)expected_bit1[i],
                 (unsigned)libspectrum_tape_block_bit1_pulses( block, i ) );
        goto done;
      }
    }
  }

  r = TEST_PASS;

done:
  libspectrum_free( data );
  libspectrum_free( bit0_pulses );
  libspectrum_free( bit1_pulses );
  libspectrum_tape_block_free( block );
  return r;
}

static libspectrum_tape_block *
make_pzx_style_data_block( int level, libspectrum_word pulse_length,
                           size_t pulse_count )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK );
  libspectrum_word *bit0 = libspectrum_new( libspectrum_word, pulse_count );
  libspectrum_word *bit1 = libspectrum_new( libspectrum_word, pulse_count );
  libspectrum_byte *data = libspectrum_new( libspectrum_byte, 1 );
  size_t i;

  for( i = 0; i < pulse_count; i++ ) {
    bit0[i] = pulse_length;
    bit1[i] = pulse_length + 1;
  }
  data[0] = 0;
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_level( block, level );
  libspectrum_tape_block_set_tail_length( block, 0 );
  libspectrum_tape_block_set_bit0_pulse_count( block, pulse_count );
  libspectrum_tape_block_set_bit0_pulses( block, bit0 );
  libspectrum_tape_block_set_bit1_pulse_count( block, pulse_count );
  libspectrum_tape_block_set_bit1_pulses( block, bit1 );
  libspectrum_tape_block_set_data_length( block, 1 );
  libspectrum_tape_block_set_bits_in_last_byte( block, 1 );
  libspectrum_tape_block_set_data( block, data );
  return block;
}

/* PZX-style levels are carried by forced GDB symbols, not 0x2B blocks.
   Compare positive-duration pulses independently of zero-time boundaries. */
test_return_t
tzx_write_preserves_pzx_style_initial_pulse_levels( void )
{
  static const libspectrum_dword expected_tstates[] = {
    100, 200, 200, 250, 300, 300, 3500, 400
  };
  static const libspectrum_tape_signal_level expected_levels[] = {
    LIBSPECTRUM_TAPE_SIGNAL_LOW, LIBSPECTRUM_TAPE_SIGNAL_HIGH,
    LIBSPECTRUM_TAPE_SIGNAL_LOW, LIBSPECTRUM_TAPE_SIGNAL_HIGH,
    LIBSPECTRUM_TAPE_SIGNAL_LOW, LIBSPECTRUM_TAPE_SIGNAL_HIGH,
    LIBSPECTRUM_TAPE_SIGNAL_LOW, LIBSPECTRUM_TAPE_SIGNAL_HIGH
  };
  libspectrum_tape *source = NULL, *roundtrip = NULL;
  libspectrum_tape_block *block;
  libspectrum_dword *lengths;
  size_t *repeats, length = 0, i;
  libspectrum_byte *output = NULL;
  libspectrum_tape_edge edge;
  test_return_t r = TEST_INCOMPLETE;

  source = libspectrum_tape_alloc();
  roundtrip = libspectrum_tape_alloc();
  if( !source || !roundtrip ) goto done;

  block = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  lengths = libspectrum_new( libspectrum_dword, 1 );
  repeats = libspectrum_new( size_t, 1 );
  lengths[0] = 100; repeats[0] = 1;
  libspectrum_tape_block_set_count( block, 1 );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  if( libspectrum_tape_append_block( source, block ) ) goto done;

  block = make_pzx_style_data_block( 1, 200, 2 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;
  block = make_pzx_style_data_block( 1, 250, 1 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;
  block = make_pzx_style_data_block( 0, 300, 2 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;

  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_tape_block_set_level( block, 0 );
  libspectrum_set_pause_tstates( block, 3500 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;

  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_tape_block_set_level( block, 1 );
  libspectrum_set_pause_tstates( block, 400 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;

  block = libspectrum_tape_block_alloc(
    LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
  libspectrum_tape_block_set_level( block, 1 );
  if( libspectrum_tape_append_block( source, block ) ) goto done;

  if( libspectrum_tape_write( &output, &length, source,
                              LIBSPECTRUM_ID_TAPE_TZX ) ||
      libspectrum_tape_read( roundtrip, output, length,
                             LIBSPECTRUM_ID_TAPE_TZX, NULL ) ) goto done;

  r = TEST_FAIL;
  for( i = 0; i < sizeof( expected_tstates ) / sizeof( expected_tstates[0] );
       i++ ) {
    do {
      if( libspectrum_tape_get_next_edge( &edge, roundtrip ) ) goto done;
      if( ( edge.flags & LIBSPECTRUM_TAPE_FLAGS_TAPE ) && !edge.tstates ) goto done;
    } while( !edge.tstates );
    if( edge.tstates != expected_tstates[i] ||
        edge.level != expected_levels[i] ) {
      fprintf( stderr, "%s: TZX PZX-style initial level mismatch at edge %lu"
               " (expected %lu/%d, got %lu/%d)\n", progname,
               (unsigned long)i, (unsigned long)expected_tstates[i],
               expected_levels[i], (unsigned long)edge.tstates, edge.level );
      goto done;
    }
  }
  r = TEST_PASS;

done:
  libspectrum_free( output );
  if( roundtrip ) libspectrum_tape_free( roundtrip );
  if( source ) libspectrum_tape_free( source );
  return r;
}

/* More than 256 distinct GDB symbols require an additional alphabet/block. */
test_return_t
tzx_pzx_gdb_alphabet_splitting( void )
{
  libspectrum_tape *tape;
  libspectrum_tape_block *block;
  libspectrum_dword *lengths;
  size_t *repeats;
  libspectrum_byte *output;
  size_t length;
  const size_t pulse_count = 300;
  const size_t first_block_expected = 256;
  const size_t second_block_expected = 44;
  test_return_t r;
  size_t i, offset;
  int pulses_blocks_found, first_count, second_count, blk_count;

  lengths = libspectrum_new( libspectrum_dword, pulse_count );
  repeats = libspectrum_new( size_t, pulse_count );
  for( i = 0; i < pulse_count; i++ ) {
    lengths[i] = 1000 + (libspectrum_dword)i;
    repeats[i] = 1;
  }

  tape = libspectrum_tape_alloc();
  if( !tape ) {
    libspectrum_free( lengths );
    libspectrum_free( repeats );
    return TEST_INCOMPLETE;
  }

  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE );
  if( !block ) {
    libspectrum_free( lengths );
    libspectrum_free( repeats );
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }

  libspectrum_tape_block_set_count( block, pulse_count );
  libspectrum_tape_block_set_pulse_lengths( block, lengths );
  libspectrum_tape_block_set_pulse_repeats( block, repeats );
  lengths = NULL; /* block owns the array now */
  repeats = NULL;
  libspectrum_tape_append_block( tape, block );

  output = NULL;
  length = 0;
  r = TEST_INCOMPLETE;
  if( libspectrum_tape_write( &output, &length, tape, LIBSPECTRUM_ID_TAPE_TZX ) ) {
    fprintf( stderr, "%s: GDB alphabet splitting: tape write failed\n", progname );
    libspectrum_tape_free( tape );
    return TEST_INCOMPLETE;
  }
  libspectrum_tape_free( tape );

  r = TEST_FAIL;
  offset = 10;
  pulses_blocks_found = first_count = second_count = 0;
  while( offset + 19 <= length &&
         output[offset] == LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA ) {
    const libspectrum_byte *ptr = output + offset + 1;
    libspectrum_dword size = libspectrum_read_dword( &ptr );
    blk_count = output[offset + 12];
    if( !blk_count ) blk_count = 256;
    pulses_blocks_found++;
    if( pulses_blocks_found == 1 ) first_count = blk_count;
    else if( pulses_blocks_found == 2 ) second_count = blk_count;
    offset += 5 + size;
  }
  if( offset != length ) goto done;

  if( pulses_blocks_found != 2 ) {
    fprintf( stderr, "%s: expected 2 GDB blocks, found %d\n",
             progname, pulses_blocks_found );
    goto done;
  }
  if( (size_t)first_count != first_block_expected ) {
    fprintf( stderr, "%s: expected first GDB alphabet size=%lu, got %d\n",
             progname, (unsigned long)first_block_expected, first_count );
    goto done;
  }
  if( (size_t)second_count != second_block_expected ) {
    fprintf( stderr, "%s: expected second GDB alphabet size=%lu, got %d\n",
             progname, (unsigned long)second_block_expected, second_count );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( output );
  return r;
}

test_return_t
tape_group_start_block_text_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
  char *text = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_group_start_block_text_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_GROUP_START ) {
    fprintf( stderr, "%s: tape_group_start_block_text_getter_setter: expected GROUP_START block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_text( block ) != NULL ) {
    fprintf( stderr, "%s: tape_group_start_block_text_getter_setter: default text should be NULL\n", progname );
    goto done;
  }

  text = libspectrum_new( char, strlen( "TestGroup" ) + 1 );
  strcpy( text, "TestGroup" );
  libspectrum_tape_block_set_text( block, text );
  text = NULL;

  if( strcmp( libspectrum_tape_block_text( block ), "TestGroup" ) != 0 ) {
    fprintf( stderr, "%s: tape_group_start_block_text_getter_setter: expected text=\"TestGroup\", got \"%s\"\n",
             progname, libspectrum_tape_block_text( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( text );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_comment_block_text_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_COMMENT );
  char *text = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_comment_block_text_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_COMMENT ) {
    fprintf( stderr, "%s: tape_comment_block_text_getter_setter: expected COMMENT block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_text( block ) != NULL ) {
    fprintf( stderr, "%s: tape_comment_block_text_getter_setter: default text should be NULL\n", progname );
    goto done;
  }

  text = libspectrum_new( char, strlen( "Hello, World!" ) + 1 );
  strcpy( text, "Hello, World!" );
  libspectrum_tape_block_set_text( block, text );
  text = NULL;

  if( strcmp( libspectrum_tape_block_text( block ), "Hello, World!" ) != 0 ) {
    fprintf( stderr, "%s: tape_comment_block_text_getter_setter: expected text=\"Hello, World!\", got \"%s\"\n",
             progname, libspectrum_tape_block_text( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( text );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_jump_block_offset_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_JUMP );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_jump_block_offset_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_JUMP ) {
    fprintf( stderr, "%s: tape_jump_block_offset_getter_setter: expected JUMP block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_offset( block ) != 0 ) {
    fprintf( stderr, "%s: tape_jump_block_offset_getter_setter: default offset should be 0, got %d\n",
             progname, libspectrum_tape_block_offset( block ) );
    goto done;
  }

  libspectrum_tape_block_set_offset( block, -3 );
  if( libspectrum_tape_block_offset( block ) != -3 ) {
    fprintf( stderr, "%s: tape_jump_block_offset_getter_setter: expected offset=-3, got %d\n",
             progname, libspectrum_tape_block_offset( block ) );
    goto done;
  }

  libspectrum_tape_block_set_offset( block, 5 );
  if( libspectrum_tape_block_offset( block ) != 5 ) {
    fprintf( stderr, "%s: tape_jump_block_offset_getter_setter: expected offset=5, got %d\n",
             progname, libspectrum_tape_block_offset( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_loop_start_block_count_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_LOOP_START );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_loop_start_block_count_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_LOOP_START ) {
    fprintf( stderr, "%s: tape_loop_start_block_count_getter_setter: expected LOOP_START block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_loop_start_block_count_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  libspectrum_tape_block_set_count( block, 5 );
  if( libspectrum_tape_block_count( block ) != 5 ) {
    fprintf( stderr, "%s: tape_loop_start_block_count_getter_setter: expected count=5, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_message_block_text_and_pause_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
  char *text = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_MESSAGE ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: expected MESSAGE block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_text( block ) != NULL ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: default text should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: default pause should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  text = libspectrum_new( char, strlen( "Press PLAY on tape." ) + 1 );
  strcpy( text, "Press PLAY on tape." );
  libspectrum_tape_block_set_text( block, text );
  text = NULL;

  if( strcmp( libspectrum_tape_block_text( block ), "Press PLAY on tape." ) != 0 ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: expected text=\"Press PLAY on tape.\", got \"%s\"\n",
             progname, libspectrum_tape_block_text( block ) );
    goto done;
  }

  libspectrum_tape_block_set_pause( block, 10 );
  if( libspectrum_tape_block_pause( block ) != 10 ) {
    fprintf( stderr, "%s: tape_message_block_text_and_pause_getter_setter: expected pause=10, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( text );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_archive_info_block_count_ids_and_texts_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO );
  int *ids = NULL;
  char **strings = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected ARCHIVE_INFO block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  ids = libspectrum_new( int, 2 );
  ids[0] = 0x00;
  ids[1] = 0x02;

  strings = libspectrum_new( char *, 2 );
  strings[0] = libspectrum_new( char, strlen( "Manic Miner" ) + 1 );
  strcpy( strings[0], "Manic Miner" );
  strings[1] = libspectrum_new( char, strlen( "Software Projects" ) + 1 );
  strcpy( strings[1], "Software Projects" );

  libspectrum_tape_block_set_count( block, 2 );
  libspectrum_tape_block_set_ids( block, ids );
  libspectrum_tape_block_set_texts( block, strings );
  ids = NULL;
  strings = NULL;

  if( libspectrum_tape_block_count( block ) != 2 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected count=2, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  if( libspectrum_tape_block_ids( block, 0 ) != 0x00 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected ids[0]=0x00, got 0x%02x\n",
             progname, libspectrum_tape_block_ids( block, 0 ) );
    goto done;
  }

  if( libspectrum_tape_block_ids( block, 1 ) != 0x02 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected ids[1]=0x02, got 0x%02x\n",
             progname, libspectrum_tape_block_ids( block, 1 ) );
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 0 ), "Manic Miner" ) != 0 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected texts[0]=\"Manic Miner\", got \"%s\"\n",
             progname, libspectrum_tape_block_texts( block, 0 ) );
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 1 ), "Software Projects" ) != 0 ) {
    fprintf( stderr, "%s: tape_archive_info_block_count_ids_and_texts_getter_setter: expected texts[1]=\"Software Projects\", got \"%s\"\n",
             progname, libspectrum_tape_block_texts( block, 1 ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( ids );
  if( strings ) {
    libspectrum_free( strings[0] );
    libspectrum_free( strings[1] );
    libspectrum_free( strings );
  }
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_hardware_block_count_types_ids_and_values_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_HARDWARE );
  int *types = NULL, *ids = NULL, *values = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_HARDWARE ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: expected HARDWARE block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  types = libspectrum_new( int, 2 );
  types[0] = 0x00;
  types[1] = 0x09;

  ids = libspectrum_new( int, 2 );
  ids[0] = 0x00;
  ids[1] = 0x00;

  values = libspectrum_new( int, 2 );
  values[0] = 0x01;
  values[1] = 0x01;

  libspectrum_tape_block_set_count( block, 2 );
  libspectrum_tape_block_set_types( block, types );
  libspectrum_tape_block_set_ids( block, ids );
  libspectrum_tape_block_set_values( block, values );
  types = NULL;
  ids = NULL;
  values = NULL;

  if( libspectrum_tape_block_count( block ) != 2 ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: expected count=2, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  if( libspectrum_tape_block_types( block, 0 ) != 0x00 ||
      libspectrum_tape_block_types( block, 1 ) != 0x09 ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: types mismatch\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_ids( block, 0 ) != 0x00 ||
      libspectrum_tape_block_ids( block, 1 ) != 0x00 ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: ids mismatch\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_values( block, 0 ) != 0x01 ||
      libspectrum_tape_block_values( block, 1 ) != 0x01 ) {
    fprintf( stderr, "%s: tape_hardware_block_count_types_ids_and_values_getter_setter: values mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( types );
  libspectrum_free( ids );
  libspectrum_free( values );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_select_block_count_offsets_and_texts_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SELECT );
  int *offsets = NULL;
  char **descriptions = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_SELECT ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: expected SELECT block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_count( block ) != 0 ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: default count should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  offsets = libspectrum_new( int, 2 );
  offsets[0] = 10;
  offsets[1] = 20;

  descriptions = libspectrum_new( char *, 2 );
  descriptions[0] = libspectrum_new( char, strlen( "Side A" ) + 1 );
  strcpy( descriptions[0], "Side A" );
  descriptions[1] = libspectrum_new( char, strlen( "Side B" ) + 1 );
  strcpy( descriptions[1], "Side B" );

  libspectrum_tape_block_set_count( block, 2 );
  libspectrum_tape_block_set_offsets( block, offsets );
  libspectrum_tape_block_set_texts( block, descriptions );
  offsets = NULL;
  descriptions = NULL;

  if( libspectrum_tape_block_count( block ) != 2 ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: expected count=2, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_count( block ) );
    goto done;
  }

  if( libspectrum_tape_block_offsets( block, 0 ) != 10 ||
      libspectrum_tape_block_offsets( block, 1 ) != 20 ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: offsets mismatch\n", progname );
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 0 ), "Side A" ) != 0 ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: expected texts[0]=\"Side A\", got \"%s\"\n",
             progname, libspectrum_tape_block_texts( block, 0 ) );
    goto done;
  }

  if( strcmp( libspectrum_tape_block_texts( block, 1 ), "Side B" ) != 0 ) {
    fprintf( stderr, "%s: tape_select_block_count_offsets_and_texts_getter_setter: expected texts[1]=\"Side B\", got \"%s\"\n",
             progname, libspectrum_tape_block_texts( block, 1 ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( offsets );
  if( descriptions ) {
    libspectrum_free( descriptions[0] );
    libspectrum_free( descriptions[1] );
    libspectrum_free( descriptions );
  }
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_set_signal_level_block_level_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL );
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_set_signal_level_block_level_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL ) {
    fprintf( stderr, "%s: tape_set_signal_level_block_level_getter_setter: expected SET_SIGNAL_LEVEL block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_level( block ) != 0 ) {
    fprintf( stderr, "%s: tape_set_signal_level_block_level_getter_setter: default level should be 0, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  libspectrum_tape_block_set_level( block, 1 );
  if( libspectrum_tape_block_level( block ) != 1 ) {
    fprintf( stderr, "%s: tape_set_signal_level_block_level_getter_setter: expected level=1, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  libspectrum_tape_block_set_level( block, 0 );
  if( libspectrum_tape_block_level( block ) != 0 ) {
    fprintf( stderr, "%s: tape_set_signal_level_block_level_getter_setter: expected level=0 after reset, got %d\n",
             progname, libspectrum_tape_block_level( block ) );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_custom_block_text_data_and_data_length_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_CUSTOM );
  char *description = NULL;
  libspectrum_byte *data = NULL;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_CUSTOM ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: expected CUSTOM block type\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_text( block ) != NULL ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: default text should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) != NULL ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: default data should be NULL\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: default data_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  description = libspectrum_new( char, strlen( "My Custom Block" ) + 1 );
  strcpy( description, "My Custom Block" );
  libspectrum_tape_block_set_text( block, description );
  description = NULL;

  if( strcmp( libspectrum_tape_block_text( block ), "My Custom Block" ) != 0 ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: expected text=\"My Custom Block\", got \"%s\"\n",
             progname, libspectrum_tape_block_text( block ) );
    goto done;
  }

  data = libspectrum_new( libspectrum_byte, 3 );
  data[0] = 0xde;
  data[1] = 0xad;
  data[2] = 0xbe;
  libspectrum_tape_block_set_data_length( block, 3 );
  libspectrum_tape_block_set_data( block, data );
  data = NULL;

  if( libspectrum_tape_block_data_length( block ) != 3 ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: expected data_length=3, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  if( libspectrum_tape_block_data( block ) == NULL ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: data should not be NULL after set\n", progname );
    goto done;
  }

  if( libspectrum_tape_block_data( block )[0] != 0xde ||
      libspectrum_tape_block_data( block )[1] != 0xad ||
      libspectrum_tape_block_data( block )[2] != 0xbe ) {
    fprintf( stderr, "%s: tape_custom_block_text_data_and_data_length_getter_setter: data content mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_free( description );
  libspectrum_free( data );
  libspectrum_tape_block_free( block );
  return r;
}

test_return_t
tape_block_description_returns_correct_string_for_all_types( void )
{
  static const struct {
    libspectrum_tape_type type;
    const char *expected;
  } cases[] = {
    { LIBSPECTRUM_TAPE_BLOCK_ROM,             "Standard Speed Data"       },
    { LIBSPECTRUM_TAPE_BLOCK_TURBO,           "Turbo Speed Data"          },
    { LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,       "Pure Tone"                 },
    { LIBSPECTRUM_TAPE_BLOCK_PULSES,          "List of Pulses"            },
    { LIBSPECTRUM_TAPE_BLOCK_PURE_DATA,       "Pure Data"                 },
    { LIBSPECTRUM_TAPE_BLOCK_RAW_DATA,        "Raw Data"                  },
    { LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA,"Generalised Data"          },
    { LIBSPECTRUM_TAPE_BLOCK_PAUSE,           "Pause"                     },
    { LIBSPECTRUM_TAPE_BLOCK_GROUP_START,     "Group Start"               },
    { LIBSPECTRUM_TAPE_BLOCK_GROUP_END,       "Group End"                 },
    { LIBSPECTRUM_TAPE_BLOCK_JUMP,            "Jump"                      },
    { LIBSPECTRUM_TAPE_BLOCK_LOOP_START,      "Loop Start Block"          },
    { LIBSPECTRUM_TAPE_BLOCK_LOOP_END,        "Loop End"                  },
    { LIBSPECTRUM_TAPE_BLOCK_SELECT,          "Select"                    },
    { LIBSPECTRUM_TAPE_BLOCK_STOP48,          "Stop Tape If In 48K Mode"  },
    { LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL,"Set Signal Level"          },
    { LIBSPECTRUM_TAPE_BLOCK_COMMENT,         "Comment"                   },
    { LIBSPECTRUM_TAPE_BLOCK_MESSAGE,         "Message"                   },
    { LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO,    "Archive Info"              },
    { LIBSPECTRUM_TAPE_BLOCK_HARDWARE,        "Hardware Information"      },
    { LIBSPECTRUM_TAPE_BLOCK_CUSTOM,          "Custom Info"               },
    { LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE,       "RLE Pulse"                 },
    { LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE,  "Pulse Sequence"            },
    { LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK,      "Data Block"                },
    { LIBSPECTRUM_TAPE_BLOCK_CONCAT,          "Glue Block"                },
  };

  char buf[64];
  size_t i;
  test_return_t r = TEST_PASS;

  for( i = 0; i < ARRAY_SIZE( cases ); i++ ) {
    libspectrum_tape_block *block =
      libspectrum_tape_block_alloc( cases[i].type );
    libspectrum_error err;

    if( !block ) {
      fprintf( stderr, "%s: tape_block_description_all_types: tape_block_alloc returned NULL for type 0x%02x\n",
               progname, cases[i].type );
      return TEST_INCOMPLETE;
    }

    err = libspectrum_tape_block_description( buf, sizeof( buf ), block );
    libspectrum_tape_block_free( block );

    if( err != LIBSPECTRUM_ERROR_NONE ) {
      fprintf( stderr, "%s: tape_block_description_all_types: description failed for type 0x%02x\n",
               progname, cases[i].type );
      r = TEST_FAIL;
      continue;
    }

    if( strcmp( buf, cases[i].expected ) != 0 ) {
      fprintf( stderr, "%s: tape_block_description_all_types: type 0x%02x: expected '%s', got '%s'\n",
               progname, cases[i].type, cases[i].expected, buf );
      r = TEST_FAIL;
    }
  }
  return r;
}

/* Test that pause_tstates getter/setter works correctly across all block
   types that support it: PAUSE, ROM, TURBO, PURE_DATA, RAW_DATA, and MESSAGE. */
test_return_t
tape_pause_tstates_getter_setter_across_block_types( void )
{
  /* We test each block type in a local scope for clarity */
  libspectrum_tape_block *block;
  test_return_t r = TEST_FAIL;

  /* --- PAUSE block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PAUSE alloc failed\n", progname );
    return TEST_INCOMPLETE;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PAUSE default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 35000 );
  if( libspectrum_tape_block_pause_tstates( block ) != 35000 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PAUSE expected 35000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  /* pause_tstates and pause are independent fields */
  if( libspectrum_tape_block_pause( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PAUSE ms-pause should be unaffected, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  /* --- ROM block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_ROM );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: ROM alloc failed\n", progname );
    goto done_no_block;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: ROM default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 70000 );
  if( libspectrum_tape_block_pause_tstates( block ) != 70000 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: ROM expected 70000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  /* --- TURBO block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_TURBO );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: TURBO alloc failed\n", progname );
    goto done_no_block;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: TURBO default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 12345 );
  if( libspectrum_tape_block_pause_tstates( block ) != 12345 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: TURBO expected 12345, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  /* --- PURE_DATA block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_DATA );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PURE_DATA alloc failed\n", progname );
    goto done_no_block;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PURE_DATA default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 99999 );
  if( libspectrum_tape_block_pause_tstates( block ) != 99999 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: PURE_DATA expected 99999, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  /* --- RAW_DATA block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RAW_DATA );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: RAW_DATA alloc failed\n", progname );
    goto done_no_block;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: RAW_DATA default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 1000000 );
  if( libspectrum_tape_block_pause_tstates( block ) != 1000000 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: RAW_DATA expected 1000000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  /* --- MESSAGE block --- */
  block = libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_MESSAGE );
  if( !block ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: MESSAGE alloc failed\n", progname );
    goto done_no_block;
  }
  if( libspectrum_tape_block_pause_tstates( block ) != 0 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: MESSAGE default pause_tstates should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_set_pause_tstates( block, 5000 );
  if( libspectrum_tape_block_pause_tstates( block ) != 5000 ) {
    fprintf( stderr, "%s: tape_pause_tstates_getter_setter_across_block_types: MESSAGE expected 5000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_pause_tstates( block ) );
    libspectrum_tape_block_free( block );
    goto done_no_block;
  }
  libspectrum_tape_block_free( block );

  r = TEST_PASS;

done_no_block:
  return r;
}

/* Test that scale, data, and data_length accessors work for the RLE_PULSE
   block (libspectrum's internal type 0x100 used by the PZX format). */
test_return_t
tape_rle_pulse_block_scale_data_and_data_length_getter_setter( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *data;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: tape_block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_block_type( block ) != LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: expected RLE_PULSE block type\n", progname );
    goto done;
  }

  /* Default scale should be 0 */
  if( libspectrum_tape_block_scale( block ) != 0 ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: default scale should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_scale( block ) );
    goto done;
  }

  libspectrum_tape_block_set_scale( block, 3500000 );
  if( libspectrum_tape_block_scale( block ) != 3500000 ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: expected scale=3500000, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_scale( block ) );
    goto done;
  }

  /* Default data should be NULL, data_length 0 */
  if( libspectrum_tape_block_data( block ) != NULL ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: default data should be NULL\n", progname );
    goto done;
  }
  if( libspectrum_tape_block_data_length( block ) != 0 ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: default data_length should be 0, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }

  /* Set data: 4-byte RLE payload {3, 5, 1, 7} */
  data = libspectrum_new( libspectrum_byte, 4 );
  if( !data ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: data alloc failed\n", progname );
    goto done;
  }
  data[0] = 3; data[1] = 5; data[2] = 1; data[3] = 7;

  libspectrum_tape_block_set_data( block, data );
  libspectrum_tape_block_set_data_length( block, 4 );

  if( libspectrum_tape_block_data( block ) != data ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: data pointer mismatch\n", progname );
    goto done;
  }
  if( libspectrum_tape_block_data_length( block ) != 4 ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: expected data_length=4, got %lu\n",
             progname, (unsigned long)libspectrum_tape_block_data_length( block ) );
    goto done;
  }
  if( libspectrum_tape_block_data( block )[0] != 3 ||
      libspectrum_tape_block_data( block )[1] != 5 ||
      libspectrum_tape_block_data( block )[2] != 1 ||
      libspectrum_tape_block_data( block )[3] != 7 ) {
    fprintf( stderr, "%s: tape_rle_pulse_block_scale_data_and_data_length_getter_setter: data contents mismatch\n", progname );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

/* libspectrum_tape_present returns 0 for a freshly allocated (empty) tape */
test_return_t
tape_present_returns_false_for_empty_tape( void )
{
  libspectrum_tape *tape = libspectrum_tape_alloc();

  if( !tape ) {
    fprintf( stderr, "%s: tape_present_returns_false_for_empty_tape: "
             "tape_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_present( tape ) ) {
    fprintf( stderr, "%s: tape_present_returns_false_for_empty_tape: "
             "expected tape_present to return 0 for empty tape\n", progname );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  libspectrum_tape_free( tape );
  return TEST_PASS;
}

/* libspectrum_tape_present returns non-zero after loading blocks from a
   tape file, and libspectrum_tape_clear makes it empty again */
test_return_t
tape_present_true_after_load_and_false_after_clear( void )
{
  const char *filename = STATIC_TEST_PATH( "standard-tap.tap" );
  libspectrum_byte *buffer = NULL;
  size_t filesize = 0;
  libspectrum_tape *tape;
  test_return_t r = TEST_INCOMPLETE;

  if( read_file( &buffer, &filesize, filename ) ) return TEST_INCOMPLETE;

  tape = libspectrum_tape_alloc();
  if( !tape ) {
    fprintf( stderr, "%s: tape_present_true_after_load_and_false_after_clear: "
             "tape_alloc returned NULL\n", progname );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  if( libspectrum_tape_read( tape, buffer, filesize, LIBSPECTRUM_ID_UNKNOWN,
                             filename ) ) {
    fprintf( stderr, "%s: tape_present_true_after_load_and_false_after_clear: "
             "tape_read failed\n", progname );
    libspectrum_tape_free( tape );
    libspectrum_free( buffer );
    return TEST_INCOMPLETE;
  }

  libspectrum_free( buffer );

  if( !libspectrum_tape_present( tape ) ) {
    fprintf( stderr, "%s: tape_present_true_after_load_and_false_after_clear: "
             "expected tape_present to return non-zero after loading\n",
             progname );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_clear( tape ) != LIBSPECTRUM_ERROR_NONE ) {
    fprintf( stderr, "%s: tape_present_true_after_load_and_false_after_clear: "
             "tape_clear returned error\n", progname );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  if( libspectrum_tape_present( tape ) ) {
    fprintf( stderr, "%s: tape_present_true_after_load_and_false_after_clear: "
             "expected tape_present to return 0 after tape_clear\n", progname );
    libspectrum_tape_free( tape );
    return TEST_FAIL;
  }

  r = TEST_PASS;

  libspectrum_tape_free( tape );
  return r;
}

/* Helper: allocate a block of given type, call description, free block */
static libspectrum_error
description_for_type( libspectrum_tape_type type, char *buf, size_t len )
{
  libspectrum_tape_block *block = libspectrum_tape_block_alloc( type );
  libspectrum_error e;
  if( !block ) return LIBSPECTRUM_ERROR_MEMORY;
  e = libspectrum_tape_block_description( buf, len, block );
  libspectrum_tape_block_free( block );
  return e;
}

#define TAPE_DESC_TEST( name, type, expected ) \
test_return_t \
tape_block_description_ ## name ( void ) \
{ \
  char buf[64]; \
  if( description_for_type( LIBSPECTRUM_TAPE_BLOCK_ ## type, buf, sizeof( buf ) ) != LIBSPECTRUM_ERROR_NONE ) { \
    fprintf( stderr, "%s: tape_block_description_" #name ": returned error\n", progname ); \
    return TEST_FAIL; \
  } \
  if( strcmp( buf, expected ) != 0 ) { \
    fprintf( stderr, "%s: tape_block_description_" #name ": expected \"%s\", got \"%s\"\n", \
             progname, expected, buf ); \
    return TEST_FAIL; \
  } \
  return TEST_PASS; \
}

TAPE_DESC_TEST( rom,              ROM,              "Standard Speed Data" )
TAPE_DESC_TEST( turbo,            TURBO,            "Turbo Speed Data" )
TAPE_DESC_TEST( pure_tone,        PURE_TONE,        "Pure Tone" )
TAPE_DESC_TEST( pulses,           PULSES,           "List of Pulses" )
TAPE_DESC_TEST( pure_data,        PURE_DATA,        "Pure Data" )
TAPE_DESC_TEST( raw_data,         RAW_DATA,         "Raw Data" )
TAPE_DESC_TEST( generalised_data, GENERALISED_DATA, "Generalised Data" )
TAPE_DESC_TEST( pause,            PAUSE,            "Pause" )
TAPE_DESC_TEST( group_start,      GROUP_START,      "Group Start" )
TAPE_DESC_TEST( group_end,        GROUP_END,        "Group End" )
TAPE_DESC_TEST( jump,             JUMP,             "Jump" )
TAPE_DESC_TEST( loop_start,       LOOP_START,       "Loop Start Block" )
TAPE_DESC_TEST( loop_end,         LOOP_END,         "Loop End" )
TAPE_DESC_TEST( select,           SELECT,           "Select" )
TAPE_DESC_TEST( stop48,           STOP48,           "Stop Tape If In 48K Mode" )
TAPE_DESC_TEST( set_signal_level, SET_SIGNAL_LEVEL, "Set Signal Level" )
TAPE_DESC_TEST( comment,          COMMENT,          "Comment" )
TAPE_DESC_TEST( message,          MESSAGE,          "Message" )
TAPE_DESC_TEST( archive_info,     ARCHIVE_INFO,     "Archive Info" )
TAPE_DESC_TEST( hardware,         HARDWARE,         "Hardware Information" )
TAPE_DESC_TEST( custom,           CUSTOM,           "Custom Info" )
TAPE_DESC_TEST( concat,           CONCAT,           "Glue Block" )
TAPE_DESC_TEST( rle_pulse,        RLE_PULSE,        "RLE Pulse" )
TAPE_DESC_TEST( pulse_sequence,   PULSE_SEQUENCE,   "Pulse Sequence" )
TAPE_DESC_TEST( data_block,       DATA_BLOCK,       "Data Block" )

/* tape_block_metadata: data blocks (ROM, PAUSE, STOP48) return 0 */
test_return_t
tape_block_metadata_data_block_returns_zero( void )
{
  static const libspectrum_tape_type data_types[] = {
    LIBSPECTRUM_TAPE_BLOCK_ROM,
    LIBSPECTRUM_TAPE_BLOCK_TURBO,
    LIBSPECTRUM_TAPE_BLOCK_PURE_TONE,
    LIBSPECTRUM_TAPE_BLOCK_PAUSE,
    LIBSPECTRUM_TAPE_BLOCK_STOP48,
  };
  size_t i;

  for( i = 0; i < sizeof( data_types ) / sizeof( data_types[0] ); i++ ) {
    libspectrum_tape_block *block =
      libspectrum_tape_block_alloc( data_types[i] );
    int meta;

    if( !block ) {
      fprintf( stderr, "%s: tape_block_metadata_data_block_returns_zero: "
               "block_alloc returned NULL for type 0x%02x\n",
               progname, (int)data_types[i] );
      return TEST_INCOMPLETE;
    }

    meta = libspectrum_tape_block_metadata( block );
    libspectrum_tape_block_free( block );

    if( meta != 0 ) {
      fprintf( stderr, "%s: tape_block_metadata_data_block_returns_zero: "
               "expected 0 for type 0x%02x, got %d\n",
               progname, (int)data_types[i], meta );
      return TEST_FAIL;
    }
  }

  return TEST_PASS;
}

/* tape_block_metadata: metadata blocks (ARCHIVE_INFO, GROUP_START, COMMENT)
   return 1 */
test_return_t
tape_block_metadata_metadata_block_returns_one( void )
{
  static const libspectrum_tape_type meta_types[] = {
    LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO,
    LIBSPECTRUM_TAPE_BLOCK_GROUP_START,
    LIBSPECTRUM_TAPE_BLOCK_COMMENT,
    LIBSPECTRUM_TAPE_BLOCK_HARDWARE,
  };
  size_t i;

  for( i = 0; i < sizeof( meta_types ) / sizeof( meta_types[0] ); i++ ) {
    libspectrum_tape_block *block =
      libspectrum_tape_block_alloc( meta_types[i] );
    int meta;

    if( !block ) {
      fprintf( stderr, "%s: tape_block_metadata_metadata_block_returns_one: "
               "block_alloc returned NULL for type 0x%02x\n",
               progname, (int)meta_types[i] );
      return TEST_INCOMPLETE;
    }

    meta = libspectrum_tape_block_metadata( block );
    libspectrum_tape_block_free( block );

    if( meta != 1 ) {
      fprintf( stderr, "%s: tape_block_metadata_metadata_block_returns_one: "
               "expected 1 for type 0x%02x, got %d\n",
               progname, (int)meta_types[i], meta );
      return TEST_FAIL;
    }
  }

  return TEST_PASS;
}

/* tape_block_length: PAUSE block returns the stored length_tstates value */
test_return_t
tape_block_length_pause_block_returns_pause_tstates( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PAUSE );
  libspectrum_dword got;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_block_length_pause_block_returns_pause_tstates: "
             "block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  libspectrum_tape_block_set_pause_tstates( block, 12345 );
  got = libspectrum_tape_block_length( block );

  if( got != 12345 ) {
    fprintf( stderr, "%s: tape_block_length_pause_block_returns_pause_tstates: "
             "expected 12345, got %lu\n", progname, (unsigned long)got );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

/* tape_block_length: PURE_TONE block returns pulses * pulse_length */
test_return_t
tape_block_length_pure_tone_returns_pulses_times_length( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_PURE_TONE );
  libspectrum_dword got;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_block_length_pure_tone_returns_pulses_times_length: "
             "block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  /* Set 500 pulses of 100 tstates each → expect 50000 */
  libspectrum_tape_block_set_count( block, 500 );
  libspectrum_tape_block_set_pulse_length( block, 100 );
  got = libspectrum_tape_block_length( block );

  if( got != 50000 ) {
    fprintf( stderr, "%s: tape_block_length_pure_tone_returns_pulses_times_length: "
             "expected 50000, got %lu\n", progname, (unsigned long)got );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

/* tape_block_length: RLE_PULSE block honours the CSW/TZX long-form pulse
   encoding (zero marker followed by an LSB dword) */
test_return_t
tape_block_length_rle_pulse_uses_long_form_encoding( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE );
  libspectrum_byte *data;
  libspectrum_dword got;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_block_length_rle_pulse_uses_long_form_encoding: "
             "block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  /* Pulse 1: 100 samples (short form). Pulse 2: 300 samples (long form:
     marker 0x00 followed by the dword 0x0000012c in LSB-first order, the
     same encoding rle_pulse_edge() plays back). Scale 1 tstate/sample. */
  data = libspectrum_new( libspectrum_byte, 11 );
  if( !data ) {
    fprintf( stderr, "%s: tape_block_length_rle_pulse_uses_long_form_encoding: "
             "data alloc failed\n", progname );
    libspectrum_tape_block_free( block );
    return TEST_INCOMPLETE;
  }
  memset( data, 0, 11 );
  data[ 0 ] = 100;
  data[ 2 ] = 0x2c; data[ 3 ] = 0x01;
  /* Third pulse: 0x01000000 samples, exercising the high byte. */
  data[ 10 ] = 0x01;

  libspectrum_tape_block_set_scale( block, 1 );
  libspectrum_tape_block_set_data_length( block, 11 );
  libspectrum_tape_block_set_data( block, data );

  got = libspectrum_tape_block_length( block );

  if( got != 0x01000190 ) {
    fprintf( stderr, "%s: tape_block_length_rle_pulse_uses_long_form_encoding: "
             "expected 0x01000190, got %lu\n", progname, (unsigned long)got );
    goto done;
  }

  /* A zero marker without all four length bytes must not yield a partial
     block duration. */
  libspectrum_tape_block_set_data_length( block, 10 );
  got = libspectrum_tape_block_length( block );
  if( got != (libspectrum_dword)-1 ) {
    fprintf( stderr, "%s: tape_block_length_rle_pulse_uses_long_form_encoding: "
             "expected error sentinel for truncated pulse, got %lu\n",
             progname, (unsigned long)got );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}

/* tape_block_length: metadata blocks (GROUP_START) return 0 */
test_return_t
tape_block_length_metadata_block_returns_zero( void )
{
  libspectrum_tape_block *block =
    libspectrum_tape_block_alloc( LIBSPECTRUM_TAPE_BLOCK_GROUP_START );
  libspectrum_dword got;
  test_return_t r = TEST_FAIL;

  if( !block ) {
    fprintf( stderr, "%s: tape_block_length_metadata_block_returns_zero: "
             "block_alloc returned NULL\n", progname );
    return TEST_INCOMPLETE;
  }

  got = libspectrum_tape_block_length( block );

  if( got != 0 ) {
    fprintf( stderr, "%s: tape_block_length_metadata_block_returns_zero: "
             "expected 0, got %lu\n", progname, (unsigned long)got );
    goto done;
  }

  r = TEST_PASS;

done:
  libspectrum_tape_block_free( block );
  return r;
}
