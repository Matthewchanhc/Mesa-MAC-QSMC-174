//
//  Mesa_MACTests.m
//  Mesa-MACTests
//
//  Created by Antonio Yu on 26/9/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "TestInfoController.h"

@interface Mesa_MACTests : XCTestCase

@end

@implementation Mesa_MACTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [TestInfoController beginTest];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test_TestInfoController {
    // This is an example of a functional test case.
//    [TestInfoController startTesting];
    [TestInfoController testMessage:@"no para"];
    [TestInfoController testMessage:[NSString stringWithFormat:@"1 para:%d",1]];
    
    [TestInfoController beginTest];
    [TestInfoController stopTest];
    
    [TestInfoController testMessage:@"off test"];
    
    if(![TestInfoController isTestMode])
        XCTAssert(YES, @"Pass");
    else
        XCTAssert(NO, @"Fail");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        int c = 10;
        NSLog(@"adad%d",c);
    }];
}

@end
