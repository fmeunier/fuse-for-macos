/* DisplayOverlayState.h: Renderer-neutral display overlay state
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#ifndef FUSE_DISPLAY_OVERLAY_STATE_H
#define FUSE_DISPLAY_OVERLAY_STATE_H

typedef enum {
  DISPLAY_OVERLAY_STATE_NOT_AVAILABLE,
  DISPLAY_OVERLAY_STATE_INACTIVE,
  DISPLAY_OVERLAY_STATE_ACTIVE,
} DisplayOverlayItemState;

typedef struct {
  DisplayOverlayItemState disk_state;
  DisplayOverlayItemState microdrive_state;
  DisplayOverlayItemState tape_state;
} DisplayOverlayState;

#endif
