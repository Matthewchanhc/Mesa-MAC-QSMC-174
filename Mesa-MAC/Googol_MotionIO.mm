//
//  Googol_MotionIO.m
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/6/16.
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

#import "Googol_MotionIO.h"

#import "AppDelegate.h"

static Googol_MotionIO *motion = nil;

@interface Googol_MotionIO ()
{
    int homing;//0 as default, 1 is homing, 2 is moving
}

/**
 *  Indicate the target position of each axis for move action.
 */
@property NSMutableArray *axesTargetPosition;

//command flag
/**
 *  Indicate the homing status of each axis. true means the axis is finish homing
 */
@property NSMutableArray *axesHomeStatus;

//IO
@property NSMutableArray *inputSignal;
@property NSMutableArray *outputSignal;

@property BOOL getPositioinFin;
@property BOOL getForceFin;
@property BOOL outputFin;
@property BOOL inputFin;
@property BOOL setGotoVelFin;
@property BOOL setHomeVelFin;
@property BOOL stopFin;

@property AppDelegate *app;

- (void)timeHandler;
- (void)setSignal:(bool)isInput port:(int)port toStatus:(bool)status;

//change comand log to human readable log
- (void)inputPortLog:(int)port state: (int)portState;
- (void)outputPortLog:(int)port state: (int)portState isRequest: (bool)isRequest;

@end

@implementation Googol_MotionIO
//Command Def
NSString * const CMD_GO_HOME = @"HOME %@#\r\n";
NSString * const CMD_GOTO_POS = @"GOTO %@ %.2f#\r\n";
NSString * const CMD_GET_POS = @"GETPOS %@#\r\n";
NSString * const CMD_GET_FORCE = @"GETFORCE %d#\r\n";
NSString * const CMD_SET_OUTPUT = @"GPO %d %d#\r\n";
NSString * const CMD_GET_INPUT = @"GPI %d#\r\n";
NSString * const CMD_SET_GOTO_VEL = @"SETGOTOVEL %@ %.3f#\r\n";
NSString * const CMD_SET_HOME_VEL = @"SETHOMEVEL %.3f#\r\n";
NSString * const CMD_STOP = @"STOP %@#\r\n";
NSString * const CMD_GET_AI = @"GETAI %d#\r\n";
NSString * const CMD_AXIS_ENABLE = @"AXISENABLE %@ 1#\r\n";
NSString * const CMD_AXIS_DISABLE = @"AXISENABLE %@ 0#\r\n";


bool axisEnableFin[4];
bool axisDisableFin[4];
bool allAxisEnableFin;
bool allAxisDisableFin;

#pragma mark - singleton
+(Googol_MotionIO *)sharedMyClass{
    @synchronized(self){
        if (!motion) {
            [[self alloc] init];
        }
    }
    return motion;
}
+(id)allocWithZone:(NSZone *)zone{
    @synchronized(self){
        if (!motion) {
            motion = [super allocWithZone:zone];
            return motion;
        }
    }
    return nil;
}
- (id)copyWithZone:(NSZone *)zone;{
    return self;
}

#pragma mark - System
- (void)processResponse:(NSDictionary *)dict{
    NSString *msg = dict[@"output"];
    if ([TestInfoController isTestMode]) {
        MESALog(@"Process response string: %@", msg);
    }

    _outputFin = true;
    @autoreleasepool {
        if([msg rangeOfString:@"ECHO"].location != NSNotFound)          // Operation completed
        {
            return;
        }
        
        if([msg rangeOfString:@"DONE"].location != NSNotFound)          // Operation completed
        {
            if([msg rangeOfString:@"SETHOMEVEL"].location != NSNotFound)      // SET HOME VEL done
            {
                _setHomeVelFin = true;
                return;
            }
            if([msg rangeOfString:@"SETGOTOVEL"].location != NSNotFound)      // SET GOTO VEL done
            {
                _setGotoVelFin = true;
                return;
            }
            if([msg rangeOfString:@"STOP"].location != NSNotFound){         // STOP axis done
                NSString *axisName = [[msg substringFromIndex:[@"STOP " length]] substringToIndex:1];
                MESALog(@"Stop Axis %@ completed, get its position now.", axisName);
                [self getPosition:(int)[_axes indexOfObject:axisName]];
                _stopFin = true;
                return;
            }
            if([msg rangeOfString:@"HOME"].location != NSNotFound)      // HOME done
            {
                NSString *axis = [[msg substringFromIndex:[@"HOME " length]] substringToIndex:1];
                
                MESALog(@"Axis %@ home completed.", axis);
                
                for(int i=1;i<5;i++)
                {
                    int axisNum;
                    
                    if([axis isEqualToString:[_axes objectAtIndex:i]])
                    {
                        axisNum = i;
                        [_axesHomeStatus setObject:[NSNumber numberWithBool:true] atIndexedSubscript:axisNum];
                        [_axesMoveStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axisNum];
                        break;
                    }
                }
                
                _app.homing = false;
                
                if(_tcpip.isOpened == false)      // Initial startup
                {
                    if([_axesHomeStatus objectAtIndex:AXIS_X] && [_axesHomeStatus objectAtIndex:AXIS_Y] && [_axesHomeStatus objectAtIndex:AXIS_Z1] && [_axesHomeStatus objectAtIndex:AXIS_Z2])
                    {
                        MESALog(@"All axes are home.");
                        
                        _tcpip.isOpened = true;
                    }
                }
            }
            else if([msg rangeOfString:@"AXISENABLE "].location != NSNotFound)     // AXISENABLE done
            {
                NSString *axis = [[msg substringFromIndex:[@"AXISENABLE " length]] substringToIndex:1];
                NSString *mode = [[msg substringFromIndex:13] substringToIndex:1];
                
                int axisNum = 0;
                
                if ([axis isEqual: @"X"]){
                    axisNum = 0;
                }
                else if ([axis isEqual: @"Y"]){
                    axisNum = 1;
                }
                else if ([axis isEqual: @"Z"]){
                    axisNum = 2;
                }
                else if ([axis isEqual: @"A"]){
                    axisNum = 3;
                }
                else if ([axis isEqual: @"T"]){
                    axisNum = -1;
                }
                
                if (axisNum != -1){
                    if ([mode isEqual: @"1"]){
                        axisEnableFin[axisNum] = true;
                        MESALog(@"All AXIS Enable finish");
                    }
                    else if([mode isEqual: @"0"]){
                        axisDisableFin[axisNum] = true;
                        MESALog(@"All AXIS Disable finish");
                    }
                }
                else{
                    if ([mode isEqual: @"1"]){
                        allAxisEnableFin = true;
                        MESALog(@"AXIS Enable finish, axis = %@", axis);
                    }
                    else if([mode isEqual: @"0"]){
                        allAxisDisableFin = true;
                        MESALog(@"AXIS Disable finish, axis = %@", axis);
                    }
                }
            }
            else if([msg rangeOfString:@"GOTO "].location != NSNotFound)     // GOTO done
            {
                NSString *axis = [[msg substringFromIndex:[@"GOTO " length]] substringToIndex:1];
                NSString *tmp = [msg substringFromIndex:7];
                float pos = [[tmp substringToIndex:[tmp rangeOfString:@" DONE#"].location] floatValue];
                
                MESALog(@"Axis %@ goto %f completed.", axis, pos);
                
                for(int i=1;i<5;i++)
                {
                    int axisNum;
                    if([axis isEqualToString:[_axes objectAtIndex:i]])
                    {
                        [_axesPosition setObject:[NSNumber numberWithFloat:pos] atIndexedSubscript:i];
                        axisNum = i;
                        MESALog(@"the pos of %d is %f",axisNum,pos);
                        
//                        if (i>=3) {
//                            [self setOutput:(i==AXIS_Z1?DO_Z1_BRAKE:DO_Z2_BRAKE) toState:IO_OFF];
//                        }
                        [_axesMoveStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axisNum];
                        [_axesTargetPosition setObject:[NSNumber numberWithInt:0] atIndexedSubscript:axisNum];
                        _getPositioinFin = true;
                        break;
                    }
                }
            }
            else if([msg rangeOfString:@"GPO "].location != NSNotFound)    // GPO done
            {
                NSString *tmp = [NSString stringWithString:[msg substringFromIndex:4]];
                int port = [[[msg substringFromIndex:[@"GPO " length]] substringToIndex:[tmp rangeOfString:@" "].location] intValue];
                int value = [[[msg substringFromIndex:[@"GPO " length] + [tmp rangeOfString:@" "].location +1] substringToIndex:1] intValue];
                
                //MESALog(@"Output port %d state = %d.", port, value);
                [self outputPortLog: port state: value isRequest: false]; //replace above MESALog with this method

                
                [self setSignal:OUTPUT port:port toStatus:value];
                
                _outputFin = true;
            }
        }
        else if([msg rangeOfString:@"GETAI "].location != NSNotFound){
            int axis = [[[msg substringFromIndex:[@"GETAI " length]] substringToIndex:1] intValue];
            float value = -999;
            
            NSError *error = NULL;
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"GETAI . [=@]?([+-]?(\\d+(\.\\d*)?|(\.\\d+)))#" options:NSRegularExpressionCaseInsensitive error:&error];
            
            NSArray* matches = [regex matchesInString:msg options:0 range:NSMakeRange(0, [msg length])];
            
            if([matches count] != 0)
            {
                for (NSTextCheckingResult* match in matches) {
                    value = [[msg substringWithRange:[match rangeAtIndex:1]] floatValue];
                }
            } else {
                MESALog(@"Force string %@ format not matched.", msg);
            }
            // End - The retrivel of force value is changed to using Regular Expression, added by Antonio 2016-02-19
            
            if(axis == 1)
            {
                _z1Force = value;
            }
            if(axis == 2)
            {
                _z2Force = value;
            }
            
            _getForceFin = true;

        }
        else if([msg rangeOfString:@"GETFORCE "].location != NSNotFound)
        {

            // The retrivel of force value is changed to using Regular Expression, added by Antonio 2016-02-19
            
/*            int axis = [[[msg substringFromIndex:[@"GETFORCE " length]] substringToIndex:1] intValue];
            int trailerPos = (int)[msg rangeOfString:@"#"].location;
            float value = [[[msg substringFromIndex:[@"GETFORCE " length] + 2] substringToIndex:trailerPos - 3] floatValue];
            
            if(axis == 1)
            {
                _z1Force = value;
            }
            if(axis == 2)
            {
                _z2Force = value;
            }
            
            _getForceFin = true;
 */

            int axis = [[[msg substringFromIndex:[@"GETFORCE " length]] substringToIndex:1] intValue];
            float value = -999;
            
            NSError *error = NULL;
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"GETFORCE . [=@]?([+-]?(\\d+(\.\\d*)?|(\.\\d+)))#" options:NSRegularExpressionCaseInsensitive error:&error];
                
            NSArray* matches = [regex matchesInString:msg options:0 range:NSMakeRange(0, [msg length])];
                
            if([matches count] != 0)
            {
                for (NSTextCheckingResult* match in matches) {
                    value = [[msg substringWithRange:[match rangeAtIndex:1]] floatValue];
                }
            } else {
                MESALog(@"Force string %@ format not matched.", msg);
            }
            // End - The retrivel of force value is changed to using Regular Expression, added by Antonio 2016-02-19
            
            if(axis == 1)
            {
                _z1Force = value;
            }
            if(axis == 2)
            {
                _z2Force = value;
            }
            
            _getForceFin = true;

        }
        else if([msg rangeOfString:@"#"].location != NSNotFound)
        {
            if([msg rangeOfString:@"GPI"].location != NSNotFound)     // Input state changed
            {
                int port = 0;
                int value = 0;
                
                if (isMacbook){
                    port = [[[msg substringFromIndex:[@"GPI " length]] substringToIndex:2] intValue];
                    
                    if (port < 10)
                        value = [[[msg substringFromIndex:[@"GPI " length] + 2] substringToIndex:1] intValue];
                    else
                        value = [[[msg substringFromIndex:[@"GPI " length] + 3] substringToIndex:1] intValue];
                }
                else{
                    port = [[[msg substringFromIndex:[@"GPI " length]] substringToIndex:1] intValue];
                    value = [[[msg substringFromIndex:[@"GPI " length] + 2] substringToIndex:1] intValue];
                }
                
                //MESALog(@"Input port %d state = %d.", port, value);
                [self inputPortLog: port state: value]; //replace above MESALog with this method

                [self setSignal:INPUT port:port toStatus:value];
                
//                if (_app.sysInitFin && (port == DI_START_LEFT||port == DI_START_RIGHT)) {
//                    [self checkTwoStart];
//                    [self checkLighting];
//                }
//                else if (_app.sysInitFin && port == DI_POWER) {
//                    [self checkPower];
//                    [self checkLighting];
//                }
//                else if (_app.sysInitFin && port == DI_RESET) {
//                    [self checkResetButton];
//                    [self checkLighting];
//                }
//                else if (_app.sysInitFin && (port == DI_Z1_WARNING || port == DI_Z2_WARNING)) {
//                    [self checkForceLimit];
//                    [self checkLighting];
//                }

                _inputFin = TRUE;
            }
            else if([msg rangeOfString:@"GETPOS"].location != NSNotFound)
            {
                NSString *axis = [[msg substringFromIndex:[@"GETPOS " length]] substringToIndex:1];
                int trailerPos = (int)[msg rangeOfString:@"#"].location;
                float pos = [[[msg substringFromIndex:[@"GETPOS " length] + 2] substringToIndex:trailerPos - 9] floatValue];
                
                NSLog(@"GETPOS done, axis %@ pos = %f", axis, pos);
                
                [_axesPosition setObject:[NSNumber numberWithFloat:pos] atIndexedSubscript:[_axes indexOfObject:axis]];
                
                _getPositioinFin = true;
            }
            else if([msg rangeOfString:@"PLIMIT"].location != NSNotFound)     // Input state changed
            {
                int pLimit = [[[msg substringFromIndex:[@"PLIMIT " length]] substringToIndex:1] intValue];
                int value = [[[msg substringFromIndex:9] substringToIndex:1] intValue];
                
                MESALog(@"PLIMIT %d state = %d.", pLimit, value);
                
                if((_axesPositiveLimit & (1<<pLimit))&&!value)
                    _axesPositiveLimit = _axesPositiveLimit & (0XFF - (1<<pLimit));
                else if(!(_axesPositiveLimit & (1<<pLimit))&&value)
                    _axesPositiveLimit = _axesPositiveLimit ^ (value<<pLimit);
                
//                if (_app.sysInitFin){
//                    [self checkAxesPositiveLimit];
//                    [self checkLighting];
//                }
                
            }
            else if([msg rangeOfString:@"NLIMIT"].location != NSNotFound)     // Input state changed
            {
                int nLimit = [[[msg substringFromIndex:[@"NLIMIT " length]] substringToIndex:1] intValue];
                int value = [[[msg substringFromIndex:9] substringToIndex:1] intValue];
                
                MESALog(@"NLIMIT %d state = %d.", nLimit, value);
                
                if((_axesNegativeLimit & (1<<nLimit))&&!value)
                    _axesNegativeLimit = _axesNegativeLimit & (0XFF - (1<<nLimit));
                else if(!(_axesNegativeLimit & (1<<nLimit))&&value)
                    _axesNegativeLimit = _axesNegativeLimit ^ (value<<nLimit);
                
//                if (_app.sysInitFin){
//                    [self checkAxesNegativeLimit];
//                    [self checkLighting];
//                }
            }
            else if([msg rangeOfString:@"ALARM"].location != NSNotFound)     // Input state changed
            {
                int alarm = [[[msg substringFromIndex:[@"ALARM " length]] substringToIndex:1] intValue];
                int value = [[[msg substringFromIndex:8] substringToIndex:1] intValue];
                
                MESALog(@"ALARM %d state = %d.", alarm, value);
                
                if((_axesAlarm & (1<<alarm))&&!value)
                    _axesAlarm = _axesAlarm & (0XFF - (1<<alarm));
                else if(!(_axesAlarm & (1<<alarm))&&value)
                    _axesAlarm = _axesAlarm ^ (value<<alarm);
                
//                if (_app.sysInitFin){
//                    [self checkAxesAlarm];
//                    [self checkLighting];
//                }
            }
        }
    }
}

- (void)timeHandler{
    if ([TestInfoController isTestMode]) {
        MESALog(@"timeout happen!!!");
    }
    _timeOut = YES;
    [self timerReset];
}
- (void)timerReset{
    _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:5000000];
    if ([TestInfoController isTestMode]) {
        MESALog(@"reset timer to %@",_runloopTimer.fireDate);
    }
}
- (bool)getSignal:(bool)isInput portStatus:(int)port{
    return isInput? [[_inputSignal objectAtIndex:port] boolValue] : [[_outputSignal objectAtIndex:port] boolValue];
}
- (void)setSignal:(bool)isInput port:(int)port toStatus:(bool)status{
    isInput ? [_inputSignal setObject:[NSNumber numberWithBool:status] atIndexedSubscript:port] : [_outputSignal setObject:[NSNumber numberWithBool:status] atIndexedSubscript:port];
}

#pragma mark - Open & Close
- (void)open:(NSMutableDictionary *)config withApp:(AppDelegate *)app;
{
    _cmdBuffer = [[NSString alloc] init];
    _app = app;
    
    _getForce1Lock = [[NSLock alloc] init];
    _getForce2Lock = [[NSLock alloc] init];
    
    _runloopTimer = [NSTimer timerWithTimeInterval:50000000 target:self selector:@selector(timeHandler) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_runloopTimer forMode:NSDefaultRunLoopMode];
    
    if (isMacbook){
        _inputSignal = [NSMutableArray arrayWithObjects:
                        [NSNumber numberWithBool:false],//0
                        [NSNumber numberWithBool:false],//1
                        [NSNumber numberWithBool:false],//2
                        [NSNumber numberWithBool:false],//3
                        [NSNumber numberWithBool:false],//4
                        [NSNumber numberWithBool:false],//5
                        [NSNumber numberWithBool:false],//6
                        [NSNumber numberWithBool:false],//7
                        [NSNumber numberWithBool:false],//8
                        [NSNumber numberWithBool:false],//9
                        [NSNumber numberWithBool:false],//10
                        [NSNumber numberWithBool:false],//11
                        [NSNumber numberWithBool:false],//12
                        [NSNumber numberWithBool:false],//13
                        [NSNumber numberWithBool:false],//14
                        [NSNumber numberWithBool:false],//15
                        [NSNumber numberWithBool:false],//16
                        [NSNumber numberWithBool:false],//17
                        [NSNumber numberWithBool:false],//18
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        @"RESERVED",                    //reserved
                        [NSNumber numberWithBool:false],//30 (for Mesa to Ping Googol)
                        nil];
        
        _outputSignal = [NSMutableArray arrayWithObjects:
                         [NSNumber numberWithBool:false],//0
                         [NSNumber numberWithBool:false],//1
                         [NSNumber numberWithBool:false],//2
                         [NSNumber numberWithBool:false],//3
                         [NSNumber numberWithBool:false],//4
                         [NSNumber numberWithBool:false],//5
                         [NSNumber numberWithBool:false],//6
                         [NSNumber numberWithBool:false],//7
                         [NSNumber numberWithBool:false],//8
                         [NSNumber numberWithBool:false],//9
                         [NSNumber numberWithBool:false],//10
                         [NSNumber numberWithBool:false],//11
                         [NSNumber numberWithBool:false],//12
                         [NSNumber numberWithBool:false],//13
                         [NSNumber numberWithBool:false],//14
                         nil];
    }
    else{
        _inputSignal = [NSMutableArray arrayWithObjects:
                        @"RESERVED",//reserved
                        [NSNumber numberWithBool:false],//1
                        [NSNumber numberWithBool:false],//2
                        [NSNumber numberWithBool:false],//3
                        [NSNumber numberWithBool:false],//4
                        [NSNumber numberWithBool:false],//5
                        [NSNumber numberWithBool:false],//6
                        [NSNumber numberWithBool:false],//7
                        [NSNumber numberWithBool:false],//8
                        nil];
        
        _outputSignal = [NSMutableArray arrayWithObjects:
                         @"RESERVED",//reserved
                         [NSNumber numberWithBool:false],//1
                         [NSNumber numberWithBool:false],//2
                         @"RESERVED",//reserved
                         [NSNumber numberWithBool:false],//4
                         [NSNumber numberWithBool:false],//5
                         [NSNumber numberWithBool:false],//6
                         @"RESERVED",//reserved
                         [NSNumber numberWithBool:false],//8
                         [NSNumber numberWithBool:false],//9
                         [NSNumber numberWithBool:false],//10
                         nil];
    }

    _axes = [NSArray arrayWithObjects:
              @"RESERVED",//reserved
              @"X",//1
              @"Y",//2
              @"Z",//3
              @"A",//4
              nil];
    
    _axesHomeStatus = [NSMutableArray arrayWithObjects:
              @"RESERVED",//reserved
              [NSNumber numberWithBool:false],//1,X
              [NSNumber numberWithBool:false],//2,Y
              [NSNumber numberWithBool:false],//3,Z1
              [NSNumber numberWithBool:false],//4,Z2
              nil];
    
    _axesMoveStatus = [NSMutableArray arrayWithObjects:
              @"RESERVED",//reserved
              [NSNumber numberWithBool:false],//1,X
              [NSNumber numberWithBool:false],//2,Y
              [NSNumber numberWithBool:false],//3,Z1
              [NSNumber numberWithBool:false],//4,Z2
              nil];
    
    _axesTargetPosition = [NSMutableArray arrayWithObjects:
                            @"RESERVED",//reserved
                            [NSNumber numberWithFloat:0],//1,X
                            [NSNumber numberWithFloat:0],//2,Y
                            [NSNumber numberWithFloat:0],//3,Z1
                            [NSNumber numberWithFloat:0],//4,Z2
                            nil];
    
    _axesPosition = [NSMutableArray arrayWithObjects:
                           @"RESERVED",//reserved
                           [NSNumber numberWithFloat:0],//1,X
                           [NSNumber numberWithFloat:0],//2,Y
                           [NSNumber numberWithFloat:0],//3,Z1
                           [NSNumber numberWithFloat:0],//4,Z2
                           nil];
    _axesAlarm = 0;
    _axesPositiveLimit = 0;
    _axesNegativeLimit = 0;
    
    _motionParams = [config objectForKey:@"motion"];
    
    // Read the home velocity & the velocity for each axis, set the velocity values
    _homeVelocity = [[_motionParams objectForKey:@"HOME_VEL"] floatValue];
    _xVelocity = [[_motionParams objectForKey:@"X_VEL"] floatValue];
    _yVelocity = [[_motionParams objectForKey:@"Y_VEL"] floatValue];
    _z1Velocity = [[_motionParams objectForKey:@"Z1_VEL"] floatValue];
    _z2Velocity = [[_motionParams objectForKey:@"Z2_VEL"] floatValue];
    
    _z1Tolerance = [[_motionParams objectForKey:@"Z1_TOLERANCE"] floatValue];
    _z2Tolerance = [[_motionParams objectForKey:@"Z2_TOLERANCE"] floatValue];
    
    _tcpip = [[Googol_TCPIP alloc] init];
    NSString *ip_addr   = [_motionParams objectForKey:@"IP_ADDR"];
    int port            = [[_motionParams objectForKey:@"TCP_PORT"] intValue];
    MESALog(@"Opening motion controller with IP=%@, Port=%d", ip_addr, port);
    // Connect to the motion controller
    [_tcpip connectWithIP:ip_addr andPort:port];
    
    [self getInput:DI_ESTOP];
    [self getInput:DI_RESET];
    [self getInput:DI_START_LEFT];
    [self getInput:DI_START_RIGHT];
    [self getInput:DI_POWER];
//    [self getInput:DI_DOOR];
    [self getInput:DI_Z1_WARNING];
    [self getInput:DI_Z2_WARNING];
    
    if (isMacbook){
        [self getInput:DI_BOTTOM_VACUUM_WARNING];
        [self getInput:DI_TOP_VACUUM_WARNING];
        
        
        [self getInput:DI_USB_CYLINDER_FRONT_LIMIT];
        [self getInput:DI_USB_CYLINDER_BACK_LIMIT];
        
        [self getInput:DI_MB_TOP_TOUCH_1];
        [self getInput:DI_MB_TOP_TOUCH_2];
        [self getInput:DI_MB_BOTTOM_TOUCH_1];
        [self getInput:DI_MB_BOTTOM_TOUCH_2];
        [self getInput:DI_OVERRIDE_KEY];
        
        if ([self getInput:DI_OVERRIDE_KEY] == false){
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Override Key is inserted, please remove it";
                MESALog(@"[Warning]Override Key is inserted when app init");
                [alert runModal];
            });
            exit(0);
        }
    }
  

    
    [self setOutput:DO_SIGNAL_GREEN toState:IO_OFF];
    [self setOutput:DO_SIGNAL_YELLOW toState:IO_ON];
    [self setOutput:DO_SIGNAL_RED toState:IO_OFF];
    
    [self setOutput:DO_ION_FAN toState:IO_OFF];
    
    [self setGotoVelocity:AXIS_X withVelocity:_xVelocity];
    [self setGotoVelocity:AXIS_Y withVelocity:_yVelocity];
    [self setGotoVelocity:AXIS_Z1 withVelocity:_z1Velocity];
    [self setGotoVelocity:AXIS_Z2 withVelocity:_z2Velocity];
    [self setGoHomeVelocity:_homeVelocity];
    
    [self setOutput:DO_DOOR_LOCK toState: IO_ON];
    [self setOutput:DO_Z1_BRAKE toState:IO_ON];
    [self setOutput:DO_Z2_BRAKE toState:IO_ON];
    
    
    
 
    // Stop Z1
    MESALog(@"Stop axis %@", [_axes objectAtIndex:AXIS_Z1]);
    // Stop Axis first
    _stopFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_STOP, [_axes objectAtIndex:AXIS_Z1]]];
    while(!_stopFin && !STOPTEST /*&&  !_timeOut*/){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    // Stop Z2
    MESALog(@"Stop axis %@", [_axes objectAtIndex:AXIS_Z2]);
    // Stop Axis first
    _stopFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_STOP, [_axes objectAtIndex:AXIS_Z2]]];
    while(!_stopFin && !STOPTEST /*&&  !_timeOut*/){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    // Stop X and Y
    [self stopAxis:AXIS_X isOriginalStop_Z:true];
    [self stopAxis:AXIS_Y isOriginalStop_Z:true];
/*
    //Ask OP to open door first, otherwirse, it will fall into intfity Hbb mode
    [self setOutput:DO_DOOR_LOCK toState: IO_OFF];  //Unlock front door lock
    
    while ([self getInput:DI_FRONT_DOOR] == false){
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Please OPEN front door and then click OK";
            MESALog(@"Request OP open door when system init");
            [alert runModal];
        });
    }
    
    //Ask OP to close door to continue system init
    while ([self getInput:DI_FRONT_DOOR] == true){
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Please CLOSE front door and then click OK";
            MESALog(@"Request OP close foor when system init");
            [alert runModal];
        });
    }
    */
    //Check door close or not
     
    [self setOutput:DO_DOOR_LOCK toState: IO_OFF];
    while ([self getInput:DI_FRONT_DOOR] == false){
        dispatch_sync(dispatch_get_main_queue(), ^{
           
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Please OPEN front door and then click OK";
            MESALog(@"Request OP open door when system init");
            [alert runModal];
        });
    }
 
    while ([self getInput:DI_FRONT_DOOR] == true){
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Please CLOSE front door and then click OK";
            MESALog(@"Request OP close foor when system init");
            [alert runModal];
        });
    }
    [self setOutput:DO_DOOR_LOCK toState: IO_ON];
    [self disableAxis];
    [self enableAxis : false];
    
     // Z1 and Z2 axes go home
    [self goHome:AXIS_Z1];
    [self goHome:AXIS_Z2];
    
    [self waitMotor:AXIS_Z1];
    [self waitMotor:AXIS_Z2];
    
    [self getPosition:AXIS_Z1];
    [self getPosition:AXIS_Z2];
    //2023-10-18 matthew enable for QSMC
    // Alert if DUT inside fixture before X Y homing
    while ([self getInput:DI_MB_BOTTOM_TOUCH_1] || [self getInput:DI_MB_BOTTOM_TOUCH_2]) {
         
        if ([self getInput:DI_USB_CYLINDER_FRONT_LIMIT]) {
            [self setOutput:DO_USB_CYLINDER toState:IO_OFF];
        }
        
        if ([self getInput:DI_TOP_VACUUM_WARNING] || [self getInput:DI_BOTTOM_VACUUM_WARNING]){
            //停真空
            [self setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
            [self setOutput:DO_TOP_VACUUM toState:IO_OFF];
            
            // 噴氣
            [self setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_ON];
            [self setOutput:DO_TOP_ANTI_VACUUM toState:IO_ON];
            
            [NSThread sleepForTimeInterval:0.3];
            
            // 停噴氣
            [self setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
            [self setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
        }
        
        [self disableAxis];
        [self setOutput:DO_DOOR_LOCK toState:IO_OFF];    // unlock door if DUT inside fixture
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"DUT inside fixture when axis X and Y are homing, please take out DUT and close the door then click OK";
            MESALog(@"[Warning] DUT inside fixture when X and Y axis homing");
            [alert runModal];
        });
        [NSThread sleepForTimeInterval:0.5];
        
    }
    [self enableAxis:false];
    [self setOutput:DO_DOOR_LOCK toState: IO_ON];
    //Double check door close or not
    if (![self getInput:DI_FRONT_DOOR]){
        MESALog(@"Door close when init, lock door now");
        [self setOutput:DO_DOOR_LOCK toState: IO_ON];
        [NSThread sleepForTimeInterval: 0.5];
        
        // clear Hbb
        [self disableAxis];
        [NSThread sleepForTimeInterval: 1];
        [self enableAxis : false];
    }
    else{
        MESALog(@"Door is not close when init");
    }
    
    // X and Y go Home
    [self goHome:AXIS_X] ;
    [self goHome:AXIS_Y];
    [self waitMotor:AXIS_X];
    [self waitMotor:AXIS_Y];
    
    [self getPosition:AXIS_X];
    [self getPosition:AXIS_Y];
    
    [self setOutput:DO_Z1_FORCE_CLEAR toState:IO_ON];
    [self setOutput:DO_Z1_FORCE_CLEAR toState:IO_OFF];
    [self setOutput:DO_Z2_FORCE_CLEAR toState:IO_ON];
    [self setOutput:DO_Z2_FORCE_CLEAR toState:IO_OFF];
    
    if(isMacbook){
        MESALog(@"Start init output");
        [self setOutput:DO_USB_CYLINDER toState:IO_OFF];
        [NSThread sleepForTimeInterval:0.3];
        [self setOutput:DO_TOP_VACUUM toState:IO_OFF];
        [self setOutput:DO_TOP_ANTI_VACUUM toState:IO_ON];
        [self setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
        [self setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_ON];
        [NSThread sleepForTimeInterval:0.3];
        [self setOutput:DO_TOP_VACUUM toState:IO_OFF];
        [self setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
        [self setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
        [self setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
        
        [self setOutput:DO_FRONT_LED toState:IO_ON];

       //[self setOutput:DO_DOOR_LOCK toState: IO_OFF];
    }
    [self setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
    
    [self setOutput:DO_SIGNAL_GREEN toState:IO_ON];
    [self setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
    [self setOutput:DO_SIGNAL_RED toState:IO_OFF];
}

- (void)close
{
    [self setOutput:DO_Z1_BRAKE toState:IO_OFF];
    [self setOutput:DO_Z2_BRAKE toState:IO_OFF];
    if(_tcpip.isOpened)
        [_tcpip close];
}

#pragma mark - Command with Googol
- (bool)enableAxis : (bool)checkHbbClear{
//    
    float pos = 0;
    float newPos = 0;
//
//    for (int i = 1; i <= 4; i++){
//        MESALog(@"Enable axis %@ now", [_axes objectAtIndex:i]);
//        
//        axisEnableFin[i-1] = false;
//        [_tcpip writeOut:[NSString stringWithFormat:CMD_AXIS_ENABLE, [_axes objectAtIndex:i]]];
//        while(!axisEnableFin[i-1] && !STOPTEST){
//            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
//        }
//        
//        [NSThread sleepForTimeInterval:0.3];
//        // update pos after re-enable
//        pos = [self getPosition:i];
//    }
    
    MESALog(@"Enable all axis");

    allAxisEnableFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_AXIS_ENABLE, @"T"]];    //T means all axis
    while(!allAxisEnableFin && !STOPTEST){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    // Not suitable for system init, move 1 mm for checking
    
    if (checkHbbClear){       //check Y only for saving time
        pos = [self getPosition:AXIS_Y];     // get position after re-enable
        
        // Move 1 mm
        [self goTo:AXIS_Y withPosition:(pos+1)];
        [self waitMotor:AXIS_Y];
        
        newPos = [self getPosition:AXIS_Y];  // get postion after moving 1mm
        
        // check moving distant, if moving distant is < 0.7mm, return error
        if ((newPos - pos) < 0.7){
            MESALog(@"[Error] fail to clear Hbb warning");
            return false;
        }
    }

    return true;
}

- (void)disableAxis{
//    for (int i = 1; i <= 4; i++){
//        // Disable axis
//        MESALog(@"Disable axis %@", [_axes objectAtIndex:i]);
//
//        axisDisableFin[i-1] = false;
//        [_tcpip writeOut:[NSString stringWithFormat:CMD_AXIS_DISABLE, [_axes objectAtIndex:i]]];
//        
//        while(!axisDisableFin[i-1] && !STOPTEST){
//            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
//        }
//        
//        [NSThread sleepForTimeInterval:0.3];
//    }
    
    MESALog(@"Disable all axis");

    allAxisDisableFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_AXIS_DISABLE, @"T"]];   // T means all axis
    [NSThread sleepForTimeInterval:0.2];
    
    [_tcpip writeOut:[NSString stringWithFormat:CMD_AXIS_DISABLE, @"T"]];
    while(!allAxisDisableFin && !STOPTEST){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    }
}

- (bool)compareCurrentPosWithHomePos{
    
    bool isCurrentAxisAtHome[4];
    float currentPos = 0;
    float homePos = 0;
    
    for (int i = 1; i <= 4; i++){

        // check is still @home position after re-enable axis
        currentPos = [self getPosition:i];
        
        switch (i) {
            case 1:
            case 3:
            case 4:
                homePos = 0;
                break;
                
            case 2:
                homePos = _app.dutY;
                break;
        }
        
        if (abs(currentPos - homePos) > 1){
            MESALog(@"Axis %d not at home position after re-enable", i);
            isCurrentAxisAtHome[i-1] = false;
        }
        else{
            isCurrentAxisAtHome[i-1] = true;
            MESALog(@"Axis %d still at home position after re-enable", i);
        }
    }
    
    if (isCurrentAxisAtHome[0] && isCurrentAxisAtHome[1] && isCurrentAxisAtHome[2] && isCurrentAxisAtHome[3])
        _app.isAtHomePosition = true;
    else
        _app.isAtHomePosition = false;

    
    return _app.isAtHomePosition;

}

- (void)goHome:(int)axis{

    if((self.axesNegativeLimit & 1<<2) || (self.axesNegativeLimit & 1<<3)) {
        
        // Disconnect USB cable
        [self setOutput:DO_USB_CYLINDER toState:![self getSignal:OUTPUT portStatus:DO_USB_CYLINDER]];

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Axis Z1 or Z2 reaches negative limit, please check and reopen this app.";
            [alert runModal];
        });
        MESALog(@"Axis Z1 or Z2 reaches negative limit, please check.");
        [_app closeAppWithSaveLog];
    }
    else {

        if (axis == AXIS_Z1){
            [self setOutput:DO_Z1_BRAKE toState: 1];    //release Z1 brake;
            MESALog(@"Release Z1 brake");
        }
        if (axis == AXIS_Z2){
            [self setOutput:DO_Z2_BRAKE toState: 1];    //release Z2 brake;
            MESALog(@"Release Z2 brake");
        }
    
        MESALog(@"Axis %@ goes home", [_axes objectAtIndex:axis]);
        homing = 1;

        //flag setup
        [_axesHomeStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axis];
        [_axesMoveStatus setObject:[NSNumber numberWithBool:true] atIndexedSubscript:axis];

        [_tcpip writeOut:[NSString stringWithFormat:CMD_GO_HOME, [_axes objectAtIndex:axis]]];
    }
}

- (void)goTo:(int)axis withPosition:(float)position{

    if((self.axesNegativeLimit & 1<<2) || (self.axesNegativeLimit & 1<<3)) {
        
        // Disconnect USB cable
        [self setOutput:DO_USB_CYLINDER toState:![self getSignal:OUTPUT portStatus:DO_USB_CYLINDER]];

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Axis Z1 or Z2 reaches negative limit, please check and reopen this app.";
            [alert runModal];
        });
        MESALog(@"Axis Z1 or Z2 reaches negative limit, please check.");
        [_app closeAppWithSaveLog];
    }
    else {
        
        if (axis == AXIS_Z1) {
            [self setOutput:DO_Z1_BRAKE toState: 1];    //release Z1 brake;
        }
        
        if (axis == AXIS_Z2){
            [self setOutput:DO_Z2_BRAKE toState: 1];    //release Z1 brake;
        }
        
        MESALog(@"Axis %@ moving to %f", [_axes objectAtIndex:axis], position);
        homing = 2;
        //flag setup
        [_axesMoveStatus setObject:[NSNumber numberWithBool:true] atIndexedSubscript:axis];
        [_axesTargetPosition setObject:[NSNumber numberWithFloat:position] atIndexedSubscript:axis];
        
        [_tcpip writeOut:[NSString stringWithFormat:CMD_GOTO_POS, [_axes objectAtIndex:axis], position]];
    }
}

- (void)waitMotor:(int)axis{
    //homing
    if (homing == 1)
    {
        while((![[_axesHomeStatus objectAtIndex:axis] boolValue]) && !STOPTEST)
        {
//            if (isMacbook && [self getSignal:INPUT portStatus:DI_FRONT_DOOR] && CALIBRATION == false) {
/*            if (isMacbook && CALIBRATION == false) {
            for(int i=1; i<=4; i++)
                {
                    [self stopAxis:i isOriginalStop_Z:true];
                }

                dispatch_sync(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [[NSAlert alloc] init];
                    alert.messageText = @"Door is open when homing, please close the door and reopen this app";
                    [alert runModal];
                });
                MESALog(@"Door is open when axis homing");
                [_app closeAppWithSaveLog];

            }
            else{
*/                @autoreleasepool {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                }
//            }

        }
    }
    
    //moving
    else if(homing == 2)
    {
        for (int i=1 ; i<MAX_RETRY_TIME ; i++) {
            if (i > MAX_RETRY_TIME) {
                MESALog(@"[Error]Googol_MotionIO.waitMotor: %@ axis, retry %d times but end up fail. exit now", [_axes objectAtIndex:axis], i);
                exit(-1);
            } else {
                if (i > 1){
                    MESALog(@"[Warning]Googol_MotionIO.waitMotor: %@ axis, Timeout, retry %d time", [_axes objectAtIndex:axis], i-1);
                }
            }
            
            //init timer
            _timeOut = NO;
            _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
            //MESALog(@"setup timer to %@",_runloopTimer.fireDate);
            while([[_axesMoveStatus objectAtIndex:axis] boolValue] && !STOPTEST && !_timeOut)
            {
/*                if (isMacbook && [self getSignal:INPUT portStatus:DI_FRONT_DOOR] && CALIBRATION == false) {

                    //for release DUT method used
                    if (_app.isDutReleasing){
                        _app.isInterruptDutRelease = true;
                    }
                    
                    //stop all axis when door is open during axis moving
                    //for(int i=1; i<=4; i++)
                    //{
                    //[self stopAxis:axis isOriginalStop_Z:false];
                    //}
                    
                    // set STOPTEST to ture to break this loop;
                    STOPTEST = true;
//                }
                else{
*/
                @autoreleasepool {
                        //charlie changes 0.5 to 0.05 for stop Motor in faster respond when door is open
                        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                    }
                }
//            }
            
            if (_timeOut && [[_axesMoveStatus objectAtIndex:axis] boolValue]) {
                @autoreleasepool {
                    MESALog(@"[Warning]Googol_MotionIO.waitMotor %@ axis timeout the %d time(s)", [_axes objectAtIndex:axis], i);
                    [self goTo:axis withPosition:[[_axesTargetPosition objectAtIndex:axis] floatValue]];
                }
            }
            else
            {
                [self timerReset];
                _timeoutCount = 0;
                break;
            }
        }
    }
}

- (float)getPosition:(int)axis{
    //flag setup
    
    //        if (++_timeoutCount > MAX_RETRY_TIME) {
    //            MESALog(@"[Error]Googol_MotionIO.getPosition:(int)axis, retry 5 times but end up fail. exit now");
    //            exit(-1);
    //        } else {
    //            if (_timeoutCount > 1){
    //                MESALog(@"[Warning]Googol_MotionIO.getPosition:(int)axis, Timeout, retry %d time",_timeoutCount -1);
    //            }
    //        }
    
    _getPositioinFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_GET_POS, [_axes objectAtIndex:axis]]];
    
    //        //init timer
    //        _timeOut = NO;
    //        _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
    
    //MESALog(@"--[BEFORE] get position runloop, axis:%d",axis);
    while(!_getPositioinFin && !STOPTEST /*&&  !_timeOut*/){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    //MESALog(@"--[AFTER] get position runloop, axis:%d",axis);
    //        if (_timeOut && !_getPositioinFin) {
    //            @autoreleasepool {
    //                MESALog(@"[Warning]Googol_MotionIO.getPosition: Get Position %@ TImeoutthe %d time",[_axes objectAtIndex:axis], _timeoutCount-1);
    //                [self getPosition:axis];
    //            }
    //        }
    //        else
    //        {
    //            [self timerReset];
    //            _timeoutCount = 0;
    //        }
    
    //MESALog(@"--[getPosition]in the getposition");
    return [[_axesPosition objectAtIndex:axis] floatValue];
    
}

- (float)getForce:(int)axis{
    
    //MESALog(@"--[getForce]in the getforce");
    //        if (++_timeoutCount > MAX_RETRY_TIME) {
    //            MESALog(@"[Error]Googol_MotionIO.getForce:(int)axis, retry 5 times but end up fail. exit now");
    //            exit(-1);
    //        } else {
    //            if (_timeoutCount > 1){
    //                MESALog(@"[Warning]Googol_MotionIO.getForce:(int)axis, Timeout, retry %d time",_timeoutCount -1);
    //            }
    //        }
    
    int probeNum = (axis == AXIS_Z1)?1:2;
    
    //flag setup
    _getForceFin = false;
    [_tcpip writeOut:[NSString stringWithFormat:CMD_GET_FORCE, probeNum]];
    //[_tcpip writeOut:[NSString stringWithFormat:CMD_GET_AI, probeNum]];
    
    //        //init timer
//    _timeOut = NO;
//    _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
    
    int tmp_wait=0;
    //MESALog(@"--[BEFORE] get force runloop, axis:%d",axis);
    while(!_getForceFin && !STOPTEST && tmp_wait!=100/*!_timeOut*/){
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
            [NSThread sleepForTimeInterval:0.025];
            tmp_wait++;
        }
    }
    //MESALog(@"--[AFTER] get force runloop, axis:%d",axis);
    if (/*_timeOut*/tmp_wait==100 && !_getForceFin) {
        @autoreleasepool {
            MESALog(@"[Warning]Googol_MotionIO.getForce: Get Force in axis %@ Timeout",[_axes objectAtIndex:axis]);
            [self getForce:axis];
        }
    }
    else
    {
//        [self timerReset];
//        _getForceFin = true;
//        _timeoutCount = 0;
    }
    
    switch (axis) {
        case AXIS_Z1:
            return _z1Force;
        case AXIS_Z2:
            return _z2Force;
        default:
            return 9999;
    }
}

- (void)setOutput:(int)port toState:(int)state{
    [NSThread sleepForTimeInterval:0.05]; // add by charlie, because googol not stable
    @autoreleasepool {

        //flag setup
        _outputFin = false;
        [_tcpip writeOut:[NSString stringWithFormat:CMD_SET_OUTPUT, port, state]];
        [self outputPortLog: port state: state isRequest: true];
        //NSLog(@"%@", [NSString stringWithFormat:CMD_SET_OUTPUT, port, state]);
        
        while(!_outputFin && [self getSignal:OUTPUT portStatus:port]!= state && !STOPTEST /*&& !_timeOut*/){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

    }
}
- (bool) pingGoogol{
    
    [NSThread sleepForTimeInterval:0.05]; // add by charlie, because googol not stable
    
    _inputFin = false;
    
    [_tcpip writeOut:[NSString stringWithFormat:CMD_GET_INPUT, DI_FOR_PING]];
    
    int count = 0;
    while(!_inputFin && !STOPTEST /*&& !_timeOut*/){
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        [NSThread sleepForTimeInterval : 0.05];
        count++;
        
        if (count > 50)
        {
            MESALog(@"Motion controller disconnected!");

            NSString *ip_addr   = [_motionParams objectForKey:@"IP_ADDR"];
            int port            = [[_motionParams objectForKey:@"TCP_PORT"] intValue];
            [_tcpip close];
            
            [NSThread sleepForTimeInterval : 3];

            MESALog(@"Reopening motion controller with IP=%@, Port=%d", ip_addr, port);
            // Connect to the motion controller
            [_tcpip connectWithIP:ip_addr andPort:port];
        }
//        return false;
    }
    
    return true;
}

- (int)getInput:(int)port{
    @autoreleasepool {
//        if (++_timeoutCount > MAX_RETRY_TIME)
//        {
//            MESALog(@"[Error]Googol_MotionIO.getInput, retry 5 times but end up fail. exit now");
//            exit(-1);
//        }
//        else
//        {
//            if (_timeoutCount > 1) {
//                MESALog(@"[Error]Googol_MotionIO.getInput, Timeout, retry %d time",_timeoutCount -1);
//            }
//        }
        
        [NSThread sleepForTimeInterval:0.05]; // add by charlie, because googol not stable
        
        _inputFin = false;
        [_tcpip writeOut:[NSString stringWithFormat:CMD_GET_INPUT, port]];
        
//        //init timer
//        _timeOut = NO;
//        _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
        
        while(!_inputFin && !STOPTEST /*&& !_timeOut*/){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
//        if (_timeOut && !_inputFin) {
//            MESALog(@"[Warning]Googol_MotionIO.getInput: for GPI%i: Timeoutthe %d time",port, _timeoutCount-1);
//            [self getInput:port];
//        }else{
//            [self timerReset];
//            _timeoutCount = 0;
//        }
        //[NSThread sleepForTimeInterval:0.005];
        return [[_inputSignal objectAtIndex:port] intValue];
    }
}

- (void)setGoHomeVelocity:(float)velocity{
    @autoreleasepool {
//        if (++_timeoutCount > MAX_RETRY_TIME)
//        {
//            MESALog(@"[Error]Googol_MotionIO.setGoHomeVelocity, retry 5 times but end up fail. exit now");
//            exit(-1);
//        }
//        else
//        {
//            if (_timeoutCount > 1) {
//                MESALog(@"[Error]Googol_MotionIO.setGoHomeVelocity, Timeout, retry %d time",_timeoutCount -1);
//            }
//        }
        
        MESALog(@"Set home velocity to %f", velocity);
        _setHomeVelFin = false;
        [_tcpip writeOut:[NSString stringWithFormat:CMD_SET_HOME_VEL, velocity]];
        
//        //init timer
//        _timeOut = NO;
//        _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
        
        while(!_setHomeVelFin && !STOPTEST /*&& !_timeOut*/){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        
//        if (_timeOut && !_setHomeVelFin) {
//            MESALog(@"[Warning]Googol_MotionIO.setGoHomeVelocity: Timeoutthe %d time", _timeoutCount-1);
//            [self setGoHomeVelocity:velocity];
//        }else{
//            [self timerReset];
//            _timeoutCount = 0;
//        }
    }
}

- (void)setGotoVelocity:(int)axis withVelocity:(float)velocity{
    @autoreleasepool {
//        if (++_timeoutCount > MAX_RETRY_TIME)
//        {
//            MESALog(@"[Error]Googol_MotionIO.setGotoVelocity, retry 5 times but end up fail. exit now");
//            exit(-1);
//        }
//        else
//        {
//            if (_timeoutCount > 1) {
//                MESALog(@"[Error]Googol_MotionIO.setGotoVelocity, Timeout, retry %d time",_timeoutCount -1);
//            }
//        }
        
        MESALog(@"Set axis %@ velocity to %f", [_axes objectAtIndex:axis], velocity);
        _setGotoVelFin = false;
        
        
        [_tcpip writeOut:[NSString stringWithFormat:CMD_SET_GOTO_VEL,[_axes objectAtIndex:axis], velocity]];
        
//        //init timer
//        _timeOut = NO;
//        _runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
        
        while(!_setGotoVelFin && !STOPTEST /*&& !_timeOut*/){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        
//        if (_timeOut && !_setGotoVelFin) {
//            MESALog(@"[Warning]Googol_MotionIO.setGoHomeVelocity: Timeoutthe %d time", _timeoutCount-1);
//            [self setGotoVelocity:axis withVelocity:(float)velocity];
//        }else{
//            [self timerReset];
//            _timeoutCount = 0;
//        }
    }
}

- (void)stopAxis:(int)axis isOriginalStop_Z:(bool)originalStopZ{
    MESALog(@"Stop Axis %@",[_axes objectAtIndex:axis]);
    
    if (axis == 1 || axis == 2 || (axis == 3 && originalStopZ) || (axis == 4 && originalStopZ)) {
        _stopFin = false;
        [_tcpip writeOut:[NSString stringWithFormat:CMD_STOP, [_axes objectAtIndex:axis]]];
        while(!_stopFin && !STOPTEST){
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
    }
    else if (axis == 3 && originalStopZ == false){
        MESALog(@"Stop Z1 axis, set vel to 0 then go home");
        [self setGotoVelocity:AXIS_Z1 withVelocity:0];
        [self goTo:AXIS_Z1 withPosition:0];
        [self setOutput:DO_Z1_BRAKE toState: 0];    //turn on Z1 brake;
        [NSThread sleepForTimeInterval:0.2];
        [self getPosition: AXIS_Z1];
        [self setGotoVelocity:AXIS_Z1 withVelocity:_z1Velocity];
    }
    else if (axis == 4 && originalStopZ == false){
        MESALog(@"Stop Z2 axis, set vel to 0 then go home");
        [self setGotoVelocity:AXIS_Z2 withVelocity:0];
        [self goTo:AXIS_Z2 withPosition:0];
        [self setOutput:DO_Z2_BRAKE toState: 0];    //trun on Z2 brake;
        [NSThread sleepForTimeInterval:0.2];
        [self getPosition: AXIS_Z2];
        [self setGotoVelocity:AXIS_Z2 withVelocity:_z2Velocity];
    }
    
    [_axesHomeStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axis];
    [_axesMoveStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axis];
    

    //homing = 0;
}

- (void)goHome:(int)axis inMsgMode:(bool)isMsgMode{
    MESALog(@"Axis %@ goes home", [_axes objectAtIndex:axis]);
    homing = 1;
    //flag setup
    [_axesHomeStatus setObject:[NSNumber numberWithBool:false] atIndexedSubscript:axis];
    [_axesMoveStatus setObject:[NSNumber numberWithBool:true] atIndexedSubscript:axis];
    
    if (isMsgMode) {
        [_app.lock lock];
        _cmdBuffer = nil;
        _cmdBuffer = [NSString stringWithString:[NSString stringWithFormat:CMD_GO_HOME, [_axes objectAtIndex:axis]]];
        _app.workFlag = SendMessage;
        
        while (_app.workFlag != WorkDefault) {
            [NSThread sleepForTimeInterval:0.01];
        }
        [_app.lock unlock];
    }
    else
    {
        [_tcpip writeOut:[NSString stringWithFormat:CMD_GO_HOME, [_axes objectAtIndex:axis]]];
    }
}

- (void)inputPortLog:(int)port state:(int)portState{
    NSString *portName;
    NSString *portCurrentState;
    
    NSLock *myLock = [[NSLock alloc] init];
    [myLock lock];
    if (isMacbook) {
        switch (port) {
            case DI_ESTOP:
                portName = @"E-Stop button";
                portCurrentState = (portState == IO_ON)? @"Pressed" : @"released";
                break;
                
            case DI_RESET:
                portName = @"Reset home button";
                portCurrentState = (portState == IO_ON)? @"pressed" : @"released";
                break;
                
            case DI_START_LEFT:
                portName = @"Left button";
                portCurrentState = (portState == IO_ON)? @"pressed" : @"released";
                break;
                
            case DI_START_RIGHT:
                portName = @"Right start button";
                portCurrentState = (portState == IO_ON)? @"pressed" : @"released";
                break;
                
            case DI_POWER:
                portName = @"Fixture power";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
/*            case DI_DOOR:
                portName = @"Fixture back door";
                portCurrentState = (portState == IO_ON)? @"closed" : @"opened";
                break;
*/
            case DI_Z1_WARNING:
                portName = @"Z1 warning sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_Z2_WARNING:
                portName = @"Z2 warning sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_BOTTOM_VACUUM_WARNING:
                portName = @"Holder bottom vacuum sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_TOP_VACUUM_WARNING:
                portName = @"Holder top vacuum sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_USB_CYLINDER_FRONT_LIMIT:
                portName = @"USB cylinder front limit sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_USB_CYLINDER_BACK_LIMIT:
                portName = @"USB cylinder back limit sensor";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_MB_TOP_TOUCH_1:
                portName = @"Holder top IR sensor 1";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_MB_TOP_TOUCH_2:
                portName = @"Holder top IR sensor 2";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_MB_BOTTOM_TOUCH_1:
                portName = @"Holder bottom IR sensor 1";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_MB_BOTTOM_TOUCH_2:
                portName = @"Holder bottom IR sensor 2";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DI_FRONT_DOOR :
                portName = @"Front door is";
                portCurrentState = (portState == IO_ON)? @"Opened" : @"Closed";
                break;
                
            case DI_FRONT_DOOR_LOCKED:
                portName = @"Door is";
                portCurrentState = (portState == IO_ON)? @"Unlocked" : @"Locked";
                break;
                
            case DI_OVERRIDE_KEY:
                portName = @"Override key is";
                portCurrentState = (portState == IO_ON)? @"Removed" : @"Inserted";
                break;
                
            case DI_FOR_PING:
                break;

            default:
                portName = @"Unknown pin";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
        }
        
        if (port != DI_FOR_PING)
            MESALog(@"[Input state] %@ is %@", portName, portCurrentState);
    }
    [myLock unlock];
}

- (void)outputPortLog:(int)port state:(int)portState isRequest:(bool)isRequest {
    NSString *portName;
    NSString *portCurrentState;
    
    NSLock *myLock = [[NSLock alloc] init];
    [myLock lock];
    if (isMacbook){
        switch (port) {
            case DO_Z1_FORCE_CLEAR:
                portName = @"Z1 force meter set zero";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_Z2_FORCE_CLEAR:
                portName = @"Z2 force meter set zero";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_Z1_BRAKE:
                portName = @"Z1 axis brake";
                portCurrentState = (portState == 0)? @"ON" : @"Release";
                break;
                
            case DO_Z2_BRAKE:
                portName = @"Z2 axis brake";
                portCurrentState = (portState == 0)? @"ON" : @"Release";
                break;
                
            case DO_SIGNAL_RED:
                portName = @"Red light";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_SIGNAL_GREEN:
                portName = @"Green light";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_SIGNAL_YELLOW:
                portName = @"Yellow light";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_ION_FAN:
                portName = @"Ion Fan";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_BOTTOM_VACUUM:
                portName = @"Bottom vacuum";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_TOP_VACUUM:
                portName = @"Top vacuum";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_BOTTOM_ANTI_VACUUM:
                portName = @"Bottom anti-vacuum";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_TOP_ANTI_VACUUM:
                portName = @"Top anti-vacuum";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_USB_CYLINDER:
                portName = @"USB cylinder";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;
                
            case DO_FRONT_LED:
                portName = @"Front LED";
                portCurrentState = (portState == IO_ON)? @"ON" : @"OFF";
                break;

            case DO_DOOR_LOCK:
                portName = @"Door lock trigger signal";
                portCurrentState = (portState == IO_ON)? @"Turned ON" : @"Turned OFF";
                break;

            default:
                break;
        }
        if(isRequest){
            MESALog(@"[Output request] %@ set to %@", portName, portCurrentState);
        }
        else{
            MESALog(@"[Output state] %@ is %@", portName, portCurrentState);
        }
    }
    [myLock unlock];
}

@end

/************************************************************/
