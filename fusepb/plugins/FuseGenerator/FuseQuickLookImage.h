/* FuseQuickLookImage.h: Shared Quick Look image extraction and rendering
   Copyright (c) 2026 Fredrick Meunier

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
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import <Cocoa/Cocoa.h>

#include <libspectrum.h>

typedef enum FuseQuickLookImageKind {
  FUSE_QUICKLOOK_IMAGE_NONE,
  FUSE_QUICKLOOK_IMAGE_SCR,
  FUSE_QUICKLOOK_IMAGE_IMAGEIO,
} FuseQuickLookImageKind;

@interface FuseQuickLookImage : NSObject

- (id)initWithContentsOfURL:(NSURL*)url;

- (libspectrum_id_t)libspectrumType;
- (libspectrum_class_t)libspectrumClass;
- (FuseQuickLookImageKind)imageKind;

- (NSData*)imageData;
- (NSDictionary*)imageOptions;
- (NSBitmapImageRep*)bitmapImageRep;
- (NSSize)canvasSize;

@end
