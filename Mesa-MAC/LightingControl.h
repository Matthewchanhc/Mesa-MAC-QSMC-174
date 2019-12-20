//
//  SerialControl.h
//  EagleEye
//
//  Created by Antonio Yu on 13/12/13.
//  Copyright (c) 2013 Antonio Yu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "ORSSerialPort.h"
#import "ORSSerialPortManager.h"

@class IOControl;
@class AppDelegate;

@interface LightingControl : NSObject <ORSSerialPortDelegate>

@property (strong) ORSSerialPort *rs232;
@property (strong) AppDelegate *app;
@property (readonly) bool isOn;
@property int brightness;

- (void)openPort;
- (void)closePort;

- (void)setBrightness:(int)brightness;

-(void)lightOn;
-(void)lightOnWithBrightness:(int)brightness;
-(void)lightOff;
-(void)lightSwitch;
@end
