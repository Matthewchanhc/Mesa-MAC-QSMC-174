//
//  MESATestRS232.h
//  Mesa-MAC
//
//  Created by MESA on 20/8/15.
//  Copyright (c) 2015 Antonio Yu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ORSSerialPort.h"
#import "TestInfoController.h"

@interface MESATestRS232 : NSObject <ORSSerialPortDelegate>
@property ORSSerialPort *mesaSerialPort;
-(void)delegateOpen;

@end
