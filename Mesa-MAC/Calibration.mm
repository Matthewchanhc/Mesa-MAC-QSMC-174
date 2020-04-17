//
//  Calibration.m
//  Mesa-MAC
//
//  Created by Antonio Yu on 16/10/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import "Calibration.h"
#import "AppDelegate.h"
#import "TestInfoController.h"

#define ACTION_DEFAULT      0
#define ACTION_PROBE1_TOP   1
#define ACTION_PROBE1_CONN  2
#define ACTION_PROBE1_HOVER 3
#define ACTION_PROBE1_DOWN  4
#define ACTION_PROBE2_TOP   5
#define ACTION_PROBE2_CONN  6
#define ACTION_PROBE2_HOVER 7
#define ACTION_PROBE2_DOWN  8
#define ACTION_CAPTURE      9
#define ACTION_HOME         10
#define ACTION_CLEAN        11

@interface Calibration ()
@property (atomic)BOOL gettingForce;
@end

@implementation Calibration

#pragma mark - System
- (void)windowDidLoad {
    [super windowDidLoad];
    
    @autoreleasepool {
        _actionLock = [[NSLock alloc] init];
        
        CALIBRATION = true;
        
        _stressTestEnd = false;
        
        if ([TestInfoController isTestMode])
        {
            _stressTest.enabled = true;
            _stressTest.transparent = false;
            _stressTestStop.enabled = true;
            _stressTestStop.transparent = false;
        }
        else
        {
            _stressTest.enabled = false;
            _stressTest.transparent = true;
            _stressTestStop.enabled = false;
            _stressTestStop.transparent = true;
        }
        
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
        
        //Thread to update UI
        _updateUIThreadRunning = true;
        _updateUIThread = [[NSThread alloc] initWithTarget:self selector:@selector(UpdateUI) object:nil];
        _updateUIThread.name = @"Cal update GUI";
        [_updateUIThread start];
        
        //Thread to provide action
        _actionFlag = ACTION_DEFAULT;
        //_gettingForce = false;
        _actionFinish = true;
        
        _actionThreadRunning = true;
        _actionThread = [[NSThread alloc] initWithTarget:self selector:@selector(actionActive) object:nil];
        _actionThread.name = @"Cal action";
        [_actionThread start];
        
        //Axes Moving Zone
        _keepCapture.intValue = false;
        
        //Parameter Setting Zone
        _posCameraX.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"camera_x"] floatValue]];
        _posCameraY.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"camera_y"] floatValue]];
        _posCameraCX.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"camera_cx"] floatValue]];
        _posCameraCY.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"camera_cy"] floatValue]];
        
        _posProbe1X.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe1_x"]floatValue]];
        _posProbe1Y.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe1_y"] floatValue]];
        _posProbe1Conn.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe1_conn"]floatValue]];
        _posProbe1Hover.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe1_hover"]floatValue]];
        
        _posProbe2X.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe2_x"] floatValue]];
        _posProbe2Y.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe2_y"] floatValue]];
        _posProbe2Conn.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe2_conn"] floatValue]];
        _posProbe2Hover.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"probe2_hover"] floatValue]];
        
        _posCleanX.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"clean_x"] floatValue]];
        _posCleanY.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"clean_y"] floatValue]];
        _posCleanZ1.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"clean_z1"] floatValue]];
        _posCleanZ2.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"clean_z2"] floatValue]];
        _cleaningCycle.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"cleaning_cycle"] floatValue]];
        _cleaningGap.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"cleaning_gap"] floatValue]];
        _leftPressure.stringValue = [self formatNumberToString:[[_app formatNumberToString:[[_app.settingsDictionary objectForKey:@"pressure_left"] floatValue]] floatValue]];
        _rightPressure.stringValue = [self formatNumberToString:[[_app formatNumberToString:[[_app.settingsDictionary objectForKey:@"pressure_right"] floatValue]] floatValue]];
        _fixtureID.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"fixture_id"] floatValue]];
        _testerID.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"tester_id"] floatValue]];
        _softwareID.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"software_id"] floatValue]];
        _dutYPosition.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"dut_y"] floatValue]];
        _pidP.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"pid_p"] floatValue]];
        _pidD.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"pid_d"] floatValue]];
        _brightness.stringValue = [self formatNumberToString:[[_app.settingsDictionary objectForKey:@"brightness"] floatValue]];
        _lightSwitch.intValue = false;
        
        //Output Signal Zone
        _outZ1Clear.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z1_FORCE_CLEAR];
        _outZ2Clear.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z2_FORCE_CLEAR];
        
        _outZ1Brake.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z1_BRAKE];
        _outZ2Brake.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z2_BRAKE];
        
        _outGreen.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_GREEN];
        _outRed.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_RED];
        _outYellow.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_YELLOW];
        
        //Function Test Zone
        _keepCapture.intValue = false;
        _isTestMode.intValue = [TestInfoController isTestMode];
        IMAGESAVING = false;
        [_app.camera capture_image_in_mode : camera_software_trigger
                             num_of_frames : camera_single_frame_capture
                               ns_img_view : _cameraView
                        image_process_mode : find_circle_mode];
    }
}

- (void) UpdateUI {
    @autoreleasepool {
        int cnt = 0;
        
        while(_updateUIThreadRunning) {
            
            // Input signals indication
            [_inEStop setColor:[_app.motion getSignal:INPUT portStatus:DI_ESTOP] ?[NSColor greenColor]:[NSColor redColor]];
            [_inReset setColor:[_app.motion getSignal:INPUT portStatus:DI_RESET]?[NSColor greenColor]:[NSColor redColor]];
            [_inStartLeft setColor:[_app.motion getSignal:INPUT portStatus:DI_START_LEFT]?[NSColor greenColor]:[NSColor redColor]];
            [_inStartRight setColor:[_app.motion getSignal:INPUT portStatus:DI_START_RIGHT]?[NSColor greenColor]:[NSColor redColor]];
            [_inPower setColor:[_app.motion getSignal:INPUT portStatus:DI_POWER]?[NSColor greenColor]:[NSColor redColor]];
//            [_inDoor setColor:[_app.motion getSignal:INPUT portStatus:DI_DOOR]?[NSColor greenColor]:[NSColor redColor]];
            [_inZ1Warning setColor:[_app.motion getSignal:INPUT portStatus:DI_Z1_WARNING]?[NSColor greenColor]:[NSColor redColor]];
            [_inZ2Warning setColor:[_app.motion getSignal:INPUT portStatus:DI_Z2_WARNING]?[NSColor greenColor]:[NSColor redColor]];
            
            if(![[_app.motion.axesMoveStatus objectAtIndex:AXIS_X] boolValue])
            {
                _textCurrentX.floatValue = [[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue];
            }
            if(![[_app.motion.axesMoveStatus objectAtIndex:AXIS_Y] boolValue])
            {
                _textCurrentY.floatValue = [[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue];
            }
            if(![[_app.motion.axesMoveStatus objectAtIndex:AXIS_Z1] boolValue])
            {
                _textCurrentZ1.floatValue = [[_app.motion.axesPosition objectAtIndex:AXIS_Z1] floatValue];
            }
            if(![[_app.motion.axesMoveStatus objectAtIndex:AXIS_Z2] boolValue])
            {
                _textCurrentZ2.floatValue = [[_app.motion.axesPosition objectAtIndex:AXIS_Z2] floatValue];
            }
            
            //Output Signal Zone
            _outZ1Clear.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z1_FORCE_CLEAR];
            _outZ2Clear.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z2_FORCE_CLEAR];
            
            _outZ1Brake.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z1_BRAKE];
            _outZ2Brake.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_Z2_BRAKE];
            
            _outGreen.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_GREEN];
            _outRed.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_RED];
            _outYellow.intValue = [_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_YELLOW];
            
            if (++cnt == 30) {
                if (!_app.probeDowning) {
                    if ([TestInfoController isTestMode]) {
                        MESALog(@"[Cal page] GET FORCE NOW");
                    }
                    // _gettingForce = true;
                    [_app.motion getForce:AXIS_Z1];
                    [_app.motion getForce:AXIS_Z2];
                    // _gettingForce = false;
                }
                else{
                    if ([TestInfoController isTestMode]) {
                        MESALog(@"[Cal page] DO NOT GET FORCE DUE TO PROBE DOWN NOW");
                    }
                }
                cnt = 0;
            }
            
            _textForceZ1.floatValue = (_app.motion.z1Force>0.01)?_app.motion.z1Force:0;
            _textForceZ2.floatValue = (_app.motion.z2Force>0.01)?_app.motion.z2Force:0;
            
            if (_textForceZ1.floatValue > 0.05 || _textForceZ2.floatValue > 0.05) {
                _xHomeBut.enabled = false;
                _xRightBut.enabled = false;
                _xLeftBut.enabled = false;
                _yHomeBut.enabled = false;
                _yInBut.enabled = false;
                _yOutBut.enabled = false;
                
                _xHomeBut.transparent = true;
                _xRightBut.transparent = true;
                _xLeftBut.transparent = true;
                _yHomeBut.transparent = true;
                _yInBut.transparent = true;
                _yOutBut.transparent = true;
            }
            else{
                _xHomeBut.enabled = true;
                _xRightBut.enabled = true;
                _xLeftBut.enabled = true;
                _yHomeBut.enabled = true;
                _yInBut.enabled = true;
                _yOutBut.enabled = true;
                
                _xHomeBut.transparent = false;
                _xRightBut.transparent = false;
                _xLeftBut.transparent = false;
                _yHomeBut.transparent = false;
                _yInBut.transparent = false;
                _yOutBut.transparent = false;
            }
            
            if (_autoSave.intValue) {
                if (_app.myProbeStatus == MESARS232ProbeAtLeft && _app.zProbeStatus == MESARS232ProbeHoverPosition) {
                    _posProbe1X.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
                    _posProbe1Y.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1X.floatValue] forKey:@"probe1_x"];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1Y.floatValue] forKey:@"probe1_y"];
                    
                    _posProbe1Hover.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Z1] floatValue]];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1Hover.floatValue] forKey:@"probe1_hover"];
                }
                else if (_app.myProbeStatus == MESARS232ProbeAtRight && _app.zProbeStatus == MESARS232ProbeHoverPosition) {
                    _posProbe2X.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
                    _posProbe2Y.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2X.floatValue] forKey:@"probe2_x"];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2Y.floatValue] forKey:@"probe2_y"];
                    
                    _posProbe2Hover.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Z2] floatValue]];
                    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2Hover.floatValue] forKey:@"probe2_hover"];
                }
            }
            // MESALog(@"before cal update GUI sleep");
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            [NSThread sleepForTimeInterval:0.02];
            //MESALog(@"after cal update GUI sleep");
        }
        [_app showMessage:@"Quit setup page" inColor:[NSColor blackColor]];
        _app.setupOpen = false;
    }
}

-(void)actionActive{
    while (_actionThreadRunning) {
        @autoreleasepool {
            switch (_actionFlag) {
                case ACTION_DEFAULT:
                    [NSThread sleepForTimeInterval:0.03];
                    break;
                case ACTION_PROBE1_TOP:
                    _actionFinish = false;
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"in the ACTION_PROBE1_TOP now" inColor:[NSColor blackColor]];
                    }
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkLeftProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkTopPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor blackColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                    
                case ACTION_PROBE1_CONN:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE1_CONN now" inColor:[NSColor blueColor]];
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkLeftProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkConnPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE1_HOVER:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE1_HOVER now" inColor:[NSColor greenColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkLeftProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkHoverPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor blackColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE1_DOWN:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE1_DOWN now"  inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkLeftProbePosition;
                    [_app showMessage:[NSString stringWithFormat:@"-go to left probe position and workflag:%lu",(unsigned long)_app.workFlag] inColor:[NSColor blackColor]];
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkDownPosition;
                    [_app showMessage:[NSString stringWithFormat:@"-go to down probe position and workflag:%lu",(unsigned long)_app.workFlag] inColor:[NSColor blackColor]];
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE2_TOP:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE2_TOP now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkRightProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkTopPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE2_CONN:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE2_CONN now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkRightProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkConnPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE2_HOVER:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE2_HOVER now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkRightProbePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkHoverPosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_PROBE2_DOWN:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_PROBE2_DOWN now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkRightProbePosition;
                    [_app showMessage:[NSString stringWithFormat:@"-go to right probe position and workflag:%lu",(unsigned long)_app.workFlag] inColor:[NSColor blackColor]];
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkDownPosition;
                    [_app showMessage:[NSString stringWithFormat:@"-go to down probe position and workflag:%lu",(unsigned long)_app.workFlag] inColor:[NSColor blackColor]];
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_CAPTURE:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_CAPTURE now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _keepCapture.intValue = false;
                    
                    IMAGESAVING = true;
                    /* why need call below method here????
                    [_app.camera capture_image_in_mode : camera_software_trigger
                                         num_of_frames : camera_single_frame_capture
                                           ns_img_view : _cameraView
                                    image_process_mode : find_circle_mode];
                    */
                    
                    //    [_app.camera capture_image_in : single_capture_mode
                    //                                  : _cameraView
                    //                                  : nil];
                    
                    [_app goToCamPositionWithDisplay:_cameraView];
                    IMAGESAVING = false;
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_HOME:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_HOME now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkDUTPlacePosition;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor greenColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
                case ACTION_CLEAN:
                    _actionFinish = false;
                    [_app showMessage:@"in the ACTION_CLEAN now" inColor:[NSColor blackColor]];
                    
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    _app.workFlag = WorkClean;
                    while (_app.workFlag != WorkDefault) {
//                        [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
//                    [TestInfoController testMessage:[NSString stringWithFormat:@"%lu",_app.workFlag]];
                    
                    if ([TestInfoController isTestMode]) {
                        [_app showMessage:@"ACTION FIN" inColor:[NSColor blackColor]];
                    }
                    
                    _actionFlag = ACTION_DEFAULT;
                    _actionFinish = true;
                    break;
            }
        }
    }
}

- (IBAction)clickStressTest:(id)sender {
    STOPTEST = false;
    
    if (_testThread == nil) {
        _testThread = [[NSThread alloc] initWithTarget:self selector:@selector(stressTestContent) object:nil];
        _testThread.name = @"Cal stress test thread";
    }
    [_testThread start];
}

-(void)stressTestContent{
    _actionFlag = ACTION_DEFAULT;
    
    for (int i=0 ; i<400000 ; i++) {
        @autoreleasepool {
            MESALog(@"the %d time",i+1);
            int value = arc4random() % 11;
            switch (value) {
                case 0:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE1_TOP",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe1Top:nil];
                    
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 1:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE1_CONN",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe1Conn:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 2:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE1_HOVER",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe1Hover:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 3:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE1_DOWN",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe1Down:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 4:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE2_TOP",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe2Top:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 5:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE2_CONN",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe2Conn:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 6:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE2_HOVER",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe2Hover:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 7:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_PROBE2_DOWN",i+1] inColor:[NSColor blackColor]];
                    [self clickProbe2Down:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 8:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_CAPTURE",i+1] inColor:[NSColor blackColor]];
                    [self clickCapturePosition:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 9:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_HOME",i+1] inColor:[NSColor blackColor]];
                    [self clickHomePosition:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                case 10:
                    [_app showMessage:[NSString stringWithFormat:@"[%d] ACTION_CLEAN",i+1] inColor:[NSColor blackColor]];
                    [self clickClean:nil];
                    do{
                        [NSThread sleepForTimeInterval:0.05];
                    }while (!_actionFinish);
                    MESALog(@"[%d] FIN",i+1);
                    if (_stressTestEnd) {
                        return;
                    }
                    break;
                default:
                    break;
            }
        }
    }
}

- (IBAction)clickStressTestStop:(id)sender {
    _stressTestEnd = true;
    MESALog(@"Cal Stress Test Stop Press");
}

#pragma mark - Top Main Button Zone
//- (IBAction)clickCapture:(id)sender {
//    [_app.camera save_image:YES];
//}

- (IBAction)clickSaveConfig:(id)sender {
    [Util SaveSettingsToPlist:_app.settingsDictionary];
    [_app paraRefresh];
    _app.light232.brightness = _app.brightness;
}

- (IBAction)clickQuit:(id)sender {
    STOPTEST = false;
    CALIBRATION = false;
    
    _updateUIThreadRunning = false;
//    [_app.camera capture_image_in_mode : camera_software_trigger
//                         num_of_frames : camera_single_frame_capture
//                           ns_img_view : _cameraView
//                    image_process_mode : find_circle_mode];
    [_app.camera stop_capture];
    
    //    _actionThreadRunning = false;
    //    [_updateUIThread cancel];
    //    [_actionThread cancel];
    [_testThread cancel];
    //    _updateUIThread = nil;
    //    _actionThread = nil;
    //    [_app.camera capture_image_in : single_capture_mode
    //                                  : _cameraView
    //                                  : nil];
    
    //_app.settingsDictionary = [Util ReadParamsFromPlist:@"settings"];
    [self close];
}

#pragma mark - Axes Moving Zone
- (IBAction)clickXHome:(id)sender {
    if (!_app.homing) {
        _app.homing = true;
        
        [_app.motion goHome:AXIS_X inMsgMode:YES];
    }
}

- (IBAction)clickXLeft:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue] - offset;
    
    [_app.motion goTo:AXIS_X withPosition:targetPos];
    [_app.motion waitMotor:AXIS_X];
    //[_app.motion goTo:AXIS_X withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickXRight:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue] + offset;
    
    [_app.motion goTo:AXIS_X withPosition:targetPos];
    [_app.motion waitMotor:AXIS_X];
    //[_app.motion goTo:AXIS_X withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickYHome:(id)sender {
    if(!_app.homing)
    {
        _app.homing = true;
        
        [_app.motion goHome:AXIS_Y inMsgMode:YES];
    }
}

- (IBAction)clickYIn:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue] + offset;
    
    [_app.motion goTo:AXIS_Y withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Y];
    //[_app.motion goTo:AXIS_Y withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickYOut:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue] - offset;
    
    [_app.motion goTo:AXIS_Y withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Y];
    //    [_app.motion goTo:AXIS_Y withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickZ1Home:(id)sender {
    if (!_app.homing) {
        _app.homing = true;
        
        [_app.motion goHome:AXIS_Z1 inMsgMode:YES];
    }
}

- (IBAction)clickZ1Up:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Z1] floatValue] + offset;
    
    [_app.motion goTo:AXIS_Z1 withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Z1];
    //    [_app.motion goTo:AXIS_Z1 withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickZ1Down:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Z1] floatValue] - offset;
    
    [_app.motion goTo:AXIS_Z1 withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Z1];
    //    [_app.motion goTo:AXIS_Z1 withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickZ2Home:(id)sender {
    if (!_app.homing) {
        _app.homing = true;
        
        [_app.motion goHome:AXIS_Z2 inMsgMode:YES];
    }
}

- (IBAction)clickZ2Up:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Z2] floatValue] + offset;
    
    [_app.motion goTo:AXIS_Z2 withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Z2];
    //    [_app.motion goTo:AXIS_Z2 withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickZ2Down:(id)sender {
    
    float offset = [_gotoOffset floatValue];
    float targetPos = [[_app.motion.axesPosition objectAtIndex:AXIS_Z2] floatValue] - offset;
    
    [_app.motion goTo:AXIS_Z2 withPosition:targetPos];
    [_app.motion waitMotor:AXIS_Z2];
    //    [_app.motion goTo:AXIS_Z2 withPosition:targetPos inMsgMode:YES];
}

- (IBAction)clickAutoSave:(id)sender{
    if (_autoSave.intValue) {
        _app.isToChangeValue = true;
    }
    else{
        _app.isToChangeValue = false;
    }
}

#pragma mark - Parameter Setting Zone
- (IBAction)clickSetPosCameraAutoFill:(id)sender{
    _posCameraX.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
    _posCameraY.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
    
    _posCameraCX.stringValue = [_app formatNumberToString:_app.camera.centerX];
    _posCameraCY.stringValue = [_app formatNumberToString:_app.camera.centerY];
}

- (IBAction)clickSetPosCameraSave:(id)sender {
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCameraX.floatValue] forKey:@"camera_x"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCameraY.floatValue] forKey:@"camera_y"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCameraCX.floatValue] forKey:@"camera_cx"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCameraCY.floatValue] forKey:@"camera_cy"];
}

- (IBAction)clickSetPosProbe1AutoFill:(id)sender{
    _posProbe1X.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
    _posProbe1Y.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
}

- (IBAction)clickSetPosProbe1Save:(id)sender{
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1X.floatValue] forKey:@"probe1_x"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1Y.floatValue] forKey:@"probe1_y"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1Conn.floatValue] forKey:@"probe1_conn"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe1Hover.floatValue] forKey:@"probe1_hover"];
}

- (IBAction)clickSetPosProbe2AutoFill:(id)sender{
    _posProbe2X.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
    _posProbe2Y.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
}

- (IBAction)clickSetPosProbe2Save:(id)sender{
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2X.floatValue] forKey:@"probe2_x"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2Y.floatValue] forKey:@"probe2_y"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2Conn.floatValue] forKey:@"probe2_conn"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posProbe2Hover.floatValue] forKey:@"probe2_hover"];
}

- (IBAction)clickSetCleanAutoFill:(id)sender{
    _posCleanX.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_X] floatValue]];
    _posCleanY.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Y] floatValue]];
    _posCleanZ1.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Z1] floatValue]];
    _posCleanZ2.stringValue = [_app formatNumberToString:[[_app.motion.axesPosition objectAtIndex:AXIS_Z2] floatValue]];
}

- (IBAction)clickSetCleanSave:(id)sender{
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCleanX.floatValue] forKey:@"clean_x"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCleanY.floatValue] forKey:@"clean_y"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCleanZ1.floatValue] forKey:@"clean_z1"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_posCleanZ2.floatValue] forKey:@"clean_z2"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_cleaningCycle.intValue] forKey:@"cleaning_cycle"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_cleaningGap.floatValue] forKey:@"cleaning_gap"];
}

- (IBAction)clickLightSwitch:(id)sender{
    [_app.light232 setBrightness:_brightness.intValue];
    [_app.light232 lightSwitch];
}

- (IBAction)clickSetSystemPara:(id)sender{
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_leftPressure.floatValue] forKey:@"pressure_left"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_rightPressure.floatValue] forKey:@"pressure_right"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_fixtureID.floatValue] forKey:@"fixture_id"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_dutYPosition.floatValue] forKey:@"dut_y"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_pidP.floatValue] forKey:@"pid_p"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_pidD.floatValue] forKey:@"pid_d"];
    [_app.settingsDictionary setValue:[NSNumber numberWithFloat:_brightness.intValue] forKey:@"brightness"];
}

#pragma mark - Output Signal Zone
- (IBAction)clickOutZ1Clear:(id)sender {
    //[NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_Z1_FORCE_CLEAR toState:![_app.motion getSignal:OUTPUT portStatus:DO_Z1_FORCE_CLEAR]];
}

- (IBAction)clickOutZ2Clear:(id)sender {
    // [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_Z2_FORCE_CLEAR toState:![_app.motion getSignal:OUTPUT portStatus:DO_Z2_FORCE_CLEAR]];
}

- (IBAction)clickOutZ1Brake:(id)sender {
    // [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_Z1_BRAKE toState:![_app.motion getSignal:OUTPUT portStatus:DO_Z1_BRAKE]];
}

- (IBAction)clickOutZ2Brake:(id)sender {
    // [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_Z2_BRAKE toState:![_app.motion getSignal:OUTPUT portStatus:DO_Z2_BRAKE]];
}

- (IBAction)clickOutRed:(id)sender {
    // [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_SIGNAL_RED toState:![_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_RED]];
}

- (IBAction)clickOutGreen:(id)sender {
    // [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_SIGNAL_GREEN toState:![_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_GREEN]];
}

- (IBAction)clickOutYellow:(id)sender {
    //  [NSThread sleepForTimeInterval:0.5];
    [_app.motion setOutput:DO_SIGNAL_YELLOW toState:![_app.motion getSignal:OUTPUT portStatus:DO_SIGNAL_YELLOW]];
}

#pragma mark - Function Test Zone
- (IBAction)clickKeepCapture:(id)sender{
    if (_keepCapture.intValue) {
        MESALog(@"Capture Now for keep capture active!!!!");
        IMAGESAVING = false;
        [_app.camera capture_image_in_mode : camera_software_trigger
                             num_of_frames : camera_free_run_capture
                               ns_img_view : _cameraView
                        image_process_mode : find_circle_mode];
    }
    else
    {
        MESALog(@"Close cam Now for keep capture active!!!!");
        [_app.camera stop_capture];
        IMAGESAVING = true;
    }
}

- (IBAction)clickTestMode:(id)sender {
    if (_isTestMode.intValue) {
        [TestInfoController beginTest];
        
        _app.msgBox.editable = true;
        _app.stressTest.enabled = true;
        _app.stressTest.transparent = false;
        _app.stop.enabled = true;
        _app.stop.transparent = false;
        
        _stressTest.enabled = true;
        _stressTest.transparent = false;
        _stressTestStop.enabled = true;
        _stressTestStop.transparent = false;
    }
    else
    {
        [TestInfoController stopTest];
        
        _app.msgBox.editable = false;
        _app.stressTest.enabled = false;
        _app.stressTest.transparent = true;
        _app.stop.enabled = false;
        _app.stop.transparent = true;
        
        _stressTest.enabled = false;
        _stressTest.transparent = true;
        _stressTestStop.enabled = false;
        _stressTestStop.transparent = true;
    }
}

- (IBAction)clickProbe1Top:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE1_TOP;
    }
}

- (IBAction)clickProbe1Conn:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE1_TOP;
    }
    
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE1_CONN;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickProbe1Hover:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE1_HOVER;
    }
    //
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE1_HOVER;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}
- (IBAction)clickProbe1Down:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE1_DOWN;
    }
    //
    //    [_actionLock lock];
    ////    while (!_gettingForce) {
    ////        _gettingForce = true;
    ////        usleep(10000);
    ////    }
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE1_DOWN;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickProbe2Top:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE2_TOP;
    }
    //
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE2_TOP;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickProbe2Conn:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE2_CONN;
    }
    
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE2_CONN;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickProbe2Hover:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE2_HOVER;
    }
    //
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE2_HOVER;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}
- (IBAction)clickProbe2Down:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_PROBE2_DOWN;
    }
    
    //    [_actionLock lock];
    ////    while (!_gettingForce) {
    ////        _gettingForce = true;
    ////        usleep(10000);
    ////    }
    //    _actionFinish = false;
    //    _actionFlag = ACTION_PROBE2_DOWN;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickCapturePosition:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_CAPTURE;
    }
    
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    //CALIBRATION = true;
    //    _actionFlag = ACTION_CAPTURE;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickHomePosition:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_HOME;
    }
    
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_HOME;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickClean:(id)sender{
    if (_actionFlag == ACTION_DEFAULT) {
        _actionFlag = ACTION_CLEAN;
    }
    
    //    [_actionLock lock];
    //    _actionFinish = false;
    //    _actionFlag = ACTION_CLEAN;
    //    while (!_actionFinish) {
    //        usleep(10000);
    //    }
    //    [_actionLock unlock];
}

- (IBAction)clickStop:(id)sender{
    STOPTEST = true;
}

- (IBAction)clickSingleCapture:(id)sender{
    
    _keepCapture.intValue = 0;
    
    if (_isSaveImg.intValue){
        IMAGESAVING = true;
    }
    else{
        IMAGESAVING = false;
    }
    
    [_app.camera capture_image_in_mode : camera_software_trigger
                         num_of_frames : camera_single_frame_capture
                           ns_img_view : _cameraView
                    image_process_mode : find_circle_mode];
    
    //IMAGESAVING = true;
    
}

- (NSString *)formatNumberToString :(float)input
{
    return [_formatter stringFromNumber:[NSNumber numberWithFloat:input]];
}

@end
