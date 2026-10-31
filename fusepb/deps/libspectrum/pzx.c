/* pzx.c: Shared PZX archive-information mapping
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
#include "pzx_internals.h"

static const struct {
  const char *name;
  int id;
} archive_info[] = {
  { "Publisher",  0x01 },
  { "Author",     0x02 },
  { "Year",       0x03 },
  { "Language",   0x04 },
  { "Type",       0x05 },
  { "Price",      0x06 },
  { "Protection", 0x07 },
  { "Origin",     0x08 },
  { "Comment",    0xff },
};

int
internal_pzx_archive_id( const char *name )
{
  size_t i;
  for( i = 0; i < ARRAY_SIZE( archive_info ); i++ )
    if( !strcmp( name, archive_info[i].name ) ) return archive_info[i].id;
  return -1;
}

const char *
internal_pzx_archive_name( int id )
{
  size_t i;
  for( i = 0; i < ARRAY_SIZE( archive_info ); i++ )
    if( id == archive_info[i].id ) return archive_info[i].name;
  return NULL;
}
