//
//  Googol_MotionIO.h
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/6/16.
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "Constants.h"
#import "Googol_TCPIP.h"
#import "TestInfoController.h"
#import "Macro.h"
#import "DataCollctor.h"
@class AppDelegate;

/* Communication protocol
 
 Operation               Command                 Return msg
 ---------               -------                 ----------
 - Home one axis         HOME X#                 HOME X DONE#
 - Goto positon          GOTO X 10.5#            GOTO X 10.5 DONE#
 - Set output signal     GPO 5 0#                GPO 5 0 DONE#
 - Get input status      GPI 5#                  GPI 5 1#
 - Get current position	 GETPOS X#               GETPOS X 199.5#
 - Set Goto Velocity     SETGOTOVEL X 100#       SETGOTOVEL X 20 DONE#
 - Set Home Velocity     SETHOMEVEL 100#         SETHOMEVEL 100 DONE#
 
 Alarm, added for anomaly detection
 - Axis positive limit sensor alarm              PLIMIT 0 1#
 - Axis nagetive limit sensor alarm              NLIMIT 2 1#
 - Axis alarm                                    PLIMIT 0 1#
 */


#define MACBOOK_MESA      //define it when macbook project

#ifdef MACBOOK_MESA

/* ----------For mesa mac macbooK---------------- */
#define EXT_IO_OFFSET                   16

// should be undefine and redefine in app delegate
#define DO_Z1_FORCE_CLEAR   0 //Active-High
#define DO_Z2_FORCE_CLEAR   1 //Active-High
#define DO_Z1_BRAKE         2 //Active-Low, so 0 the brake will on
#define DO_Z2_BRAKE         3 //Active-Low, so 0 the brake will on
#define DO_SIGNAL_RED       4 //Active-High
#define DO_SIGNAL_GREEN     5 //Active-High
#define DO_SIGNAL_YELLOW    6//Active-High
#define DO_ION_FAN          8 //Active-High

#define DO_BOTTOM_VACUUM                9
#define DO_TOP_VACUUM                   10
#define DO_BOTTOM_ANTI_VACUUM           11
#define DO_TOP_ANTI_VACUUM              12
#define DO_USB_CYLINDER                 7
#define DO_FRONT_LED                    13
#define DO_DOOR_LOCK                    14

//



//Matthew 2023-08-28  Add Cylinder Io






 
#define DO_SHORT_CYLINDER_ON              16 //短边气缸伸出
#define DO_LONG_CYLINDER_ON               17  //长气缸伸出 (左&右长气缸伸出)
#define DO_SHORT_CYLINDER_OFF             18  //短边气缸已松开
#define DO_LONG_CYLINDER_OFF              19  //长边气缸已松开


#define DI_SHORT_CYLINDER_INITIAl              19 //短边气缸初始位
#define DI_SHORT_CYLINDER_WORK              20  //短边气缸工作位
#define DI_LEFT_LONG_CYLINDER_INITIAl               21  //左长边气缸初始位
#define DI_LEFT_LONG_CYLINDER_WORK             22  //左长边气缸工作位
#define DI_RIGTH_LONG_CYLINDER_INITIAl               23  //右长边气缸初始位
#define DI_RIGTH_LONG_CYLINDER_WORK             24  //右长边气缸工作位

//end by Matthew


//pin 7-15 are OK
#define DI_BOTTOM_VACUUM_WARNING        7
#define DI_TOP_VACUUM_WARNING           8
#define DI_FRONT_DOOR                   17
#define DI_FRONT_DOOR_LOCKED            10
#define DI_OVERRIDE_KEY                 18

#define DI_USB_CYLINDER_FRONT_LIMIT     11
#define DI_USB_CYLINDER_BACK_LIMIT      12
#define DI_MB_TOP_TOUCH_1               13
#define DI_MB_TOP_TOUCH_2               14
#define DI_MB_BOTTOM_TOUCH_1            15
#define DI_MB_BOTTOM_TOUCH_2            16

// should be undefine and redefine in app delegate
#define DI_ESTOP            0
#define DI_RESET            1
#define DI_START_LEFT       2
#define DI_START_RIGHT      3
#define DI_POWER            9
#define DI_DOOR             4
#define DI_Z1_WARNING       5
#define DI_Z2_WARNING       6
#define DI_FOR_PING         30


/* ---------For mesa mac macbook END------------------ */
#else
/* ---------For mesa mac iphone------------------------*/
//Z1 left; Z2 right
#define DO_Z1_FORCE_CLEAR   1 //Active-High
#define DO_Z2_FORCE_CLEAR   2 //Active-High
#define DO_ION_FAN          4 //Active-High
#define DO_Z1_BRAKE         5 //Active-Low, so 0 the brake will on
#define DO_Z2_BRAKE         6 //Active-Low, so 0 the brake will on
#define DO_SIGNAL_RED       8 //Active-High
#define DO_SIGNAL_GREEN     9 //Active-High
#define DO_SIGNAL_YELLOW    10//Active-High
//Deprecated:
//#define DO_HOME_STATUS 3    //Active-High

#define DI_ESTOP 1
#define DI_RESET 2
#define DI_START_LEFT 3
#define DI_START_RIGHT 4
#define DI_POWER 5
#define DI_DOOR 6
#define DI_Z1_WARNING 7
#define DI_Z2_WARNING 8

#define DO_LEFT_CYLINDER                71
#define DO_BACK_CYLINDER                72
#define DO_BOTTOM_VACUUM                73
#define DO_TOP_VACUUM                   74
#define DO_BOTTOM_ANTI_VACUUM           75
#define DO_TOP_ANTI_VACUUM              76
#define DO_USB_CYLINDER                 77
#define DO_DOOR_CYLINDER                78
#define DO_FRONT_DOOR_LOCK              79
#define DI_BOTTOM_VACUUM_WARNING        80
#define DI_TOP_VACUUM_WARNING           81
#define DI_FRONT_DOOR_1                 82
#define DI_FRONT_DOOR_2                 83
#define DI_LEFT_CYLINDER_FRONT_LIMIT    84
#define DI_LEFT_CYLINDER_BACK_LIMIT     85
#define DI_BACK_CYLINDER_FRONT_LIMIT    86
#define DI_BACK_CYLINDER_BACK_LIMIT     87
#define DI_USB_CYLINDER_FRONT_LIMIT     88
#define DI_USB_CYLINDER_BACK_LIMIT      89
#define DI_DOOR_CYLINDER_UP_LIMIT       90
#define DI_DOOR_CYLINDER_DOWN_LIMIT     91
#define DI_MB_TOP_TOUCH_1               92
#define DI_MB_TOP_TOUCH_2               93
#define DI_MB_TOP_TOUCH_3               94
#define DI_MB_TOP_TOUCH_4               95
#define DI_MB_BOTTOM_TOUCH_1            96
#define DI_MB_BOTTOM_TOUCH_2            97
#define DI_MB_BOTTOM_TOUCH_3            98
#define DI_MB_BOTTOM_TOUCH_4            99
#define DI_FRONT_DOOR                   70
/* ---------For mesa mac iphone END-------------------*/
#endif


#define IO_OFF 0
#define IO_ON 1

#define INPUT 1
#define OUTPUT 0

#define AXIS_X  1
#define AXIS_Y  2
#define AXIS_Z1 3
#define AXIS_Z2 4

#define MAX_RETRY_TIME 10
#define TIMEOUT_TOLERANCE 3

@interface Googol_MotionIO : NSObject

@property (strong) NSMutableDictionary *motionParams;
@property (strong) Googol_TCPIP *tcpip;
@property NSString *cmdBuffer;

@property NSLock *getForce1Lock;
@property NSLock *getForce2Lock;

//Axis
@property NSArray *axes;
/**
 *  Indicate the moving status of each axis. true means the axis is moving
 */
@property NSMutableArray *axesMoveStatus;

//Motion home & move velocity
@property (assign) float homeVelocity;
@property (assign) float xVelocity;
@property (assign) float yVelocity;
@property (assign) float z1Velocity;
@property (assign) float z2Velocity;
//Force
@property (assign) float z1Tolerance;
@property (assign) float z2Tolerance;
// Current values
@property (atomic) NSMutableArray *axesPosition;
//Alarm
@property bitData axesAlarm;
@property bitData axesPositiveLimit;
@property bitData axesNegativeLimit;

@property (atomic,assign) float z1Force;
@property (atomic,assign) float z2Force;

//Timeout
@property int timeoutCount;
@property NSTimer *runloopTimer;
@property BOOL timeOut;
- (void)timerReset;

//Singleton
+(Googol_MotionIO *)sharedMyClass;

- (void)open:(NSDictionary *)config withApp:(AppDelegate *)app;
- (void)close;
- (void)processResponse:(NSDictionary *)dict;
- (bool)getSignal:(bool)isInput portStatus:(int)port;

//Command with Googol
- (bool)compareCurrentPosWithHomePos;
- (bool)enableAxis : (bool)checkHbbClear;
- (void)disableAxis;
- (void)goHome:(int)axis;
- (void)goTo:(int)axis withPosition:(float)position;
- (void)waitMotor:(int)axis;
- (float)getPosition:(int)axis;
- (float)getForce:(int)axis;
- (void)setOutput:(int)port toState:(int)state;
- (int)getInput:(int)port;
- (void)setGoHomeVelocity:(float)velocity;
- (void)setGotoVelocity:(int)axis withVelocity:(float)velocity;

- (void)goHome:(int)axis inMsgMode:(bool)isMsgMode;
//- (void)stopAxis:(int)axis;
- (void)stopAxis:(int)axis isOriginalStop_Z:(bool)forceStopZ;
- (bool)pingGoogol;

//- (void)goTo:(int)axis withPosition:(float)position inMsgMode:(bool)isMsgMode;
//- (void)waitMotor:(int)axis inMsgMode:(bool)isMsgMode;
//- (float)getPosition:(int)axis inMsgMode:(bool)isMsgMode;
//- (float)getForce:(int)axis inMsgMode:(bool)isMsgMode;
//- (void)setOutput:(int)port toState:(int)state inMsgMode:(bool)isMsgMode;
@end

//- (void)runLoopHandler;
