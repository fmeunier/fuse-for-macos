/* EmulationSessionController.m: App-facing emulation session façade
   Copyright (c) 2026 Fredrick Meunier

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "DisplayOpenGLView.h"
#import "EmulationSessionController.h"

@implementation EmulationSessionController

static EmulationSessionController *instance = nil;

+(EmulationSessionController *) instance
{
  if( !instance ) instance = [[self alloc] init];

  return instance;
}

-(void) openFile:(const char *)filename
{
  [[DisplayOpenGLView instance] openFile:filename];
}
-(void) snapOpen:(const char *)filename
{
  [[DisplayOpenGLView instance] snapOpen:filename];
}
-(void) tapeOpen:(const char *)filename
{
  [[DisplayOpenGLView instance] tapeOpen:filename];
}
-(void) tapeWrite:(const char *)filename
{
  [[DisplayOpenGLView instance] tapeWrite:filename];
}
-(void) tapeTogglePlay
{
  [[DisplayOpenGLView instance] tapeTogglePlay];
}
-(void) tapeToggleRecord
{
  [[DisplayOpenGLView instance] tapeToggleRecord];
}
-(void) tapeRewind
{
  [[DisplayOpenGLView instance] tapeRewind];
}
-(void) tapeClear
{
  [[DisplayOpenGLView instance] tapeClear];
}
-(void) tapeWindowInitialise
{
  [[DisplayOpenGLView instance] tapeWindowInitialise];
}
-(void) cocoaBreak
{
  [[DisplayOpenGLView instance] cocoaBreak];
}
-(void) pause
{
  [[DisplayOpenGLView instance] pause];
}
-(void) unpause
{
  [[DisplayOpenGLView instance] unpause];
}
-(void) reset
{
  [[DisplayOpenGLView instance] reset];
}
-(void) hard_reset
{
  [[DisplayOpenGLView instance] hard_reset];
}
-(void) nmi
{
  [[DisplayOpenGLView instance] nmi];
}

-(void) diskInsertNew:(int)which
{
  [[DisplayOpenGLView instance] diskInsertNew:which];
}
-(void) diskInsert:(const char *)filename inDrive:(int)which
{
  [[DisplayOpenGLView instance] diskInsert:filename inDrive:which];
}
-(void) diskEject:(int)drive
{
  [[DisplayOpenGLView instance] diskEject:drive];
}
-(void) diskSave:(int)drive saveAs:(bool)saveas
{
  [[DisplayOpenGLView instance] diskSave:drive saveAs:saveas];
}
-(void) diskFlip:(int)drive side:(int)flip
{
  [[DisplayOpenGLView instance] diskFlip:drive side:flip];
}
-(void) diskWriteProtect:(int)which protect:(int)write
{
  [[DisplayOpenGLView instance] diskWriteProtect:which protect:write];
}

-(void) snapshotWrite:(const char *)filename
{
  [[DisplayOpenGLView instance] snapshotWrite:filename];
}
-(void) screenshotScrRead:(const char *)filename
{
  [[DisplayOpenGLView instance] screenshotScrRead:filename];
}
-(void) screenshotScrWrite:(const char *)filename
{
  [[DisplayOpenGLView instance] screenshotScrWrite:filename];
}
-(void) screenshotWrite:(const char *)filename
{
  [[DisplayOpenGLView instance] screenshotWrite:filename];
}
-(void) profileStart
{
  [[DisplayOpenGLView instance] profileStart];
}
-(void) profileFinish:(const char *)filename
{
  [[DisplayOpenGLView instance] profileFinish:filename];
}
-(void) settingsSave
{
  [[DisplayOpenGLView instance] settingsSave];
}
-(void) settingsResetDefaults
{
  [[DisplayOpenGLView instance] settingsResetDefaults];
}
-(void) fullscreen
{
  [[DisplayOpenGLView instance] fullscreen];
}
-(void) joystickToggleKeyboard
{
  [[DisplayOpenGLView instance] joystickToggleKeyboard];
}
-(void) keyboardToggleRecreatedZXSpectrum
{
  [[DisplayOpenGLView instance] keyboardToggleRecreatedZXSpectrum];
}
-(void) keyboardToggleArrowsShifted
{
  [[DisplayOpenGLView instance] keyboardToggleArrowsShifted];
}

-(void) rzxInsertSnap
{
  [[DisplayOpenGLView instance] rzxInsertSnap];
}
-(void) rzxRollback
{
  [[DisplayOpenGLView instance] rzxRollback];
}
-(void) rzxStop
{
  [[DisplayOpenGLView instance] rzxStop];
}
-(void) if1MdrNew:(int)drive
{
  [[DisplayOpenGLView instance] if1MdrNew:drive];
}
-(void) if1MdrInsert:(const char *)filename inDrive:(int)drive
{
  [[DisplayOpenGLView instance] if1MdrInsert:filename inDrive:drive];
}
-(void) if1MdrCartEject:(int)drive
{
  [[DisplayOpenGLView instance] if1MdrCartEject:drive];
}
-(void) if1MdrCartSave:(int)drive saveAs:(bool)saveas
{
  [[DisplayOpenGLView instance] if1MdrCartSave:drive saveAs:saveas];
}
-(void) if1MdrWriteProtect:(int)w inDrive:(int)drive
{
  [[DisplayOpenGLView instance] if1MdrWriteProtect:w inDrive:drive];
}
-(void) if2Eject
{
  [[DisplayOpenGLView instance] if2Eject];
}
-(void) dckEject
{
  [[DisplayOpenGLView instance] dckEject];
}
-(void) psgStart:(const char *)psgfile
{
  [[DisplayOpenGLView instance] psgStart:psgfile];
}
-(void) psgStop
{
  [[DisplayOpenGLView instance] psgStop];
}
-(void) movieStartRecording:(const char *)filename
{
  [[DisplayOpenGLView instance] movieStartRecording:filename];
}
-(void) movieTogglePause
{
  [[DisplayOpenGLView instance] movieTogglePause];
}
-(void) movieStop
{
  [[DisplayOpenGLView instance] movieStop];
}
-(void) didaktik80Snap
{
  [[DisplayOpenGLView instance] didaktik80Snap];
}
-(void) multifaceRedButton
{
  [[DisplayOpenGLView instance] multifaceRedButton];
}

-(int) tapeClose
{
  return [[DisplayOpenGLView instance] tapeClose];
}
-(int) diskWrite:(int)drive saveAs:(bool)saveas
{
  return [[DisplayOpenGLView instance] diskWrite:drive saveAs:saveas];
}
-(int) rzxStartPlayback:(const char *)filename
{
  return [[DisplayOpenGLView instance] rzxStartPlayback:filename];
}
-(int) rzxStartRecording:(const char *)filename embedSnapshot:(int)flag
{
  return [[DisplayOpenGLView instance] rzxStartRecording:filename embedSnapshot:flag];
}
-(int) rzxContinueRecording:(const char *)filename
{
  return [[DisplayOpenGLView instance] rzxContinueRecording:filename];
}
-(int) rzxFinaliseRecording:(const char *)filename
{
  return [[DisplayOpenGLView instance] rzxFinaliseRecording:filename];
}
-(int) if2Insert:(const char *)filename
{
  return [[DisplayOpenGLView instance] if2Insert:filename];
}
-(int) dckInsert:(const char *)filename
{
  return [[DisplayOpenGLView instance] dckInsert:filename];
}
-(int) simpleideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] simpleideInsert:filename inUnit:unit];
}
-(int) simpleideCommit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] simpleideCommit:unit];
}
-(int) simpleideEject:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] simpleideEject:unit];
}
-(int) zxataspInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] zxataspInsert:filename inUnit:unit];
}
-(int) zxataspCommit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] zxataspCommit:unit];
}
-(int) zxataspEject:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] zxataspEject:unit];
}
-(int) zxcfInsert:(const char *)filename
{
  return [[DisplayOpenGLView instance] zxcfInsert:filename];
}
-(int) zxcfCommit
{
  return [[DisplayOpenGLView instance] zxcfCommit];
}
-(int) zxcfEject
{
  return [[DisplayOpenGLView instance] zxcfEject];
}
-(int) divideInsert:(const char *)filename inUnit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] divideInsert:filename inUnit:unit];
}
-(int) divideCommit:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] divideCommit:unit];
}
-(int) divideEject:(libspectrum_ide_unit)unit
{
  return [[DisplayOpenGLView instance] divideEject:unit];
}
-(int) divmmcInsert:(const char *)filename
{
  return [[DisplayOpenGLView instance] divmmcInsert:filename];
}
-(int) divmmcCommit
{
  return [[DisplayOpenGLView instance] divmmcCommit];
}
-(int) divmmcEject
{
  return [[DisplayOpenGLView instance] divmmcEject];
}
-(int) zxmmcInsert:(const char *)filename
{
  return [[DisplayOpenGLView instance] zxmmcInsert:filename];
}
-(int) zxmmcCommit
{
  return [[DisplayOpenGLView instance] zxmmcCommit];
}
-(int) zxmmcEject
{
  return [[DisplayOpenGLView instance] zxmmcEject];
}

@end
