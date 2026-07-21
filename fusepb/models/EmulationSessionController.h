/* EmulationSessionController.h: App-facing emulation session façade
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import <Cocoa/Cocoa.h>

#include <libspectrum.h>

#include "ui/ui.h"

@class DisplayOpenGLView;
@class Emulator;

@interface EmulationSessionController : NSObject
{
  Emulator *real_emulator;
  Emulator *proxy_emulator;
  NSConnection *kit_connection;
  DisplayOpenGLView *display_view;
}

+(EmulationSessionController *) instance;

-(void) startWithDisplayView:(DisplayOpenGLView *)view;
-(void) stop;
-(void) setServer:(Emulator *)server;
-(int) checkMediaChanged;
-(void) setEmulationHz:(float)hz;

-(void) openFile:(const char *)filename;
-(void) snapOpen:(const char *)filename;
-(void) tapeOpen:(const char *)filename;
-(void) tapeWrite:(const char *)filename;
-(void) tapeTogglePlay;
-(void) tapeToggleRecord;
-(void) tapeRewind;
-(void) tapeClear;
-(void) tapeWindowInitialise;
-(void) cocoaBreak;
-(void) pause;
-(void) unpause;
-(void) reset;
-(void) hard_reset;
-(void) nmi;

-(void) diskInsertNew:(int)which;
-(void) diskInsert:(const char *)filename inDrive:(int)which;
-(void) diskEject:(int)drive;
-(void) diskSave:(int)drive saveAs:(bool)saveas;
-(void) diskFlip:(int)drive side:(int)flip;
-(void) diskWriteProtect:(int)which protect:(int)write;

-(void) snapshotWrite:(const char *)filename;
-(void) screenshotScrRead:(const char *)filename;
-(void) screenshotScrWrite:(const char *)filename;
-(void) screenshotWrite:(const char *)filename;
-(void) profileStart;
-(void) profileFinish:(const char *)filename;
-(void) settingsSave;
-(void) settingsResetDefaults;
-(void) fullscreen;
-(void) joystickToggleKeyboard;
-(void) keyboardToggleRecreatedZXSpectrum;
-(void) keyboardToggleArrowsShifted;

-(void) rzxInsertSnap;
-(void) rzxRollback;
-(void) rzxStop;
-(void) if1MdrNew:(int)drive;
-(void) if1MdrInsert:(const char *)filename inDrive:(int)drive;
-(void) if1MdrCartEject:(int)drive;
-(void) if1MdrCartSave:(int)drive saveAs:(bool)saveas;
-(void) if1MdrWriteProtect:(int)w inDrive:(int)drive;
-(void) if2Eject;
-(void) dckEject;
-(void) psgStart:(const char *)psgfile;
-(void) psgStop;
-(void) movieStartRecording:(const char *)filename;
-(void) movieTogglePause;
-(void) movieStop;
-(void) didaktik80Snap;
-(void) multifaceRedButton;

-(int) tapeClose;
-(int) diskWrite:(int)drive saveAs:(bool)saveas;
-(int) rzxStartPlayback:(const char *)filename;
-(int) rzxStartRecording:(const char *)filename embedSnapshot:(int)flag;
-(int) rzxContinueRecording:(const char *)filename;
-(int) rzxFinaliseRecording:(const char *)filename;
-(int) if2Insert:(const char *)filename;
-(int) dckInsert:(const char *)filename;
-(int) simpleideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit;
-(int) simpleideCommit:(libspectrum_ide_unit)unit;
-(int) simpleideEject:(libspectrum_ide_unit)unit;
-(int) zxataspInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit;
-(int) zxataspCommit:(libspectrum_ide_unit)unit;
-(int) zxataspEject:(libspectrum_ide_unit)unit;
-(int) zxcfInsert:(const char *)filename;
-(int) zxcfCommit;
-(int) zxcfEject;
-(int) divideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit;
-(int) divideCommit:(libspectrum_ide_unit)unit;
-(int) divideEject:(libspectrum_ide_unit)unit;
-(int) divmmcInsert:(const char *)filename;
-(int) divmmcCommit;
-(int) divmmcEject;
-(int) zxmmcInsert:(const char *)filename;
-(int) zxmmcCommit;
-(int) zxmmcEject;

-(void) mouseMoved:(NSEvent *)event;
-(void) mouseDown:(NSEvent *)event;
-(void) mouseUp:(NSEvent *)event;
-(void) rightMouseDown:(NSEvent *)event;
-(void) rightMouseUp:(NSEvent *)event;
-(void) otherMouseDown:(NSEvent *)event;
-(void) otherMouseUp:(NSEvent *)event;
-(void) flagsChanged:(NSEvent *)event;
-(void) keyDown:(NSEvent *)event;
-(void) keyUp:(NSEvent *)event;
-(void) keyboardReleaseAll;

-(void) setDiskState:(NSNumber *)state;
-(void) setTapeState:(NSNumber *)state;
-(void) setMdrState:(NSNumber *)state;
-(ui_confirm_save_t) confirmSave:(NSString *)message;
-(int) confirm:(NSString *)message;
-(int) tapeWrite;
-(int) if1MdrWrite:(int)which saveAs:(bool)saveas;
-(ui_confirm_joystick_t) confirmJoystick:(libspectrum_joystick)type inputs:(int)inputs;
-(void) debuggerActivate;

@end
