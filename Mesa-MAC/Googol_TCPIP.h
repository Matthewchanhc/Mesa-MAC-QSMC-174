//
//  Googol_TCPIP.h
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/6/16.
//  Q: = question    W: = warning    C: = comment    E: = edit
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestInfoController.h"
#import "DataCollctor.h"

@class Googol_MotionIO;


/**
 *  This class implements the TCP/IP related methods for Googol motion control card
 */
@interface Googol_TCPIP : NSObject <NSStreamDelegate>
@property Googol_MotionIO *motion;
@property  NSInputStream *inputStream;
@property  NSOutputStream *outputStream;
@property (assign) NSString *ip;
@property (assign) NSInteger port;
@property (assign) bool isOpened;
@property BOOL inputInitFin;
@property BOOL outputInitFin;
@property bool TCP_IN_USE;
- (void)connectWithIP:(NSString *)ip andPort:(NSInteger)port;
- (void)close;
- (void)writeOut:(NSString *)outputString;



@property NSString *cmdBuffer;
@end
