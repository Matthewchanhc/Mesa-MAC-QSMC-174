//
//  DataCollctor.m
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/9/17.
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

#import "DataCollctor.h"

DataCollctor *defaultSpider;

@interface DataCollctor ()

@property NSMutableData *dataContent;
@property float autoSaveSize;

@end

@implementation DataCollctor

-(id)init{
    if (self = [super init]) {
        _dataContent = [[NSMutableData alloc] init];
        _autoSaveSize = 5;
        _recordedWithTimestamp = YES;
        _folderMode = YES;
        _myLock = [[NSLock alloc] init];
    }
    
    if (defaultSpider == nil) {
        defaultSpider = self;
    }
    return self;
}

-(id)initWithFilePath:(NSString *)path andAutoSaveSize:(float)size{
    if (self = [super init])
    {
        _dataContent = [[NSMutableData alloc] init];
        _recordPath = path;
        _autoSaveSize = size;
        _recordedWithTimestamp = YES;
        _folderMode = NO;
        _myLock = [[NSLock alloc] init];
    }
    
    if (defaultSpider == nil) {
        defaultSpider = self;
    }
    return self;
}

-(id)initWithFolderPath:(NSString *)path andAutoSaveSize:(float)size{
    if (self = [super init])
    {
        _dataContent = [[NSMutableData alloc] init];
        
        if ([path characterAtIndex:[path length]-1] != '/')
        {
            path = [path stringByAppendingString:@"/"];
        }
        _recordFolder = path;
        _autoSaveSize = size;
        _recordedWithTimestamp = YES;
        _folderMode = YES;
        _myLock = [[NSLock alloc] init];
    }
    
    if (defaultSpider == nil) {
        defaultSpider = self;
    }
    return self;
}

-(void)addRecordWithData:(NSData *)record{
    [_myLock lock];
    NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
    [DateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss "];
    NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
    
    NSString *content = [NSString stringWithString:dateTimeStr];
    
    NSString *tmp = [[NSString alloc] initWithData:record  encoding:NSUTF8StringEncoding];
    tmp = [tmp stringByAppendingString:@"\n"];
    
    if (_recordedWithTimestamp) {
        content = [content stringByAppendingString:tmp];
    }
    
    NSData *tmpData = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    [_dataContent appendData:tmpData];
    if ([_dataContent length]> 1024 * 1024 * _autoSaveSize) {
        [self collectData];
    }
    [_myLock unlock];
}

-(void)collectData{
    NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
    [DateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
    
    NSString *tmpPath;
    
    if (_folderMode) {
        tmpPath = [NSString stringWithString:[_recordFolder stringByAppendingString:[dateTimeStr stringByAppendingString:@".log"]]];
    }
    else{
        tmpPath = _recordPath;
    }
    
    if ([_dataContent writeToFile:tmpPath atomically:YES]) {
        NSLog(@"Record down success");
    }
    else{
        NSLog(@"Fail to save record, please recheck the directory, directory:%@",_folderMode?_recordFolder:_recordPath);
    }
    _dataContent = nil;
    _dataContent = [[NSMutableData alloc] init];
}

-(BOOL)changeAutoSaveSize:(int)size{
    if (size > 50) {
        NSLog(@"Size > 50. Please set a smaller size");
        return false;
    }
    else
    {
        _autoSaveSize = size;
        return true;
    }
}

+(void)setDefaultDataCollector:(DataCollctor *)spider{
    defaultSpider = spider;
}

@end

bool MESALog(NSString *format, ...)NS_FORMAT_FUNCTION(1,2)
{
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(msg);
    
    if(defaultSpider == nil)
    {
        NSLog(@"No defaultSpider. Init one before use this method");
        return NO;
    }
    else
    {
        [defaultSpider addRecordWithData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
        return YES;
    }
}

void MESALog2(DataCollctor *spider, NSString *format, ...)NS_FORMAT_FUNCTION(2,3){
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(msg);
    [spider addRecordWithData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
}