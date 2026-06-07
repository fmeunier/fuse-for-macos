/* LibspectrumSCRExtractor.m: Extract SCR image from libspectrum-supported Spectrum files
   Copyright (c) 2007-2008 Fredrick Meunier

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

#import "LibspectrumSCRExtractor.h"

#include <sys/types.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

#include <libspectrum.h>

#define STANDARD_SCR_SIZE      6912
#define MONO_BITMAP_SIZE       6144
#define HICOLOUR_SCR_SIZE      (2 * MONO_BITMAP_SIZE)
#define HIRES_ATTR             HICOLOUR_SCR_SIZE
#define HIRES_SCR_SIZE         (HICOLOUR_SCR_SIZE + 1)
#define HIRESCOLMASK           0x38
#define ALTDFILE_OFFSET        0x2000
#define SCREEN_ADDRESS         16384
#define CODE_FILE_TYPE         3
#define SCREEN_TAPE_BLOCK_SIZE ( STANDARD_SCR_SIZE + 2 )


static int
mmap_file( const char *filename, unsigned char **buffer, size_t *length )
{
  int fd; struct stat file_info;

  if( ( fd = open( filename, O_RDONLY ) ) == -1 ) {
    NSLog(@"LibspectrumSCRExtractor: couldn't open `%s': %s\n", filename,
            strerror( errno ) );
    return 1;
  }

  if( fstat( fd, &file_info) ) {
    NSLog(@"LibspectrumSCRExtractor: couldn't stat `%s': %s\n", filename,
            strerror( errno ) );
    close(fd);
    return 1;
  }

  (*length) = file_info.st_size;

  (*buffer) = mmap( 0, *length, PROT_READ, MAP_SHARED, fd, 0 );
  if( (*buffer) == (void*)-1 ) {
    NSLog(@"LibspectrumSCRExtractor: couldn't mmap `%s': %s\n", filename,
            strerror( errno ) );
    close(fd);
    return 1;
  }

  if( close(fd) ) {
    NSLog(@"LibspectrumSCRExtractor: couldn't close `%s': %s\n", filename,
            strerror( errno ) );
    munmap( *buffer, *length );
    return 1;
  }

  return 0;
}

@implementation LibspectrumSCRExtractor

- (id)initWithContentsOfURL:(NSURL*)aURL
{
  const char *fileString;
  self = [super init];

  fileString = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:[aURL path]];
  filename = @(fileString);

  scrData = nil;
  scrOptions = nil;

  image_type = TYPE_NONE;

  return self;
}

- (libspectrum_id_t) type
{
  if(!scrData) { [self processFile]; }

  return type;
}

- (libspectrum_class_t) class
{
  if(!scrData) { [self processFile]; }
  
  return lsclass;
}

- (NSData*) scrData
{
  if(!scrData) { [self processFile]; }
  
  return scrData;
}

- (NSDictionary*) scrOptions
{
  if(!scrData) { [self processFile]; }
  
  return scrOptions;
}

- (image_t) image_type
{
  if(!scrData) { [self processFile]; }
  
  return image_type;
}

- (void) processFile
{
  if( mmap_file( [filename UTF8String], &buffer, &length ) ) return;

  if( libspectrum_identify_file_with_class( &type, &lsclass,
                                            [filename UTF8String],
                                            buffer, length ) ) {
    munmap( buffer, length );
    return;
  } 

  switch( lsclass ) {

  case LIBSPECTRUM_CLASS_UNKNOWN:
    NSLog( @"LibspectrumSCRExtractor: couldn't identify `%s'\n", [filename UTF8String] );
    break;

  case LIBSPECTRUM_CLASS_RECORDING:
    [self process_rzx];
    break;

  case LIBSPECTRUM_CLASS_SNAPSHOT:
    [self process_snap];
    break;

  case LIBSPECTRUM_CLASS_TAPE:
    [self process_tape];
    break;

  case LIBSPECTRUM_CLASS_SCREENSHOT:
    [self process_scr];
    break;

  case LIBSPECTRUM_CLASS_MICRODRIVE:
    [self process_mdr];
    break;

  case LIBSPECTRUM_CLASS_DISK_PLUS3:
  case LIBSPECTRUM_CLASS_DISK_TRDOS:
  case LIBSPECTRUM_CLASS_DISK_OPUS:
  case LIBSPECTRUM_CLASS_HARDDISK:
  case LIBSPECTRUM_CLASS_CARTRIDGE_TIMEX:
  case LIBSPECTRUM_CLASS_CARTRIDGE_IF2:
  case LIBSPECTRUM_CLASS_DISK_PLUSD:
  case LIBSPECTRUM_CLASS_DISK_GENERIC:
  case LIBSPECTRUM_CLASS_AUXILIARY:
  case LIBSPECTRUM_CLASS_DISK_DIDAKTIK:
    break;

  default:
    NSLog(@"LibspectrumSCRExtractor: loadFile: unknown class %d!\n", lsclass );
  }

  if( munmap( buffer, length ) == -1 ) {
    NSLog(@"LibspectrumSCRExtractor: couldn't munmap `%s': %s\n", [filename UTF8String],
            strerror( errno ) );
    return;
  }
}

// If a tape has a ROM header block for Bytes length 6912, location 16384
// followed by a ROM data block of 6912 bytes, use that as a SCR. Custom
// loaders may also use headerless data blocks, so we still accept a raw
// 6912-byte screen payload plus flag and checksum without requiring a header.
// Also have a look at turbo blocks as sometimes the timing is just a bit
// different from the ROM values, but are otherwise identical
// And finally look for TZX custom blocks with loading screens or tape inlays
- (void) process_tape
{
  int error = 0;

  libspectrum_tape *tape;
  libspectrum_tape_iterator iterator;
  libspectrum_tape_block *block;

  tape = libspectrum_tape_alloc();

  error = libspectrum_tape_read( tape, buffer, length, LIBSPECTRUM_ID_UNKNOWN,
                                 [filename UTF8String] );
  if( error ) { return; }

  block = libspectrum_tape_iterator_init( &iterator, tape );

  while( block ) {
  
    switch( libspectrum_tape_block_type( block ) ) {

    case LIBSPECTRUM_TAPE_BLOCK_ROM:
    case LIBSPECTRUM_TAPE_BLOCK_TURBO:
    case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK:
      /* See if this looks like a standard Spectrum screen and if so
         display it if we haven't already assigned an image */
      if( scrData ) {
        block = libspectrum_tape_iterator_next( &iterator );
        continue;
      }

      // SCREEN$ payload is 6912 bytes plus flag and checksum
      if( libspectrum_tape_block_data_length( block ) ==
          SCREEN_TAPE_BLOCK_SIZE ) {
        libspectrum_byte *data = libspectrum_tape_block_data( block );

        scrData = [NSData dataWithBytes:(const void *)(data+1)
                                 length:STANDARD_SCR_SIZE];    

        image_type = TYPE_SCR;
      }
      break;

    case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
      {
        char* description = libspectrum_tape_block_text( block );
        if( !description ) {
          block = libspectrum_tape_iterator_next( &iterator );
          continue;
        }

        if( !scrData &&
            strncmp( "Spectrum Screen ", description, 0x10 ) == 0 ) {
          size_t data_length = libspectrum_tape_block_data_length( block );
          libspectrum_byte *data = libspectrum_tape_block_data( block );
          size_t scr_length = data_length - data[0] - 2;

          if( scr_length == STANDARD_SCR_SIZE ||
              scr_length == HICOLOUR_SCR_SIZE ||
              scr_length == HIRES_SCR_SIZE ) {
            scrData = [NSData dataWithBytes:(const void *)(data+data[0]+2)
                                     length:scr_length];    

            image_type = TYPE_SCR;
          }
        } else if( strncmp( "Picture        ", description, 0x10 ) == 0 ) {
          size_t data_length = libspectrum_tape_block_data_length( block );
          libspectrum_byte *data = libspectrum_tape_block_data( block );
          size_t picture_length = data_length - data[1] - 2;

          /* Image is an 'Inlay Card' and is in GIF or JPEG format */
          if( data[1] == 0 && ( data[0] == 0 || data[0] == 1 ) ) {
            id myValue = nil;

            switch( data[0] ) {
            case 0: myValue = (NSString*)kUTTypeGIF; break;
            case 1: myValue = (NSString*)kUTTypeJPEG; break;
            }

            scrOptions =
              @{(NSString*)kCGImageSourceTypeIdentifierHint: myValue};

            scrData = [NSData dataWithBytes:data + data[1] + 2
                                     length:picture_length];

            image_type = TYPE_IMAGEIO;

            goto done;
          }
        }
      }
      break;

    default:
      break;
    }
    
    block = libspectrum_tape_iterator_next( &iterator );

  }

done:
  error = libspectrum_tape_free( tape );
  if( error ) { return; }
}

static unsigned int
read_le16( const unsigned char *data )
{
  return data[0] | ( data[1] << 8 );
}

static int
microdrive_header_is_screen_dump( const unsigned char *data, int length )
{
  if( length >= 7 &&
      data[0] == CODE_FILE_TYPE &&
      read_le16( data + 1 ) == STANDARD_SCR_SIZE &&
      read_le16( data + 3 ) == SCREEN_ADDRESS )
    return 1;

  if( length >= 8 &&
      data[1] == CODE_FILE_TYPE &&
      read_le16( data + 2 ) == STANDARD_SCR_SIZE &&
      read_le16( data + 4 ) == SCREEN_ADDRESS )
    return 1;

  return 0;
}

/* Look for the first microdrive CODE file saved to the standard Spectrum
   screen address. SCREEN$ is BASIC shorthand for such a file, not a literal
   filename. MDR data is split into up to LIBSPECTRUM_MICRODRIVE_BLOCK_MAX
   sectors of LIBSPECTRUM_MICRODRIVE_BLOCK_LEN bytes. Each sector's second
   header (at byte offset LIBSPECTRUM_MICRODRIVE_HEAD_LEN) contains:
     recflg (1 byte)  -- bit0: 1=file-descriptor header, 0=data block
     recnum (1 byte)  -- sector sequence number within the file (0-based)
     reclen (2 bytes) -- number of valid data bytes in this sector (LE)
     recnam (10 bytes)-- file name, space-padded
   Actual sector data follows at offset LIBSPECTRUM_MICRODRIVE_HEAD_LEN*2. */
- (void) process_mdr
{
  int num_blocks, i, found, have_screen_file;
  unsigned char file_name[10], screen[STANDARD_SCR_SIZE];

  if( length < (size_t)LIBSPECTRUM_MICRODRIVE_BLOCK_LEN ) return;

  num_blocks = (int)( length / LIBSPECTRUM_MICRODRIVE_BLOCK_LEN );
  if( num_blocks > LIBSPECTRUM_MICRODRIVE_BLOCK_MAX )
    num_blocks = LIBSPECTRUM_MICRODRIVE_BLOCK_MAX;

  have_screen_file = 0;

  for( i = 0; i < num_blocks; i++ ) {
    const unsigned char *blk, *data;
    int recflg, reclen;

    blk = buffer + i * LIBSPECTRUM_MICRODRIVE_BLOCK_LEN;

    recflg = blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN ];
    reclen = blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 2 ] |
             ( blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 3 ] << 8 );

    if( reclen == 0 || !( recflg & 0x01 ) ) continue;

    data = blk + LIBSPECTRUM_MICRODRIVE_HEAD_LEN * 2;
    if( !microdrive_header_is_screen_dump( data, reclen ) ) continue;

    memcpy( file_name, blk + LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 4,
            sizeof( file_name ) );
    have_screen_file = 1;
    break;
  }

  if( !have_screen_file ) return;

  memset( screen, 0, sizeof( screen ) );
  found = 0;

  for( i = 0; i < num_blocks; i++ ) {
    const unsigned char *blk;
    int recflg, recnum, reclen, offset, copy_len;

    blk = buffer + i * LIBSPECTRUM_MICRODRIVE_BLOCK_LEN;

    recflg = blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN ];
    recnum = blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 1 ];
    reclen = blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 2 ] |
             ( blk[ LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 3 ] << 8 );

    /* Skip free/erased blocks and file-descriptor-header blocks */
    if( reclen == 0 || ( recflg & 0x01 ) ) continue;

    if( memcmp( blk + LIBSPECTRUM_MICRODRIVE_HEAD_LEN + 4, file_name,
                sizeof( file_name ) ) != 0 )
      continue;

    offset = recnum * LIBSPECTRUM_MICRODRIVE_DATA_LEN;
    if( offset >= STANDARD_SCR_SIZE ) continue;

    copy_len = reclen < LIBSPECTRUM_MICRODRIVE_DATA_LEN
               ? reclen : LIBSPECTRUM_MICRODRIVE_DATA_LEN;
    if( offset + copy_len > STANDARD_SCR_SIZE )
      copy_len = STANDARD_SCR_SIZE - offset;

    memcpy( screen + offset,
            blk + LIBSPECTRUM_MICRODRIVE_HEAD_LEN * 2,
            copy_len );
    found++;
  }

  /* Require at least the 13 sectors that cover the full bitmap area */
  if( found >= 13 ) {
    scrData = [NSData dataWithBytes:screen length:STANDARD_SCR_SIZE];
    image_type = TYPE_SCR;
  }
}

// Populate scrData directly
- (void) process_scr
{
  scrData = [NSData dataWithBytes:(const void *)buffer length:length];
  image_type = TYPE_SCR;
}

// Extract first snap then delegate to process_snap2
- (void) process_rzx
{
  int error = 0;
  libspectrum_rzx *rzx;
  libspectrum_snap *snap;

  rzx = libspectrum_rzx_alloc();

  error = libspectrum_rzx_read( rzx, buffer, length );
  if( error != LIBSPECTRUM_ERROR_NONE ) { return; }

  error = libspectrum_rzx_start_playback( rzx, 0, &snap );
  if( error ) { return; }

  if( snap ) {
    [self process_snap2:snap];
  }

  error = libspectrum_rzx_free( rzx );
  if( error ) { return; }
}

// Extract active screen from snap
- (void) process_snap
{
  int error = 0;
  libspectrum_snap *snap;

  snap = libspectrum_snap_alloc();

  error = libspectrum_snap_read( snap, buffer, length, type,
                                 [filename UTF8String] );
  if( error ) { libspectrum_snap_free( snap ); return; }

  [self process_snap2:snap];

  error = libspectrum_snap_free( snap );
  if( error ) { return; }
}

- (void) process_snap2:(libspectrum_snap *)snap
{
  switch(libspectrum_snap_machine(snap)) {
  case LIBSPECTRUM_MACHINE_16:
  case LIBSPECTRUM_MACHINE_48:
    [self process_snap_sinclair48:snap];
    break;
  
  case LIBSPECTRUM_MACHINE_TC2048:
  case LIBSPECTRUM_MACHINE_TC2068:
  case LIBSPECTRUM_MACHINE_TS2068:
    [self process_snap_timex:snap];
    break;
  
  case LIBSPECTRUM_MACHINE_128:
  case LIBSPECTRUM_MACHINE_PLUS2:
  case LIBSPECTRUM_MACHINE_PENT:
  case LIBSPECTRUM_MACHINE_PLUS2A:
  case LIBSPECTRUM_MACHINE_PLUS3:
  case LIBSPECTRUM_MACHINE_SCORP:
  case LIBSPECTRUM_MACHINE_PLUS3E:
  case LIBSPECTRUM_MACHINE_PENT512:
  case LIBSPECTRUM_MACHINE_PENT1024:
    [self process_snap_sinclair128:snap];
    break;

  case LIBSPECTRUM_MACHINE_SE:
    [self process_snap_se:snap];
    break;
      
  default:
    break;
  }
}

- (void) process_snap_sinclair48:(libspectrum_snap *)snap
{
  // Just need to copy out first 6912 bytes from page 5
  scrData = [NSData dataWithBytes:(const void *)libspectrum_snap_pages( snap, 5 )
                           length:STANDARD_SCR_SIZE];
  image_type = TYPE_SCR;
}

- (void) process_snap_sinclair128:(libspectrum_snap *)snap
{
  // Check which screen page is active and copy standard 6912 bytes
  int screen = ( libspectrum_snap_out_128_memoryport( snap ) & 0x08 ) ? 7 : 5;
  scrData = [NSData dataWithBytes:(const void *)libspectrum_snap_pages( snap, screen )
                           length:STANDARD_SCR_SIZE];
  image_type = TYPE_SCR;
}

- (void) process_snap_timex:(libspectrum_snap *)snap inPage:(int)page
{
  // Check which screen mode and pages are active and copy as appropriate
  libspectrum_byte* scr_data = calloc( HIRES_SCR_SIZE, 1 );
  int scr_length;

  if( libspectrum_snap_out_scld_dec( snap ) & 0x04 ) {
    memcpy( scr_data,
            libspectrum_snap_pages( snap, page ),
            MONO_BITMAP_SIZE );
    memcpy( scr_data + MONO_BITMAP_SIZE,
            libspectrum_snap_pages( snap, page ) + ALTDFILE_OFFSET,
            MONO_BITMAP_SIZE );
    scr_data[HIRES_ATTR] = ( libspectrum_snap_out_scld_dec( snap ) & HIRESCOLMASK ) | 0x07;
    scr_length = HIRES_SCR_SIZE;
  } else if( libspectrum_snap_out_scld_dec( snap ) & 0x02 ) {
    memcpy( scr_data,
            libspectrum_snap_pages( snap, page ),
            MONO_BITMAP_SIZE );
    memcpy( scr_data + MONO_BITMAP_SIZE,
            libspectrum_snap_pages( snap, page ) + ALTDFILE_OFFSET,
            MONO_BITMAP_SIZE );
    scr_length = HICOLOUR_SCR_SIZE;
  } else { /* ALTDFILE and default */
    int offset = ( libspectrum_snap_out_scld_dec( snap ) & 0x01 ) ? ALTDFILE_OFFSET : 0x0000;
    scr_length = STANDARD_SCR_SIZE;
    memcpy( scr_data,
            libspectrum_snap_pages( snap, page ) + offset,
            scr_length );
  }

  scrData = [NSData dataWithBytesNoCopy:(void *)scr_data length:scr_length];
  image_type = TYPE_SCR;
}

- (void) process_snap_timex:(libspectrum_snap *)snap
{
  // Timex screens are always in page 5
  [self process_snap_timex:snap inPage:5]; 
}

- (void) process_snap_se:(libspectrum_snap *)snap
{
  // SE uses the 128k port to decide which page, and then applies the Timex rule
  int screen = ( libspectrum_snap_out_128_memoryport( snap ) & 0x08 ) ? 7 : 5;
  [self process_snap_timex:snap inPage:screen];
}

@end
