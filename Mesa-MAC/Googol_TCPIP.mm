//
//  Googol_TCPIP.m
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/6/16.
//  Q: = question    W: = warning    C: = comment    E: = edit
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

#import "Googol_TCPIP.h"
#import "Googol_MotionIO.h"

dispatch_queue_t queue;

@interface Googol_TCPIP()
@property int failCount;

@end

@implementation Googol_TCPIP
- (void)connectWithIP:(NSString *)ip andPort:(NSInteger)port
{
    _isOpened = false;
    _inputInitFin = NO;
    _outputInitFin = NO;
    _ip = ip;
    _port = port;
    _motion = [Googol_MotionIO sharedMyClass];
    
//    MESALog(@"Create queue");
//    queue = dispatch_queue_create("com.metronhk.googol", NULL);
    
  //  NSHost* host = [NSHost hostWithAddress:ip];
    NSInputStream *tempInputStream = nil;
    NSOutputStream *tempOutputStream = nil;
    
    
    //[host name]
    [NSStream getStreamsToHostWithName:ip port:_port inputStream:&tempInputStream outputStream:&tempOutputStream];
    //[NSStream getStreamsToHost:host port:port inputStream:&tempInputStream outputStream:&tempOutputStream];
    [tempInputStream setDelegate:self];
    [tempOutputStream setDelegate:self];
    [tempInputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                            forMode:NSDefaultRunLoopMode];
    [tempOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                             forMode:NSDefaultRunLoopMode];
    
//    [tempInputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
//                               forMode:NSRunLoopCommonModes];
//    [tempOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
//                                forMode:NSRunLoopCommonModes];
    
    [tempInputStream open];
    [tempOutputStream open];
    _inputStream = tempInputStream;
    _outputStream = tempOutputStream;
    
    _failCount = 0;
    
    while(!_inputInitFin && !_outputInitFin)
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    MESALog(@"TCP Open");
}

- (void)close
{
    [_inputStream close];
    [_outputStream close];
    
    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
//    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
//    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [_inputStream setDelegate:nil];
    [_outputStream setDelegate:nil];
    
    _inputStream = nil;
    _outputStream = nil;
    
    _inputInitFin = NO;
    _outputInitFin = NO;
    
    _failCount = 0;
    
    MESALog(@"TCP Close");
}

- (void)writeOut:(NSString *)outputString {
    if ([outputString isNotEqualTo:@""])
    {
        if ([_outputStream streamStatus] == NSStreamStatusNotOpen)
        {
            MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: not connect");
        }
        else if ([_outputStream streamStatus] == NSStreamStatusError)
        {
            MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: server close");
        }
        else if ([_outputStream streamStatus] == NSStreamStatusOpen)
        {
            @autoreleasepool {
                
                while (YES) {
                    if([_outputStream hasSpaceAvailable])
                    {
                        uint8_t *buf = (uint8_t *)[outputString UTF8String];
          
                        if ([TestInfoController isTestMode]) {
                            MESALog(@"Writing to motion controller %@.", outputString);
                        }
                        long returnCode = [_outputStream write:buf maxLength:strlen((char *)buf)];
                        if ([TestInfoController isTestMode]) {
                            MESALog(@"Writing to controller finished. Return code = %ld.", returnCode);
                        }
                        
                        _failCount = 0;
                        
//                        dispatch_async(queue, ^{
//                            uint8_t *buf = (uint8_t *)[outputString UTF8String];
//                            
//                            MESALog(@"Writing to motion controller %@.", outputString);
//                            long returnCode = [_outputStream write:buf maxLength:strlen((char *)buf)];
//                            MESALog(@"Writing to controller finished. Return code = %ld.", returnCode);
//                            
//                            _failCount = 0;
//                            
//                            [NSThread sleepForTimeInterval:0.08];
//                        });
                        
                        break;
                    }
                    else
                    {
                        MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: Message not sent: %@", outputString);
                        MESALog(@"resend after 0.01s");
                        [NSThread sleepForTimeInterval:0.01];
                    }
                }
            }//@autoreleasepool
        }//else if ([_outputStream streamStatus] == NSStreamStatusOpen)
        else if ([_outputStream streamStatus] == NSStreamStatusOpening)
        {
            if([TestInfoController isTestMode]){
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: status is NSStreamStatusOpening");
                MESALog(@"resend after 0.01s");
            }
            [NSThread sleepForTimeInterval:0.01];
            [self writeOut:outputString];
        }
        else if ([_outputStream streamStatus] == NSStreamStatusReading)
        {
            if([TestInfoController isTestMode]){
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: status is NSStreamStatusReading");
                MESALog(@"resend after 0.01s");
            }
            [NSThread sleepForTimeInterval:0.01];
            [self writeOut:outputString];
        }
        else if ([_outputStream streamStatus] == NSStreamStatusWriting)
        {
            if([TestInfoController isTestMode]){
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: status is NSStreamStatusWriting");
                MESALog(@"resend after 0.1s");
            }
            _failCount++;
            [NSThread sleepForTimeInterval:0.1];
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            if (_failCount >= 50) {
                [self close];
                [self connectWithIP:_ip andPort:_port];
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: failed 5 time in NSStreamStatusWriting. Reopen the stream now");
                while (!_inputInitFin && !_outputInitFin){
                    @autoreleasepool {
                        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                        [NSThread sleepForTimeInterval:0.001];
                    }
                }
            }
            [self writeOut:outputString];
        }
        else if ([_outputStream streamStatus] == NSStreamStatusAtEnd)
        {
            if([TestInfoController isTestMode]){
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: status is NSStreamStatusAtEnd");
                MESALog(@"resend after 0.01s");
            }
            [NSThread sleepForTimeInterval:0.01];
            [self writeOut:outputString];
        }
        else if ([_outputStream streamStatus] == NSStreamStatusClosed)
        {
            if([TestInfoController isTestMode]){
                MESALog(@"[Warning] Googol_TCPIP.writeOut:(NSString *)outputString: status is NSStreamStatusClosed");
                MESALog(@"resend after 0.01s");
            }
            [NSThread sleepForTimeInterval:0.01];
            [self writeOut:outputString];
        }
    }//if ([outputString isNotEqualTo:@""])
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    //assert(theStream == _outputStream || theStream == _inputStream);
    
    switch (streamEvent) {
        case NSStreamEventNone:
            MESALog(@"None.");
            break;
            
        case NSStreamEventOpenCompleted:
            MESALog(@"Stream opened");
            if (theStream == _inputStream) {
                _inputInitFin = true;
            }
            if (theStream == _outputStream) {
                _outputInitFin = true;
            }
            break;
            
        case NSStreamEventHasBytesAvailable:
            
            @autoreleasepool {
                
                if (theStream == _inputStream)
                {
                    uint8_t buffer[64];
                    int len;
                    
                    len = (int)[_inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0)
                    {
                        NSString *output = [NSString stringWithFormat:@"%@", [[[[[NSString alloc]initWithBytes:buffer length:len encoding:NSASCIIStringEncoding] stringByReplacingOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, 1)]stringByReplacingOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0, 1)] stringByReplacingOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, 1)]];
                        
                       // [_motion processResponse:@{ @"output" : output}];
                        [NSThread detachNewThreadSelector:@selector(processResponse:) toTarget:_motion withObject:@{ @"output" : output}];
                    }
                }
                
            }
            break;
            
        case  NSStreamEventHasSpaceAvailable:
            //MESALog(@"Has space available");
            break;
            
        case NSStreamEventErrorOccurred:
            MESALog(@"Can not connect to the host!");
            
            MESALog(@"err code = %ld, details = %@", (long)[[theStream streamError] code], [[theStream streamError] localizedDescription]);
            [theStream close];
            
            break;
            
        case NSStreamEventEndEncountered:
            _isOpened = false;
            MESALog(@"Stream closed");
            break;
            
        default:
            MESALog(@"Default");
    }
}

@end












