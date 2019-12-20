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

#import <Foundation/Foundation.h>
#import "DataCollctor.h"

@interface TestInfoController : NSObject
/**
*  start the test mode by simply set the TESTMODEON to true.
*/
+ (void)beginTest;

/**
 *  stop the test mode by simply set the TESTMODEON to false.
 */
+ (void)stopTest;

+ (BOOL)isTestMode;

+ (void)testMessage:(NSString *)message;
@end
