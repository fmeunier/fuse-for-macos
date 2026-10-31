/* pzx_internals.h: Shared internal PZX definitions
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

#ifndef LIBSPECTRUM_PZX_INTERNALS_H
#define LIBSPECTRUM_PZX_INTERNALS_H

#include "libspectrum.h"

#define PZX_VERSION_MAJOR 1
#define PZX_VERSION_MINOR 0
#define PZX_STOP_ALWAYS   0
#define PZX_STOP_48K      1
#define PZX_REPEAT_MAX    0x7fff
#define PZX_DURATION_FLAG 0x8000
#define PZX_LEVEL_FLAG    UINT32_C( 0x80000000 )
#define PZX_VALUE_MASK    UINT32_C( 0x7fffffff )

/* Standard PZX block tags, shared by the reader and writer. */
#define PZX_HEADER "PZXT"
#define PZX_PULSE  "PULS"
#define PZX_DATA   "DATA"
#define PZX_PAUSE  "PAUS"
#define PZX_BROWSE "BRWS"
#define PZX_STOP   "STOP"

/* Title (TZX ID 0) is positional, not a key/value pair. Unknown names
   return -1; unknown IDs return NULL. */
int internal_pzx_archive_id( const char *name );
const char *internal_pzx_archive_name( int id );

#endif
