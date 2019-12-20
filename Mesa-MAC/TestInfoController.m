/*************************************************
 Copyright (c) 2015年 Antonio Yu. All rights reserved.
 Filename:      TestInfoController.h
 Author:        MetronHK_Sylar
 Date:          15/2/16
 Description:
 This class is about to provide the debug messages control.
 FunctionList:
 +(void)startTesting;
 +(void)endTesting;
 *************************************************/

#import "TestInfoController.h"

BOOL TESTMODE = FALSE;

@implementation TestInfoController

+ (void)beginTest{
    TESTMODE = true;
}

+ (void)stopTest{
    TESTMODE = false;
}

+ (void)testMessage:(NSString *)message{
    if (TESTMODE) {
        MESALog(@"%@",message);
    }
}

+ (BOOL)isTestMode{
    return TESTMODE;
}
@end
