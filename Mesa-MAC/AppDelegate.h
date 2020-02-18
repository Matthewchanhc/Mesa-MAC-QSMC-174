//
//  AppDelegate.h
//  Mesa-MAC
//
//  Created by Antonio Yu on 26/9/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//
//Cam Defualt using GigE
//#define GigECam
//#define FireWireCam

//#ifdef GigECam
#import "GigECamera.h"
//#undef FireWireCam
//#endif
//
//#ifdef FireWireCam
//#import "FirewireCamera.h"
//#undef GigECam
//#endif

#import <Cocoa/Cocoa.h>
#import "Constants.h"

#import "Util.h"
#import "Calibration.h"
#import "LightingControl.h"
#import "ORSSerialPort.h"
#import "Macro.h"
#import "CalibrationMacBook.h"

#import "DataCollctor.h"
#import "FastSocket.h"
#import "FastServerSocket.h"

@class Googol_MotionIO;

extern bool STOPTEST;
extern bool CALIBRATION;
extern bool IMAGESAVING;
extern bool isMacbook;
extern bool is2ChannelsController;
extern bool RECORD_PROCESSING_TIME;

@interface AppDelegate : NSObject <ORSSerialPortDelegate, NSApplicationDelegate>

#pragma mark - System para
@property NSThread *workThread;
@property bool sysInitFin;
@property bool startTest;

@property bool prevIsGoogolAlive;

//@property NSThread *updateThread;

@property NSThread *statusThread;

@property (strong) NSNumberFormatter *formatter;

@property (assign) float ratio;

@property (strong) NSTimer *statusTimer;

@property WorkFlag workFlag;
@property NSLock *lock;

@property bool isReadyForTest;
@property bool prevBotVac;
@property bool isInterruptDutRelease;
@property bool isDutReleasing;
@property bool prevOverrideKey;

@property bool homing;
@property bool setupOpen;
@property bool probeDowning;

@property DataCollctor *spiderman;

@property BOOL isRunningTest;
@property NSThread *testThread;
@property BOOL startFlag;
@property BOOL resetFlag;
@property bitData axesAlarmOn;
@property bitData positiveLimitOn;
@property bitData negativeLimitOn;

@property int cleancount;

@property (assign) int pingCamCycle;
@property (assign) int pingCamCount;

// below property for macbook version only
@property int macbookCount;

#pragma mark - Warning flag
@property int problemFlag;
@property BOOL powerFlag;
@property NSArray *axesAlarmFlag;
@property NSArray *axesPositveFlag;
@property NSArray *axesNegatveFlag;
@property BOOL force1Flag;
@property BOOL force2Flag;
@property BOOL doorFlag;
#pragma mark -

#pragma mark - RS232 para
//RS232 delegate
@property (strong) LightingControl *light232;
@property (strong) ORSSerialPort *mesaSerialPort;
@property NSMutableString *commandBuffer;
//motion delegate
@property (strong) Googol_MotionIO *motion;
//camera config
//#ifdef FireWireCam
//@property (strong) FirewireCamera *camera;
//#endif
//#ifdef GigECam
@property (strong) GigECamera *camera;
//#endif
@property (strong) NSString *cameraName;
@property (assign) long cameraID;
@property (assign) long triggerMode;

//capture image
@property (weak) IBOutlet IKImageView *cameraIKView;
@property (weak) IBOutlet NSImageView *cameraNSView;
@property (weak) IBOutlet NSImageView *metronNSView;

//cal delegate
@property (strong) Calibration *config_window;
@property (strong) CalibrationMacBook *config_window_macbook;
//msg center
@property (unsafe_unretained) IBOutlet NSTextView *msgBox;

#pragma mark - MESA Status flag
@property bool isCaptureFinish;
@property bool isAtHomePosition;
@property bool isAtLeftRightPosition;
@property MESARS232ZStatus zProbeStatus;
@property MESARS232ProbeStatus myProbeStatus;
@property bool isCleaningFinish;
@property bool isReleaseDutFinish;
//@property BOOL holderAtPPosition;
//cal page para for x404
@property bool isToChangeValue;
@property MESARS232ProbeMovementLength stepLength;
@property bool isPositiveDirection;
@property int movementDistance;

#pragma mark - Para from plist
//setting plist
@property (strong) NSMutableDictionary *configDictionary;
@property (strong) NSMutableDictionary *settingsDictionary;
//capture position
@property (assign) float posCameraX;
@property (assign) float posCameraY;
@property (assign) float posCameraCX;
@property (assign) float posCameraCY;
//left probe test position
@property (assign) float posProbe1X;
@property (assign) float posProbe1Y;
@property (assign) float posProbe1Conn;
@property (assign) float posProbe1Hover;
//right probe test position
@property (assign) float posProbe2X;
@property (assign) float posProbe2Y;
@property (assign) float posProbe2Conn;
@property (assign) float posProbe2Hover;
//cleaning position
@property (assign) float posCleanX;
@property (assign) float posCleanY;
@property (assign) float posCleanZ1;
@property (assign) float posCleanZ2;
@property (assign) int cleaningCycle;
@property (assign) float cleaningGap;
//MESA system para
@property (assign) float pressureLeft;
@property (assign) float pressureRight;
@property (assign) int fixtureID;
@property (assign) int testerID;
@property (assign) NSString *softwareID;
@property (assign) bool useMessagePort;
@property (assign) bool useSocketPort;
@property (assign) int socketPort;
@property (assign) float dutY;
@property (assign) float pidP;
@property (assign) float pidD;
@property (assign) int brightness;
@property (assign) int brightness2;


#pragma mark - System Method
- (NSString *)formatNumberToString :(float)input;
-(void)paraRefresh;

#pragma mark - GUI Method
@property (weak) IBOutlet NSButton *stressTest;
@property (weak) IBOutlet NSButton *stop;
@property (weak) IBOutlet NSButton *setup;
@property NSTimer *pingCamTimer;
@property NSTimer *pingMotionTimer;
- (IBAction)clickStart:(id)sender;
- (IBAction)clickStop:(id)sender;
//- (IBAction)clickSetup:(id)sender;
-(void)clickSetup;
- (IBAction)clickQuit:(id)sender;
- (void)showMessage:(NSString *)msg inColor:(NSColor*)textColor;
- (NSString *)inputPassword:(NSString *)prompt;
- (void) closeAppWithSaveLog;

#pragma mark - Work Method
-(bool)macbookSafetyCheck;
-(bool)macbookReleaseWithCleanning : (bool)isCountCleanning;
-(void)macbookCleanProbe;
-(void)goToCamPositionWithDisplay:(NSImageView *)cameraView;
-(void)goToLeftProbePosition;
-(void)goToRightProbePosition;
-(void)goToTopProbePosition;
-(void)goToConnProbePosition;
-(void)goToHoverProbePosition;
-(void)goToDownProbePosition_V2;
-(void)goToHomePosition;
-(void)goToClean;
-(void)reconnectCamera : (tPvErr)e;

- (void)commandHandler:(NSString *)command;


@property (strong) NSLock* pidLock;

@end
