/* pzx_write_internal.h: Private interfaces for PZX output
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
#ifndef LIBSPECTRUM_PZX_WRITE_INTERNAL_H
#define LIBSPECTRUM_PZX_WRITE_INTERNAL_H

#include "internals.h"
#include "pzx_internals.h"
#include "tape_block.h"

/* Bounds apply only to tapes containing control flow. */
#define PZX_MAX_VISITS 65536
#define PZX_MAX_EXPANDED_SIZE ( 64 * 1024 * 1024 )

typedef struct pzx_writer {
  libspectrum_buffer *out, *body;
  libspectrum_tape_block_state state;
  int need_playback, level, first, last, in_group, bounded;
} pzx_writer;

typedef struct pzx_legacy_data {
  size_t bits, pilot;
  libspectrum_dword bit0, bit1, pilot_length, sync1, sync2, pause, tail;
} pzx_legacy_data;

/* All blocks and iterators are borrowed from the source tape. The caller
   owns the returned plan array and releases it with libspectrum_free(). */
libspectrum_error internal_pzx_validate_tape( pzx_writer *writer,
                                             libspectrum_tape *tape );
libspectrum_error internal_pzx_plan_blocks( pzx_writer *writer,
  libspectrum_tape *tape, libspectrum_tape_iterator **plan, size_t *visits );
libspectrum_error internal_pzx_get_legacy_data( libspectrum_tape_block *block,
                                              pzx_legacy_data *data );
int internal_pzx_needs_playback( libspectrum_tape_block *block );
libspectrum_error internal_pzx_prepare_playback( pzx_writer *writer,
  libspectrum_tape *tape, libspectrum_tape_iterator *plan, size_t visits );
libspectrum_error internal_pzx_inspect_block( pzx_writer *writer,
  libspectrum_tape *tape, libspectrum_tape_iterator next );
libspectrum_error internal_pzx_write_pulse( libspectrum_buffer *body,
                                          libspectrum_dword duration,
                                          size_t count );

#endif /* LIBSPECTRUM_PZX_WRITE_INTERNAL_H */
