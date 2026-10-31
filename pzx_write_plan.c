/* pzx_write_plan.c: Checked, bounded execution paths for PZX output
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

typedef struct pzx_source_block {
  libspectrum_tape_iterator node;
  size_t loop, target;
} pzx_source_block;

typedef struct pzx_path_state {
  size_t pc, active, remaining;
  int in_group;
} pzx_path_state;

static libspectrum_error
index_source_loops( pzx_source_block *source, libspectrum_tape *tape )
{
  size_t i, loop = SIZE_MAX;
  libspectrum_tape_iterator it;
  libspectrum_tape_iterator_init( &it, tape );
  for( i = 0; it; i++, it = it->next ) {
    libspectrum_tape_block *block = it->data;
    source[i].node = it;
    source[i].loop = loop;
    switch( libspectrum_tape_block_type( block ) ) {
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
      if( loop != SIZE_MAX || libspectrum_tape_block_count( block ) < 2 ||
          libspectrum_tape_block_count( block ) > 0xffff )
        return LIBSPECTRUM_ERROR_INVALID;
      loop = i;
      break;
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
      if( loop == SIZE_MAX ) return LIBSPECTRUM_ERROR_INVALID;
      loop = SIZE_MAX;
      break;
    default: break;
    }
  }
  return loop == SIZE_MAX ? LIBSPECTRUM_ERROR_NONE : LIBSPECTRUM_ERROR_INVALID;
}

/* Jumps count every source block. They can skip a complete loop but cannot
   enter or leave its body without passing its state-setting boundaries. */
static libspectrum_error
check_jump_target( pzx_source_block *source, size_t count, size_t index )
{
  int offset = libspectrum_tape_block_offset( source[index].node->data );
  size_t target;
  if( !offset || offset < -32768 || offset > 32767 )
    return LIBSPECTRUM_ERROR_INVALID;
  if( offset < 0 ) {
    size_t distance = (size_t)( -( offset + 1 ) ) + 1;
    if( distance > index ) return LIBSPECTRUM_ERROR_INVALID;
    target = index - distance;
  } else {
    if( (size_t)offset >= count - index ) return LIBSPECTRUM_ERROR_INVALID;
    target = index + offset;
  }
  if( source[index].loop != source[target].loop )
    return LIBSPECTRUM_ERROR_INVALID;
  source[index].target = target;
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
check_source_jumps( pzx_source_block *source, size_t count )
{
  size_t i;
  for( i = 0; i < count; i++ ) {
    libspectrum_tape_block *block = source[i].node->data;
    if( libspectrum_tape_block_type( block ) == LIBSPECTRUM_TAPE_BLOCK_JUMP ) {
      libspectrum_error error = check_jump_target( source, count, i );
      if( error ) return error;
    }
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
advance_path( const pzx_source_block *source, pzx_path_state *path )
{
  libspectrum_tape_block *block = source[path->pc].node->data;
  switch( libspectrum_tape_block_type( block ) ) {
  case LIBSPECTRUM_TAPE_BLOCK_JUMP:
    path->pc = source[path->pc].target;
    break;
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
    if( path->active != SIZE_MAX ) return LIBSPECTRUM_ERROR_INVALID;
    path->active = path->pc++;
    path->remaining = libspectrum_tape_block_count( block );
    break;
  case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
    if( path->active != source[path->pc].loop ) return LIBSPECTRUM_ERROR_INVALID;
    if( --path->remaining ) path->pc = path->active + 1;
    else { path->active = SIZE_MAX; path->pc++; }
    break;
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
    if( path->in_group ) return LIBSPECTRUM_ERROR_INVALID;
    path->in_group = 1;
    path->pc++;
    break;
  case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
    if( !path->in_group ) return LIBSPECTRUM_ERROR_INVALID;
    path->in_group = 0;
    path->pc++;
    break;
  default: path->pc++; break;
  }
  return LIBSPECTRUM_ERROR_NONE;
}

static libspectrum_error
expand_path( const pzx_source_block *source, size_t count,
             libspectrum_tape_iterator *plan, size_t *visits )
{
  pzx_path_state path = { 0, SIZE_MAX, 0, 0 };
  while( path.pc < count ) {
    libspectrum_error error;
    if( *visits == PZX_MAX_VISITS ) return LIBSPECTRUM_ERROR_INVALID;
    plan[(*visits)++] = source[path.pc].node;
    error = advance_path( source, &path );
    if( error ) return error;
  }
  return path.in_group || path.active != SIZE_MAX ?
    LIBSPECTRUM_ERROR_INVALID : LIBSPECTRUM_ERROR_NONE;
}

/* Validate unreachable targets too, before any playback or output. */
libspectrum_error
internal_pzx_plan_blocks( pzx_writer *writer, libspectrum_tape *tape,
                          libspectrum_tape_iterator **plan, size_t *visits )
{
  size_t count = libspectrum_tape_count( tape );
  pzx_source_block *source;
  libspectrum_error error;
  *plan = NULL;
  *visits = count;
  if( !writer->bounded ) return LIBSPECTRUM_ERROR_NONE;
  *visits = 0;
  *plan = libspectrum_new( libspectrum_tape_iterator, PZX_MAX_VISITS );
  source = libspectrum_new( pzx_source_block, count );
  error = index_source_loops( source, tape );
  if( error ) goto done;
  error = check_source_jumps( source, count );
  if( error ) goto done;
  error = expand_path( source, count, *plan, visits );
done:
  libspectrum_free( source );
  if( error ) {
    libspectrum_free( *plan ); *plan = NULL; *visits = 0;
  }
  return error;
}
