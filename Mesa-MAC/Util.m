//
//  Util.m
//  Mesa-MAC
//
//  Created by Antonio Yu on 7/10/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import "Util.h"

@implementation Util

+(NSMutableArray*)CheckMesaFolder{
    
    NSMutableArray* errMsg = [[NSMutableArray alloc] init];
    
    // create a check list of folder
    NSArray *pathCheckList = [NSArray arrayWithObjects: @"/vault/MesaFixture",
                                                        @"/vault/MesaFixture/MesaLog",
                                                        @"/vault/MesaFixture/MesaMacConfig",
                                                        @"/vault/MesaFixture/MesaPic",
                                                        @"/vault/MesaFixture/MesaPic/Result",
                                                        nil];

    //Check folder exist or not one by one
    for (int i = 0; i < [pathCheckList count]; i++){
        NSString *folderPath = [pathCheckList objectAtIndex:i];
        BOOL isDir = YES;
        NSError* err;
        BOOL isPlistPathExisit = [[NSFileManager defaultManager] fileExistsAtPath:folderPath isDirectory:&isDir];
        
        // if exisit, print out it exisit
        if (isPlistPathExisit) {
            MESALog(@"%@ exisits when init", folderPath);
        }
        else{// if it doesn't exisit, creat it!!
            if (i == 0) {
                // no permission to creat /vault/MesaFixture in NSFileManage, so I use NSTask -> sudo mkdir to creat it
                NSTask *task = [[NSTask alloc] init];
                task.launchPath = @"/usr/bin/sudo";
                NSArray* arg = [[NSArray alloc] initWithObjects:@"mkdir ", folderPath, nil];
                task.arguments = arg;
                [task launch];
                [task waitUntilExit];
            }
            else{
                //
                [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:NO attributes:NO error:&err];
                NSLog(@"err = %@", err);
            }

            MESALog(@"[warning] %@ does not exisit, create it now", folderPath);
            [errMsg addObject:err];
        }
    }
    
    return errMsg;
}

+(NSMutableDictionary *)ReadParamsFromPlist:(NSString *)configName
{
//    NSString *plistPath = [[NSBundle mainBundle] pathForResource:configName ofType:@"plist"];
    
    NSString *plistPath = @"/vault/MesaFixture/MesaMacConfig/";
    plistPath = [plistPath stringByAppendingString:configName];
    plistPath = [plistPath stringByAppendingString:@".plist"];
    
    NSMutableDictionary *plistDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    
    if (plistDictionary == nil) {
        MESALog(@"MesaMacConfig contain no configName list, use the one in App");
        plistPath = [[NSBundle mainBundle] pathForResource:configName ofType:@"plist"];
        plistDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        [Util SavePlist:configName withPara:plistDictionary];
    }
    return plistDictionary;
}

+(void) SavePlist:(NSString *)plist withPara:(NSMutableDictionary *)paraDic{
    NSString *plistPath = @"/vault/MesaFixture/MesaMacConfig/";
    plistPath = [plistPath stringByAppendingString:plist];
    plistPath = [plistPath stringByAppendingString:@".plist"];
    
    [paraDic writeToFile:plistPath atomically:YES];
}

#pragma mark - Deprecated soon
+(void) SaveSettingsToPlist:(NSMutableDictionary *)settingList{
    NSString *plistPath = @"/vault/MesaFixture/MesaMacConfig/settings.plist";
   
//     NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"];
    //MESALog(@"plistPath is %@",plistPath);
    [settingList writeToFile:plistPath atomically:YES];
    //[settingList writeToFile:@"~/Documents/Mesa-MAC/Mesa-MAC/settings.plist" atomically:YES];
    return;
}


#pragma mark - Deprecated
@end
