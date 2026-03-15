/* LibspectrumMetadataImporter.h: Extract metadata from libspectrum-supported Spectrum files
   Copyright (c) 2005 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

   Author contact information:

   E-mail: fredm@spamcop.net

*/

#include <Foundation/Foundation.h>

#include <sys/types.h>
#include <libspectrum.h>

@interface LibspectrumMetadataImporter : NSObject
{
	NSString *filename;
	NSMutableDictionary *attributes;
	unsigned char *buffer;
	size_t length;
	libspectrum_id_t type;
}
- (id) initWithFilename:(NSString*)aFile andAttributes:(NSMutableDictionary*)aDict;
- (BOOL) processFile;

- (BOOL) process_tape;
- (BOOL) process_hdr;
- (BOOL) process_mdr;
- (BOOL) process_if2r;
- (BOOL) process_dck;
- (BOOL) process_trd;
- (BOOL) process_dsk;
- (BOOL) process_screenshot;
- (BOOL) process_rzx;
- (BOOL) process_opd;
- (BOOL) process_plusd;
- (BOOL) process_d80;
- (BOOL) process_generic;
- (BOOL) process_auxilliary;
- (BOOL) process_snap2:(libspectrum_snap *)snap;

@end
