/* GeneratePreviewForURL.m: Extract preview from libspectrum-supported Spectrum files
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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <QuickLook/QLGenerator.h>

#import "JWSpectrumScreen/JWSpectrumScreen.h"
#import "LibspectrumSCRExtractor.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
  NSAutoreleasePool *pool;
  LibspectrumSCRExtractor *speccyFile;

  /* Don't assume that there is an autorelease pool around the calling of
     this function. */
  pool = [[NSAutoreleasePool alloc] init];

  speccyFile = [[[LibspectrumSCRExtractor alloc]
                  initWithContentsOfURL:(NSURL*)url] autorelease];

  /* No preview for tapes, these are going to have inlays etc. which are more
     like album art in mp3s than file previews IMO */
  if( [speccyFile class] == LIBSPECTRUM_CLASS_TAPE ) {
    [pool release];
    return noErr;
  }

  switch( [speccyFile image_type] ) {
  case TYPE_SCR:
    {
      JWSpectrumScreen* screen =
        [[[JWSpectrumScreen alloc] initFromData:[speccyFile scrData]
                                        mltHint:[speccyFile type] == LIBSPECTRUM_ID_SCREEN_MLT]
            autorelease];
      NSBitmapImageRep* imageRep = [[screen imageRep] retain];
      NSSize canvasSize = [screen canvasSize];
              
      CGContextRef cgContext =
        QLPreviewRequestCreateContext( preview, *(CGSize *)&canvasSize,
                                       false, NULL );
      if( cgContext ) {
        NSGraphicsContext* context =
          [NSGraphicsContext graphicsContextWithGraphicsPort:(void*)cgContext
                                                     flipped:YES];
        if(context) {
          [NSGraphicsContext saveGraphicsState]; 
          [NSGraphicsContext setCurrentContext:context];
          
          /* Now we're ready to draw using Cocoa. */
          NSImage* image =
            [[[NSImage alloc] initWithSize:canvasSize] autorelease];
          [image addRepresentation:imageRep];
          NSRect imageRect = NSMakeRect( 0.0, 0.0, canvasSize.width,
                                         canvasSize.height );
          [image drawAtPoint:NSMakePoint(0.0, 0.0)
                    fromRect:imageRect
                   operation:NSCompositeSourceOver
                    fraction:1.0];
          [NSGraphicsContext restoreGraphicsState];
        }
        QLPreviewRequestFlushContext(preview, cgContext);
        CFRelease(cgContext);
      }
      
      [imageRep release];
    }
    break;
  case TYPE_IMAGEIO:
    QLPreviewRequestSetDataRepresentation( preview,
                                           (CFDataRef)[speccyFile scrData],
                                           kUTTypeImage,
                                           NULL );
    break;
  default:
    break;
  }
 
  [pool release];

  return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
