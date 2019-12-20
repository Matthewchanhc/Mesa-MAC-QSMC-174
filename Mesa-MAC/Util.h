//
//  Util.h
//  Mesa-MAC
//
//  Created by Antonio Yu on 7/10/14.
//  Copyright (c) 2014 Antonio Yu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataCollctor.h"

@interface Util : NSObject

+(NSMutableArray*) CheckMesaFolder;

+(NSMutableDictionary *) ReadParamsFromPlist:(NSString *)plist;


+(void) SavePlist:(NSString *)plist withPara:(NSMutableDictionary *)paraDic;

#pragma mark - Deprecated soon
+(void) SaveSettingsToPlist:(NSMutableDictionary *)settingList;

#pragma mark - Deprecated
@end
