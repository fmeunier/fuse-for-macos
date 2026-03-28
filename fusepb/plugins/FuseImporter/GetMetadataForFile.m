/* GetMetadataForFile.m: Extract metadata from libspectrum-supported Spectrum files
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

#import "LibspectrumMetadataImporter.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <Foundation/Foundation.h>

#include "GetMetadataForFile.h"

/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    Boolean error = FALSE;
    NSAutoreleasePool *pool;
    LibspectrumMetadataImporter *mdi;

    /* Don't assume that there is an autorelease pool around the calling of this function. */
    pool = [[NSAutoreleasePool alloc] init];

    mdi = [[[LibspectrumMetadataImporter alloc] initWithFilename:(NSString*)pathToFile
						   andAttributes:(NSMutableDictionary*)attributes] autorelease];

    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    error = [mdi processFile];
	
    [pool release];
	
    return error;
}