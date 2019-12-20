//
//  Calibration.h
//  Mesa-MAC
//
//  Created by Antonio Yu on 16/10/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Googol_MotionIO.h"
@class TestInfoController;

@class AppDelegate;

@interface Calibration : NSWindowController

#pragma mark - System
@property (strong) AppDelegate *app;
@property (strong) NSThread *updateUIThread;
@property bool updateUIThreadRunning;
@property NSLock *actionLock;

@property (strong) NSThread *actionThread;
@property bool actionThreadRunning;
@property int actionFlag;
@property bool actionFinish;

@property (strong) NSThread *testThread;

- (IBAction)clickStressTest:(id)sender;
- (IBAction)clickStressTestStop:(id)sender;
- (NSString *)formatNumberToString :(float)input;
@property (strong) NSNumberFormatter *formatter;
@property (weak) IBOutlet NSButton *stressTest;
@property (weak) IBOutlet NSButton *stressTestStop;
@property bool stressTestEnd;

#pragma mark - Capture Zone
@property (weak) IBOutlet NSImageView *cameraView;

#pragma mark - Top Main Button Zone
- (IBAction)clickSaveConfig:(id)sender;
- (IBAction)clickQuit:(id)sender;

#pragma mark - Axes Moving Zone
@property (weak) IBOutlet NSTextField *gotoOffset;
@property (weak) IBOutlet NSButtonCell *autoSave;
@property (weak) IBOutlet NSButton *xHomeBut;
@property (weak) IBOutlet NSButton *xRightBut;
@property (weak) IBOutlet NSButton *xLeftBut;
@property (weak) IBOutlet NSButton *yHomeBut;
@property (weak) IBOutlet NSButton *yInBut;
@property (weak) IBOutlet NSButton *yOutBut;
@property (weak) IBOutlet NSButton *z1HomeBut;
@property (weak) IBOutlet NSButton *z1UpBut;
@property (weak) IBOutlet NSButton *z1DownBut;
@property (weak) IBOutlet NSButton *z2HomeBut;
@property (weak) IBOutlet NSButton *z2UpBut;
@property (weak) IBOutlet NSButton *z2DownBut;

- (IBAction)clickXHome:(id)sender;
- (IBAction)clickXLeft:(id)sender;
- (IBAction)clickXRight:(id)sender;

- (IBAction)clickYHome:(id)sender;
- (IBAction)clickYIn:(id)sender;
- (IBAction)clickYOut:(id)sender;

- (IBAction)clickZ1Home:(id)sender;
- (IBAction)clickZ1Up:(id)sender;
- (IBAction)clickZ1Down:(id)sender;

- (IBAction)clickZ2Home:(id)sender;
- (IBAction)clickZ2Up:(id)sender;
- (IBAction)clickZ2Down:(id)sender;
- (IBAction)clickAutoSave:(id)sender;

#pragma mark - Parameter Setting Zone
@property (weak) IBOutlet NSTextField *posCameraX;
@property (weak) IBOutlet NSTextField *posCameraY;
@property (weak) IBOutlet NSTextField *posCameraCX;
@property (weak) IBOutlet NSTextField *posCameraCY;

@property (weak) IBOutlet NSTextField *posProbe1X;
@property (weak) IBOutlet NSTextField *posProbe1Y;
@property (weak) IBOutlet NSTextField *posProbe1Conn;
@property (weak) IBOutlet NSTextField *posProbe1Hover;

@property (weak) IBOutlet NSTextField *posProbe2X;
@property (weak) IBOutlet NSTextField *posProbe2Y;
@property (weak) IBOutlet NSTextField *posProbe2Conn;
@property (weak) IBOutlet NSTextField *posProbe2Hover;

@property (weak) IBOutlet NSTextField *posCleanX;
@property (weak) IBOutlet NSTextField *posCleanY;
@property (weak) IBOutlet NSTextField *posCleanZ1;
@property (weak) IBOutlet NSTextField *posCleanZ2;
@property (weak) IBOutlet NSTextField *cleaningCycle;
@property (weak) IBOutlet NSTextField *cleaningGap;

@property (weak) IBOutlet NSTextField *leftPressure;
@property (weak) IBOutlet NSTextField *rightPressure;
@property (weak) IBOutlet NSTextField *fixtureID;
@property (weak) IBOutlet NSTextField *testerID;
@property (weak) IBOutlet NSTextField *softwareID;
@property (weak) IBOutlet NSTextField *dutYPosition;
@property (weak) IBOutlet NSTextField *pidP;
@property (weak) IBOutlet NSTextField *pidD;
@property (weak) IBOutlet NSTextField *brightness;
@property (weak) IBOutlet NSButton *lightSwitch;

- (IBAction)clickSetPosCameraAutoFill:(id)sender;
- (IBAction)clickSetPosCameraSave:(id)sender;

- (IBAction)clickSetPosProbe1AutoFill:(id)sender;
- (IBAction)clickSetPosProbe1Save:(id)sender;

- (IBAction)clickSetPosProbe2AutoFill:(id)sender;
- (IBAction)clickSetPosProbe2Save:(id)sender;

- (IBAction)clickSetCleanAutoFill:(id)sender;
- (IBAction)clickSetCleanSave:(id)sender;

- (IBAction)clickLightSwitch:(id)sender;
- (IBAction)clickSetSystemPara:(id)sender;

#pragma mark - Reading Zone
@property (weak) IBOutlet NSTextField *textCurrentX;
@property (weak) IBOutlet NSTextField *textCurrentY;
@property (weak) IBOutlet NSTextField *textCurrentZ1;
@property (weak) IBOutlet NSTextField *textCurrentZ2;

@property (weak) IBOutlet NSTextField *textForceZ1;
@property (weak) IBOutlet NSTextField *textForceZ2;

#pragma mark - Input Signal Zone
@property (weak) IBOutlet NSColorWell *inEStop;
@property (weak) IBOutlet NSColorWell *inReset;
@property (weak) IBOutlet NSColorWell *inStartLeft;
@property (weak) IBOutlet NSColorWell *inStartRight;
@property (weak) IBOutlet NSColorWell *inPower;
@property (weak) IBOutlet NSColorWell *inDoor;

@property (weak) IBOutlet NSColorWell *inZ1Warning;
@property (weak) IBOutlet NSColorWell *inZ2Warning;

#pragma mark - Output Signal Zone
@property (weak) IBOutlet NSButton *outZ1Clear;
@property (weak) IBOutlet NSButton *outZ2Clear;

@property (weak) IBOutlet NSButton *outZ1Brake;
@property (weak) IBOutlet NSButton *outZ2Brake;

@property (weak) IBOutlet NSButton *outRed;
@property (weak) IBOutlet NSButton *outGreen;
@property (weak) IBOutlet NSButton *outYellow;

- (IBAction)clickOutZ1Clear:(id)sender;
- (IBAction)clickOutZ2Clear:(id)sender;

- (IBAction)clickOutZ1Brake:(id)sender;
- (IBAction)clickOutZ2Brake:(id)sender;

- (IBAction)clickOutRed:(id)sender;
- (IBAction)clickOutGreen:(id)sender;
- (IBAction)clickOutYellow:(id)sender;

#pragma mark - Function Test Zone
@property (weak) IBOutlet NSButton *keepCapture;
@property (weak) IBOutlet NSButton *isTestMode;
@property (weak) IBOutlet NSButton *isSaveImg;
- (IBAction)clickKeepCapture:(id)sender;
- (IBAction)clickTestMode:(id)sender;

- (IBAction)clickProbe1Top:(id)sender;
- (IBAction)clickProbe1Conn:(id)sender;
- (IBAction)clickProbe1Hover:(id)sender;
- (IBAction)clickProbe1Down:(id)sender;

- (IBAction)clickProbe2Top:(id)sender;
- (IBAction)clickProbe2Conn:(id)sender;
- (IBAction)clickProbe2Hover:(id)sender;
- (IBAction)clickProbe2Down:(id)sender;

- (IBAction)clickCapturePosition:(id)sender;
- (IBAction)clickHomePosition:(id)sender;
- (IBAction)clickClean:(id)sender;
- (IBAction)clickStop:(id)sender;

- (IBAction)clickSingleCapture:(id)sender;

@end
