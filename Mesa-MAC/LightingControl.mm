//
//  SerialControl.m
//  EagleEye
//
//  Created by Antonio Yu on 13/12/13.
//  Copyright (c) 2013 Antonio Yu. All rights reserved.
//

#import "LightingControl.h"
//#import "IOControl.h"
//#import "Motion.h"
#import "AppDelegate.h"

@implementation LightingControl

- (void)openPort
{
    _isOn = false;
    _brightness= 50;
    _rs232 = [ORSSerialPort serialPortWithPath:@"/dev/cu.usbserial-LIGHTING"];
    _rs232.baudRate = [NSNumber numberWithInt:19200];
    _rs232.delegate = self;
    [_rs232 open];
}

- (void)closePort
{
    MESALog(@"Serial port closed.");
    [_rs232 close];
}

- (void)setBrightness:(int)brightness{
    _brightness = brightness;
}

-(void)lightOn{
    if (is2ChannelsController){
        NSString *outputString = [NSString stringWithFormat:@"SA0%03d#SB0%03d#ST9999#", _brightness, _brightness];
        
        MESALog(@"Lighting on,%d",_brightness);
        
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
        
    }
    else{
        NSString *outputString = [NSString stringWithFormat:@"S%03dT110F120F130F140F150F160F170FC#", _brightness];
    
        MESALog(@"Lighting on,%d",_brightness);
    
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
    }
    _isOn = true;
}

-(void)lightOnWithBrightness:(int)brightness{
    if (is2ChannelsController){
        NSString *outputString = [NSString stringWithFormat:@"SA0%03d#SB0%03d#ST9999#", brightness, brightness];
        
        MESALog(@"Lighting on with brightness: %d",brightness);
        
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
        
    }
    else{
        NSString *outputString = [NSString stringWithFormat:@"S%03dT110F120F130F140F150F160F170FC#", brightness];
    
        MESALog(@"Lighting on with brightness: %d",brightness);
    
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
    }
    _isOn = true;
    _brightness = brightness;
}

-(void)lightOff{
    if (is2ChannelsController){
        NSString *outputString = [NSString stringWithFormat:@"SA0%03d#SB0%03d#ST9999#", 0, 0];
        
        MESALog(@"Lighting off");
        
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
        
    }
    else{
        NSString *outputString = [NSString stringWithFormat:@"S%03dF110F120F130F140F150F160F170FC#", _brightness];
    
        MESALog(@"Lighting off");
    
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    _isOn = false;
}

-(void)lightSwitch{
    NSString *state = _isOn ? @"F" : @"T";
    
    if (is2ChannelsController) {
        if (_isOn) {
            NSString *outputString = [NSString stringWithFormat:@"SA0%03d#SB0%03d#ST9999#", 0, 0];
            [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
        }
        else{
            NSString *outputString = [NSString stringWithFormat:@"SA0%03d#SB0%03d#ST9999#", _brightness, _brightness];
            [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
        }
    }
    else{
    
        NSString *outputString = [NSString stringWithFormat:@"S%03d%@110F120F130F140F150F160F170FC#", _brightness, state];
    
        [_rs232 sendData:[outputString dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    _isOn = !_isOn;
}


- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    
    NSMutableString *result = [[NSMutableString alloc] init];

    @autoreleasepool{
        
        NSUInteger len = [data length];
        
        Byte *byteData = (Byte*)malloc(len);
        memcpy(byteData, [data bytes], len);
        
        for(int i = 0; i < len; ++i)
        {
            [result appendFormat:@"%02x ", byteData[i]];
        }
        
        //MESALog(@"Result from lighting: %@", result);
        
    }
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    
    [_app showMessage:@"[Error] Lighiting Serial is loss" inColor:[NSColor redColor]];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Lighiting Serial port is loss, please check hardware and reopen this app";
        [alert runModal];
    });
    [_app closeAppWithSaveLog];
    
}


@end
