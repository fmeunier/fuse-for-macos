/* LibspectrumSCRExtractor.h: Extract SCR image from libspectrum-supported Spectrum files
   Copyright (c) 2007 Fredrick Meunier

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

#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <libspectrum.h>

typedef enum image_t {
  TYPE_NONE,
  TYPE_SCR,
  TYPE_IMAGEIO,
} image_t;

@interface LibspectrumSCRExtractor : NSObject {
	NSString *filename;
	NSData *scrData;
	NSDictionary *scrOptions;
	image_t image_type;
	unsigned char *buffer;
	size_t length;
	libspectrum_id_t type;
	libspectrum_class_t lsclass;
}
- (id) initWithContentsOfURL:(NSURL*)aURL;

- (libspectrum_id_t) type;
- (libspectrum_class_t) class;
- (NSData*) scrData;
- (NSDictionary*) scrOptions;
- (image_t) image_type;

- (void) processFile;

- (void) process_tape;
- (void) process_mdr;
- (void) process_scr;
- (void) process_rzx;
- (void) process_snap;
- (void) process_snap2:(libspectrum_snap *)snap;
- (void) process_snap_sinclair48:(libspectrum_snap *)snap;
- (void) process_snap_sinclair128:(libspectrum_snap *)snap;
- (void) process_snap_timex:(libspectrum_snap *)snap inPage:(int)page;
- (void) process_snap_timex:(libspectrum_snap *)snap;
- (void) process_snap_se:(libspectrum_snap *)snap;

@end
