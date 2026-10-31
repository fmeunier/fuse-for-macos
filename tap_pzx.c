/* tap_pzx.c: Conservative ROM recognition for recorded PZX pulses
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
#include "internals.h"
#include "tape_block.h"

/* Prototype: recognise only standard ROM SAVE waveforms, not arbitrary audio.
   The 5% windows are disjoint for pilot/data; sync is checked in order.
   At least 256 pilot pulses are required. No pulse arrays are expanded. */
enum phase { GAP, PILOT, SYNC2, DATA };
typedef struct {
  enum phase phase;
  unsigned pilot, bits, byte, gap_pulses;
  int half, level;
  libspectrum_byte checksum, *bytes;
  size_t used, blocks;
  libspectrum_buffer *output;
} rom_decoder;

static int
duration_near( libspectrum_dword duration, unsigned nominal )
{
  unsigned tolerance = nominal / 20;
  return duration >= nominal - tolerance && duration <= nominal + tolerance;
}

static int
finish_data( rom_decoder *d )
{
  if( d->phase != DATA ) return d->phase == GAP;
  if( d->half != -1 || d->bits || d->used < 2 || d->checksum ||
      ( d->bytes[0] != 0 && d->bytes[0] != 0xff ) ||
      ( d->bytes[0] == 0 && d->used != 19 ) ) return 0;
  libspectrum_buffer_write_word( d->output, d->used );
  libspectrum_buffer_write( d->output, d->bytes, d->used );
  d->blocks++;
  d->phase = GAP;
  d->gap_pulses = 0;
  return 1;
}

static int
bit_pulse( rom_decoder *d, int bit )
{
  if( d->half == -1 ) { d->half = bit; return 1; }
  if( d->half != bit ) return 0;
  d->half = -1;
  d->byte = ( d->byte << 1 ) | bit;
  if( ++d->bits == 8 ) {
    if( d->used == 65535 ) return 0;
    d->bytes[d->used++] = d->byte;
    d->checksum ^= d->byte;
    d->bits = d->byte = 0;
  }
  return 1;
}

static int
pulse( rom_decoder *d, libspectrum_dword duration )
{
  /* Pilot runs are consumed in bulk by pulse_run(). */
  switch( d->phase ) {
  case GAP:
    if( duration < 3500 || d->gap_pulses ) return 0;
    d->gap_pulses = 1;
    return 1;
  case PILOT:
    if( d->pilot < 256 || !duration_near( duration, 667 ) ) return 0;
    d->phase = SYNC2;
    return 1;
  case SYNC2:
    if( !duration_near( duration, 735 ) ) return 0;
    d->phase = DATA;
    d->used = d->bits = d->byte = d->checksum = 0;
    d->half = -1;
    return 1;
  case DATA:
    if( duration_near( duration, 855 ) ) return bit_pulse( d, 0 );
    if( duration_near( duration, 1710 ) ) return bit_pulse( d, 1 );
    /* A ROM tail or silence terminates data only at a valid byte boundary.
       pulse_run() also allows a following pilot to delimit blocks. */
    if( !finish_data( d ) ) return 0;
    if( duration_near( duration, 945 ) ) return 1;
    return pulse( d, duration );
  }
  return 0;
}

static int
pulse_run( rom_decoder *d, libspectrum_dword duration, size_t count )
{
  size_t i;
  if( !count || duration > 0x7fffffff ) return 0;
  if( duration_near( duration, 2168 ) ) {
    if( d->phase == DATA && !finish_data( d ) ) return 0;
    if( d->phase != GAP && d->phase != PILOT ) return 0;
    if( d->phase == GAP ) d->pilot = 0;
    d->phase = PILOT;
    d->pilot += count < 256 - d->pilot ? count : 256 - d->pilot;
    return 1;
  }
  /* Bound work even for malicious repeat counts. Data cannot exceed TAP's
     65535-byte limit; long alternating holds are not silence. */
  if( count > 65535 * 16U || ( duration >= 3500 && count != 1 ) ) return 0;
  for( i = 0; i < count; i++ ) if( !pulse( d, duration ) ) return 0;
  return 1;
}

static int
sequence( rom_decoder *d, libspectrum_tape_block *block )
{
  libspectrum_tape_pulse_sequence_block *p = &block->types.pulse_sequence;
  size_t i;
  int level;
  if( !p->count || !p->lengths || !p->pulse_repeats ) return 0;
  level = !p->lengths[0];
  if( d->phase != GAP && level != d->level ) return 0;
  if( level && p->count == 1 ) return 0;
  for( i = 0; i < p->count; i++ ) {
    /* Fuse starts a high-level chunk with a single zero polarity marker. */
    if( !p->lengths[i] ) {
      if( i || p->pulse_repeats[i] != 1 ) return 0;
    } else {
      if( !pulse_run( d, p->lengths[i], p->pulse_repeats[i] ) ) return 0;
      level ^= p->pulse_repeats[i] & 1;
    }
  }
  d->level = level;
  return 1;
}

libspectrum_error
internal_tap_write_pzx( libspectrum_buffer *buffer, libspectrum_tape *tape )
{
  rom_decoder d = { .phase = GAP, .half = -1, .output = buffer };
  libspectrum_tape_iterator it;
  libspectrum_tape_block *block;
  int ok = 1;
  d.bytes = libspectrum_new( libspectrum_byte, 65535 );
  for( block = libspectrum_tape_iterator_init( &it, tape ); block && ok;
       block = libspectrum_tape_iterator_next( &it ) ) {
    switch( libspectrum_tape_block_type( block ) ) {
    case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE:
      ok = sequence( &d, block ); break;
    case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
      ok = finish_data( &d ); break;
    case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
    case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO:
    case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
    case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
    case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
    case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
    case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
    case LIBSPECTRUM_TAPE_BLOCK_STOP48:
    case LIBSPECTRUM_TAPE_BLOCK_SET_SIGNAL_LEVEL:
      break;
    default:
      ok = 0; break;
    }
  }
  ok = ok && finish_data( &d ) && d.blocks;
  libspectrum_free( d.bytes );
  if( ok ) return LIBSPECTRUM_ERROR_NONE;
  libspectrum_print_error( LIBSPECTRUM_ERROR_INVALID,
    "TAP export: recording is not a complete recognised ROM waveform" );
  return LIBSPECTRUM_ERROR_INVALID;
}
