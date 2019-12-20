//
//  Macro.h
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/7/31.
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

#ifndef Mesa_MAC_Macro_h
#define Mesa_MAC_Macro_h


#endif

#import <Foundation/NSObject.h>

#pragma mark - MESA RS232
#define charToInt(a) (a-48)

#define bitData char
#define HAHAHAHAHAHA
#define HEHEHEHEHEHE

typedef NS_ENUM(NSUInteger, MESARS232ZStatus) {
    MESARS232ProbeDefault = 1<<0,//active while probe is not at TOP, CONN, HOVER or DOWN position
    MESARS232ProbeTopPosition = 1<<1,
    MESARS232ProbeConnPosition = 1<<2,
    MESARS232ProbeHoverPosition = 1<<3,
    MESARS232ProbeDownPosition = 1<<4,
};

typedef NS_ENUM(NSUInteger, MESARS232ProbeMovementLength) {
    MESARS232LengthDefault = 0,//init step
    //lv1 is shortest step and lv4 is the longest one
    MESARS232LengthLv1 = 1,
    MESARS232LengthLv2 = 2,
    MESARS232LengthLv3 = 3,
    MESARS232LengthLv4 = 4,
};

//prob
typedef NS_ENUM(NSUInteger, MESARS232ProbeStatus) {
    MESARS232ProbeAtCpature = 1<<0,    //capture position
    MESARS232ProbeAtLeft = 1<<1,       //left test position
    MESARS232ProbeAtRight = 2<<2,      //right test position
};

#pragma mark - Action Flag
typedef NS_ENUM(NSUInteger, WorkFlag) {
    WorkDefault = 1<<0,                 //1
    WorkImageCapture = 1<<1,            //10
    WorkLeftProbePosition = 1<<2,       //20
    WorkRightProbePosition = 1 <<3,     //50
    WorkTopPosition = 1<<4,             //40
    WorkConnPosition = 1<<5,            //200
    WorkHoverPosition = 1<<6,           //100
    WorkDownPosition = 1<<7,            //30
    WorkDUTPlacePosition = 1<<8,        //60
    WorkClean = 1<<9,                   //210
    CalXMovement = 1<<10,               //80
    CalYMovement = 1<<11,               //70
    CalZmovement = 1<<12,               //90
    SendMessage = 1<<13,                 //other thread have to active this flag to use motion object to send message
    ReleaseDUT = 1<<14
};

#pragma mark - Global directory
