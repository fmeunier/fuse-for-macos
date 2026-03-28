/* LibspectrumMetadataImporter.m: Extract metadata from libspectrum-supported Spectrum files
   Copyright (c) 2005 Fredrick Meunier
   Based on tzxlist from fuse-utils
   Copyright (c) 2001-2003 Philip Kendall, Darren Salt

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

#import "LibspectrumMetadataImporter.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <Foundation/Foundation.h>

#include <sys/types.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

#include <libspectrum.h>

static libspectrum_error
libspectrum_importer_error_function( libspectrum_error error,
                                    const char *format, va_list ap );

static char fsrep[MAXPATHLEN+1];

static int
mmap_file( const char *filename, unsigned char **buffer, size_t *length )
{
  int fd; struct stat file_info;

  if( ( fd = open( filename, O_RDONLY ) ) == -1 ) {
    NSLog(@"LibspectrumMetadataImporter: couldn't open `%s': %s\n", filename,
             strerror( errno ) );
    return 1;
  }

  if( fstat( fd, &file_info) ) {
    NSLog(@"LibspectrumMetadataImporter: couldn't stat `%s': %s\n", filename,
             strerror( errno ) );
    close(fd);
    return 1;
  }

  (*length) = file_info.st_size;

  (*buffer) = mmap( 0, *length, PROT_READ, MAP_SHARED, fd, 0 );
  if( (*buffer) == (void*)-1 ) {
    NSLog(@"LibspectrumMetadataImporter: couldn't mmap `%s': %s\n", filename,
             strerror( errno ) );
    close(fd);
    return 1;
  }

  if( close(fd) ) {
    NSLog(@"LibspectrumMetadataImporter: couldn't close `%s': %s\n", filename,
             strerror( errno ) );
    munmap( *buffer, *length );
    return 1;
  }

  return 0;
}

#define DESCRIPTION_LENGTH 80

static void
hardware_desc( NSMutableArray *machines, NSMutableArray *peripherals, int type,
               int id )
{
  switch( type ) {
  case 0:
    switch( id ) {
    case 0:
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_16))];
      return;
    case 1:
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_48))];
      return;
    case 2:
      [machines addObject:[NSString stringWithFormat:@"%s (Issue 1)",
        libspectrum_machine_name(LIBSPECTRUM_MACHINE_48)]];
      return;
    case 3:
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_128))];
      return;
    case 4:
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_PLUS2))];
      return;
    case 5:
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_PLUS2A))];
      [machines addObject:@(libspectrum_machine_name(LIBSPECTRUM_MACHINE_PLUS3))];
      return;
    default:
      [machines addObject:@"Unknown machine"];
      return;
    }
  case 3:
    switch( id ) {
    case 0:
      [peripherals addObject:@"AY-3-8192"]; return;
    default:
      [peripherals addObject:@"Unknown sound device"];
      return;
    }
  case 4:
    switch( id ) {
    case 0:
      [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
        libspectrum_joystick_name(LIBSPECTRUM_JOYSTICK_KEMPSTON)]];
      return;
    case 1:
      [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
        libspectrum_joystick_name(LIBSPECTRUM_JOYSTICK_CURSOR)]];
      return;
    case 2:
      [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
        libspectrum_joystick_name(LIBSPECTRUM_JOYSTICK_SINCLAIR_1)]];
      return;
    case 3:
      [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
        libspectrum_joystick_name(LIBSPECTRUM_JOYSTICK_SINCLAIR_2)]];
      return;
    case 4:
      [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
        libspectrum_joystick_name(LIBSPECTRUM_JOYSTICK_FULLER)]];
      return;
    default:
      [peripherals addObject:@"Unknown joystick"];
      return;
    }
  default: NSLog(@"Unknown type"); return;
  }
}

static libspectrum_error
libspectrum_importer_error_function( libspectrum_error error,
                                     const char *format, va_list ap )
{
  char err_msg[256];

  vsnprintf( err_msg, 256, format, ap );

  NSLog(@"LibspectrumMetadataImporter: error `%s': %s\n", fsrep, err_msg );

  return LIBSPECTRUM_ERROR_NONE;
}

@implementation LibspectrumMetadataImporter

- (BOOL)
process_tape
{
  int error;

  libspectrum_tape *tape;
  libspectrum_tape_iterator iterator;
  libspectrum_tape_block *block;
  libspectrum_dword tstates_total = 0;

  size_t i;

  tape = libspectrum_tape_alloc();

  NSLog(@"LibspectrumMetadataImporter: reading tape `%s'\n", fsrep );

  error = libspectrum_tape_read( tape, buffer, length, type, fsrep );
  if( error != LIBSPECTRUM_ERROR_NONE ) {
    return NO;
  }

  [attributes setObject:[NSNumber numberWithInt:1]
                 forKey:(NSString *)kMDItemAudioChannelCount];

  block = libspectrum_tape_iterator_init( &iterator, tape );

  while( block ) {
    char description[ DESCRIPTION_LENGTH ];
	NSMutableArray *machines, *peripherals;

    error =
      libspectrum_tape_block_description( description, DESCRIPTION_LENGTH,
					  block );
    if( error ) return NO;

    switch( libspectrum_tape_block_type( block ) ) {

    case LIBSPECTRUM_TAPE_BLOCK_ROM:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_TURBO:
    case LIBSPECTRUM_TAPE_BLOCK_PURE_DATA:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PURE_TONE:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PULSES:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_RAW_DATA:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PAUSE:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_GROUP_START:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_GROUP_END:
    case LIBSPECTRUM_TAPE_BLOCK_LOOP_END:
    case LIBSPECTRUM_TAPE_BLOCK_STOP48:
      /* Do nothing */
      break;

    case LIBSPECTRUM_TAPE_BLOCK_JUMP:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_LOOP_START:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_SELECT:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_MESSAGE:
      /* Fall through */

    case LIBSPECTRUM_TAPE_BLOCK_COMMENT:
      // FIXME: Sometimes contains MakeTZX text
      //NSLog(@"LibspectrumMetadataImporter: Comment: %s\n", libspectrum_tape_block_text( block ) );
      //[attributes setObject:[NSString stringWithUTF8String:(const char *)libspectrum_tape_block_text( block )]
      //                          forKey:(NSString *)kMDItemComment];
      break;

    case LIBSPECTRUM_TAPE_BLOCK_ARCHIVE_INFO:
      for( i = 0; i < libspectrum_tape_block_count( block ); i++ ) {
		NSString *info;

	switch( libspectrum_tape_block_ids( block, i ) ) {
	case   0:
		[attributes setObject:[NSString stringWithCString:
                  (const char *)libspectrum_tape_block_texts( block, i )
                  encoding:NSWindowsCP1252StringEncoding]
                                forKey:(NSString *)kMDItemTitle];
		break;
	case   1:
		info = [NSString stringWithCString:
                        (const char *)libspectrum_tape_block_texts( block, i )
                        encoding:NSWindowsCP1252StringEncoding];
		[attributes setObject:[info componentsSeparatedByString:@"\n"]
                                forKey:(NSString *)kMDItemPublishers];
		break;
	case   2:
		info = [NSString stringWithCString:
                        (const char *)libspectrum_tape_block_texts( block, i )
                        encoding:NSWindowsCP1252StringEncoding];
		[attributes setObject:[info componentsSeparatedByString:@"\n"]
                                forKey:(NSString *)kMDItemAuthors];
		break;
	case   3:
		[attributes setObject:[NSNumber numberWithInt:
			[[NSString stringWithCString:
                          (const char *)libspectrum_tape_block_texts( block, i )
                          encoding:NSWindowsCP1252StringEncoding] intValue]]
                               forKey:(NSString *)kMDItemRecordingYear];
		break;
	case   4: // We will want to translate from "English" etc.
		info = [NSString stringWithCString:
                        (const char *)libspectrum_tape_block_texts( block, i )
                        encoding:NSWindowsCP1252StringEncoding];
		[attributes setObject:[info componentsSeparatedByString:@"\n"]
		                        forKey:(NSString *)kMDItemLanguages];
		break;
	case   5:
		[attributes setObject:[NSString stringWithCString:
                        (const char *)libspectrum_tape_block_texts( block, i )
                        encoding:NSWindowsCP1252StringEncoding]
                    forKey:@"net_sourceforge_projects_fuse_emulator_Category"];
		break;
	case   6:
                {
                const char *infoString =
                  libspectrum_tape_block_texts( block, i );
                NSMutableString *priceString =
                  [NSMutableString stringWithCString:infoString 
                        encoding:NSWindowsCP1252StringEncoding];
                // WoS Infoseek has been putting HTML-style "&euro;" in for the
                // Euro symbol which isn't in the ISO Latin 1 string encoding.
                // Martijn has agreed to use CP1252 (a superset of Latin 1)
                // instead.
                // In case of encountering some old blocks we support
                // translating "&euro;" to the correect sign as well as
                // supporting CP1252 encoding on import replace it with the
                // standard euro sign
                [priceString replaceOccurrencesOfString:@"&euro;"
                    withString:@"€"
                       options:NSCaseInsensitiveSearch
                         range:NSMakeRange(0, [priceString length])];
                // Also should consider UKP from some TZX Vault info blocks?
		[attributes setObject:priceString 
                    forKey:@"net_sourceforge_projects_fuse_emulator_Price"];
                }
		break;
	case   7:
		[attributes setObject:[NSString stringWithCString:
                  (const char *)libspectrum_tape_block_texts( block, i )
                  encoding:NSWindowsCP1252StringEncoding]
                    forKey:@"net_sourceforge_projects_fuse_emulator_Loader"];
		break;
	case   8:
		[attributes setObject:[NSString stringWithCString:
                  (const char *)libspectrum_tape_block_texts( block, i )
                  encoding:NSWindowsCP1252StringEncoding]
                    forKey:@"net_sourceforge_projects_fuse_emulator_Origin"];
		break;
	case 255:
		[attributes setObject:[NSString stringWithCString:
                  (const char *)libspectrum_tape_block_texts( block, i )
                  encoding:NSWindowsCP1252StringEncoding]
                    forKey:(NSString *)kMDItemComment];
		break;
	 default: NSLog(@"(Unknown string): %s",
                        (const char *)libspectrum_tape_block_texts( block, i ));
		break;
	}
      }
      break;

    case LIBSPECTRUM_TAPE_BLOCK_HARDWARE:
      machines = [NSMutableArray array];
      peripherals = [NSMutableArray array];
      for( i = 0; i < libspectrum_tape_block_count( block ); i++ ) {
        switch( libspectrum_tape_block_values( block, i ) ) {
        case 0: /* runs */
          hardware_desc( machines, peripherals,
                         libspectrum_tape_block_types( block, i ),
                         libspectrum_tape_block_ids( block, i )
                         );
          break;
        case 1: break; /* runs, using hardware */
        case 2: break; /* runs, does not use hardware */
        case 3: break; /* does not run */
        }
      }
      if( [machines count] ) {
        [attributes setObject:machines
                  forKey:@"net_sourceforge_projects_fuse_emulator_Machines"];
      }
      if( [peripherals count] ) {
        [attributes setObject:peripherals
                  forKey:@"net_sourceforge_projects_fuse_emulator_Peripherals"];
      }
      break;

    case LIBSPECTRUM_TAPE_BLOCK_CUSTOM:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_RLE_PULSE:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_GENERALISED_DATA:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_PULSE_SEQUENCE:
      break;

    case LIBSPECTRUM_TAPE_BLOCK_DATA_BLOCK:
      break;

    default:
      NSLog(@"LibspectrumMetadataImporter: (Sorry -- can't handle that kind of block. Skipping it)\n");
      break;
    }

    tstates_total += libspectrum_tape_block_length( block );

    block = libspectrum_tape_iterator_next( &iterator );

  }

  float duration = tstates_total/3500000.0;

  [attributes setObject:[NSNumber numberWithFloat:duration]
                 forKey:(NSString *)kMDItemDurationSeconds];

  error = libspectrum_tape_free( tape );
  if( error != LIBSPECTRUM_ERROR_NONE ) {
    munmap( buffer, length );
    return NO;
  }

  return YES;
}

- (BOOL)
process_snap2:(libspectrum_snap *)snap
{
  int error = 0;
  NSMutableArray *peripherals = [NSMutableArray arrayWithCapacity:7];

  if( !libspectrum_snap_issue2(snap) &&
      (libspectrum_snap_machine(snap) == LIBSPECTRUM_MACHINE_48 ||
       libspectrum_snap_machine(snap) == LIBSPECTRUM_MACHINE_16) ) {
    [attributes setObject:[NSArray arrayWithObject:
                    [NSString stringWithFormat:@"%s (Issue 1)",
                     libspectrum_machine_name(libspectrum_snap_machine(snap))]]
                    forKey:@"net_sourceforge_projects_fuse_emulator_Machines"];
  } else {
    [attributes setObject:[NSArray arrayWithObject:
       [NSString stringWithUTF8String:
        libspectrum_machine_name(libspectrum_snap_machine(snap))]]
            forKey:@"net_sourceforge_projects_fuse_emulator_Machines"];
  }

  if( libspectrum_snap_joystick_active_count( snap ) ) {
    int i;

    for( i=0; i< libspectrum_snap_joystick_active_count( snap ); i++ ) {
      if(libspectrum_snap_joystick_list(snap, i) != LIBSPECTRUM_JOYSTICK_NONE) {
        [peripherals addObject:[NSString stringWithFormat:@"%s joystick",
         libspectrum_joystick_name(libspectrum_snap_joystick_list( snap, i ))]];
      }
    }
  }

  /* FIXME: Other connected hardware? */
  if( libspectrum_snap_ulaplus_active( snap ) ) {
    [peripherals addObject:@"ULAplus"];
  }
  if( libspectrum_snap_divmmc_active( snap ) ) {
    [peripherals addObject:@"DivMMC"];
  }
  if( libspectrum_snap_zxmmc_active( snap ) ) {
    [peripherals addObject:@"ZXMMC"];
  }
  if( libspectrum_snap_zxatasp_active( snap ) ) {
    [peripherals addObject:@"ZXATASP"];
  }
  if( libspectrum_snap_zxcf_active( snap ) ) {
    [peripherals addObject:@"ZXCF"];
  }
  if( libspectrum_snap_interface1_active( snap ) ) {
    [peripherals addObject:@"Interface I"];
  }
  if( libspectrum_snap_interface2_active( snap ) ) {
    [peripherals addObject:@"Interface II Cartridge"];
  }
  if( libspectrum_snap_dock_active( snap ) &&
      libspectrum_snap_machine(snap) != LIBSPECTRUM_MACHINE_SE ) {
    [peripherals addObject:@"Timex Dock Cartidge"];
  }
  if( libspectrum_snap_beta_active( snap ) ) {
    [peripherals addObject:@"Beta Disk"];
  }
  if( libspectrum_snap_plusd_active( snap ) ) {
    [peripherals addObject:@"+D Disk"];
  }
  if( libspectrum_snap_opus_active( snap ) ) {
    [peripherals addObject:@"Opus Disk"];
  }
  if( libspectrum_snap_kempston_mouse_active( snap ) ) {
    [peripherals addObject:@"Kempston Mouse"];
  }
  if( libspectrum_snap_simpleide_active( snap ) ) {
    [peripherals addObject:@"Simple IDE"];
  }
  if( libspectrum_snap_divide_active( snap ) ) {
    [peripherals addObject:@"DivIDE"];
  }
  if( libspectrum_snap_fuller_box_active( snap ) ) {
    [peripherals addObject:@"Fuller Box"];
  }
  if( libspectrum_snap_melodik_active( snap ) ) {
    [peripherals addObject:@"Melodik"];
  }
  if( libspectrum_snap_specdrum_active( snap ) ) {
    [peripherals addObject:@"SpecDrum"];
  }
  if( libspectrum_snap_spectranet_active( snap ) ) {
    [peripherals addObject:@"Spectranet"];
  }
  if( libspectrum_snap_zx_printer_active( snap ) ) {
    [peripherals addObject:@"ZX Printer"];
  }
  if( libspectrum_snap_usource_active( snap ) ) {
    [peripherals addObject:@"Currah µSource"];
  }
  if( libspectrum_snap_disciple_active( snap ) ) {
    [peripherals addObject:@"DISCiPLE"];
  }
  if( libspectrum_snap_didaktik80_active( snap ) ) {
    [peripherals addObject:@"Didaktik D80"];
  }
  if( libspectrum_snap_covox_active( snap ) ) {
    [peripherals addObject:@"Covox"];
  }
  if( libspectrum_snap_multiface_active( snap ) ) {
    if( libspectrum_snap_multiface_model_one( snap ) ) {
      [peripherals addObject:@"Multiface One"];
    }
    if( libspectrum_snap_multiface_model_128( snap ) ) {
      [peripherals addObject:@"Multiface 128"];
    }
    if( libspectrum_snap_multiface_model_3( snap ) ) {
      [peripherals addObject:@"Multiface 3"];
    }
  }
  if( [peripherals count] ) {
    [attributes setObject:peripherals
                  forKey:@"net_sourceforge_projects_fuse_emulator_Peripherals"];
  }

  return error ? NO : YES;
}

- (BOOL)
process_snap
{
  int error = 0;

  libspectrum_snap *snap;

  snap = libspectrum_snap_alloc();

  error = libspectrum_snap_read( snap, buffer, length, type, fsrep );
  if( error ) {
    libspectrum_snap_free( snap );
    return NO;
  }

  error = [self process_snap2:snap] ? 0 : 1;
  if( error ) {
    libspectrum_snap_free( snap );
    return NO;
  }

  error = libspectrum_snap_free( snap );
  if( error ) { return NO; }

  return error ? NO : YES;
}

- (BOOL)
process_rzx
{
  int error = 0;

  libspectrum_rzx *rzx;
  libspectrum_snap *snap = NULL;

  rzx = libspectrum_rzx_alloc();

  error = libspectrum_rzx_read( rzx, buffer, length );
  if( error ) {
    libspectrum_rzx_free( rzx );
    return NO;
  }

  error = libspectrum_rzx_start_playback( rzx, 0, &snap );
  if( error ) return error;

  if( snap ) {
    error = [self process_snap2:snap] ? 0 : 1;
    if( error ) {
      libspectrum_rzx_free( rzx );
      return NO;
    }
  }

  error = libspectrum_rzx_free( rzx );
  if( error ) { return NO; }

  return YES;
}

#define STANDARD_SCR_SIZE 6912
#define MONO_BITMAP_SIZE 6144
#define HICOLOUR_SCR_SIZE (2 * MONO_BITMAP_SIZE)
#define HIRES_ATTR HICOLOUR_SCR_SIZE
#define HIRES_SCR_SIZE (HICOLOUR_SCR_SIZE + 1)

- (BOOL)
process_screenshot
{
  int width;
  NSString *mode;

  switch( length ) {
  case HICOLOUR_SCR_SIZE:
    mode = @"HiColour";
    width = 256;
    break;
  case STANDARD_SCR_SIZE:
    mode = @"Standard";
    width = 256;
    break;
  case HIRES_SCR_SIZE:
    mode = @"HiRes";
    width = 512;
    break;
  default:
    /* Wrong file size for an scr file */
    return NO;
  }

  [attributes setObject:[NSNumber numberWithInt:width]
                                forKey:(NSString *)kMDItemPixelWidth];
  [attributes setObject:[NSNumber numberWithInt:192]
                                forKey:(NSString *)kMDItemPixelHeight];
  [attributes setObject:[NSNumber numberWithInt:0]
                                forKey:(NSString *)kMDItemOrientation];
  [attributes setObject:@"RGB" forKey:(NSString *)kMDItemColorSpace];

  [attributes setObject:mode
                 forKey:@"net_sourceforge_projects_fuse_emulator_GraphicsMode"];

  return YES;
}

- (BOOL)
process_dsk
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_trd
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_dck
{
  BOOL error = NO;

  /* FIXME: size etc? */

  return error;
}

- (BOOL)
process_opd
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_plusd
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_generic
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_auxilliary
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_d80
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_if2r
{
  BOOL error = NO;

  /* FIXME: size etc? */

  return error;
}

- (BOOL)
process_mdr
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (BOOL)
process_hdr
{
  BOOL error = NO;

  /* FIXME: size, %full?, read-only vs read-write etc? */

  return error;
}

- (id)initWithFilename:(NSString*)aFile andAttributes:(NSMutableDictionary*)aDict
{
  self = [super init];

  filename = aFile;
  attributes = aDict;

  libspectrum_init();
  libspectrum_error_function = libspectrum_importer_error_function;

  return self;
}

- (BOOL)processFile
{
  libspectrum_class_t lsclass;
  BOOL retval = YES;

  [filename getFileSystemRepresentation:fsrep maxLength:MAXPATHLEN];

  if( mmap_file( fsrep, &buffer, &length ) ) return NO;

  //NSLog( @"LibspectrumMetadataImporter: processing `%s'\n", fsrep );

  if( libspectrum_identify_file( &type, fsrep, buffer, length ) ) {
    munmap( buffer, length );
    return NO;
  }

  if( libspectrum_identify_class( &lsclass, type ) ) {
    munmap( buffer, length );
    return NO;
  }

  switch( lsclass ) {

  case LIBSPECTRUM_CLASS_UNKNOWN:
    NSLog( @"LibspectrumMetadataImporter: couldn't identify `%s'\n", fsrep );
    retval = NO;
    break;

  case LIBSPECTRUM_CLASS_RECORDING:
    retval = [self process_rzx];
    break;

  case LIBSPECTRUM_CLASS_SNAPSHOT:
    retval = [self process_snap];
    break;

  case LIBSPECTRUM_CLASS_TAPE:
    retval = [self process_tape];
    break;

  case LIBSPECTRUM_CLASS_SCREENSHOT:
    retval = [self process_screenshot];
    break;

  case LIBSPECTRUM_CLASS_DISK_PLUS3:
    retval = [self process_dsk];
    break;

  case LIBSPECTRUM_CLASS_DISK_TRDOS:
    retval = [self process_trd];
    break;

  case LIBSPECTRUM_CLASS_CARTRIDGE_TIMEX:
    retval = [self process_dck];
    break;

  case LIBSPECTRUM_CLASS_CARTRIDGE_IF2:
    retval = [self process_if2r];
    break;

  case LIBSPECTRUM_CLASS_MICRODRIVE:
    retval = [self process_mdr];
    break;

  case LIBSPECTRUM_CLASS_HARDDISK:
    retval = [self process_hdr];
    break;

  case LIBSPECTRUM_CLASS_DISK_OPUS:
    retval = [self process_opd];
    break;

  case LIBSPECTRUM_CLASS_DISK_DIDAKTIK:
    retval = [self process_d80];
    break;

  case LIBSPECTRUM_CLASS_DISK_PLUSD:
    retval = [self process_plusd];
    break;

  case LIBSPECTRUM_CLASS_DISK_GENERIC:
    retval = [self process_generic];
    break;

  case LIBSPECTRUM_CLASS_AUXILIARY:
    retval = [self process_auxilliary];
    break;

  default:
    NSLog(@"LibspectrumMetadataImporter: loadFile: unknown class %d!\n", lsclass );
    retval = NO;
  }

  if( munmap( buffer, length ) == -1 ) {
    NSLog(@"LibspectrumMetadataImporter: couldn't munmap `%s': %s\n", fsrep,
	     strerror( errno ) );
    return NO;
  }

  //NSLog(@"returning: %d\n",retval);

  return retval;
}

@end
