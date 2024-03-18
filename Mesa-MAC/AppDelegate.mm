//
//  AppDelegate.m
//  Mesa-MAC
//
//  Created by Antonio Yu on 26/9/14.
//  Edited by Sylar on 26th/May/15.
//  Q: = question    W: = warning    C: = comment    E: = edit
//
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import "AppDelegate.h"
#import "TestInfoController.h"
#import "Googol_MotionIO.h"

#define TESTVALUE 0

AppDelegate *globalApp;

CFDataRef onRecvMessageCallBack(CFMessagePortRef local,SInt32 msgid,CFDataRef cfData, void*info);

bool STOPTEST = FALSE;
bool CALIBRATION = FALSE;
bool IMAGESAVING = true;
bool isMacbook = true;
bool is2ChannelsController = true;
bool RECORD_PROCESSING_TIME = false;
bool isAutoReleaseDUT = false;
bool isForceQuitPID = false;

CFMessagePortRef mpToMesaHost;
// this CFDataRef is to be used by sending back data via Message Port, added by Antonio on 17-02-2016
CFDataRef sgReturn;

@interface AppDelegate ()
{
    float offsetX, offsetY;
    
    // MessagePort reference, added by Antonio on 17-02-2016
    CFMessagePortRef        mpFromMesaHost;
    FastServerSocket        *socketServer;
    FastSocket              *socketConnection;
    bool                    socketServerRunning;
}

@property (weak) IBOutlet NSWindow *window;


-(void)delegateOpen;
-(void)delegateClose;
-(void)commandAcknowledge:(NSString *)ack;


- (void)workflow;

/**
 *  for workflow method to init the system. Run once
 *
 *  @return true if init step fin. false if init fail
 */
- (BOOL)systemInit;


-(unsigned short)CRC16withData:(unsigned char*) data andDataLength:(int) length;

-(void)statusCheck;

@end
#pragma mark -

@implementation AppDelegate
#pragma mark - System
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    //NSURL * metronLogoUrl = [[NSURL alloc] initFileURLWithPath:@"Metron.png"];
    //NSImage * metronLogo = [[NSImage alloc] initWithContentsOfURL : metronLogoUrl];
    
//    MESALog(@"open macbook calibration page");
//    _config_window_macbook = [[CalibrationMacBook alloc] initWithWindowNibName:@"CalibrationMacBook"];
//    _config_window_macbook.app = self;
//    [_config_window_macbook showWindow:self];

    
    // displau metron logo on GUI
    NSString *metronLogoPath = [[[NSBundle mainBundle] resourcePath]  stringByAppendingString:@"/Metron.png"];
    NSImage * metronLogo = [[NSImage alloc] initWithContentsOfFile: metronLogoPath];
    [_metronNSView setImage:metronLogo];

    globalApp = self;

    _spiderman = [[DataCollctor alloc] initWithFolderPath:@"/vault/MesaFixture/MesaLog" andAutoSaveSize:5];
    _WriteLog = [[NSThread alloc] initWithTarget:self selector:@selector(WriteLogOnThread) object:nil];
    _WriteLog.name = @"Workflow thread";
    [_WriteLog start];
    _workThread = [[NSThread alloc] initWithTarget:self selector:@selector(workflow) object:nil];
    _workThread.name = @"Workflow thread";
    [_workThread start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    //Insert code here to tear down your application
    [_spiderman collectData];
    
    if(_useMessagePort)
    {
        CFMessagePortInvalidate(mpFromMesaHost);
        CFRelease(mpFromMesaHost);
        CFMessagePortInvalidate(mpToMesaHost);
        CFRelease(mpToMesaHost);
    }
    else if(_useSocketPort)
    {
        socketServerRunning = false;
        [socketServer close];
    }
    else
    {
        [self delegateClose];
    }
}

- (void)applicationDidResignActive:(NSNotification *)notification{
//    MESALog(@"applicationDidResignActive", NULL);
//    if(_alwaysActive.intValue)
//        [NSApp activateIgnoringOtherApps:YES];
}

- (void)listenSocketPortAndRepeat:(id)obj {
    
    @autoreleasepool {
        
        MESALog(@"Started listening");
        socketServerRunning = true;
        
        [socketServer listen];
        
        while(socketServerRunning)
        {

            MESALog(@"Accepting connection");

            socketConnection = [socketServer accept];
            
            if (!socketConnection) {
                MESALog(@"Connection error: %@", [socketServer lastError]);
                return;
            }
            
            // Read some bytes then echo them back.
            int bufferSize = 2048;
            unsigned char recvBuf[bufferSize];
            long bytesReceived = 0;
            
            do {
                // Read bytes.
                bytesReceived = [socketConnection receiveBytes:recvBuf limit:bufferSize];
                
                if(bytesReceived <= 0)
                {
                    MESALog(@"Connection lost.");
                }
                else
                {

                    MESALog(@"Command received");

                    NSData *receivedData = [NSData dataWithBytes:recvBuf length:bytesReceived];
                    
                    
                    // Convert received NSData into bytes
                    Byte *bytes = (Byte *)malloc(sizeof(Byte)*8);
                    [receivedData getBytes:bytes range:NSMakeRange(0,[receivedData length])];
                    
                    NSString *command=@"";
                    
                    for(int i=0;i< [receivedData length];i++)
                    {
                        NSString *newHexStr = [NSString stringWithFormat:@"%x", bytes[i]&0xff];///16进制数
                        
                        if([newHexStr length]==1)
                            command = [NSString stringWithFormat:@"%@0%@", command, newHexStr];
                        else
                            command = [NSString stringWithFormat:@"%@%@", command, newHexStr];
                    }
                    
                    MESALog(@"[MesaMac] Command received:%@, length = %lu", command, (unsigned long)[command length], NULL);

                    [self commandHandler:command];
                }
                
                // Allow other threads to work.
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                
            } while (bytesReceived > 0);
        }
    }
    
    [socketServer close];
}

- (BOOL)systemInit{
    
    // recode down current software version and build version to log file
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    MESALog(@"Software version = %@", [infoDictionary objectForKey:@"CFBundleShortVersionString"]);
    MESALog(@"Build version = %@", [infoDictionary objectForKey:@"CFBundleVersion"]);
    
    if (!isMacbook) {
        for(int i=0; i<[[NSApp windows] count]; i++)
            if ([[[[NSApp windows] objectAtIndex:i] identifier]  isEqual: @"MAINWINDOW"]) {
                [[[NSApp windows] objectAtIndex:i] setFrameTopLeftPoint:{0,1000}];
                [[[NSApp windows] objectAtIndex:i] makeKeyWindow];
            }
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        _msgBox.editable = false;
        _stressTest.enabled = false;
        _stressTest.transparent = true;
        _stop.enabled = false;
        _stop.transparent = true;
        _setup.enabled = false;
    });
    
    _sysInitFin = false;
    
    /******************* Init Display Formatter *******************/
    _formatter = [[NSNumberFormatter alloc] init];
    _formatter.numberStyle = NSNumberFormatterDecimalStyle;
    _formatter.maximumIntegerDigits = 4;
    _formatter.minimumFractionDigits = 2;
    _formatter.maximumFractionDigits = 2;
    _formatter.usesSignificantDigits = NO;
    _formatter.usesGroupingSeparator = NO;
    _formatter.groupingSeparator = @",";
    _formatter.decimalSeparator = @".";

    _lock = [[NSLock alloc] init];
    
    _homing = false;
    _setupOpen = false;
    
    NSMutableArray* errMsg = [[NSMutableArray alloc] init];
    errMsg = [Util CheckMesaFolder];
    for (int i = 0; i < [errMsg count]; i++){
        [self showMessage:[errMsg objectAtIndex:i] inColor:[NSColor orangeColor]];
    }
    
    _configDictionary = [Util ReadParamsFromPlist:@"config"];
    _settingsDictionary = [Util ReadParamsFromPlist:@"settings"];
    
    [self paraRefresh];
    
    MESALog(@"ratio = %f", _ratio);
    _cleancount = 0;
    _macbookCount = 0;
    
    _isCaptureFinish = false;
    _isAtHomePosition = false;
    _isAtLeftRightPosition = false;
    _zProbeStatus = MESARS232ProbeDefault;
    _myProbeStatus = MESARS232ProbeAtCpature;
    _isCleaningFinish = false;
    
    _probeDowning = false;
    
    _isToChangeValue = false;
    _stepLength = MESARS232LengthDefault;
    _isPositiveDirection = 0;
    
    _startTest = false;
    _resetFlag = false;
    _powerFlag = true;
    _axesAlarmOn = 0;
    _positiveLimitOn = 0;
    _negativeLimitOn = 0;
    _problemFlag = 0;
    _force1Flag = false;
    _force2Flag = false;
    
    _isToChangeValue = false;
    _stepLength = MESARS232LengthDefault;
    _isPositiveDirection = true;
    
    if(_useMessagePort == true)
        MESALog(@"Using message port for communication with MesaHost.");
    else if(_useSocketPort == true)
        MESALog(@"Using network socket for communication with MesaHost.");
    else
        MESALog(@"Using RS232 for communication with MesaHost.");
    
    //[TestInfoController beginTest];
    [TestInfoController stopTest];
    
    /******************* Init Lighting *******************/
    [self showMessage:@"[Init] Initializing lighting..." inColor:[NSColor blackColor]];
    _light232 = [[LightingControl alloc] init];
    [_light232 openPort];
    _light232.brightness = _brightness;
    [_light232 lightOn];
    [self showMessage:@"[Init] Lighting init finish..." inColor:[NSColor greenColor]];

    if(_useMessagePort) {   // Init Message Port
        
        //Initialize the Message Port for communication with MesaHost, added by Antonio on 29-02-2016
        mpFromMesaHost = CFMessagePortCreateLocal ( NULL, CFSTR("TO_MESAMAC"), &onRecvMessageCallBack, NULL, NULL);
        CFRunLoopSourceRef source = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, mpFromMesaHost, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
        
    }
    else if(_useSocketPort) {   // Init Socket Port
        
        [self showMessage:@"[Init] Initializing socket port for MesaHost communication..." inColor:[NSColor blackColor]];

        socketServer = [[FastServerSocket alloc] initWithPort:[NSString stringWithFormat:@"%d", _socketPort]];
        [NSThread detachNewThreadSelector:@selector(listenSocketPortAndRepeat:) toTarget:self withObject:nil];
        [self showMessage:@"[Init] Finished startup socket port!" inColor:[NSColor blackColor]];
    }
    else
    {
        
        // Otherwise, use RS232
//    /******************* Init MESA RS232 *******************/
        [self showMessage:@"[Init] Initializing Serial port for MesaHost communication..." inColor:[NSColor blackColor]];
        [self delegateOpen];
        _commandBuffer = [[NSMutableString alloc] init];
        [self showMessage:@"[Init] Serial port monitor init finish..." inColor:[NSColor greenColor]];
    }
    
///******************* Init Motion *******************/
    [self showMessage:@"[Init] Initializing motion..." inColor:[NSColor blackColor]];
    _motion = [Googol_MotionIO sharedMyClass];
    [_motion open:_configDictionary withApp:self];

    [self showMessage:@"[Init] Motion init finish..." inColor:[NSColor greenColor]];
    
    _prevIsGoogolAlive = true;

    /******************* Init Camera *******************/
    [self showMessage:@"[Init] Initializing camera..." inColor:[NSColor blackColor]];
    //    _camera = [[FirewireCamera alloc] init];
    //    [_camera open_camera];
    //    [_camera set_camera_feature:@"exposure" :15000];
    
    //  For GigE cameras
    PvInitialize();
    [NSThread sleepForTimeInterval:2];
    
    _camera = [[GigECamera alloc] init];
    
    [_camera open_camera:[_camera find_camera_ID:[[NSString stringWithFormat:@"%s", CAM_A_NAME] UTF8String]]];
    _triggerMode = camera_software_trigger;
    [_camera setUint32:"ExposureValue" :250000];

    [self showMessage:@"[Init] Camera init finish..." inColor:[NSColor greenColor]];
    
    _pingCamTimer = [[NSTimer alloc] init];
    
    _pingCamTimer = [NSTimer scheduledTimerWithTimeInterval: 2
                                                     target: self
                                                   selector: @selector(pingCamera)
                                                   userInfo: nil
                                                    repeats: YES];
    
    _pingMotionTimer = [[NSTimer alloc] init];

    _pingMotionTimer = [NSTimer scheduledTimerWithTimeInterval: 2
                                                        target: self
                                                      selector: @selector(pingMotion)
                                                      userInfo: nil
                                                       repeats: YES];

    [self showMessage:@"[Init] System init finish" inColor:[NSColor greenColor]];
    
    _pingCamCycle = 100;
    _pingCamCount = 0;
    
    _isInterruptDutRelease = false;
    _isDutReleasing = false;
    
    _setup.enabled = true;
    
    if (!isMacbook) {
        for(int i=0; i<[[NSApp windows] count]; i++)
        {
            if ([[[[NSApp windows] objectAtIndex:i] identifier]  isEqual: @"MAINWINDOW"]) {
                [[[NSApp windows] objectAtIndex:i] setFrameTopLeftPoint:{0,200}];
            }
        }
    }
    else{
        _isReadyForTest = false;
    }
    
    _sysInitFin = true;
    return true;
}

- (void)workflow{
    
    [self systemInit];

    @autoreleasepool {
         _workFlag = WorkDefault;
        
        _statusThread = [[NSThread alloc] initWithTarget:self selector:@selector(statusCheck) object:nil];
        _statusThread.name = @"Status thread";
        [_statusThread start];
        
//        _updateThread = [[NSThread alloc] initWithTarget:self selector:@selector(updateStatus) object:nil];
//        _updateThread.name = @"Update thread";
//        [_updateThread start];
        @try {
            while (_workFlag) {
                
                if (_workFlag != WorkDefault) {
                    STOPTEST = FALSE;
                }
                //writeToLogFile( @"Start on WorkFlow: %i",_workFlag);
                switch(_workFlag)
                {
                        
   #pragma mark --WorkDefault
                    case WorkDefault:               //Default
                    {
                        @autoreleasepool {
                            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                        }
                        break;
                    }
   #pragma mark --WorkImageCapture
                    case WorkImageCapture:          //[XY] Capture
                    {
                        IMAGESAVING = true;
                        
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToCamPositionWithDisplay:_cameraNSView];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToCamPositionWithDisplay" isFirstTask:false];
                        }
                        else{
                            [self goToCamPositionWithDisplay:_cameraNSView];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkLeftProbePosition
                    case WorkLeftProbePosition:     //[XY] Left probe position
                    {
                        
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToLeftProbePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToLeftProbePosition" isFirstTask:false];
                        }
                        else{
                            [self goToLeftProbePosition];
                        }

                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkRightProbePosition
                    case WorkRightProbePosition:    //[XY] Right probe position
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToRightProbePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToRightProbePosition" isFirstTask:false];
                        }
                        else{
                            [self goToRightProbePosition];
                        }

                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkTopPosition
                    case WorkTopPosition:           //[Z1/Z2] Top position
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToTopProbePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToTopProbePosition" isFirstTask:false];
                        }
                        else{
                            [self goToTopProbePosition];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkConnPosition
                    case WorkConnPosition:          //[Z1/Z2] Conn position
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToConnProbePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToConnProbePosition" isFirstTask:false];
                        }
                        else{
                            [self goToConnProbePosition];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkHoverPosition
                    case WorkHoverPosition:         //[Z1/Z2] Hover psotion
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToHoverProbePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToHoverProbePosition" isFirstTask:false];
                        }
                        else{
                            [self goToHoverProbePosition];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkDownPosition
                    case WorkDownPosition:          //[Z1/Z2] Down position
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            //[self goToDownProbePosition];
                            [self goToDownProbePosition_V2];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToDownProbePosition" isFirstTask:false];
                        }
                        else{
                            //[self goToDownProbePosition];
                            [self goToDownProbePosition_V2];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkDUTPlacePosition
                    case WorkDUTPlacePosition:      //[XYZ1Z2] home
                    {
                        if (RECORD_PROCESSING_TIME) {
                            CFTimeInterval pt = CACurrentMediaTime();
                            [self goToHomePosition];
                            pt = CACurrentMediaTime() - pt;
                            [self logProcessingTime:pt ofTask:@"goToHomePosition" isFirstTask:false];
                        }
                        else{
                            [self goToHomePosition];
                        }
                        
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --WorkClean
                    case WorkClean:                 //[XYZ1Z2] Cleaning
                    {
                        if (isMacbook) {
                            if (RECORD_PROCESSING_TIME) {
                                CFTimeInterval pt = CACurrentMediaTime();
                                [self macbookCleanProbe];
                                pt = CACurrentMediaTime() - pt;
                                [self logProcessingTime:pt ofTask:@"CleanProbe" isFirstTask:false];
                            }
                            else{
                                [self macbookCleanProbe];
                            }
                        }
                        else{
                            [self goToClean];
                        }
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --CalXMovement
                    case CalXMovement:              //[X] STREAMING WINDOW x movement
                    {
                        _isAtHomePosition = false;
                        [self axisMovement:AXIS_X];
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --CalYMovement
                    case CalYMovement:              //[Y] STREAMING WINDOW y movement
                    {
                        _isAtHomePosition = false;
                        [self axisMovement:AXIS_Y];
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --CalZmovement
                    case CalZmovement:              //[Z1/Z2] STREAMING WINDOW z movement
                    {
                        _isAtHomePosition = false;
                        [self axisMovement:_myProbeStatus == MESARS232ProbeAtLeft? AXIS_Z1:AXIS_Z2];

                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --SendMessage
                   case SendMessage:
                    {
                        MESALog(@"Msg %@ send out in SMSG mode",_motion.cmdBuffer, NULL);
                       // [_spiderman addRecordWithData:[[NSString stringWithFormat:@"Msg %@ send out in SMSG mode\n",_motion.cmdBuffer] dataUsingEncoding:NSUTF8StringEncoding]];
                        
                        [_motion.tcpip writeOut:_motion.cmdBuffer];
                        _workFlag = WorkDefault;
                        break;
                    }
   #pragma mark --ReleaseDUT
                    case ReleaseDUT:
                    {
                        _isAtHomePosition = false;
                        [self macbookReleaseWithCleanning:false];
                        _workFlag = WorkDefault;
                        break;
                    }
                }//switch
                //writeToLogFile( @"End on WorkFlow: %i",_workFlag);
            }
        } @catch (NSException *exception) {
            writeToLogFile( @"Error on WorkFlow.");
            writeToLogFile( @"Error on WorkFlow: %@", exception.name);
            writeToLogFile( @"Error on WorkFlow Reason: %@", exception.reason );
        } @finally {
            
        }
        
     }
}
-(void)WriteLogOnThread{
    while (true) {
        try
        {
            [_spiderman collectData];
            [NSThread sleepForTimeInterval:0.1];
         
        }
        catch (NSException *exception)
        {
            try
            {
                MESALog(@"Error on WriteLogOnThread");
             
            }
            catch (NSException *exception)
            {
                 
            }
            
        }
    }
    
    
}

-(void)updateStatus
{
////    [_motion.tcpip.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
////                                          forMode:NSDefaultRunLoopMode];
////    [_motion.tcpip.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
//                                         forMode:NSDefaultRunLoopMode];
    
    while(true)
    {
        @autoreleasepool {
            [_motion getPosition:AXIS_X];
            [_motion getPosition:AXIS_Y];
            [_motion getPosition:AXIS_Z1];
            [_motion getPosition:AXIS_Z2];
            
            [_motion getForce:AXIS_Z1];
            [_motion getForce:AXIS_Z2];
            
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
            [NSThread sleepForTimeInterval:0.3];
        }
    }
}

-(void)statusCheck
{
//    [_motion.tcpip.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
//                                forMode:NSDefaultRunLoopMode];
//    [_motion.tcpip.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
//                                          forMode:NSDefaultRunLoopMode];
    while (true) {
    
        @try {
            //writeToLogFile( @"Start on statusCheck");
            @autoreleasepool {
    //            for (int i=0; i<50000; i++) {
    //                i++;
    //            }
                @autoreleasepool {
                    [NSThread sleepForTimeInterval:0.01];
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                }
                /******************* Power Detect *******************/
                //Matthew 2023/09/22 : DUT放上吸气
                if([_motion getSignal:INPUT portStatus:DI_MB_TOP_TOUCH_1] )
                {
                    
                    if(_TOP_TOUCH_Status)
                    {
                        [_motion setOutput:DO_TOP_VACUUM toState:IO_OFF];
                        [NSThread sleepForTimeInterval:0.1];
                        [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
                        [_motion setOutput:DO_TOP_VACUUM toState:IO_ON];
                        
                        [NSThread sleepForTimeInterval:0.3];
                        
                       if( [_motion getSignal:INPUT portStatus:DI_TOP_VACUUM_WARNING])
                       {
                           _TOP_TOUCH_Status=false;
                           MESALog(@"DI_TOP_VACUUM_WARNING is false ");
                       }
                        MESALog(@"have DUT ");
                    }
                   
                    
                    

                }else
                {
                    
                   
                    if(!_TOP_TOUCH_Status)
                    {
                        
                        //停真空
                        [_motion setOutput:DO_TOP_VACUUM toState:IO_ON];
                        [NSThread sleepForTimeInterval:0.1];
                        [_motion setOutput:DO_TOP_VACUUM toState:IO_OFF];
                        // 噴氣
                        [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_ON];
                    
                        
                        [NSThread sleepForTimeInterval:0.3];
                    
                        // 停噴氣
                        [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
                        if( ![_motion getSignal:INPUT portStatus:DI_TOP_VACUUM_WARNING])
                        {
                            _TOP_TOUCH_Status=true;
                            MESALog(@"DI_TOP_VACUUM_WARNING is true ");
                        }
                        
                        MESALog(@"without DUT ");
                       
                    }

                }
                
                if(![_motion getSignal:INPUT portStatus:DI_POWER] && _powerFlag)
                {
                    _powerFlag = false;
                    
                    if (isMacbook) {
                        //matthew 2023-08- 28
                        //// off  Short Cylinder
                        [self StartCylinder:DO_SHORT_CYLINDER_OFF:DI_SHORT_CYLINDER_INITIAl:@"DO_SHORT_CYLINDER_OFF"];
                        
                        // off long Cylinder
                        [self StartCylinder:DO_LONG_CYLINDER_OFF:DI_LEFT_LONG_CYLINDER_INITIAl:@"DO_LONG_CYLINDER_OFF"];
                        //end matthew
                        [_motion setOutput:DO_USB_CYLINDER toState:IO_OFF];
                        
                        // blow bottom vacuum
                        [_motion setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
                        [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
                        [_motion setOutput:DO_TOP_VACUUM toState:IO_OFF];
                        [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
                    }
                    
                    [self showMessage:@"[Warning] Fixture is off power" inColor:[NSColor orangeColor]];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.messageText = @"Fixture is off power, please reopen this app";
                        [alert runModal];
                    });
                    [self closeAppWithSaveLog];
                }
                else if([_motion getSignal:INPUT portStatus:DI_POWER] && !_powerFlag)
                {
                    _powerFlag = true;
                    
                    [_motion setOutput:DO_SIGNAL_GREEN toState:IO_ON];
                    [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
                    [_motion setOutput:DO_SIGNAL_RED toState:IO_OFF];
                    
                    [self showMessage:@"Fixture is on power" inColor:[NSColor greenColor]];
                }
                
                if([_motion getSignal:INPUT portStatus:DI_POWER])
                {
                    /******************* Axes Alarm Check *******************/
                    if(_motion.axesAlarm)
                    {
                        [_motion setOutput:DO_SIGNAL_GREEN toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_RED toState:IO_ON];
                        
                        for(int i=0;i<4;i++)
                        {
                            if (_motion.axesAlarm & 1<<i) {
                                if (!(_axesAlarmOn & 1<<i)) {
                                    [self showMessage:[NSString stringWithFormat:@"[Error] Axis %@ alarm is active, please close the software", [_motion.axes objectAtIndex:i+1]] inColor:[NSColor redColor]];
                                    _axesAlarmOn = _axesAlarmOn | 1<<i;
                                    
                                    _problemFlag++;
                                }
                            }
                            else
                            {
                                _axesAlarmOn = _axesAlarmOn & (0Xff - (1<<i));
                                _problemFlag--;
                            }
                        }
                    }
                    
                    if (!_homing) {
                        /******************* Positive Limit Check *******************/
                        if(_motion.axesPositiveLimit)
                        {
                            for(int i=0;i<4;i++)
                            {
                                if (_motion.axesPositiveLimit & 1<<i) {
                                    if (!(_positiveLimitOn & 1<<i)){
                                        [self showMessage:[NSString stringWithFormat:@"[Warning] Axis %@ possive limit sensor is active", [_motion.axes objectAtIndex:i+1]] inColor:[NSColor orangeColor]];
                                        _positiveLimitOn =  _positiveLimitOn & 1<<i;
                                    }
                                }
                                else
                                {
                                    _positiveLimitOn = _positiveLimitOn & (0Xff - (1<<i));
                                }
                            }
                        }
                        
                        /******************* Negative Limit Check *******************/
                        if(_motion.axesNegativeLimit)
                        {
                            for(int i=0;i<4;i++)
                            {
                                if (_motion.axesNegativeLimit & 1<<i) {
                                    if (!(_negativeLimitOn & 1<<i)){
                                        [self showMessage:[NSString stringWithFormat:@"[Warning] Axis %@ negative limit sensor is active", [_motion.axes objectAtIndex:i+1]] inColor:[NSColor orangeColor]];
                                        _negativeLimitOn = _negativeLimitOn & 1<<i;
                                    }
                                }
                                else
                                {
                                    _negativeLimitOn = _negativeLimitOn & (0Xff - (1<<i));
                                }
                            }
                        }
                    }
                    
                    
                    
                    /******************* Override key action  [Macbook fixture only] *************/
                    if (_prevOverrideKey == true && [_motion getSignal:INPUT portStatus:DI_OVERRIDE_KEY] == false && isMacbook){
                        // key inserted, enter calibration
                        MESALog(@"Open Setup page");
                        if (!CALIBRATION) {
                            [self clickSetup];
                        }
                    }
                    else if (_prevOverrideKey == false && [_motion getSignal:INPUT portStatus:DI_OVERRIDE_KEY] == true && isMacbook){
                        // key removed, quit calibration
                        MESALog(@"Close Setup page");
                        if (CALIBRATION){
                            [_config_window_macbook clickQuit];
                        }
                    }
                    
                    _prevOverrideKey = [_motion getSignal:INPUT portStatus:DI_OVERRIDE_KEY];

                    
                    /******************* Turn ON Top Vacuum when DUT put in, turn OFF when test done [Macbook fixture only] *************/
                    
                    bool curBotVac = [_motion getSignal:INPUT portStatus:DI_MB_BOTTOM_TOUCH_2];
                    
                    if (isMacbook && !_prevBotVac && curBotVac) {
                        _isReadyForTest = true;
                    }
                    else if (isMacbook && _prevBotVac && !curBotVac){
                        _isReadyForTest = false;
                    }
                    
                    if (isMacbook){
                        _prevBotVac = curBotVac;
                    }
                    
                    /****************** NEW Start Button Detect ***************/
                    if ([_motion getSignal:INPUT portStatus:DI_START_LEFT] && [_motion getSignal:INPUT portStatus:DI_START_RIGHT]) { //pressing two start buttons
                        _startFlag = true;
                        
                       
                    }
                    else if (![_motion getSignal:INPUT portStatus:DI_START_LEFT] && ![_motion getSignal:INPUT portStatus:DI_START_RIGHT]){ //releasing two start buttons
                        if (_startFlag == true) {   //raising edge detected
                            if (isMacbook) {
                                if ([_motion getInput:DI_USB_CYLINDER_BACK_LIMIT] && _isAtHomePosition){ //if(_isAtHomePosition){
                                    /* -----safety check for macbook -----*/
                                    bool safetyCheckDone = false;
                                    
                                    if (RECORD_PROCESSING_TIME) {
                                        CFTimeInterval pt = CACurrentMediaTime();
                                        safetyCheckDone = [self macbookSafetyCheck];
                                        pt = CACurrentMediaTime() - pt;
                                        [self logProcessingTime:pt ofTask:@"Load DUT with safety check" isFirstTask:true];
                                    }
                                    else{
                                        safetyCheckDone = [self macbookSafetyCheck];
                                    }
                                    
                                    if (!safetyCheckDone){
                                        // if fail safety check, run [macbookReleaseWithCleanning]
                                        if (RECORD_PROCESSING_TIME) {
                                            CFTimeInterval pt = CACurrentMediaTime();
                                            [self macbookReleaseWithCleanning:false];
                                            pt = CACurrentMediaTime() - pt;
                                            [self logProcessingTime:pt ofTask:@"Unload DUT when safety check fail" isFirstTask:false];
                                        }
                                        else{
                                            [self macbookReleaseWithCleanning:false];
                                        }
                                        /* -----safety check for macbook END----*/
                                    }
                                    else{
                                        //********** send ok singal to mesa host here *********************
                                    }
                                }
                                else{   // USB is plugging in DUT (Macbook product)
                                    if (RECORD_PROCESSING_TIME) {
                                        CFTimeInterval pt = CACurrentMediaTime();
                                        [self macbookReleaseWithCleanning:true];
                                        pt = CACurrentMediaTime() - pt;
                                        [self logProcessingTime:pt ofTask:@"Unload DUT" isFirstTask:false];
                                    }
                                    else{
                                        [self macbookReleaseWithCleanning:true];
                                    }
                                }
                            }
                            else{   // For iphone product
                                if (_isAtHomePosition){
                                    [self goToCamPositionWithDisplay:_cameraNSView];
                                    _isAtHomePosition = false;
                                }
                                else{
                                    [self goToHomePosition];
                                    _isAtHomePosition = true;
                                }
                            }
                        }
                        _startFlag = false;
                    }
                    
                    /******************* Reset Button Detect *******************/
                    if([_motion getSignal:INPUT portStatus:DI_RESET])
                    {
                        [self showMessage:@"Reset button pressed" inColor:[NSColor blackColor]];
                        
                        while ([_motion getInput:DI_MB_BOTTOM_TOUCH_1] || [_motion getInput:DI_MB_BOTTOM_TOUCH_2]) {
                            
                            if ([_motion getInput:DI_USB_CYLINDER_FRONT_LIMIT]) {
                                [_motion setOutput:DO_USB_CYLINDER toState:IO_OFF];
                            }
                            
                            if ([_motion getInput:DI_BOTTOM_VACUUM_WARNING]){
                                //停真空
                                [_motion setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
                            
                                // 噴氣
                                [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_ON];
                            
                                [NSThread sleepForTimeInterval:0.3];
                            
                                // 停噴氣
                                [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
                            }
                            
                            MESALog(@"[Warning] DUT inside fixture when reset button is pressed");
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                NSAlert *alert = [[NSAlert alloc] init];
                                alert.messageText = @"DUT inside fixture when axis homing, please take out DUT and then click OK";
                                [alert runModal];
                            });
                            [NSThread sleepForTimeInterval:0.2];
                        }
                        while ([_motion getInput:DI_FRONT_DOOR] == true){
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                NSAlert *alert = [[NSAlert alloc] init];
                                alert.messageText = @"Please CLOSE front door and then click OK";
                                MESALog(@"Request OP close foor when system init");
                                [alert runModal];
                            });
                        }
                        [_motion setOutput:DO_DOOR_LOCK toState: IO_ON];
                        [_motion goHome:AXIS_Z1];
                        [_motion goHome:AXIS_Z2];
                        [_motion waitMotor:AXIS_Z1];
                        [_motion waitMotor:AXIS_Z2];
                        
                        [_motion goHome:AXIS_X];
                        [_motion goHome:AXIS_Y];
                        [_motion waitMotor:AXIS_X];
                        [_motion waitMotor:AXIS_Y];
                        
                        [_motion setOutput:DO_SIGNAL_GREEN toState:IO_ON];
                        [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_RED toState:IO_OFF];
                        [_motion setOutput:DO_DOOR_LOCK toState: IO_OFF];
                    }
                    
                    /******************* Probe Force Limit *******************/
                    if([_motion getSignal:INPUT portStatus:DI_Z1_WARNING])
                    {
                        _force1Flag = true;

                        if (_probeDowning == false){
                            [_motion goTo:AXIS_Z1 withPosition:0];
                            [_motion goTo:AXIS_Z2 withPosition:0];
                            [_motion waitMotor:AXIS_Z1];
                            [_motion waitMotor:AXIS_Z2];
                            
                            STOPTEST = true;
                        }
                        
                        [self showMessage:@"[Error] Pressure at left probe is over limit" inColor:[NSColor redColor]];
                    }
                    else{
                        _force1Flag = false;
                    }
                    
                    if([_motion getSignal:INPUT portStatus:DI_Z2_WARNING] && _probeDowning == false)
                    {
                        _force2Flag = true;
                        
                        if (_probeDowning == false){
                            [_motion goTo:AXIS_Z1 withPosition:0];
                            [_motion goTo:AXIS_Z2 withPosition:0];
                            [_motion waitMotor:AXIS_Z1];
                            [_motion waitMotor:AXIS_Z2];
                        
                            STOPTEST = true;
                        }
                        
                        [self showMessage:@"[Error] Pressure at right probe is over limit" inColor:[NSColor redColor]];
                    }
                    else{
                        _force2Flag = false;
                    }
                    
                    if ((_force1Flag || _force2Flag)&&[_motion getSignal:OUTPUT portStatus:DO_SIGNAL_GREEN]&&![_motion getSignal:OUTPUT portStatus:DO_SIGNAL_YELLOW]&&![_motion getSignal:OUTPUT portStatus:DO_SIGNAL_RED]) {
                        
                        [_motion setOutput:DO_SIGNAL_GREEN toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_RED toState:IO_ON];
                    }
                    if (!_force1Flag&&!_force2Flag&&![_motion getSignal:OUTPUT portStatus:DO_SIGNAL_GREEN]&&![_motion getSignal:OUTPUT portStatus:DO_SIGNAL_YELLOW]&&[_motion getSignal:OUTPUT portStatus:DO_SIGNAL_RED]) {
                        [_motion setOutput:DO_SIGNAL_GREEN toState:IO_ON];
                        [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
                        [_motion setOutput:DO_SIGNAL_RED toState:IO_OFF];
                    }
                    
                    /******************* Re-release DUT when it was interrupted *******************/
                    if (isMacbook && _isInterruptDutRelease == true) {
                        MESALog(@"Re-release platform");
                        STOPTEST = false;
                        if ([self macbookReleaseWithCleanning:true]){
                            _isAtHomePosition = true;
                        }
                    }
    /*                if (isMacbook && _isInterruptDutRelease == true) {
                        if (isMacbook && ![_motion getSignal:INPUT portStatus:DI_FRONT_DOOR]) {
                            MESALog(@"Re-release platform");
                            STOPTEST = false;
                            if ([self macbookReleaseWithCleanning:true]){
                                _isAtHomePosition = true;
                            }
                        }
                    }
    */
                }
            }
            //writeToLogFile( @"End on statusCheck");
        } @catch (NSException *exception) {
            writeToLogFile( @"Error on WorkFlow.");
            writeToLogFile( @"Error on statusCheck: %@", exception.name);
            writeToLogFile( @"Error on statusCheck Reason: %@", exception.reason );
        } @finally {
            
        }
    }
}

- (NSString *)formatNumberToString :(float)input
{
    return [_formatter stringFromNumber:[NSNumber numberWithFloat:input]];
}

- (void)showMessage:(NSString *)msg inColor:(NSColor*)textColor;
{
    @autoreleasepool {
        
        NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *attrsDictionary =[NSDictionary dictionaryWithObject:textColor forKey:NSForegroundColorAttributeName];
            NSAttributedString* attrString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - %@\n", dateTimeStr, msg] attributes:attrsDictionary];
            [[_msgBox textStorage] appendAttributedString:attrString];
            [_msgBox scrollRangeToVisible:NSMakeRange([[_msgBox string] length], 0)];
        });
        
        MESALog(@"%@", msg);
    }
    
}

- (NSString *)inputPassword:(NSString *)prompt
{

    NSInteger button;
    NSSecureTextField *input;
    
    dispatch_sync(dispatch_get_main_queue(), ^{

        NSAlert *alert = [NSAlert alertWithMessageText: prompt
                                         defaultButton:@"OK"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@""];
        
        __block NSSecureTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        
        [alert setAccessoryView:input];
        __block NSInteger button = [alert runModal];
    });

    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    }
    else if (button == NSAlertAlternateReturn) {
        return nil;
    }
    else {
        return nil;
    }
}

-(void) closeAppWithSaveLog{
    [_motion setOutput:DO_DOOR_LOCK toState:IO_OFF];
    [_spiderman collectData];
    exit(0);
}

-(void)paraRefresh{
    _posCameraX = [[_settingsDictionary objectForKey:@"camera_x"] floatValue];
    _posCameraY = [[_settingsDictionary objectForKey:@"camera_y"] floatValue];
    _posCameraCX = [[_settingsDictionary objectForKey:@"camera_cx"] floatValue];
    _posCameraCY = [[_settingsDictionary objectForKey:@"camera_cy"] floatValue];
    
    _ratio = [[_settingsDictionary objectForKey:@"pixel_to_mm_ratio"] floatValue];

    _posCleanX = [[_settingsDictionary objectForKey:@"clean_x"] floatValue];
    _posCleanY = [[_settingsDictionary objectForKey:@"clean_y"] floatValue];
    _posCleanZ1 = [[_settingsDictionary objectForKey:@"clean_z1"] floatValue];
    _posCleanZ2 = [[_settingsDictionary objectForKey:@"clean_z2"] floatValue];
    _cleaningCycle = [[_settingsDictionary objectForKey:@"cleaning_cycle"] intValue];
    _cleaningGap = [[_settingsDictionary objectForKey:@"cleaning_gap"] floatValue];
    
    _posProbe1X = [[_settingsDictionary objectForKey:@"probe1_x"] floatValue];
    _posProbe1Y = [[_settingsDictionary objectForKey:@"probe1_y"] floatValue];
    _posProbe1Conn = [[_settingsDictionary objectForKey:@"probe1_conn"] floatValue];
    _posProbe1Hover = [[_settingsDictionary objectForKey:@"probe1_hover"] floatValue];
    
    _posProbe2X = [[_settingsDictionary objectForKey:@"probe2_x"] floatValue];
    _posProbe2Y = [[_settingsDictionary objectForKey:@"probe2_y"] floatValue];
    _posProbe2Conn = [[_settingsDictionary objectForKey:@"probe2_conn"] floatValue];
    _posProbe2Hover = [[_settingsDictionary objectForKey:@"probe2_hover"] floatValue];
    
    _pressureLeft = [[_settingsDictionary objectForKey:@"pressure_left"] floatValue];
    _pressureRight = [[_settingsDictionary objectForKey:@"pressure_right"] floatValue];
    _fixtureID = [[_settingsDictionary objectForKey:@"fixture_id"] intValue];
    _testerID = [[_settingsDictionary objectForKey:@"tester_id"] intValue];
    _softwareID = [_settingsDictionary objectForKey:@"software_id"];
    _useMessagePort = [[_settingsDictionary objectForKey:@"use_message_port"] boolValue];
    _useSocketPort = [[_settingsDictionary objectForKey:@"use_socket_port"] boolValue];
    _socketPort = [[_settingsDictionary objectForKey:@"socket_port"] intValue];

    _dutY = [[_settingsDictionary objectForKey:@"dut_y"] floatValue];
    _pidP = [[_settingsDictionary objectForKey:@"pid_p"] floatValue];
    _pidD = [[_settingsDictionary objectForKey:@"pid_d"] floatValue];
    _cleaningCycle = [[_settingsDictionary objectForKey:@"cleaning_cycle"] intValue];
    _brightness = [[_settingsDictionary objectForKey:@"brightness"] intValue];
    _brightness2 = [[_settingsDictionary objectForKey:@"brightness2"] intValue];
}

#pragma mark - Button
- (IBAction)clickStart:(id)sender {
    if(!_isRunningTest)
    {
        [self showMessage:@"Start button clicked." inColor:[NSColor blackColor]];
        _isRunningTest = true;
        _testThread = [[NSThread alloc] initWithTarget:self selector:@selector(testStep) object:nil];
        _testThread.name = @"start button test thread";
        [_testThread start];
    }
}

-(void)testStep{
    STOPTEST = false;
    for(int i=0 ; i<30000 ; i++)
    {
        @autoreleasepool {
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test start",i] inColor:[NSColor blackColor]];
            
            _workFlag = WorkImageCapture;
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto capture fin",i] inColor:[NSColor blackColor]];
            
            if (!STOPTEST)
                _workFlag = WorkLeftProbePosition;
            else
                break;
            
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto left probe fin",i] inColor:[NSColor blackColor]];
            
            if (!STOPTEST)
                _workFlag = WorkDownPosition;
            else
                break;
            
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto hover fin",i] inColor:[NSColor blackColor]];
            
            if (!STOPTEST)
                _workFlag = WorkTopPosition;
            else
                break;
            
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto top fin",i] inColor:[NSColor blackColor]];
            
            if (!STOPTEST)
                _workFlag = WorkDUTPlacePosition;
            else
                break;
            
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto home fin",i] inColor:[NSColor blackColor]];
            
            if (!STOPTEST)
                _workFlag = WorkClean;
            else
                break;
            
            while (_workFlag != WorkDefault) {
                [NSThread sleepForTimeInterval:0.0001];
            }
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test goto clean fin",i] inColor:[NSColor blackColor]];
            
            [self showMessage:[NSString stringWithFormat:@"[Test %d]Test finish\n",i] inColor:[NSColor blackColor]];
        }
    }
    _isRunningTest = false;
    _workFlag = WorkDUTPlacePosition;
}

- (IBAction)clickStop:(id)sender {
    STOPTEST = true;
    [self showMessage:@"Stop button clicked." inColor:[NSColor blackColor]];
}

//- (IBAction)clickSetup:(id)sender {
- (void)clickSetup{

    dispatch_async(dispatch_get_main_queue(), ^{
        if(!_setupOpen)
        {
            //if([[self inputPassword:@"Please enter password"] isEqualToString:@"metron"]){
            if (isMacbook) {
                MESALog(@"Stop all axis before enter calibration page");
                [_motion disableAxis];

                [_motion stopAxis:AXIS_X isOriginalStop_Z:true];
                [_motion stopAxis:AXIS_Y isOriginalStop_Z:true];
                [_motion stopAxis:AXIS_Z1 isOriginalStop_Z:true];
                [_motion stopAxis:AXIS_Z2 isOriginalStop_Z:true];
                                
                MESALog(@"open macbook calibration page");
                _config_window_macbook = [[CalibrationMacBook alloc] initWithWindowNibName:@"CalibrationMacBook"];
                _config_window_macbook.app = self;
                [_config_window_macbook showWindow:self];
            }
            else {
                _config_window = [[Calibration alloc]initWithWindowNibName:@"Calibration"];
                _config_window.app = self;
                [_config_window showWindow:self];
            }
            _setupOpen = true;
            //}
        }
        else{
            // if calibration page is already opened, bring it to front
            for (int i = 0; i < [[NSApp windows] count]; i++){
                if ([[[[NSApp windows] objectAtIndex:i] identifier] isEqual: @"MAINWINDOW"] == false){
                    [[[NSApp windows] objectAtIndex:i] makeKeyAndOrderFront:[[[NSApp windows] objectAtIndex:i] identifier]];
                    break;
                }
            }
        }
    });
    }

- (IBAction)clickQuit:(id)sender {
    
    MESALog(@"Quit button clicked.");
    [self closeAppWithSaveLog];
    
}

#pragma mark - Work Method
-(bool)macbookSafetyCheck{
    
    @autoreleasepool {

        // (1) Check front door is close or not
        if ([_motion getSignal:INPUT portStatus:DI_FRONT_DOOR] == false){
            // Door closed and locked
            MESALog(@"(i) Door is closed");
        }
        else{
            MESALog(@"[Error]AppDelegate.SafetyCheck, Door not close when pressing start button");
            [self showMessage:@"[Error] Door not closed" inColor:[NSColor redColor]];
            return false;
        }
        
        // (2) Lock door and check is it locked of not
        [_motion setOutput:DO_DOOR_LOCK toState:IO_ON];
        bool isLocked = false;
        for (int i = 0; i < 1000; i++){
            if (![_motion getSignal:INPUT portStatus:DI_FRONT_DOOR_LOCKED]) {
                isLocked = true;
                break;
            }
            [NSThread sleepForTimeInterval:0.005];
        }
        if (!isLocked){
            [self showMessage:@"[Error] Door cannot be locked" inColor:[NSColor redColor]];
            return false;
        }

        // (7) re-enable all axis
        bool isHbbClear;
        [_motion disableAxis];
        isHbbClear = [_motion enableAxis : false];
        if (isHbbClear == false){
            [self showMessage : @"[Error]Hbb cannot be cleared, please reopen front door then close it" inColor:[NSColor redColor]];
            return false;
        }
        
        // (3) Check 8 touching sensors
        bool isTouching[2];
        isTouching[0] = [_motion getSignal:INPUT portStatus:DI_MB_BOTTOM_TOUCH_1];
        isTouching[1] = [_motion getSignal:INPUT portStatus:DI_MB_BOTTOM_TOUCH_2];
        
       
        for (int i = 0; i < 2; i++){
            if (isTouching[i] == true) {
                continue;
            }
            else{
                MESALog(@"[Error]AppDelegate.SafetyCheck, DUT is not put properly");
                [self showMessage:@"[Error] DUT is not put properly" inColor:[NSColor redColor]];
                return false;
            }
        }
        MESALog(@"(ii) DUT is touching all 2 sensors");
        bool isTopVacuumOK = false;
        if ([_motion getSignal:INPUT portStatus:DI_TOP_VACUUM_WARNING]) {
            isTopVacuumOK = true;

        }
          
        
      
        
        if(isTopVacuumOK )
        {
            MESALog(@"(v) Top vacuum OK");
          
        }else
        {
            [_motion setOutput:DO_TOP_VACUUM toState:IO_OFF];
            [self showMessage:@"[Error] Top Vacuum is not Ok" inColor:[NSColor redColor]];
            return false;
        }
        
        // (5) Turn ON bottom vacuum
        MESALog(@"(iv) Start bottom vacuum");
        //[_motion setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
        [NSThread sleepForTimeInterval:0.1];
        [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
        [_motion setOutput:DO_BOTTOM_VACUUM toState:IO_ON];
        //[_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
        //[_motion setOutput:DO_TOP_VACUUM toState:IO_ON];
        
        [_motion getInput:DI_BOTTOM_VACUUM_WARNING];
        
        [NSThread sleepForTimeInterval:0.1];
        for (int i = 0; i < 10; i++){
            if ([_motion getSignal:INPUT portStatus:DI_BOTTOM_VACUUM_WARNING]) {
                 
                break;
            }
            else
            {
                [_motion setOutput:DO_BOTTOM_VACUUM toState:IO_ON];
                [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
                [NSThread sleepForTimeInterval:0.05];
                
                [_motion getInput:DI_BOTTOM_VACUUM_WARNING];
                MESALog(@"[Error]Loop, Bottom Vacuum is not OK");
            }
            [NSThread sleepForTimeInterval:0.05];
        }
        
        
        // Check if the bottom vacuum is OK or not
        bool isBotVacuumOK = false;
        for (int i = 0; i < 1000; i++){
            if ([_motion getSignal:INPUT portStatus:DI_BOTTOM_VACUUM_WARNING]) {
                isBotVacuumOK = true;
                break;
            }
            [NSThread sleepForTimeInterval:0.005];
        }
        
        if (isBotVacuumOK) {
            MESALog(@"(v) Bottom vacuum OK");
        }
        else{
           
            MESALog(@"[Error]AppDelegate.SafetyCheck, Bottom Vacuum is not OK");
            [self showMessage:@"[Error] Bottom Vacuum is not OK" inColor:[NSColor redColor]];
            return false;
        }
        //matthew 2023-08-27
        // on Short Cylinder
        [self StartCylinder:DO_SHORT_CYLINDER_ON:DI_SHORT_CYLINDER_WORK:@"DO_SHORT_CYLINDER_ON"];
        //// off  Short Cylinder
        [self StartCylinder:DO_SHORT_CYLINDER_OFF:DI_SHORT_CYLINDER_INITIAl:@"DO_SHORT_CYLINDER_OFF"];
        
        // on long Cylinder
        [self StartCylinder:DO_LONG_CYLINDER_ON:DI_LEFT_LONG_CYLINDER_WORK:@"DO_LONG_CYLINDER_ON"];
        
        // off long Cylinder
        [self StartCylinder:DO_LONG_CYLINDER_OFF:DI_LEFT_LONG_CYLINDER_INITIAl:@"DO_LONG_CYLINDER_OFF"];
        
        
        // on Short Cylinder
        [self StartCylinder:DO_SHORT_CYLINDER_ON:DI_SHORT_CYLINDER_WORK:@"DO_SHORT_CYLINDER_ON"];
        // on long Cylinder
        [self StartCylinder:DO_LONG_CYLINDER_ON:DI_LEFT_LONG_CYLINDER_WORK:@"DO_LONG_CYLINDER_ON"];
       //end matthew
        [_motion setOutput:DO_USB_CYLINDER toState:IO_ON];      // plug USB cable

        // (6) check USB plug successfully or not
        bool isUsbPlug = false;
        for (int i = 0; i < 500; i++) {
            if ([_motion getSignal:INPUT portStatus:DI_USB_CYLINDER_FRONT_LIMIT]) {
                isUsbPlug = true;
                break;
            }
            [NSThread sleepForTimeInterval:0.005];
        }
        if (isUsbPlug){
            MESALog(@"(vi) USB plug in successfully");
        }
        else{
            MESALog(@"[Error]AppDelegate.SafetyCheck, USB is not put properly");
            [self showMessage:@"[Error] USB not put properly" inColor:[NSColor redColor]];
            //Turn OFF front green light
            [_motion setOutput:DO_FRONT_LED toState:IO_OFF];
            return false;
        }
        
        // Turn ON Ion fan
        [_motion setOutput:DO_ION_FAN toState:IO_ON];
        
        // (8) Turn OFF front green light
        [_motion setOutput:DO_FRONT_LED toState:IO_OFF];
    }
    
    
    isForceQuitPID = false;
    
    return true;
}
- (bool)StartCylinder:(int) DO_Port:(int)DI_Port:(NSString *)DO_Name {
     
    return true;
}



-(bool)macbookReleaseWithCleanning:(bool)isCountCleanning{

    _isDutReleasing = true;             //For stop Axis used
    _isInterruptDutRelease = false;     //This flag only be set to TRUE in Googol waitMotor method, for stop Axis used
    _isReleaseDutFinish = false;        //For reply DUT used
    
    [_motion setOutput:DO_ION_FAN toState:IO_OFF];      //Tuen OFF ion fan

    if (_probeDowning){
        isForceQuitPID = true;                    //For breaking PID loop
        [self showMessage:@"[Error] Start buttons are pressed during probe down" inColor:[NSColor redColor]];
    }

    while (_probeDowning) {                  //polling until PID loop is force quit completed
        [NSThread sleepForTimeInterval:0.2];
    }
    
    if (isAutoReleaseDUT == false) {
        // remove USB first
        MESALog(@"[DUT unload] release USB");
        //matthew 2023-08- 28
        //// off  Short Cylinder
        [self StartCylinder:DO_SHORT_CYLINDER_OFF:DI_SHORT_CYLINDER_INITIAl:@"DO_SHORT_CYLINDER_OFF"];
        
        // off long Cylinder
        [self StartCylinder:DO_LONG_CYLINDER_OFF:DI_LEFT_LONG_CYLINDER_INITIAl:@"DO_LONG_CYLINDER_OFF"];
        //end matthew
        [_motion setOutput:DO_USB_CYLINDER toState:IO_OFF];
        while (![_motion getSignal:INPUT portStatus:DI_USB_CYLINDER_BACK_LIMIT]){
            [NSThread sleepForTimeInterval:0.005];
        }
        MESALog(@"[DUT unload] release USB done");
    }
    
    // check Z1 and Z2 is up or not, if not, go Top and delay 1 second
    if ( [[_motion.axesPosition objectAtIndex:AXIS_Z1] floatValue] != 0.0 || [[_motion.axesPosition objectAtIndex:AXIS_Z2] floatValue] != 0.0 ){
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z2];
        
        [NSThread sleepForTimeInterval:0.5];
    }
    
    if (_isInterruptDutRelease == true) {
        MESALog(@"macbookReleaseWithCleanning returns false after probe up is interrupted");
        return false;
    }
    
    if (isAutoReleaseDUT == false) {
        if (isCountCleanning && [_motion getSignal:INPUT portStatus:DI_BOTTOM_VACUUM_WARNING]) {
            // decide clean the probe or not
            [self macbookCleanProbe];
        }
    }

    if (_isInterruptDutRelease == true) {
        MESALog(@"macbookReleaseWithCleanning returns false after cleaning is interrupted");
        return false;
    }
    
    // check Z1 and Z2 is up or not, if not, go Top and delay 1 seconds
    if ( [[_motion.axesPosition objectAtIndex:AXIS_Z1] floatValue] != 0.0 || [[_motion.axesPosition objectAtIndex:AXIS_Z2] floatValue] != 0.0 ){
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z2];
        
        MESALog(@"macbookReleaseWithCleanning delay 0.5s after probe up");
        [NSThread sleepForTimeInterval:0.5];
    }
    
    [self goToHomePosition];
    
    if (_isInterruptDutRelease == true) {
        MESALog(@"macbookReleaseWithCleanning returns false after goToHomePosition is interrupt");
        return false;
    }
    
    _isReleaseDutFinish = true;     // put this flag here bezcause we wants some times for fixture replys DUT "DUT release finish"

    //停真空
    [_motion setOutput:DO_BOTTOM_VACUUM toState:IO_OFF];
    
    // 噴氣
    [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_ON];
    //matthew 2023-09-22 背部噴氣
    [_motion setOutput:DO_TOP_VACUUM toState:IO_OFF];
    [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_ON];
    //end by matthew
    
    [NSThread sleepForTimeInterval:0.3];
    
    // 停噴氣
    [_motion setOutput:DO_BOTTOM_ANTI_VACUUM toState:IO_OFF];
    [_motion setOutput:DO_TOP_ANTI_VACUUM toState:IO_OFF];
    
    if (isAutoReleaseDUT == true) {
        // remove USB
        MESALog(@"[DUT unload] release USBs");
        //matthew 2023-08- 28
        //// off  Short Cylinder
        [self StartCylinder:DO_SHORT_CYLINDER_OFF:DI_SHORT_CYLINDER_INITIAl:@"DO_SHORT_CYLINDER_OFF"];
        
        // off long Cylinder
        [self StartCylinder:DO_LONG_CYLINDER_OFF:DI_LEFT_LONG_CYLINDER_INITIAl:@"DO_LONG_CYLINDER_OFF"];
        //end matthew
        [_motion setOutput:DO_USB_CYLINDER toState:IO_OFF];
        while (![_motion getSignal:INPUT portStatus:DI_USB_CYLINDER_BACK_LIMIT]){
            [NSThread sleepForTimeInterval:0.005];
        }
        MESALog(@"[DUT unload] release USB done");
    }
    
    //unlock door
    [_motion setOutput:DO_DOOR_LOCK toState:IO_OFF];

    //Turn ON front green light
    [_motion setOutput:DO_FRONT_LED toState:IO_ON];

    _isReadyForTest = false;
    _isDutReleasing = false;
    _isInterruptDutRelease = false;

    return true;
}

-(void)macbookCleanProbe{
    
    _isCleaningFinish = false;
    
    MESALog(@"In probe cleaning progress");
    
    if (_cleaningCycle == 0) {
        return;
    }
    else{
        if (_macbookCount >= _cleaningCycle) {
            _macbookCount = 1;
        }
        else{
            _macbookCount++;
            return;
        }
    }
    
    float currentCleanX = _posCleanX;
    float currentCleanY = _posCleanY;
    
    const float cleaningOffsetX = 20;
    const float cleaningOffsetY = 10;
    
    int tempConut = 0;
    
    /* cleaning position, totoal 6 position
        ______
        |  0 |
        |  1 |
        |  2 |
        |  3 |  <-- This is cleaning gel pad
        |  4 |
        |  5 |
        ------
     */
    for (int y = 0; y < 6; y++){
        if (tempConut == _cleancount) {
            currentCleanX = _posCleanX;// + (x * cleaningOffsetX);
            currentCleanY = _posCleanY + (y * cleaningOffsetY);
        }
        tempConut++;
    }
    
    
    //probe up
    [_motion goTo:AXIS_Z1 withPosition:0];
    [_motion goTo:AXIS_Z2 withPosition:0];
    [_motion waitMotor:AXIS_Z1];
    [_motion waitMotor:AXIS_Z2];
    
    //goto clean_x, clean_y
    [_motion goTo:AXIS_X withPosition:currentCleanX];
    [_motion waitMotor:AXIS_X];
    [_motion goTo:AXIS_Y withPosition:currentCleanY];
    [_motion waitMotor:AXIS_Y];
    
    //probe down for cleaning
    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
    [_motion waitMotor:AXIS_Z1];
    
    //probe up again
    [_motion goTo:AXIS_Z1 withPosition:0];
    [_motion goTo:AXIS_Z2 withPosition:0];
    [_motion waitMotor:AXIS_Z1];
    [_motion waitMotor:AXIS_Z2];
    
    //goto clean_x + clean_dis, clean_y
    [_motion goTo:AXIS_X withPosition:currentCleanX + _cleaningGap];
    [_motion waitMotor:AXIS_X];
    [_motion goTo:AXIS_Y withPosition:currentCleanY];
    [_motion waitMotor:AXIS_Y];
    
    //probe down for cleaning
    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
    [_motion waitMotor:AXIS_Z1];
    
    //probe up again
    [_motion goTo:AXIS_Z1 withPosition:0];
    [_motion goTo:AXIS_Z2 withPosition:0];
    [_motion waitMotor:AXIS_Z1];
    [_motion waitMotor:AXIS_Z2];
    
    //reset cleancount if probe in position 5
    _cleancount >= 5 ? _cleancount = 0 : _cleancount++;
    
    _isCleaningFinish = true;
}

-(void)goToCamPositionWithDisplay:(NSImageView *)cameraView
{
    
    CFTimeInterval goCapPosStart = 0;
    CFTimeInterval goCapPosFin = 0;

    CFTimeInterval wholeCapStart = 0;
    CFTimeInterval wholeCapFin = 0;
    
    
    @autoreleasepool {
        goCapPosStart = CACurrentMediaTime();
        MESALog(@"[Action] go to capture position", NULL);
        //prob = 0;       //(A0)
        _myProbeStatus = MESARS232ProbeAtCpature;
        
        _isCaptureFinish = false;
//        _myStatus = (MESARS232ActionStatus)(_myStatus | MESARS232Capturing);
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        [_motion waitMotor:AXIS_Z2];
        
        [_motion goTo:AXIS_X withPosition:_posCameraX];
        [_motion goTo:AXIS_Y withPosition:_posCameraY];
        [_motion waitMotor:AXIS_X];
        [_motion waitMotor:AXIS_Y];
        
        
        //init timer
        _motion.timeOut = NO;
        _motion.runloopTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:TIMEOUT_TOLERANCE];
        
        //[_camera capture_image_in :single_capture_mode FIXTURE:_cameraNSView :_cameraIKView];
        goCapPosFin = CACurrentMediaTime();
        wholeCapStart = goCapPosFin;
        
        for(int i=6 ; i<=6 ; i++)
        {
//            MESALog(@"The %d time capture",i, NULL);
            //[_light232 lightOn];
            
            if (i<6) {
                [_light232 lightOnWithBrightness:20+10*i];
                [NSThread sleepForTimeInterval:0.5];
            }
            if (i == 6) {
                [_light232 lightOn];
                [NSThread sleepForTimeInterval:0.5];
            }
            //sleep(1);
            
            int reCaptureTime = 0;
        recapture:
            if (CALIBRATION) {
                
                if (isMacbook){
                    [_camera capture_image_in_mode : camera_software_trigger
                                     num_of_frames : camera_single_frame_capture
                                       ns_img_view : _config_window_macbook.cameraView
                                image_process_mode : find_circle_mode];
                }
                else{
                    
                    [_camera capture_image_in_mode :camera_software_trigger
                                     num_of_frames : camera_single_frame_capture
                                       ns_img_view : _config_window.cameraView
                                image_process_mode : find_circle_mode];
                    
                }
                
            }else
            {
                // Modify here to enable detection for two different modules for J152
                if (isMacbook) {
                    
                    if(_brightness2 != 0) {

                        float roi_avg_intensity;
                        
                        MESALog(@"Set lighting brightness to %d.", _brightness2);

                        [_light232 lightOnWithBrightness:_brightness2];
                        [NSThread sleepForTimeInterval:0.5];

                        MESALog(@"Get ROI average intensity.");

                        [_camera capture_image_in_mode : camera_software_trigger
                                                              num_of_frames : camera_single_frame_capture
                                                                ns_img_view : cameraView
                                                         image_process_mode : calculate_roi_intensity_average];

                        roi_avg_intensity = _camera.roiAvgIntensity;
                        MESALog(@"ROI avg intensity = (%f)", roi_avg_intensity);
                        
                        // Very shiny surface, use smaller brightness value
                        if(roi_avg_intensity > 200) {

                            MESALog(@"Over-exposed, set lighting brightness to %d.", _brightness);

                            [_light232 lightOnWithBrightness:_brightness];
                            [NSThread sleepForTimeInterval:0.5];
                        }
                        
                        MESALog(@"Find circle for alignment.");

                        [_camera capture_image_in_mode : camera_software_trigger
                                         num_of_frames : camera_single_frame_capture
                                           ns_img_view : cameraView
                                    image_process_mode : find_circle_mode];

                    }
                    else {
                        
                        [_light232 lightOnWithBrightness:_brightness];
                        [NSThread sleepForTimeInterval:0.5];

                        [_camera capture_image_in_mode : camera_software_trigger
                                         num_of_frames : camera_single_frame_capture
                                           ns_img_view : cameraView
                                    image_process_mode : find_circle_mode];
                    }
                }
                else {
                    
                    [_light232 lightOnWithBrightness:_brightness];
                    [NSThread sleepForTimeInterval:0.5];

                    [_camera capture_image_in_mode : camera_software_trigger
                                     num_of_frames : camera_single_frame_capture
                                       ns_img_view : cameraView
                                image_process_mode : find_circle_mode];
                }
            }
            
            MESALog(@"center get from appDelegate = (%f, %f)", _camera.centerX, _camera.centerY);
            
            while(_camera.is_capturing && !STOPTEST && !_motion.timeOut)
            {
                @autoreleasepool {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
                    [NSThread sleepForTimeInterval:0.001];
                }
            }
            
            if (_motion.timeOut && _camera.is_capturing && reCaptureTime < 6) {
                MESALog(@"[Warning]Camera capture time out, re-capture now", NULL);
                reCaptureTime++;
                goto recapture;
            }
            else
            {
                [_motion timerReset];
            }
            
//            usleep(10000);
//            [_light232 lightOff];
        }
        
        //sleep(1);
        //[_light232 lightOff];
        
        if(_camera.centerX <= 0 && _camera.centerY <= 0)
        {
            if (isMacbook) {
                [self showMessage:@"--[Error]Circle not found." inColor:[NSColor redColor]];
                offsetX = 0;
                offsetY = 0;
            }
            else{
                [self showMessage:@"--[Error]Circle not found." inColor:[NSColor redColor]];
                offsetX = 0;
                offsetY = 0;
            }
        }
        else{
            // Calculate the offset from centre
            if  (isMacbook){
                offsetX = (_camera.centerX - _posCameraCX) * _ratio;
                offsetY = (_camera.centerY - _posCameraCY) * _ratio;
            }
            else{
                offsetX = (_posCameraCX - _camera.centerX) * _ratio;
                offsetY = (_posCameraCY - _camera.centerY) * _ratio;
                //offsetX = TESTVALUE;
                //offsetY = TESTVALUE;
            }
        }
        
        if ([TestInfoController isTestMode]) {
            [self showMessage:[NSString stringWithFormat:@"--Circle centre: (%@, %@)", [self formatNumberToString:_camera.centerX], [self formatNumberToString:_camera.centerY]] inColor:[NSColor greenColor]];
        }
        wholeCapFin = CACurrentMediaTime();

        
        
        //grabpos = 1;                //回复到位
        _isCaptureFinish = true;
    }
    
    MESALog(@"[Action] go to capture position", NULL);
    
    if (RECORD_PROCESSING_TIME) {
        float t1 = (goCapPosFin - goCapPosStart);
        float t2 = (wholeCapFin - wholeCapStart);
        [self logProcessingTime: t1 ofTask:@"goToCapturePosition" isFirstTask:false];
        [self logProcessingTime:t2 ofTask:@"captureAndImageProcessing" isFirstTask:false];
    }
}

-(void)goToLeftProbePosition{
    @autoreleasepool {
        MESALog(@"[Action] go to left position", NULL);
        
        //prob = 1;      //(L2)
        _myProbeStatus = MESARS232ProbeAtLeft;
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        
        //LRpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus | MESARS232LeftRightProbeMoving);
        _isAtLeftRightPosition = false;
        
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        [_motion waitMotor:AXIS_Z2];
        
        if (isMacbook) {
            MESALog(@" isMacbook offset x = %f, offset y = %f", offsetX, offsetY);
            MESALog(@"Go to  Probe Positionx = %f, offset y = %f", _posProbe1X - offsetX, _posProbe1Y + offsetY);
            [_motion goTo:AXIS_X withPosition:_posProbe1X - offsetX];
            [_motion goTo:AXIS_Y withPosition:_posProbe1Y + offsetY];
        }
        else{
            MESALog(@"offset x = %f, offset y = %f", offsetX, offsetY);
            MESALog(@"Go to  Probe Positionx = %f, offset y = %f", _posProbe1X + offsetX, _posProbe1Y + offsetY);
            [_motion goTo:AXIS_X withPosition:_posProbe1X + offsetX];
            [_motion goTo:AXIS_Y withPosition:_posProbe1Y + offsetY];
        }
        [_motion waitMotor:AXIS_X];
        [_motion waitMotor:AXIS_Y];
        
        //LRpos = 1;//回复到位
//        _myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232LeftRightProbeMoving);
        _isAtLeftRightPosition = true;
    }
}

-(void)goToRightProbePosition{
    @autoreleasepool {
        MESALog(@"[Action] go to right probe position", NULL);
        
        //prob = 2;      //(R2)
        _myProbeStatus = MESARS232ProbeAtRight;
        
        //LRpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus | MESARS232LeftRightProbeMoving);
        _isAtLeftRightPosition = false;
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        [_motion waitMotor:AXIS_Z2];
        
        if (isMacbook) {
            [_motion goTo:AXIS_X withPosition:_posProbe2X + offsetY];
            [_motion goTo:AXIS_Y withPosition:_posProbe2Y + offsetX];
        }
        else{
            [_motion goTo:AXIS_X withPosition:_posProbe2X + offsetX];
            [_motion goTo:AXIS_Y withPosition:_posProbe2Y + offsetY];
        }
        [_motion waitMotor:AXIS_X];
        [_motion waitMotor:AXIS_Y];
        
        //LRpos = 1;//回复到位
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232LeftRightProbeMoving);
        _isAtLeftRightPosition = true;
    }
}

-(void)goToTopProbePosition{
    @autoreleasepool {
        MESALog(@"[Action] go to top position", NULL);
        
        //updownpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus | zMoving);
        _zProbeStatus = MESARS232ProbeDefault;
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        [_motion waitMotor:AXIS_Z2];
        
        //reset 2 froce meter reading to 0 kg
        [_motion setOutput: DO_Z1_FORCE_CLEAR toState:IO_ON];
        [_motion setOutput: DO_Z2_FORCE_CLEAR toState:IO_ON];
        [_motion setOutput: DO_Z1_FORCE_CLEAR toState:IO_OFF];
        [_motion setOutput: DO_Z2_FORCE_CLEAR toState:IO_OFF];
        
        //updownpos = 1;//回复到位
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232ZTopPosition);
        _zProbeStatus = MESARS232ProbeTopPosition;
    }
}

-(void)goToConnProbePosition{
    @autoreleasepool {
        MESALog(@"[Action] go to conn position", NULL);
        //updownpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ zMoving);
        _zProbeStatus = MESARS232ProbeDefault;
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        
        if(_myProbeStatus == MESARS232ProbeAtLeft)
        {
            [_motion goTo:AXIS_Z2 withPosition:0];
            [_motion waitMotor:AXIS_Z2];
            
            [_motion goTo:AXIS_Z1 withPosition:_posProbe1Conn];
            [_motion waitMotor:AXIS_Z1];
        }
        if(_myProbeStatus == MESARS232ProbeAtRight)
        {
            [_motion goTo:AXIS_Z1 withPosition:0];
            [_motion waitMotor:AXIS_Z1];
            
            [_motion goTo:AXIS_Z2 withPosition:_posProbe2Conn];
            [_motion waitMotor:AXIS_Z2];
        }
        
        //updownpos = 2;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232ZConnPosition);
        _zProbeStatus = MESARS232ProbeConnPosition;
    }
}

-(void)goToHoverProbePosition{
    @autoreleasepool {
        MESALog(@"[Action] go to hover position", NULL);
        //updownpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ zMoving);
        _zProbeStatus = MESARS232ProbeDefault;
        _isAtHomePosition = false;
//        _holderAtPPosition = false;
        
        if(_myProbeStatus == MESARS232ProbeAtLeft)
        {
            [_motion goTo:AXIS_Z1 withPosition:_posProbe1Hover];
            [_motion waitMotor:AXIS_Z1];
        }
        else if(_myProbeStatus == MESARS232ProbeAtRight)
        {
            [_motion goTo:AXIS_Z2 withPosition:_posProbe2Hover];
            [_motion waitMotor:AXIS_Z2];
        }
        
        //updownpos = 3;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232ZHoverPosition);
        _zProbeStatus = MESARS232ProbeHoverPosition;
        
    }
}

//----------Probe down PID Version 2-----------------
-(void)goToDownProbePosition_V2{
    @autoreleasepool {
        while (_probeDowning) {
            MESALog(@"probe is downing", NULL);
            [NSThread sleepForTimeInterval:0.03];
        }
        
        _probeDowning = true;
        
        MESALog(@"[Action] go to down position", NULL);
        
        if (CALIBRATION && isMacbook){
            // clear content of PID result text field
            [_config_window_macbook z1PID_Result].backgroundColor = [NSColor whiteColor];
            [[_config_window_macbook z1PID_Result] setStringValue:@""];
        }
        
        //updownpos = 10;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ zMoving);
        _zProbeStatus = MESARS232ProbeDefault;
        _isAtHomePosition = false;
        //        _holderAtPPosition = false;
        
        float currentLocation = 0;
        float targetForce = 0;
        float currentDelta = 0;
        float currentForce = 0;
        float previousDelta = 0;
        float newLocation = 0;
        
        if(_myProbeStatus == MESARS232ProbeAtLeft)
        {
            
            if (_zProbeStatus != MESARS232ProbeHoverPosition) {
                [_motion goTo:AXIS_Z1 withPosition:_posProbe1Hover];
                [_motion waitMotor:AXIS_Z1];
            }
            
            currentLocation = [[_motion.axesPosition objectAtIndex:AXIS_Z1] floatValue];
            targetForce = _pressureLeft;
            
        }
        else if(_myProbeStatus == MESARS232ProbeAtRight)
        {
            if (_zProbeStatus != MESARS232ProbeHoverPosition) {
                [_motion goTo:AXIS_Z2 withPosition:_posProbe2Hover];
                [_motion waitMotor:AXIS_Z2];
            }
            
            currentLocation = [[_motion.axesPosition objectAtIndex:AXIS_Z2] floatValue];
            targetForce = _pressureRight;
        }
        else
        {
            [self showMessage:@"[Error] Try probe down while no probe at test position" inColor:[NSColor redColor]];
            _probeDowning = false;
            return;
        }
        
        currentDelta = 0;
        previousDelta = 0;
        newLocation = 0;
        
        //(17-05) record PID time
        CFTimeInterval stTime = CACurrentMediaTime();
        CFTimeInterval tranTime = stTime;
        CFTimeInterval prevTime = 0;
        float timeChange = 0;
        
        vector<CFTimeInterval> pidTime;
        pidTime.clear();
        pidTime.push_back(0);
        
        vector<double> pidForce;
        pidForce.clear();
        
        [_pidLock lock];
        if(_myProbeStatus == MESARS232ProbeAtLeft)
            currentForce = [_motion getForce:AXIS_Z1];
        else if (_myProbeStatus == MESARS232ProbeAtRight)
            currentForce = [_motion getForce:AXIS_Z2];
        [_pidLock unlock];
        
        pidForce.push_back(currentForce);
        
        double errSum = 0;//+= (error * timeChange);
        double pidI = 0;
        double prevLocation = _posProbe1Hover, prevPrevLocation = _posProbe1Hover;
        //(17-05) record PID time
        
        do
        {
            [TestInfoController testMessage:[NSString stringWithFormat:@"expecting getForce and the probe is at %@",(_myProbeStatus == MESARS232ProbeAtLeft)?@"left":@"right"]];
            prevPrevLocation = prevLocation;
            prevLocation = currentLocation;

            
            if(_myProbeStatus == MESARS232ProbeAtLeft)
            {
                [_pidLock lock];
                [_motion getForce:AXIS_Z1];
                currentForce = [_motion getForce:AXIS_Z1];
                [_pidLock unlock];
                
                if (currentForce == -999 || currentForce == 999) {
                    MESALog(@"[warning] force meter in Z1 axis has problem");
                    break;
                }
                currentDelta = targetForce - currentForce;
                
                //current time, current force: save to CSV//////////////////////////////////////////////////////
                tranTime = CACurrentMediaTime() - stTime;;
                pidTime.push_back(tranTime);
                pidForce.push_back(currentForce);
                timeChange = (tranTime - prevTime) * 1000; //change s to ms
                prevTime = tranTime;
                errSum += (currentDelta * timeChange);
                
                MESALog(@"[PID] Z1 axis : Time = %f, currentForce = %f, currentDelta = %f", tranTime, currentForce, currentDelta);
            }
            else if(_myProbeStatus == MESARS232ProbeAtRight)
            {
                [_pidLock lock];
                [_motion getForce:AXIS_Z2];
                currentForce = [_motion getForce:AXIS_Z2];
                [_pidLock unlock];

                if (currentForce == -999 || currentForce == 999) {
                    MESALog(@"[warning] force meter in Z2 axis has problem");
                    break;
                }
                currentDelta = targetForce - currentForce;
                
                //current time, current force: save to CSV//////////////////////////////////////////////////////
                tranTime = CACurrentMediaTime() - stTime;;
                pidTime.push_back(tranTime);
                pidForce.push_back(currentForce);
                timeChange = (tranTime - prevTime) * 1000; //change s to ms
                prevTime = tranTime;
                errSum += (currentDelta * timeChange);
                
                MESALog(@"[PID] Z2 axis : Time = %f, currentForce = %f, currentDelta = %f", tranTime, currentForce, currentDelta);
            }
            
            [TestInfoController testMessage:[NSString stringWithFormat:@"getForce finish and left force:%f right force:%f",_motion.z1Force,_motion.z2Force]];
            
            if([TestInfoController isTestMode])
            {
                [self showMessage:[NSString stringWithFormat:@"the delta is %f \n and force is %f",currentDelta, (_myProbeStatus == MESARS232ProbeAtLeft)?_motion.z1Force:_motion.z2Force] inColor:[NSColor blackColor]];
            }
            else
            {
                MESALog(@"the delta is %f \n and force is %f",currentDelta, (_myProbeStatus == MESARS232ProbeAtLeft)?_motion.z1Force:_motion.z2Force, NULL);
            }
            
            if(abs(currentDelta) >= 0.05) // Not Finish
            {
                if ([TestInfoController isTestMode]) {
                    MESALog(@"currentLocation: %f",currentLocation, NULL);
                }

                currentLocation = currentLocation - ((_pidP * currentDelta) + (pidI * errSum) + (_pidD * ((prevLocation - prevPrevLocation)/timeChange)));
                
                if ([TestInfoController isTestMode]) {
                    MESALog(@"target location: %f",currentLocation, NULL);
                }
                
                if(STOPTEST || isForceQuitPID || [_motion getSignal:INPUT portStatus:DI_Z1_WARNING] || [_motion getSignal:INPUT portStatus:DI_Z2_WARNING] || (_motion.axesNegativeLimit & 1<<2) || _motion.axesNegativeLimit & 1<<3)
                {
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    STOPTEST = false;
                    //_zProbeStatus = MESARS232ProbeTopPosition;
                    _zProbeStatus = MESARS232ProbeDownPosition;
                    _probeDowning = false;
                    isForceQuitPID = false;
                    MESALog(@"[PID] Stop test due to safety issue");
                    return;
                }
                
                if(_myProbeStatus == MESARS232ProbeAtLeft)
                {
                    if (currentLocation <= (_posProbe1Hover - 9)) {
                        [self showMessage:@"[Error]Probe one try to reach a position too low" inColor:[NSColor redColor]];
                        MESALog(@"Probe 1 Hover = %f, Probe 1 current location = %f", _posProbe1Hover, currentLocation);
                        [_motion goTo:AXIS_Z1 withPosition:0];
                        [_motion goTo:AXIS_Z2 withPosition:0];
                        [_motion waitMotor:AXIS_Z1];
                        [_motion waitMotor:AXIS_Z2];
                        //_zProbeStatus = MESARS232ProbeTopPosition;
                        _zProbeStatus = MESARS232ProbeDownPosition;

                        
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"probe down fin" inColor:[NSColor greenColor]];
                        }
                        
                        _probeDowning = FALSE;
                        return;
                    }
                    else
                    {
                        [_motion goTo:AXIS_Z1 withPosition:currentLocation];
                        [_motion waitMotor:AXIS_Z1];
                    }
                }
                else if(_myProbeStatus == MESARS232ProbeAtRight)
                {
                    if (currentLocation <= (_posProbe2Hover - 9)) {
                        [self showMessage:@"[Error]Probe two try to reach a position too low" inColor:[NSColor redColor]];
                        MESALog(@"Probe 2 Hover = %f, Probe 2 current location = %f", _posProbe2Hover, currentLocation);
                        [_motion goTo:AXIS_Z1 withPosition:0];
                        [_motion goTo:AXIS_Z2 withPosition:0];
                        [_motion waitMotor:AXIS_Z1];
                        [_motion waitMotor:AXIS_Z2];
                        //_zProbeStatus = MESARS232ProbeTopPosition;
                        _zProbeStatus = MESARS232ProbeDownPosition;

                        
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"probe down fin" inColor:[NSColor greenColor]];
                        }
                        
                        _probeDowning = FALSE;
                        return;
                    }
                    else
                    {
                        [_motion goTo:AXIS_Z2 withPosition:currentLocation];
                        [_motion waitMotor:AXIS_Z2];
                    }
                }
            }
            else    //finish
            {
                currentForce = [_motion getForce:AXIS_Z1];
                pidForce.push_back(currentForce);
                tranTime = CACurrentMediaTime() - stTime;;
                pidTime.push_back(tranTime);
                
                NSString* csvPath = @"/vault/MesaFixture/MesaLog/PID_processing_time.csv";
                
                NSString* outTime = @"Time";
                NSString* outForce = @"Force";
                
                //*for judging PID is well tuned or not
                NSString* displayTime   = @"   Time(s): ";
                NSString* displayForce  = @"Force(kg): ";
                NSString* displayResult;
                bool isPidTimeOK = true;
                bool isPidNoOvershoot = true;
                
                for (int i = 0; i < pidTime.size(); i++){
                    MESALog(@"time = %f, force = %f", pidTime[i], pidForce[i]);
                    outTime = [NSString stringWithFormat:@"%@,%f", outTime, pidTime[i]];
                    outForce = [NSString stringWithFormat:@"%@, %f", outForce, pidForce[i]];
                    
                    if (CALIBRATION && isMacbook){
                        //*for judging PID is well tuned or not in Calibration page
                        displayTime = [NSString stringWithFormat:@"%@%.2f  ", displayTime, pidTime[i]];
                        displayForce = [NSString stringWithFormat:@"%@%.2f  ", displayForce, pidForce[i]];
                        if (pidTime[i] > 2.5)                       //Time longer than 2.5 seconds
                            isPidTimeOK = false;
                        if (pidForce[i] > _pressureLeft + 0.05)     //overshoot more than targert (force + 0.05kg)
                            isPidNoOvershoot = false;
                    }
                }
                
                outTime = [NSString stringWithFormat:@"%@\n", outTime];
                outForce = [NSString stringWithFormat:@"%@\n\n", outForce];
                
                if (CALIBRATION && isMacbook){
                    // display PID result in calibration page
                    displayTime = [NSString stringWithFormat:@"%@\n", displayTime];
                    displayForce = [NSString stringWithFormat:@"%@\n", displayForce];
                    displayResult = [NSString stringWithFormat:@"%@%@", displayTime, displayForce];
                    [[_config_window_macbook z1PID_Result] setStringValue:displayResult];
                    
                    if (isPidTimeOK && isPidNoOvershoot) {  // if result is OK, shows green
                        MESALog(@"[PID calibration] PID parameters are well tuned, Kp = %f, Kd = %f", _pidP, _pidD);
                        [_config_window_macbook z1PID_Result].backgroundColor = [NSColor greenColor];
                    }
                    if (!isPidTimeOK && isPidNoOvershoot){  // if result is slow but no overshoot, shows yellow
                        [_config_window_macbook z1PID_Result].backgroundColor = [NSColor yellowColor];
                        MESALog(@"[PID calibration] PID not fast enough, Kp = %f, Kd = %f", _pidP, _pidD);
                    }
                    if (!isPidNoOvershoot){                 // if result shows overshoot occured, shows red
                        [_config_window_macbook z1PID_Result].backgroundColor = [NSColor redColor];
                        MESALog(@"[PID calibration] Overshoot occured!!!!!, Kp = %f, Kd = %f", _pidP, _pidD);
                    }
                }
                
                NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
                [DateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@\n",[DateFormatter stringFromDate:[NSDate date]]];
                
                NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:csvPath];

                if (fileHandler == nil){
                    [fileHandler closeFile];
                    
                    NSString *firstData = [NSString stringWithFormat:@"%@%@%@", dateTimeStr, outTime, outForce];
                    [firstData writeToFile:csvPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
                }
                else{
                    [fileHandler seekToEndOfFile];
                    [fileHandler writeData:[dateTimeStr dataUsingEncoding:NSUTF8StringEncoding]];
                    [fileHandler writeData:[outTime dataUsingEncoding:NSUTF8StringEncoding]];
                    [fileHandler writeData:[outForce dataUsingEncoding:NSUTF8StringEncoding]];
                    [fileHandler closeFile];
                }
                
                break;
            }
        } while(STOPTEST == false || isForceQuitPID == false || [_motion getSignal:INPUT portStatus:DI_Z1_WARNING] || [_motion getSignal:INPUT portStatus:DI_Z2_WARNING] || (_motion.axesNegativeLimit & 1<<2) || _motion.axesNegativeLimit & 1<<3);
        
        if (STOPTEST || isForceQuitPID) {
            MESALog(@"[PID] Force break PID loop done");
            [_motion goTo:AXIS_Z1 withPosition:0];
            [_motion goTo:AXIS_Z2 withPosition:0];
            [_motion waitMotor:AXIS_Z1];
            [_motion waitMotor:AXIS_Z2];
            STOPTEST = false;
            //_zProbeStatus = MESARS232ProbeTopPosition;
            _zProbeStatus = MESARS232ProbeDownPosition;
            _probeDowning = false;
            isForceQuitPID = false;
            return;
        }
        
        //updownpos = 4;//回复到位
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232ZTestPosition);
        _zProbeStatus = MESARS232ProbeDownPosition;
        
        _probeDowning = false;
    }
}
//----------Probe down PID Version 2 end--------------

-(void)goToHomePosition
{
    @autoreleasepool {
        MESALog(@"[Action] go to home position", NULL);
        
        //homepos = 10;
//        _holderAtPPosition = false;
        _isAtHomePosition = false;
        
        [_motion goTo:AXIS_Z1 withPosition:0];
        [_motion goTo:AXIS_Z2 withPosition:0];
        [_motion waitMotor:AXIS_Z1];
        [_motion waitMotor:AXIS_Z2];
        
        [_motion goTo:AXIS_X withPosition:0];
        [_motion goTo:AXIS_Y withPosition:_dutY];
        [_motion waitMotor:AXIS_X];
        [_motion waitMotor:AXIS_Y];
        
        //                st = 1;
        //                homepos = 1;
        //                holderpos = 0;
        //_myStatus = (MESARS232ActionStatus)(_myStatus ^ MESARS232Homing);
        _isAtHomePosition = true;
        
        //_workFlag = WorkClean;
//        _holderAtPPosition = true;
    }
}
-(void)goToClean{
    @autoreleasepool {
        MESALog(@"[Action] go to clean position", NULL);
        //_holderAtPPosition = false;
        _isAtHomePosition = false;
        _isCleaningFinish = false;
        
        _cleancount++;
        if(_cleancount ==10000)
        {
            _cleancount = 0;
        }
        if(_cleancount%_cleaningCycle==0 )
        {
            switch((_cleancount/_cleaningCycle)%3)
            {
                case 0:
                {
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x
                    [_motion goTo:AXIS_X withPosition:_posCleanX];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x + clean_dis
                    [_motion goTo:AXIS_X withPosition:_posCleanX + _cleaningGap];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    break;
                }
                case 1:
                {
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x + 2*clean_dis
                    [_motion goTo:AXIS_X withPosition:_posCleanX + 2*_cleaningGap];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x
                    [_motion goTo:AXIS_X withPosition:_posCleanX ];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    break;
                }
                case 2:
                {
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x + clean_dis
                    [_motion goTo:AXIS_X withPosition:_posCleanX  + _cleaningGap];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    //goto clean_x + 2*clean_dis
                    [_motion goTo:AXIS_X withPosition:_posCleanX  + 2*_cleaningGap];
                    [_motion waitMotor:AXIS_X];
                    [_motion goTo:AXIS_Z1 withPosition:_posCleanZ1];
                    [_motion goTo:AXIS_Z2 withPosition:_posCleanZ2];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    
                    [_motion goTo:AXIS_Z1 withPosition:0];
                    [_motion goTo:AXIS_Z2 withPosition:0];
                    [_motion waitMotor:AXIS_Z1];
                    [_motion waitMotor:AXIS_Z2];
                    break;
                }
            }//switch
        } //if
        
        _isCleaningFinish = true;
    }
}

/**
 *  Finish the movement command sent from
 *
 *  @param axis <#axis description#>
 */
-(void)axisMovement:(int)axis{
    float t_length=0;
    if(axis==AXIS_X)
    {
        t_length = _movementDistance/1000.0*2.5;
    }
    else if (axis==AXIS_Y)
    {
        t_length = _movementDistance/1000.0;
    }
    else
    {
        t_length = _stepLength==MESARS232LengthLv1 ? 0.05 : (_stepLength==MESARS232LengthLv2 ? 0.1 : (_stepLength==MESARS232LengthLv3 ? 0.5 : 1));
    }
    
    float t_dis = _isPositiveDirection ? t_length : -t_length;
    
    if(!_isToChangeValue || _zProbeStatus!= MESARS232ProbeHoverPosition)
    {
        _workFlag = WorkDefault;
        return;
    }
    
    [_motion goTo:axis withPosition:[[_motion.axesPosition objectAtIndex:axis] floatValue] + t_dis];
    [_motion waitMotor:axis];
}

-(void)reconnectCamera : (tPvErr)e{
    
    [_pingCamTimer invalidate];
    _pingCamTimer = nil;

    
    NSString *countMsg = [[NSString alloc] init];
    
    if (e == ePvErrUnplugged || ePvErrBadHandle) {     // if capture method return ePvErrUnplugged, try to re-connect camera
        
        // use a for loop to reconnect camera 10 times
        for (int i = 1; i <= 10; i++) {
            if (i == 1) {
                [_camera close_camera];
                //[self showMessage:@"[Cam] Camera disconnected" inColor:[NSColor redColor]];
                MESALog(@"[Cam] Camera disconnected");
            }
            
            //countMsg = [NSString stringWithFormat:@"[Cam] Reconnect camera in %i/10 time(s)", i];
            //[self showMessage:countMsg inColor:[NSColor redColor]];
            MESALog(@"[Cam] Reconnect camera in %i/10 time(s)", i);
            
            PvUnInitialize();
            PvInitialize();
            MESALog(@"[re-connect #%d] wait for 3 seconds for PvInitialize", i);
            [NSThread sleepForTimeInterval:3];
            
            _camera = [[GigECamera alloc] init];
            
            long camID = [_camera find_camera_ID:[[NSString stringWithFormat:@"%s", CAM_A_NAME] UTF8String]];
            if (camID == 0) {
                if (i < 10) {
                    MESALog(@"[re-connect #%d], cammera ID not found", i);
                    continue;
                }
                else{
                    [self showMessage:@"[Cam] Camera disconnected and fail in reconnection, please check the hardware" inColor:[NSColor redColor]];
                }
            }
            
            MESALog(@"[re-connect #%d] try to open camera now", i);
            
            e = [_camera open_camera:camID];
            
            if (e != ePvErrSuccess) {
                MESALog(@"[re-connect #%d] camera cannot be found, reconnect again", i);
                continue;
            }
            else{
                MESALog(@"[re-connect #%d] camera can be opened, set exposure value now", i);
                _triggerMode = camera_software_trigger;
                e = [_camera setUint32:"ExposureValue" :250000];
                MESALog(@"cam can be reopened, err code = %d when setting exposure", e);
                
                if (e == ePvErrSuccess) {
                    //[self showMessage:@"Camera reconnection Done!!!" inColor:[NSColor greenColor]];
                    MESALog(@"Camera reconnection done!!");
                    
                    _pingCamTimer = [[NSTimer alloc] init];
                    _pingCamTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                                     target: self
                                                                   selector: @selector(pingCamera)
                                                                   userInfo: nil
                                                                    repeats: YES];

                    break;
                }
                else{
                    if (i == 10) {
                        [self showMessage:@"[Cam] Camera disconnected and fail in reconnection, please check the hardware" inColor:[NSColor redColor]];
                    }
                }
            }
        }
    }
}

- (void) pingCamera{
    /*
    writeToLogFile( @"Start on pingCamera");
    @try {
        
        tPvUint32 exp;
        tPvErr e;
        
        e = [_camera getUint32:"ExposureValue" :&exp];
        
        if(e == ePvErrSuccess){
            //MESALog(@"Camera connection OK");
        }
        else if(e == ePvErrUnplugged || ePvErrBadHandle){
            MESALog(@"Camera disconnected!!!!!!!!!!!!!!");
            [self reconnectCamera:e];
        }
    } @catch (NSException *exception) {
        writeToLogFile( @"Error on pingCamera: %@", exception.name);
        writeToLogFile( @"Error on pingCamera Reason: %@", exception.reason );
    } @finally {
        
    }
    writeToLogFile( @"End on pingCamera");
     */
}

- (void) pingMotion{
    /*
    writeToLogFile( @"Start on pingMotion");
    @try {
        bool isGoogolAlive = [_motion pingGoogol];
        
        if (isGoogolAlive == false && isGoogolAlive == false){      // last cycle and current cycle both report googol is disconnect
            
            // stop timer
            [_pingMotionTimer invalidate];
            _pingMotionTimer = nil;

            [self showMessage:@"[Error] Googol is Disconnect" inColor:[NSColor redColor]];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Motion controller disconnected. Please restart motion controller then relaunch this app";
                [alert runModal];
            });
            [self closeAppWithSaveLog];

        }
        else if (isGoogolAlive == false && isGoogolAlive == true){
            MESALog(@"Gogole disconnected in last cycle but reconnent successfully now");
        }
        
        _prevIsGoogolAlive = isGoogolAlive;
    } @catch (NSException *exception) {
        writeToLogFile( @"Error on pingMotion: %@", exception.name);
        writeToLogFile( @"Error on pingMotion Reason: %@", exception.reason );
    } @finally {
        
    }
    writeToLogFile( @"End on pingMotion");
    */
}

#pragma mark - MESA serial delegate methods implementation
-(void)delegateOpen
{
    _mesaSerialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.usbserial-MOTION"];
    _mesaSerialPort.delegate = self;
    
    _mesaSerialPort.baudRate = [NSNumber numberWithInt:19200];
    _mesaSerialPort.numberOfStopBits = 1;
    _mesaSerialPort.parity = ORSSerialPortParityEven;
//    _mesaSerialPort.usesDTRDSRFlowControl = true;
//    _mesaSerialPort.usesRTSCTSFlowControl = true;
    
    [_mesaSerialPort open];
}

-(void)delegateClose
{
    [_mesaSerialPort close];
}

-(void)commandAcknowledge:(NSString *)hexString
{
    int j=0;
    UInt8 bytes[[hexString length]/2];
    
    //为了测试，生成返回数据
    MESALog(@"[MesaMac] Send message response - %@, length %lu", hexString, [hexString length]/2);
    
    // Convert hex string back to binary
    for(int i=0;i<[hexString length];i++)
    {
        int int_ch;  /// 两位16进制数转化后的10进制数
        
        unichar hex_char1 = [hexString characterAtIndex:i]; ////两位16进制数中的第一位(高位*16)
        int int_ch1;
        if(hex_char1 >= '0' && hex_char1 <='9')
            int_ch1 = (hex_char1-48)*16;   //// 0 的Ascll - 48
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            int_ch1 = (hex_char1-55)*16; //// A 的Ascll - 65
        else
            int_ch1 = (hex_char1-87)*16; //// a 的Ascll - 97
        i++;
        
        unichar hex_char2 = [hexString characterAtIndex:i]; ///两位16进制数中的第二位(低位)
        int int_ch2;
        if(hex_char2 >= '0' && hex_char2 <='9')
            int_ch2 = (hex_char2-48); //// 0 的Ascll - 48
        else if(hex_char2 >= 'A' && hex_char2 <='F')
            int_ch2 = hex_char2-55; //// A 的Ascll - 65
        else
            int_ch2 = hex_char2-87; //// a 的Ascll - 97
        
        int_ch = int_ch1+int_ch2;
        bytes[j] = int_ch;  ///将转化后的数放入Byte数组里
        j++;
    }
    
    if(_useMessagePort)
    {
        // Send data to MesaHost
        int msgid = 100;

        CFDataRef cfDataToSendOut = nil, cfDataResponse = nil;
        cfDataToSendOut = CFDataCreate(NULL, bytes, [hexString length]/2);
        MESALog(@"Length %lu", [hexString length]/2);
        CFMessagePortSendRequest(mpToMesaHost, msgid, cfDataToSendOut, 0, msgid, kCFRunLoopDefaultMode, &cfDataResponse);

        CFRelease(cfDataToSendOut);
        CFRelease(cfDataResponse);
    }
    else if(_useSocketPort)     // No conversion is done
    {

        NSData *sendBackData = [hexString dataUsingEncoding:NSASCIIStringEncoding];
        long bytesToSend = [sendBackData length];
        long bytesSent = 0;

//        while (bytesToSend > 0) {
            bytesSent = [socketConnection sendBytes:bytes count:[hexString length]/2];
//            bytesToSend -= bytesSent;
//        }
    }
    else
    {
        NSData *dataToSend = [[NSData alloc] initWithBytes:bytes length:[hexString length]/2];
        [_mesaSerialPort sendData:dataToSend];
    }
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    self.mesaSerialPort = nil;
    
    [self showMessage:@"[Error] Motion Serial is loss" inColor:[NSColor redColor]];

    dispatch_sync(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Motion Serial port is loss, please check hardware and reopen this app";
        [alert runModal];
    });
    [self closeAppWithSaveLog];
}


#pragma mark -
// this function is to handle data received from Message Port, added by Antonio on 17-02-2016
- (void)commandHandler:(NSString *)command
{
    MESALog(@"Handle command, %@", command);
        if ([command length] == 0) return;
    
            //if (!([_motion getSignal:INPUT portStatus:DI_DOOR] && [_motion getSignal:INPUT portStatus:DI_DOOR_CYLINDER_DOWN_LIMIT])) {
/*            if (([_motion getSignal:INPUT portStatus:DI_DOOR] == false) || (isMacbook && [_motion getSignal:INPUT portStatus:DI_FRONT_DOOR] == true)){
                [self showMessage:@"[Error] Door opened!" inColor:[NSColor redColor]];
                return;
            }
            else
            {
*/
                if ([command characterAtIndex:1] == '2' && [command characterAtIndex:3] == '6')//ack = received
                {
                    [self commandAcknowledge:command];
                }
                
                if (([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '3') || ([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '2'))//length capture
                {
                    //if string ""1234" is the 8~11 char
                    //movepos = (1*16 + 2)*256 + (3*16 + 4)
                    _movementDistance = (charToInt([command characterAtIndex:0])*16+charToInt([command characterAtIndex:1]))*256+charToInt([command characterAtIndex:2])*16 + charToInt([command characterAtIndex:3]);
                }
#pragma mark -STATUS CHECK
                // STATUS CHECK
                //
                // if need send back:
                // 0203+ChkReg(2Byte)+ChkVal(2Byte)+ChkSum(2Byte)
                // if need no send back:
                // 0206+CmdReg(2Byte)+CmdReg(2Byte)+ChkSum(2Byte)
                //
#pragma mark --Check is at home
                if ([command isEqualToString:@"020300CB0001F5C7"] || [command isEqualToString:@"020300cb0001f5c7"])//检查是否到零位
                {
                    if ([TestInfoController isTestMode]) {
                        [self showMessage:@"[CHECK] home status" inColor:[NSColor blueColor]];
                    }
                    if(_isAtHomePosition)//回复home成功
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: At home" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200013D84"];
                        return;
                    }
                    else if (!_isAtHomePosition)//回复home不成功
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: NOT at home" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020000FC44"];
                        return;
                    }
                }
#pragma mark --Check is at capture position
                else if([command isEqualToString:@"020300CE0001E5C6"] || [command isEqualToString:@"020300ce0001e5c6"])//检查是否到拍照位
                {
                    if ([TestInfoController isTestMode]) {
                        [self showMessage:@"[CHECK] capture status" inColor:[NSColor blueColor]];
                    }
                    if(_isCaptureFinish)//到拍照位
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: Capture FINISH" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200013D84"];
                        return;
                    }
                    else if (!_isCaptureFinish)//没到拍照位
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: CAPTURING" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020000FC44"];
                        return;
                    }
                }
#pragma mark --Check is move to left/right probe position
                else if([command isEqualToString:@"020300CA0001A407"] || [command isEqualToString:@"020300ca0001a407"])//检查是否到左/右探头位
                {
                    if ([TestInfoController isTestMode]) {
                        [self showMessage:@"[CHECK] left/right probe position" inColor:[NSColor blueColor]];
                    }
                    if(_isAtLeftRightPosition)//到达了左/右探头位
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: At left/right probe position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200027D85"];
                        return;
                    }
                    else if (!_isAtLeftRightPosition)//没到左/右探头位
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: NOT at left/right probe position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020000FC44"];
                        return;
                    }
                }
#pragma mark --Check z position
                else if([command isEqualToString:@"0203009600016415"])//检查Z轴是否到位
                {
                    if ([TestInfoController isTestMode]) {
                        [self showMessage:@"[CHECK] z status" inColor:[NSColor blueColor]];
                    }
                    if (_zProbeStatus == MESARS232ProbeTopPosition)//top position
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: at TOP position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200013D84"];
                        return;
                    }
                    
                    else if (_zProbeStatus == MESARS232ProbeConnPosition)//conn position
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: at CONN position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200027D85"];
                        return;
                    }
                    else if (_zProbeStatus == MESARS232ProbeHoverPosition)//hover position
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: at HOVER position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020003BD86"];
                        return;
                    }
                    else if (_zProbeStatus == MESARS232ProbeDownPosition)//test position
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: at TEST position" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020004FD87"];
                        return;
                    }
                    else if(_zProbeStatus == MESARS232ProbeDefault)//moving
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: MOVING" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020000FC44"];
                        return;
                    }
                }
#pragma mark --Check is clean finish
                else if([command isEqualToString:@"020301C80001043B"] || [command isEqualToString:@"020301c80001043b"])//接收到检验是否完成清洁探头动作的命令
                {
                    if ([TestInfoController isTestMode]) {
                        [self showMessage:@"[CHECK] is cleaning finish" inColor:[NSColor blueColor]];
                    }
                    if(_isCleaningFinish)//Cleaning fin
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: Cleaning FINISH" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"02030200013D84"];
                        return;
                    }
                    else if (!_isCleaningFinish)//Cleaning
                    {
                        if ([TestInfoController isTestMode]) {
                            [self showMessage:@"Reply: CLEANING" inColor:[NSColor blueColor]];
                        }
                        [self commandAcknowledge:@"0203020000FC44"];
                        return;
                    }
                    //
                    // if fin
                    // send fin sig
                    // else
                    // send NOT fin sig
                    //
                }
#pragma mark --Check is release DUT finish
                else if([command isEqualToString:@"020300CC00014406"] || [command isEqualToString:@"020300cc00014406"])//
                {
                    if (_isReleaseDutFinish) {
                        [self commandAcknowledge:@"02030200013D84"];
                    }
                    else{
                        [self commandAcknowledge:@"0203020000FC44"];
                    }
                    return;
                }
                
#pragma mark -COMMAND
                // COMMAND
                //
                // if need send back:
                // 0203+ChkReg(2Byte)+ChkVal(2Byte)+ChkSum(2Byte)
                // if need no send back:
                // 0206+CmdReg(2Byte)+CmdReg(2Byte)+ChkSum(2Byte)
                //
#pragma mark --Command go to home position
                else if([command isEqualToString:@"020600D5000159C1"] || [command isEqualToString:@"020600d5000159c1"])//命令回到放料位
                {
                    [_lock lock];
                    [self showMessage:@"[DO] go home" inColor:[NSColor blueColor]];
                    //homepos = 10;
                    _isAtHomePosition = false;
                    _workFlag = WorkDUTPlacePosition;
                    [_lock unlock];
                }
#pragma mark --Command go to do alignment
                else if([command isEqualToString:@"020600D20001E800"] || [command isEqualToString:@"020600d20001e800"])//命令去拍照位
                {
                    [_lock lock];
                    [self showMessage:@"[DO] go capture" inColor:[NSColor blueColor]];
                    //grabpos = 10;
                    _isCaptureFinish = false;
                    _workFlag = WorkImageCapture;
                    [_lock unlock];
                }
#pragma mark --Command go to left probe position
                else if([command isEqualToString:@"020600CC0002C807"] || [command isEqualToString:@"020600cc0002c807"])//命令去左探头位, probe2
                {
                    [_lock lock];
                    [self showMessage:@"[DO] go left probe position" inColor:[NSColor blueColor]];
                    //LRpos = 10;
                    _isAtLeftRightPosition = false;
                    _workFlag = WorkLeftProbePosition;
                    [_lock unlock];
                }
#pragma mark --Command go to right probe position
                else if([command isEqualToString:@"020600CD000299C7"] || [command isEqualToString:@"020600cd000299c7"])//命令去右探头位, probe2
                {
                    [_lock lock];
                    [self showMessage:@"[DO] go right probe position" inColor:[NSColor blueColor]];
                    //LRpos = 10;
                    _isAtLeftRightPosition = false;
                    _workFlag = WorkRightProbePosition;
                    [_lock unlock];
                }
#pragma mark --Command go to top position
                else if([command isEqualToString:@"020600C80001C9C7"] || [command isEqualToString:@"020600c80001c9c7"])//top position
                {
                    [_lock lock];
                    [self showMessage:@"[DO] z go top" inColor:[NSColor blueColor]];
                    //updownpos = 10;
                    _zProbeStatus = MESARS232ProbeDefault;
                    _workFlag = WorkTopPosition;
                    [_lock unlock];
                }
#pragma mark --Command go to conn position
                else if([command isEqualToString:@"020600C8000289C6"] ||[command isEqualToString:@"020600c8000289c6"])//conn position
                {
                    [_lock lock];
                    [self showMessage:@"[DO] z go conn" inColor:[NSColor blueColor]];
                    //updownpos = 10;
                    _zProbeStatus = MESARS232ProbeDefault;
                    _workFlag = WorkConnPosition;
                    [_lock unlock];
                }
#pragma mark --Command go to hover position
                else if([command isEqualToString:@"020600C800034806"] || [command isEqualToString:@"020600c800034806"])//hover position
                {
                    [_lock lock];
                    [self showMessage:@"[DO] z go hover" inColor:[NSColor blueColor]];
                    //updownpos = 10;
                    _zProbeStatus = MESARS232ProbeDefault;
                    _workFlag = WorkHoverPosition;
                    [_lock unlock];
                }
#pragma mark --Command go to down position
                else if([command isEqualToString:@"020600C8000409C4"] || [command isEqualToString:@"020600c8000409c4"])//命令z轴 go to down position
                {
                    [_lock lock];
                    [self showMessage:@"[DO] z go down" inColor:[NSColor blueColor]];
                    //updownpos = 10;
                    _zProbeStatus = MESARS232ProbeDefault;
                    _workFlag = WorkDownPosition;
                    [_lock unlock];
                }
#pragma mark --Command get left force
                else if([command isEqualToString:@"020301C40001C438"] || [command isEqualToString:@"020301c40001c438"])//左压力值, L2
                {
                    [self showMessage:@"[DO] get left force" inColor:[NSColor blueColor]];
                    float weight_tmp = [_motion getForce:AXIS_Z1];
                    
                    int hi,low;
                    
                    weight_tmp *= 1024;
                    
                    int weight = (int)weight_tmp;
                    
                    low = weight % 0x100;
                    hi = weight / 0x100;
                    
                    unsigned char temp[6];
                    temp[0]= 0x02;
                    temp[1]= 0x03;
                    temp[2]= 0x00;
                    temp[3]= 0x00;
                    temp[4]= hi;
                    temp[5]= low ;
                    
                    unsigned short data = [self CRC16withData:temp andDataLength:6];
                    
                    NSString *outputString = @"02030000";
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",weight]];
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
                    
                    [self commandAcknowledge:outputString];
                }
#pragma mark --Command get right force
                else if([command isEqualToString:@"020301C40004043B"] || [command isEqualToString:@"020301c40004043b"])//右压力值, R2
                {
                    [self showMessage:@"[DO] get right force" inColor:[NSColor blueColor]];
                    float weight_tmp = [_motion getForce:AXIS_Z2];
                    
                    int hi,low;
                    
                    weight_tmp *= 1024;
                    
                    int weight = (int)weight_tmp;
                    
                    low = weight % 0x100;
                    hi = weight / 0x100;
                    
                    unsigned char temp[6];
                    temp[0]= 0x02;
                    temp[1]= 0x03;
                    temp[2]= 0x00;
                    temp[3]= 0x00;
                    temp[4]= hi;
                    temp[5]= low ;
                    
                    unsigned short data = [self CRC16withData:temp andDataLength:6];
                    
                    NSString *outputString = @"02030000";
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",weight]];
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
                    
                    [self commandAcknowledge:outputString];
                }
#pragma mark --Command get software version
                else if([command isEqualToString:@"02030122000125CF"] || [command isEqualToString:@"02030122000125cf"])//software version, 0203 + ChkReg(0122) + 0001 + ChkSum
                    //020302+"ABCD"+2Byte ckecksum
                {
                    [self showMessage:@"[DO] get firmware version" inColor:[NSColor blueColor]];
                    if (isMacbook) {
                        //[self commandAcknowledge:@"02030210113188"];  //1.0.1.1
                        //[self commandAcknowledge:@"02030210127189"];  //1.0.1.2
                        //[self commandAcknowledge:@"0203021013b049"];  //1.0.1.3
                        //[self commandAcknowledge:@"0203021014f18b"];  //1.0.1.4
                        
                        // auto generate version command from 17 Mar, 2016. Please be reminded to keep updating version number in project setting!!
                        NSString* softwareVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                        NSString* versionCommand = [self generateVersionCommand:softwareVersion];
                        [self commandAcknowledge:versionCommand];

                    }
                    else{
                        //[self commandAcknowledge:@"0203023053B935"];  //3.0.5.3
                        //[self commandAcknowledge:@"0203023063A86D"];  //3.0.6.3
                        //[self commandAcknowledge:@"0203023073A9A1"];  //3.0.7.3
                        //[self commandAcknowledge:@"0203025000C044"];  //5.0.0.0
                        //[self commandAcknowledge:@"02030250038045"];  //5.0.0.3
                        //[self commandAcknowledge:@"02030250138189"];  //5.0.1.3
                        //[self commandAcknowledge:@"0203025023819D"];  //5.0.2.3
                        //[self commandAcknowledge:@"02030250338051"];  //5.0.3.3
                        //[self commandAcknowledge:@"020302504381B5"];  //5.0.4.3
                        //[self commandAcknowledge:@"02030250538079"];  //5.0.5.3
                        [self commandAcknowledge:@"0203025063806D"];//5.0.6.3
                    }
                    
                    
                }
#pragma mark --Command get tester ID
                else if([command isEqualToString:@"020301240001C5CE"] || [command isEqualToString:@"020301240001c5ce"])//fixture ID, the serial num of tester
                    //0203 + ChkReg(0124) + 0001 + ChkSum
                {
                    [self showMessage:@"[DO] get tester id" inColor:[NSColor blueColor]];
                    int hi,low;
                    low = _fixtureID % 0xFF;
                    hi = _fixtureID  / 0xFF;
                    
                    unsigned char temp[5];
                    
                    temp[0]= 0x02;
                    temp[1]= 0x03;
                    temp[2]= 0x02;
                    temp[3]= hi;
                    temp[4]= low;
                    
                    unsigned short data = [self CRC16withData:temp andDataLength:5];
                    NSString *outputString;
                    
                    outputString = @"020302";
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",_fixtureID]];
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
                    
                    [self commandAcknowledge:outputString];
                }
#pragma mark --Command get fixture model ID
                else if([command isEqualToString:@"020301230001740F"] || [command isEqualToString:@"020301230001740f"])//get fixture model ID, TOD use 17 as original
                    //0203 + ChkReg(0123) + 0001 + ChkSum
                {
                    [self showMessage:@"[DO] get fixture model id" inColor:[NSColor blueColor]];
                    int hi,low;
                    low = _testerID % 0xFF;
                    hi = _testerID / 0xFF;
                    
                    unsigned char temp[5];
                    temp[0]= 0x02;
                    temp[1]= 0x03;
                    temp[2]= 0x02;
                    temp[3]= hi;
                    temp[4]= low;
                    
                    unsigned short data = [self CRC16withData:temp andDataLength:5];
                    
                    NSString *outputString = @"020302";
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",_testerID]];
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
                    
                    [self commandAcknowledge:outputString];
                }
#pragma mark --Command setup x movement direction
                else if([command isEqualToString:@"020600DF000239C2"] || [command isEqualToString:@"020600df000239c2"]) //x+
                {
                    [self showMessage:@"[DO] set x move right" inColor:[NSColor blueColor]];
                    _isPositiveDirection = true;
                }
                else if([command isEqualToString:@"020600DF000179C3"] || [command isEqualToString:@"020600df000179c3"])  //x-
                {
                    [self showMessage:@"[DO] set x move left" inColor:[NSColor blueColor]];
                    _isPositiveDirection = false;
                }
#pragma mark --Command setup y movement direction
                else if([command isEqualToString:@"020600E0000209CE"] || [command isEqualToString:@"020600e0000209ce"])    //y+
                {
                    [self showMessage:@"[DO] set y move in" inColor:[NSColor blueColor]];
                    _isPositiveDirection = true;
                }
                else if([command isEqualToString:@"020600E0000149CF"] || [command isEqualToString:@"020600e0000149cf"])  //y-
                {
                    [self showMessage:@"[DO] set y move out" inColor:[NSColor blueColor]];
                    _isPositiveDirection = false;
                }
#pragma mark --Command setup z movement direction
                else if([command isEqualToString:@"020601F60002E9F6"] || [command isEqualToString:@"020601f60002e9f6"])  //z+
                {
                    [self showMessage:@"[DO] set z move up" inColor:[NSColor blueColor]];
                    _isPositiveDirection = true;
                }
                else if([command isEqualToString:@"020601F60001A9F7"] || [command isEqualToString:@"020601f60001a9f7"])   //z-
                {
                    [self showMessage:@"[DO] set z move down" inColor:[NSColor blueColor]];
                    _isPositiveDirection = false;
                }
#pragma mark --Command setup z movement distance
                else if([command isEqualToString:@"020601F800328821"] || [command isEqualToString:@"020601f800328821"])//z
                {
                    [self showMessage:@"[DO] set Z cc=1" inColor:[NSColor blueColor]];
                    _stepLength = MESARS232LengthLv1;
                }
                else if([command isEqualToString:@"020601F80064081F"] || [command isEqualToString:@"020601f80064081f"])
                {
                    [self showMessage:@"[DO] set Z cc=2" inColor:[NSColor blueColor]];
                    _stepLength = MESARS232LengthLv2;
                }
                else if([command isEqualToString:@"020601F801F409E3"] || [command isEqualToString:@"020601f801f409e3"])
                {
                    [self showMessage:@"[DO] set Z cc=3" inColor:[NSColor blueColor]];
                    _stepLength = MESARS232LengthLv3;
                }
                else if([command isEqualToString:@"020601F803E8094A"] || [command isEqualToString:@"020601f803e8094a"])
                {
                    [self showMessage:@"[DO] set Z cc=4" inColor:[NSColor blueColor]];
                    _stepLength = MESARS232LengthLv4;
                }
#pragma mark --Command x move for calibration
                else if([command isEqualToString:@"020600DC000189C3"] || [command isEqualToString:@"020600dc000189c3"])   //offset   x
                {
                    [self showMessage:@"[DO] move x" inColor:[NSColor blueColor]];
                    _workFlag = CalXMovement;
                }
#pragma mark --Command y move for calibration
                else if([command isEqualToString:@"020600DD0001D803"] || [command isEqualToString:@"020600dd0001d803"])   //offset   y
                {
                    [self showMessage:@"[DO] move y" inColor:[NSColor blueColor]];
                    _workFlag = CalYMovement;
                }
#pragma mark --Command z move for calibration
                else if([command isEqualToString:@"020601F400010837"] || [command isEqualToString:@"020601f400010837"])   //offset   z
                {
                    [self showMessage:@"[DO] move z" inColor:[NSColor blueColor]];
                    _workFlag = CalZmovement;
                }
#pragma mark --Command go to clean
                else if([command isEqualToString:@"020601C70001F838"] || [command isEqualToString:@"020601c70001f838"])//接收到执行清洁探头动作的命令
                {
                    [_lock lock];
                    [self showMessage:@"[DO] go clean" inColor:[NSColor blueColor]];
                    _isCleaningFinish = false;
                    _workFlag = WorkClean;
                    [_lock unlock];
                }
#pragma mark --Command release DUT
                else if([command isEqualToString:@"020600D9000199C2"] || [command isEqualToString:@"020600d9000199c2"]) //release DUT
                {
                    [_lock lock];
                    [self showMessage:@"[DO] release DUT" inColor:[NSColor blueColor]];
                    _isReleaseDutFinish = false;
                    _workFlag = ReleaseDUT;
                    [_lock unlock];
                }
#pragma mark --Command get Date
                else if([command isEqualToString:@"0208000100017038"] || [command isEqualToString:@"0208000100017038"])//接收到执行清洁探头动作的命令
                {
                    [_lock lock];
                    [self showMessage:@"[DO] get date" inColor:[NSColor blueColor]];
                    
                    NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
                    [DateFormatter setDateFormat:@"yyMMdd"];
                    NSString *dateString =  [DateFormatter stringFromDate:[NSDate date]];
                    
                    NSRange range;
                    range.location = 0;     range.length = 2;
                    int yr = [[dateString substringWithRange: range] intValue];
                    range.location = 2;
                    int month = [[dateString substringWithRange: range] intValue];
                    range.location = 4;
                    int day = [[dateString substringWithRange: range] intValue];
                    
                    unsigned char temp[5];
                    temp[0]= 0x02;
                    temp[1]= 0x08;
                    temp[2]= yr;
                    temp[3]= month;
                    temp[4]= day;
                    
                    unsigned short chksum = [self CRC16withData:temp andDataLength:5];
                    
                    NSString *outputString = [[NSString alloc] init];
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"0208%02x%02x%02x%04x", yr, month, day, chksum]];
                    
                    [self commandAcknowledge:outputString];
                    
                    [_lock unlock];
                }
                
#pragma mark --Command get Time
                else if([command isEqualToString:@"0208000200018038"] || [command isEqualToString:@"0208000200018038"])//接收到执行清洁探头动作的命令
                {
                    [self showMessage:@"[DO] get time" inColor:[NSColor blueColor]];
                    
                    NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
                    [DateFormatter setDateFormat:@"HHmmss"];
                    NSString *dateString =  [DateFormatter stringFromDate:[NSDate date]];
                    
                    NSRange range;
                    range.location = 0;     range.length = 2;
                    int hr = [[dateString substringWithRange: range] intValue];
                    range.location = 2;
                    int min = [[dateString substringWithRange: range] intValue];
                    range.location = 4;
                    int sec = [[dateString substringWithRange: range] intValue];
                    
                    unsigned char temp[5];
                    temp[0]= 0x02;
                    temp[1]= 0x08;
                    temp[2]= hr;
                    temp[3]= min;
                    temp[4]= sec;
                    
                    unsigned short chksum = [self CRC16withData:temp andDataLength:5];
                    
                    NSString *outputString = [[NSString alloc] init];
                    
                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"0208%02x%02x%02x%04x", hr, min, sec, chksum]];
                    
                    [self commandAcknowledge:outputString];
                    
                }
            //}
        //}
}

// didReceiveData, used by RS232
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
   // int whflag;
    
    if (serialPort == _mesaSerialPort) {
        Byte *bytes = (Byte *)malloc(sizeof(Byte)*8);
        [data getBytes:bytes range:NSMakeRange(0,[data length])];
        NSString *command=@"";
        
        for(int i=0;i<[data length];i++)
            
        {
            NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];///16进制数
            
            if([newHexStr length]==1)
                command = [NSString stringWithFormat:@"%@0%@",command,newHexStr];
            else
                command = [NSString stringWithFormat:@"%@%@",command,newHexStr];
        }
    
        MESALog(@"command received:%@, length = %lu",command,(unsigned long)[command length], NULL);
        
        if ([command length] == 0) return;
        
        if([command length] <= 16)
        {
            if ([_commandBuffer length] == 0) {
                _commandBuffer = [NSMutableString stringWithString:command];
            }
            else{
                [_commandBuffer appendString:command];
            }
            
            if ([_commandBuffer length] < 16) {
                return;
            }
            if ([_commandBuffer length] > 16) {
                MESALog(@"[Error]Command received error! Command:%@",_commandBuffer, NULL);
                [_commandBuffer setString:@""];
                return;
            }
            
            command = [NSString stringWithString:_commandBuffer];
            [_commandBuffer setString:@""];
            
            MESALog(@"[After append]needed handle:%@",command, NULL);
            
/*            //if (!([_motion getSignal:INPUT portStatus:DI_DOOR] && [_motion getSignal:INPUT portStatus:DI_DOOR_CYLINDER_DOWN_LIMIT])) {
            if (([_motion getSignal:INPUT portStatus:DI_DOOR] == false) || (isMacbook && [_motion getSignal:INPUT portStatus:DI_FRONT_DOOR] == false)){
                [self showMessage:@"[Error] Door opened!" inColor:[NSColor redColor]];
                return;
            }
            else
            {
                MESALog(@"received:%@",command, NULL);
                if ([command characterAtIndex:1] == '2' && [command characterAtIndex:3] == '6')//ack = received
                {
                    [self commandAcknowledge:command];
                }
                
                if (([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '3') || ([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '2'))//length capture
                {
                    //if string ""1234" is the 8~11 char
                    //movepos = (1*16 + 2)*256 + (3*16 + 4)
                    _movementDistance = (charToInt([command characterAtIndex:0])*16+charToInt([command characterAtIndex:1]))*256+charToInt([command characterAtIndex:2])*16 + charToInt([command characterAtIndex:3]);
                }
            }
*/            [self commandHandler:command];
        }
    }
}

#pragma mark -
- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    MESALog(@"MESA Serial port %@ encountered an error: %@", serialPort, error, NULL);
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
    MESALog(@"MESA Serial port %@ opened", serialPort, NULL);
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    MESALog(@"MESA Serial port %@ opened", serialPort, NULL);
}

-(unsigned short)CRC16withData:(unsigned char*) data andDataLength:(int) length
{
    int i,j;
    
    unsigned short crc = 0xFFFF;
    
    for(i=0; i < length; i++)
    {
        crc ^= (unsigned short)data[i];
        
        for(j=0; j<8;j++)
        {
            if(crc & 1)
            {
                crc = (crc >> 1) ^ 0xA001;
            }
            else
            {
                crc = (crc >>1);
            }
        }
    }
    
    int hi = crc % 256;
    int low = crc / 256;
    
    crc = hi * 256 + low;
    
    return crc;
}

- (NSString*)generateVersionCommand : (NSString*) versionNumber{
    
    // (1) append a "." to versionNumber to make me easier to decode the vesrion number by for loop
    versionNumber = [versionNumber stringByAppendingString:@"."];
    
    /* (2) pick all number of version number individually and then save to verNo array
     for example, if versrion number is 1.0.2.4, then
     verNo[0] = 1,   verNo[1] = 0,   verNo[2] = 2,   verNo[3] = 4 */
    NSString* verNo[4];
    for (int i = 0; i < 4; i++) {
        NSRange range = [versionNumber rangeOfString:@"."];
        verNo[i] = [versionNumber substringToIndex:range.location];
        versionNumber = [versionNumber substringFromIndex:range.location+1];
    }
    
    // (3) form a version command
    unsigned char temp[6];
    temp[0]= 0x02;  temp[1]= 0x03;  temp[2]= 0x02;              // temp[0] to temp[2] is constant (register address and value)
    temp[3] = [verNo[0] intValue] * 16 + [verNo[1] intValue];   // Hex value of first 2 bits version number
    temp[4] = [verNo[2] intValue] * 16 + [verNo[3] intValue];   // Hex value of  last 2 bits version number
    
    // (4) calculate check sum of temp
    int checkSum = [self CRC16withData:temp andDataLength:5];
    
    // (5) append register, software vesrion and check sum to form a complete Version command. This will be sent to DUT
    NSString* versionCmd = [NSString stringWithFormat:@"020302%x%x%x", temp[3], temp[4], checkSum];
    
    return versionCmd;
}

-(void)logProcessingTime : (CFTimeInterval)time ofTask : (NSString*)taskNmae isFirstTask : (bool)isFirstTask{
    
    NSString* csvPath = @"/vault/MesaFixture/MesaLog/processing_time.csv";
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:csvPath];

    //FILE * fs = fopen(path, "r");
    
    NSString* outMsg;
    if (isFirstTask){
        outMsg = [NSString stringWithFormat:@"\n\n\n\n%@, %f\n", taskNmae, time];
    }
    else{
        outMsg = [NSString stringWithFormat:@"%@, %f\n", taskNmae, time];
    }
    
    
    if (fileHandler == nil){
        [fileHandler closeFile];
        [outMsg writeToFile:csvPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    else{
        [fileHandler seekToEndOfFile];
        [fileHandler writeData:[outMsg dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandler closeFile];
    }
}

@end

// received data from MessageHost, added by Antonio on 17-02-2016
#pragma mark -
CFDataRef onRecvMessageCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef cfData, void*info)
{
    MESALog(@"[MesaMac] onRecvMessageCallBack is called.");

    // MessagePort creation for mpToMesaHost for the first time
    if(mpToMesaHost == nil)
    {
        MESALog(@"[MesaMac] Create MessagePort (to MesaHost).");
        mpToMesaHost = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("TO_MESAHOST"));
    }
    
    if (cfData)
    {
        // Convert data received from MessagePort to NSData
        NSData *strData = (__bridge NSData *)cfData;
        
        // Convert received NSData into bytes
        Byte *bytes = (Byte *)malloc(sizeof(Byte)*8);
        [strData getBytes:bytes range:NSMakeRange(0,[strData length])];

        NSString *command=@"";
        
        for(int i=0;i< [strData length];i++)
        {
            NSString *newHexStr = [NSString stringWithFormat:@"%x", bytes[i]&0xff];///16进制数
            
            if([newHexStr length]==1)
                command = [NSString stringWithFormat:@"%@0%@", command, newHexStr];
            else
                command = [NSString stringWithFormat:@"%@%@", command, newHexStr];
        }
        
        MESALog(@"[MesaMac] Command received:%@, length = %lu", command, (unsigned long)[command length], NULL);
        
        // Perform the request from MesaHost
        [globalApp commandHandler:command];

    }
    return nil;
}


