////
////  MESATestRS232.m
////  Mesa-MAC
////
////  Created by MESA on 20/8/15.
////  Copyright (c) 2015 Antonio Yu. All rights reserved.
////
//
//#import "MESATestRS232.h"
//
//@implementation MESATestRS232
//
//#pragma mark - MESA serial delegate methods implementation
//-(void)delegateOpen
//{
//    _mesaSerialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.usbserial-MOTION"];
//    _mesaSerialPort.delegate = self;
//    
//    _mesaSerialPort.baudRate = [NSNumber numberWithInt:19200];
//    _mesaSerialPort.numberOfStopBits = 1;
//    _mesaSerialPort.parity = ORSSerialPortParityEven;
//    [_mesaSerialPort open];
//}
//
//-(void)delegateClose
//{
//    [_mesaSerialPort close];
//}
//
//-(void)commandAcknowledge:(NSString *)hexString
//{
//    int j=0;
//    Byte bytes[[hexString length]/2];
//    
//    for(int i=0;i<[hexString length];i++)
//    {
//        int int_ch;  /// 两位16进制数转化后的10进制数
//        
//        unichar hex_char1 = [hexString characterAtIndex:i]; ////两位16进制数中的第一位(高位*16)
//        int int_ch1;
//        if(hex_char1 >= '0' && hex_char1 <='9')
//            int_ch1 = (hex_char1-48)*16;   //// 0 的Ascll - 48
//        else if(hex_char1 >= 'A' && hex_char1 <='F')
//            int_ch1 = (hex_char1-55)*16; //// A 的Ascll - 65
//        else
//            int_ch1 = (hex_char1-87)*16; //// a 的Ascll - 97
//        i++;
//        
//        unichar hex_char2 = [hexString characterAtIndex:i]; ///两位16进制数中的第二位(低位)
//        int int_ch2;
//        if(hex_char2 >= '0' && hex_char2 <='9')
//            int_ch2 = (hex_char2-48); //// 0 的Ascll - 48
//        else if(hex_char2 >= 'A' && hex_char2 <='F')
//            int_ch2 = hex_char2-55; //// A 的Ascll - 65
//        else
//            int_ch2 = hex_char2-87; //// a 的Ascll - 97
//        
//        int_ch = int_ch1+int_ch2;
//        bytes[j] = int_ch;  ///将转化后的数放入Byte数组里
//        j++;
//    }
//    
//    NSData *dataToSend = [[NSData alloc] initWithBytes:bytes length:[hexString length]/2];
//    
////    if ([TestInfoController isTestMode]) {
////        [self showMessage:[NSString stringWithFormat:@"Reply: %@",dataToSend]];
////    }
//    [_mesaSerialPort sendData:dataToSend];
//}
//
//- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
//{
//    self.mesaSerialPort = nil;
//}
//
//#pragma mark -
//- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
//{
//    // int whflag;
//    
//    if (serialPort == _mesaSerialPort) {
//        Byte *bytes = (Byte *)malloc(sizeof(Byte)*8);
//        [data getBytes:bytes range:NSMakeRange(0,[data length])];
//        NSString *command=@"";
//        
//        for(int i=0;i<[data length];i++)
//            
//        {
//            NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];///16进制数
//            
//            if([newHexStr length]==1)
//                command = [NSString stringWithFormat:@"%@0%@",command,newHexStr];
//            else
//                command = [NSString stringWithFormat:@"%@%@",command,newHexStr];
//        }
//        
//        NSLog(@"command received:%@, length = %lu",command,(unsigned long)[command length]);
//        if ([command length] == 0) return;
//        
//        if([command length] <= 16)
//        {
//            if ([_commandBuffer length] == 0) {
//                _commandBuffer = [NSString stringWithString:command];
//            }
//            else{
//                _commandBuffer = [_commandBuffer stringByAppendingString:command];
//            }
//            
//            if ([_commandBuffer length] < 16) {
//                return;
//            }
//            if ([_commandBuffer length] > 16) {
//                NSLog(@"[Error]Command received error! Command:%@",_commandBuffer);
//                _commandBuffer = nil;
//                _commandBuffer = [[NSMutableString alloc] init];
//                return;
//            }
//            command = [NSString stringWithString:_commandBuffer];
//            _commandBuffer = nil;
//            _commandBuffer = [[NSMutableString alloc] init];
//            
//            NSLog(@"[After append]needed handle:%@",command);
//            
//            if (![_motion getSignal:INPUT portStatus:DI_DOOR]) {
//                
//                [_motion setOutput:DO_SIGNAL_RED toState:IO_ON];
//                [_motion setOutput:DO_SIGNAL_GREEN toState:IO_OFF];
//                [_motion setOutput:DO_SIGNAL_YELLOW toState:IO_OFF];
//                
//                [self showMessage:@"[Error] Door opened!"];
//                return;
//            }
//            else
//            {
//                NSLog(@"received:%@",command);
//                if ([command characterAtIndex:1] == '2' && [command characterAtIndex:3] == '6')//ack = received
//                {
//                    [self commandAcknowledge:command];
//                }
//                
//                if (([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '3') || ([command characterAtIndex:5] == '1' && [command characterAtIndex:6] == '9' && [command characterAtIndex:7] == '2'))//length capture
//                {
//                    //if string ""1234" is the 8~11 char
//                    //movepos = (1*16 + 2)*256 + (3*16 + 4)
//                    _movementDistance = (charToInt([command characterAtIndex:0])*16+charToInt([command characterAtIndex:1]))*256+charToInt([command characterAtIndex:2])*16 + charToInt([command characterAtIndex:3]);
//                }
//#pragma mark -STATUS CHECK
//                /************** STATUS CHECK **************/
//                /*
//                 if need send back:
//                 0203+ChkReg(2Byte)+ChkVal(2Byte)+ChkSum(2Byte)
//                 if need no send back:
//                 0206+CmdReg(2Byte)+CmdReg(2Byte)+ChkSum(2Byte)
//                 */
//#pragma mark --Check is at home
//                if ([command isEqualToString:@"020300CB0001F5C7"] || [command isEqualToString:@"020300cb0001f5c7"])//检查是否到零位
//                {
//                    if ([TestInfoController isTestMode]) {
//                        [self showMessage:@"[CHECK] home status"];
//                    }
//                    if(_isAtHomePosition)//回复home成功
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: At home"];
//                        }
//                        [self commandAcknowledge:@"02030200013D84"];
//                        return;
//                    }
//                    else if (!_isAtHomePosition)//回复home不成功
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: NOT at home"];
//                        }
//                        [self commandAcknowledge:@"0203020000FC44"];
//                        return;
//                    }
//                }
//#pragma mark --Check is at capture position
//                else if([command isEqualToString:@"020300CE0001E5C6"] || [command isEqualToString:@"020300ce0001e5c6"])//检查是否到拍照位
//                {
//                    if ([TestInfoController isTestMode]) {
//                        [self showMessage:@"[CHECK] capture status"];
//                    }
//                    if(_isCaptureFinish)//到拍照位
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: Capture FINISH"];
//                        }
//                        [self commandAcknowledge:@"02030200013D84"];
//                        return;
//                    }
//                    else if (!_isCaptureFinish)//没到拍照位
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: CAPTURING"];
//                        }
//                        [self commandAcknowledge:@"0203020000FC44"];
//                        return;
//                    }
//                }
//#pragma mark --Check is move to left/right probe position
//                else if([command isEqualToString:@"020300CA0001A407"] || [command isEqualToString:@"020300ca0001a407"])//检查是否到左/右探头位
//                {
//                    if ([TestInfoController isTestMode]) {
//                        [self showMessage:@"[CHECK] left/right probe position"];
//                    }
//                    if(_isAtLeftRightPosition)//到达了左/右探头位
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: At left/right probe position"];
//                        }
//                        [self commandAcknowledge:@"02030200027D85"];
//                        return;
//                    }
//                    else if (!_isAtLeftRightPosition)//没到左/右探头位
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: NOT at left/right probe position"];
//                        }
//                        [self commandAcknowledge:@"0203020000FC44"];
//                        return;
//                    }
//                }
//#pragma mark --Check z position
//                else if([command isEqualToString:@"0203009600016415"])//检查Z轴是否到位
//                {
//                    if ([TestInfoController isTestMode]) {
//                        [self showMessage:@"[CHECK] z status"];
//                    }
//                    if (_zProbeStatus == MESARS232ProbeTopPosition)//top position
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: at TOP position"];
//                        }
//                        [self commandAcknowledge:@"02030200013D84"];
//                        return;
//                    }
//                    
//                    else if (_zProbeStatus == MESARS232ProbeConnPosition)//conn position
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: at CONN position"];
//                        }
//                        [self commandAcknowledge:@"02030200027D85"];
//                        return;
//                    }
//                    else if (_zProbeStatus == MESARS232ProbeHoverPosition)//hover position
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: at HOVER position"];
//                        }
//                        [self commandAcknowledge:@"0203020003BD86"];
//                        return;
//                    }
//                    else if (_zProbeStatus == MESARS232ProbeDownPosition)//test position
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: at TEST position"];
//                        }
//                        [self commandAcknowledge:@"0203020004FD87"];
//                        return;
//                    }
//                    else if(_zProbeStatus == MESARS232ProbeDefault)//moving
//                    {
//                        if ([TestInfoController isTestMode]) {
//                            [self showMessage:@"Reply: MOVING"];
//                        }
//                        [self commandAcknowledge:@"0203020000FC44"];
//                        return;
//                    }
//                }
//#pragma mark --Check is clean finish
//                else if([command isEqualToString:@"020301C80001043B"] || [command isEqualToString:@"020301c80001043b"])//接收到检验是否完成清洁探头动作的命令
//                {
//                    /**
//                     *  if fin
//                     send fin sig
//                     else
//                     send NOT fin sig
//                     */
//                }
//                
//#pragma mark -COMMAND
//                /************** COMMAND **************/
//                /*
//                 if need send back:
//                 0203+ChkReg(2Byte)+ChkVal(2Byte)+ChkSum(2Byte)
//                 if need no send back:
//                 0206+CmdReg(2Byte)+CmdReg(2Byte)+ChkSum(2Byte)
//                 */
//#pragma mark --Command go to home position
//                else if([command isEqualToString:@"020600D5000159C1"] || [command isEqualToString:@"020600d5000159c1"])//命令回到放料位
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] go home"];
//                    //homepos = 10;
//                    _isAtHomePosition = false;
//                    _workFlag = WorkDUTPlacePosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to do alignment
//                else if([command isEqualToString:@"020600D20001E800"] || [command isEqualToString:@"020600d20001e800"])//命令去拍照位
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] go capture"];
//                    //grabpos = 10;
//                    _isCaptureFinish = false;
//                    _workFlag = WorkImageCapture;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to left probe position
//                else if([command isEqualToString:@"020600CC0002C807"] || [command isEqualToString:@"020600cc0002c807"])//命令去左探头位, probe2
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] go left probe position"];
//                    //LRpos = 10;
//                    _isAtLeftRightPosition = false;
//                    _workFlag = WorkLeftProbePosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to right probe position
//                else if([command isEqualToString:@"020600CD000299C7"] || [command isEqualToString:@"020600cd000299c7"])//命令去右探头位, probe2
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] go right probe position"];
//                    //LRpos = 10;
//                    _isAtLeftRightPosition = false;
//                    _workFlag = WorkRightProbePosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to down position
//                else if([command isEqualToString:@"020600C8000409C4"] || [command isEqualToString:@"020600c8000409c4"])//命令z轴 go to down position
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] z go down"];
//                    //updownpos = 10;
//                    _zProbeStatus = MESARS232ProbeDefault;
//                    _workFlag = WorkDownPosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to top position
//                else if([command isEqualToString:@"020600C80001C9C7"] || [command isEqualToString:@"020600c80001c9c7"])//top position
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] z go top"];
//                    //updownpos = 10;
//                    _zProbeStatus = MESARS232ProbeDefault;
//                    _workFlag = WorkTopPosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to conn position
//                else if([command isEqualToString:@"020600C8000289C6"] ||[command isEqualToString:@"020600c8000289c6"])//conn position
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] z go conn"];
//                    //updownpos = 10;
//                    _zProbeStatus = MESARS232ProbeDefault;
//                    _workFlag = WorkConnPosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command go to hbver position
//                else if([command isEqualToString:@"020600C800034806"] || [command isEqualToString:@"020600c800034806"])//hover position
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] z go hover"];
//                    //updownpos = 10;
//                    _zProbeStatus = MESARS232ProbeDefault;
//                    _workFlag = WorkHoverPosition;
//                    [_lock unlock];
//                }
//#pragma mark --Command get left force
//                else if([command isEqualToString:@"020301C40001C438"] || [command isEqualToString:@"020301c40001c438"])//左压力值, L2
//                {
//                    [self showMessage:@"[DO] get left force"];
//                    float weight_tmp = [_motion getForce:AXIS_Z1]/9.8;
//                    
//                    int hi,low;
//                    
//                    weight_tmp *= 1024;
//                    
//                    int weight = (int)weight_tmp;
//                    
//                    low = weight % 0x100;
//                    hi = weight / 0x100;
//                    
//                    unsigned char temp[6];
//                    temp[0]= 0x02;
//                    temp[1]= 0x03;
//                    temp[2]= 0x00;
//                    temp[3]= 0x00;
//                    temp[4]= hi;
//                    temp[5]= low ;
//                    
//                    unsigned short data = [self CRC16withData:temp andDataLength:6];
//                    
//                    NSString *outputString = @"02030000";
//                    
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",weight]];
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
//                    
//                    [self commandAcknowledge:outputString];
//                }
//#pragma mark --Command get right force
//                else if([command isEqualToString:@"020301C40004043B"] || [command isEqualToString:@"020301c40004043b"])//右压力值, R2
//                {
//                    [self showMessage:@"[DO] get right force"];
//                    float weight_tmp = [_motion getForce:AXIS_Z2]/9.8;
//                    
//                    int hi,low;
//                    
//                    weight_tmp *= 1024;
//                    
//                    int weight = (int)weight_tmp;
//                    
//                    low = weight % 0x100;
//                    hi = weight / 0x100;
//                    
//                    unsigned char temp[6];
//                    temp[0]= 0x02;
//                    temp[1]= 0x03;
//                    temp[2]= 0x00;
//                    temp[3]= 0x00;
//                    temp[4]= hi;
//                    temp[5]= low ;
//                    
//                    unsigned short data = [self CRC16withData:temp andDataLength:6];
//                    
//                    NSString *outputString = @"02030000";
//                    
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",weight]];
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
//                    
//                    [self commandAcknowledge:outputString];
//                }
//#pragma mark --Command get software version
//                else if([command isEqualToString:@"02030122000125CF"] || [command isEqualToString:@"02030122000125cf"])//software version, 0203 + ChkReg(0122) + 0001 + ChkSum
//                    //020302+"ABCD"+2Byte ckecksum
//                {
//                    [self showMessage:@"[DO] get firmware version"];
//                    //[self commandAcknowledge:@"0203023053B935"];  //3.0.5.3
//                    //[self commandAcknowledge:@"0203023063A86D"];  //3.0.6.3
//                    //[self commandAcknowledge:@"0203023073A9A1"];  //3.0.7.3
//                    //[self commandAcknowledge:@"0203025000C044"];  //5.0.0.0
//                    //[self commandAcknowledge:@"02030250038045"];  //5.0.0.3
//                    //[self commandAcknowledge:@"02030250138189"];  //5.0.1.3
//                    //[self commandAcknowledge:@"0203025023819D"];  //5.0.2.3
//                    //[self commandAcknowledge:@"02030250338051"];  //5.0.3.3
//                    //[self commandAcknowledge:@"020302504381B5"];  //5.0.4.3
//                    //[self commandAcknowledge:@"02030250538079"];  //5.0.5.3
//                    [self commandAcknowledge:@"0203025063806D"];//5.0.6.3
//                }
//#pragma mark --Command get tester ID
//                else if([command isEqualToString:@"020301240001C5CE"] || [command isEqualToString:@"020301240001c5ce"])//fixture ID, the serial num of tester
//                    //0203 + ChkReg(0124) + 0001 + ChkSum
//                {
//                    [self showMessage:@"[DO] get tester id"];
//                    int hi,low;
//                    low = _fixtureID % 0xFF;
//                    hi = _fixtureID  / 0xFF;
//                    
//                    unsigned char temp[5];
//                    
//                    temp[0]= 0x02;
//                    temp[1]= 0x03;
//                    temp[2]= 0x02;
//                    temp[3]= hi;
//                    temp[4]= low;
//                    
//                    unsigned short data = [self CRC16withData:temp andDataLength:5];
//                    NSString *outputString;
//                    
//                    outputString = @"020302";
//                    
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",_fixtureID]];
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
//                    
//                    [self commandAcknowledge:outputString];
//                }
//#pragma mark --Command get fixture model ID
//                else if([command isEqualToString:@"020301230001740F"] || [command isEqualToString:@"020301230001740f"])//get fixture model ID, TOD use 17 as original
//                    //0203 + ChkReg(0123) + 0001 + ChkSum
//                {
//                    [self showMessage:@"[DO] get fixture model id"];
//                    int hi,low;
//                    low = _testerID % 0xFF;
//                    hi = _testerID / 0xFF;
//                    
//                    unsigned char temp[5];
//                    temp[0]= 0x02;
//                    temp[1]= 0x03;
//                    temp[2]= 0x02;
//                    temp[3]= hi;
//                    temp[4]= low;
//                    
//                    unsigned short data = [self CRC16withData:temp andDataLength:5];
//                    
//                    NSString *outputString = @"020302";
//                    
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",_testerID]];
//                    outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%04x",data]];
//                    
//                    [self commandAcknowledge:outputString];
//                }
//#pragma mark --Command setup x movement direction
//                else if([command isEqualToString:@"020600DF000239C2"] || [command isEqualToString:@"020600df000239c2"]) //x+
//                {
//                    [self showMessage:@"[DO] set x move right"];
//                    _isPositiveDirection = true;
//                }
//                else if([command isEqualToString:@"020600DF000179C3"] || [command isEqualToString:@"020600df000179c3"])  //x-
//                {
//                    [self showMessage:@"[DO] set x move left"];
//                    _isPositiveDirection = false;
//                }
//#pragma mark --Command setup y movement direction
//                else if([command isEqualToString:@"020600E0000209CE"] || [command isEqualToString:@"020600e0000209ce"])    //y+
//                {
//                    [self showMessage:@"[DO] set y move in"];
//                    _isPositiveDirection = true;
//                }
//                else if([command isEqualToString:@"020600E0000149CF"] || [command isEqualToString:@"020600e0000149cf"])  //y-
//                {
//                    [self showMessage:@"[DO] set y move out"];
//                    _isPositiveDirection = false;
//                }
//#pragma mark --Command setup z movement direction
//                else if([command isEqualToString:@"020601F60002E9F6"] || [command isEqualToString:@"020601f60002e9f6"])  //z+
//                {
//                    [self showMessage:@"[DO] set z move up"];
//                    _isPositiveDirection = true;
//                }
//                else if([command isEqualToString:@"020601F60001A9F7"] || [command isEqualToString:@"020601f60001a9f7"])   //z-
//                {
//                    [self showMessage:@"[DO] set z move down"];
//                    _isPositiveDirection = false;
//                }
//#pragma mark --Command setup z movement distance
//                else if([command isEqualToString:@"020601F800328821"] || [command isEqualToString:@"020601f800328821"])//z
//                {
//                    [self showMessage:@"[DO] set Z cc=1"];
//                    _stepLength = MESARS232LengthLv1;
//                }
//                else if([command isEqualToString:@"020601F80064081F"] || [command isEqualToString:@"020601f80064081f"])
//                {
//                    [self showMessage:@"[DO] set Z cc=2"];
//                    _stepLength = MESARS232LengthLv2;
//                }
//                else if([command isEqualToString:@"020601F801F409E3"] || [command isEqualToString:@"020601f801f409e3"])
//                {
//                    [self showMessage:@"[DO] set Z cc=3"];
//                    _stepLength = MESARS232LengthLv3;
//                }
//                else if([command isEqualToString:@"020601F803E8094A"] || [command isEqualToString:@"020601f803e8094a"])
//                {
//                    [self showMessage:@"[DO] set Z cc=4"];
//                    _stepLength = MESARS232LengthLv4;
//                }
//#pragma mark --Command x move for calibration
//                else if([command isEqualToString:@"020600DC000189C3"] || [command isEqualToString:@"020600dc000189c3"])   //offset   x
//                {
//                    [self showMessage:@"[DO] move x"];
//                    _workFlag = CalXMovement;
//                }
//#pragma mark --Command y move for calibration
//                else if([command isEqualToString:@"020600DD0001D803"] || [command isEqualToString:@"020600dd0001d803"])   //offset   y
//                {
//                    [self showMessage:@"[DO] move y"];
//                    _workFlag = CalYMovement;
//                }
//#pragma mark --Command z move for calibration
//                else if([command isEqualToString:@"020601F400010837"] || [command isEqualToString:@"020601f400010837"])   //offset   z
//                {
//                    [self showMessage:@"[DO] move z"];
//                    _workFlag = CalZmovement;
//                }
//#pragma mark --Command go to clean
//                else if([command isEqualToString:@"020601C70001F838"] || [command isEqualToString:@"020601c70001f838"])//接收到执行清洁探头动作的命令
//                {
//                    [_lock lock];
//                    [self showMessage:@"[DO] go clean"];
//                    _workFlag = WorkClean;
//                    [_lock unlock];
//                }
//            }
//        }
//    }
//    
//}
//#pragma mark -
//- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
//{
//    NSLog(@"MESA Serial port %@ encountered an error: %@", serialPort, error);
//}
//
//- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
//{
//    NSLog(@"MESA Serial port %@ opened", serialPort);
//}
//
//- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
//{
//    NSLog(@"MESA Serial port %@ opened", serialPort);
//}
//
//@end
