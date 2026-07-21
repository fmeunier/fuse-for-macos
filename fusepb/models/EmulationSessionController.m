/* EmulationSessionController.m: App-facing emulation session façade
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "DebuggerController.h"
#import "Emulator.h"
#import "EmulationSessionController.h"
#import "FuseController.h"

@implementation EmulationSessionController

static EmulationSessionController *instance = nil;

static DisplayOverlayItemState
overlay_item_state( ui_statusbar_state state )
{
  switch( state ) {
  case UI_STATUSBAR_STATE_ACTIVE:
    return DISPLAY_OVERLAY_STATE_ACTIVE;
  case UI_STATUSBAR_STATE_INACTIVE:
    return DISPLAY_OVERLAY_STATE_INACTIVE;
  case UI_STATUSBAR_STATE_NOT_AVAILABLE:
  default:
    return DISPLAY_OVERLAY_STATE_NOT_AVAILABLE;
  }
}

+(EmulationSessionController *) instance
{
  if( !instance ) instance = [[self alloc] init];

  return instance;
}

-(void) startWithDisplayPresenter:(id <DisplayPresenting>)presenter
{
  NSPort *port1;
  NSPort *port2;
  NSArray *portArray;

  display_presenter = presenter;
  overlay_state.disk_state = DISPLAY_OVERLAY_STATE_NOT_AVAILABLE;
  overlay_state.microdrive_state = DISPLAY_OVERLAY_STATE_NOT_AVAILABLE;
  overlay_state.tape_state = DISPLAY_OVERLAY_STATE_NOT_AVAILABLE;
  if( real_emulator ) return;

  real_emulator = [[Emulator alloc] init];

  port1 = [NSPort port];
  port2 = [NSPort port];

  kit_connection = [[NSConnection alloc] initWithReceivePort:port1
                                                     sendPort:port2];
  [kit_connection setRootObject:self];
  [kit_connection enableMultipleThreads];

  portArray = @[port2, port1];
  [NSThread detachNewThreadSelector:@selector(connectWithPorts:)
                           toTarget:real_emulator withObject:portArray];
}

-(void) applyFramebufferWithValue:(NSValue *)framebuffer_value
{
  [display_presenter applyFramebuffer:[framebuffer_value pointerValue]];
}

-(void) removeFramebuffer
{
  [display_presenter removeFramebuffer];
}

-(void) stop
{
  [display_presenter shutdown];
  [proxy_emulator stop];
  [proxy_emulator release];
  proxy_emulator = nil;
  [real_emulator release];
  real_emulator = nil;
  [kit_connection release];
  kit_connection = nil;
  display_presenter = nil;
}

-(void) setServer:(Emulator *)server
{
  proxy_emulator = [server retain];
}

-(int) checkMediaChanged
{
  return [proxy_emulator checkMediaChanged];
}

-(void) setEmulationHz:(float)hz
{
  [proxy_emulator setEmulationHz:hz];
}

-(void) openFile:(const char *)filename
{
  [proxy_emulator openFile:filename];
}
-(void) snapOpen:(const char *)filename
{
  [proxy_emulator snapOpen:filename];
}
-(void) tapeOpen:(const char *)filename
{
  [proxy_emulator tapeOpen:filename];
}
-(void) tapeWrite:(const char *)filename
{
  [proxy_emulator tapeWrite:filename];
}
-(void) tapeTogglePlay
{
  [proxy_emulator tapeTogglePlay];
}
-(void) tapeToggleRecord
{
  [proxy_emulator tapeToggleRecord];
}
-(void) tapeRewind
{
  [proxy_emulator tapeRewind];
}
-(void) tapeClear
{
  [proxy_emulator tapeClear];
}
-(void) tapeWindowInitialise
{
  [proxy_emulator tapeWindowInitialise];
}
-(void) cocoaBreak
{
  [proxy_emulator cocoaBreak];
}
-(void) pause
{
  [proxy_emulator pause];
}
-(void) unpause
{
  [proxy_emulator unpause];
}
-(void) reset
{
  [proxy_emulator reset];
}
-(void) hard_reset
{
  [proxy_emulator hard_reset];
}
-(void) nmi
{
  [proxy_emulator nmi];
}

-(void) diskInsertNew:(int)which
{
  [proxy_emulator diskInsertNew:which];
}
-(void) diskInsert:(const char *)filename inDrive:(int)which
{
  [proxy_emulator diskInsert:filename inDrive:which];
}
-(void) diskEject:(int)drive
{
  [proxy_emulator diskEject:drive];
}
-(void) diskSave:(int)drive saveAs:(bool)saveas
{
  [proxy_emulator diskSave:drive saveAs:saveas];
}
-(void) diskFlip:(int)drive side:(int)flip
{
  [proxy_emulator diskFlip:drive side:flip];
}
-(void) diskWriteProtect:(int)which protect:(int)write
{
  [proxy_emulator diskWriteProtect:which protect:write];
}

-(void) snapshotWrite:(const char *)filename
{
  [proxy_emulator snapshotWrite:filename];
}
-(void) screenshotScrRead:(const char *)filename
{
  [proxy_emulator screenshotScrRead:filename];
}
-(void) screenshotScrWrite:(const char *)filename
{
  [proxy_emulator screenshotScrWrite:filename];
}
-(void) screenshotWrite:(const char *)filename
{
  [proxy_emulator screenshotWrite:filename];
}
-(void) profileStart
{
  [proxy_emulator profileStart];
}
-(void) profileFinish:(const char *)filename
{
  [proxy_emulator profileFinish:filename];
}
-(void) settingsSave
{
  [proxy_emulator settingsSave];
}
-(void) settingsResetDefaults
{
  [proxy_emulator settingsResetDefaults];
}
-(void) fullscreen
{
  [display_presenter performFullscreen];
}
-(void) joystickToggleKeyboard
{
  [proxy_emulator joystickToggleKeyboard];
}
-(void) keyboardToggleRecreatedZXSpectrum
{
  [proxy_emulator keyboardToggleRecreatedZXSpectrum];
}
-(void) keyboardToggleArrowsShifted
{
  [proxy_emulator keyboardToggleArrowsShifted];
}

-(void) rzxInsertSnap
{
  [proxy_emulator rzxInsertSnap];
}
-(void) rzxRollback
{
  [proxy_emulator rzxRollback];
}
-(void) rzxStop
{
  [proxy_emulator rzxStop];
}
-(void) if1MdrNew:(int)drive
{
  [proxy_emulator if1MdrNew:drive];
}
-(void) if1MdrInsert:(const char *)filename inDrive:(int)drive
{
  [proxy_emulator if1MdrInsert:filename inDrive:drive];
}
-(void) if1MdrCartEject:(int)drive
{
  [proxy_emulator if1MdrCartEject:drive];
}
-(void) if1MdrCartSave:(int)drive saveAs:(bool)saveas
{
  [proxy_emulator if1MdrCartSave:drive saveAs:saveas];
}
-(void) if1MdrWriteProtect:(int)w inDrive:(int)drive
{
  [proxy_emulator if1MdrWriteProtect:w inDrive:drive];
}
-(void) if2Eject
{
  [proxy_emulator if2Eject];
}
-(void) dckEject
{
  [proxy_emulator dckEject];
}
-(void) psgStart:(const char *)psgfile
{
  [proxy_emulator psgStart:psgfile];
}
-(void) psgStop
{
  [proxy_emulator psgStop];
}
-(void) movieStartRecording:(const char *)filename
{
  [proxy_emulator movieStartRecording:filename];
}
-(void) movieTogglePause
{
  [proxy_emulator movieTogglePause];
}
-(void) movieStop
{
  [proxy_emulator movieStop];
}
-(void) didaktik80Snap
{
  [proxy_emulator didaktik80Snap];
}
-(void) multifaceRedButton
{
  [proxy_emulator multifaceRedButton];
}

-(int) tapeClose
{
  return [proxy_emulator tapeClose];
}
-(int) diskWrite:(int)drive saveAs:(bool)saveas
{
  return [[FuseController singleton] diskWrite:drive saveAs:saveas];
}
-(int) rzxStartPlayback:(const char *)filename
{
  return [proxy_emulator rzxStartPlayback:filename];
}
-(int) rzxStartRecording:(const char *)filename embedSnapshot:(int)flag
{
  return [proxy_emulator rzxStartRecording:filename embedSnapshot:flag];
}
-(int) rzxContinueRecording:(const char *)filename
{
  return [proxy_emulator rzxContinueRecording:filename];
}
-(int) rzxFinaliseRecording:(const char *)filename
{
  return [proxy_emulator rzxFinaliseRecording:filename];
}
-(int) if2Insert:(const char *)filename
{
  return [proxy_emulator if2Insert:filename];
}
-(int) dckInsert:(const char *)filename
{
  return [proxy_emulator dckInsert:filename];
}
-(int) simpleideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator simpleideInsert:filename inUnit:unit];
}
-(int) simpleideCommit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator simpleideCommit:unit];
}
-(int) simpleideEject:(libspectrum_ide_unit)unit
{
  return [proxy_emulator simpleideEject:unit];
}
-(int) zxataspInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator zxataspInsert:filename inUnit:unit];
}
-(int) zxataspCommit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator zxataspCommit:unit];
}
-(int) zxataspEject:(libspectrum_ide_unit)unit
{
  return [proxy_emulator zxataspEject:unit];
}
-(int) zxcfInsert:(const char *)filename
{
  return [proxy_emulator zxcfInsert:filename];
}
-(int) zxcfCommit
{
  return [proxy_emulator zxcfCommit];
}
-(int) zxcfEject
{
  return [proxy_emulator zxcfEject];
}
-(int) divideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator divideInsert:filename inUnit:unit];
}
-(int) divideCommit:(libspectrum_ide_unit)unit
{
  return [proxy_emulator divideCommit:unit];
}
-(int) divideEject:(libspectrum_ide_unit)unit
{
  return [proxy_emulator divideEject:unit];
}
-(int) divmmcInsert:(const char *)filename
{
  return [proxy_emulator divmmcInsert:filename];
}
-(int) divmmcCommit
{
  return [proxy_emulator divmmcCommit];
}
-(int) divmmcEject
{
  return [proxy_emulator divmmcEject];
}
-(int) zxmmcInsert:(const char *)filename
{
  return [proxy_emulator zxmmcInsert:filename];
}
-(int) zxmmcCommit
{
  return [proxy_emulator zxmmcCommit];
}
-(int) zxmmcEject
{
  return [proxy_emulator zxmmcEject];
}

-(void) mouseMoved:(NSEvent *)event
{
  [proxy_emulator mouseMoved:event];
}

-(void) mouseDown:(NSEvent *)event
{
  [proxy_emulator mouseDown:event];
}

-(void) mouseUp:(NSEvent *)event
{
  [proxy_emulator mouseUp:event];
}

-(void) rightMouseDown:(NSEvent *)event
{
  [proxy_emulator rightMouseDown:event];
}

-(void) rightMouseUp:(NSEvent *)event
{
  [proxy_emulator rightMouseUp:event];
}

-(void) otherMouseDown:(NSEvent *)event
{
  [proxy_emulator otherMouseDown:event];
}

-(void) otherMouseUp:(NSEvent *)event
{
  [proxy_emulator otherMouseUp:event];
}

-(void) flagsChanged:(NSEvent *)event
{
  [proxy_emulator flagsChanged:event];
}

-(void) keyDown:(NSEvent *)event
{
  [proxy_emulator keyDown:event];
}

-(void) keyUp:(NSEvent *)event
{
  [proxy_emulator keyUp:event];
}

-(void) keyboardReleaseAll
{
  [proxy_emulator keyboardReleaseAll];
}

-(void) setDiskState:(NSNumber *)state
{
  overlay_state.disk_state = overlay_item_state( [state unsignedCharValue] );
  [display_presenter applyOverlayState:&overlay_state];
  [[FuseController singleton] setDiskState:state];
}

-(void) setTapeState:(NSNumber *)state
{
  overlay_state.tape_state = overlay_item_state( [state unsignedCharValue] );
  [display_presenter applyOverlayState:&overlay_state];
  [[FuseController singleton] setTapeState:state];
}

-(void) setMdrState:(NSNumber *)state
{
  overlay_state.microdrive_state =
    overlay_item_state( [state unsignedCharValue] );
  [display_presenter applyOverlayState:&overlay_state];
  [[FuseController singleton] setMdrState:state];
}

-(ui_confirm_save_t) confirmSave:(NSString *)message
{
  return [[FuseController singleton] confirmSave:message];
}

-(int) confirm:(NSString *)message
{
  return [[FuseController singleton] confirm:message];
}

-(int) tapeWrite
{
  return [[FuseController singleton] tapeWrite];
}

-(int) if1MdrWrite:(int)which saveAs:(bool)saveas
{
  return [[FuseController singleton] if1MdrWrite:which saveAs:saveas];
}

-(ui_confirm_joystick_t) confirmJoystick:(libspectrum_joystick)type
                                   inputs:(int)inputs
{
  return [[FuseController singleton] confirmJoystick:type inputs:inputs];
}

-(void) debuggerActivate
{
  [[DebuggerController singleton] debugger_activate:nil];
}

@end
