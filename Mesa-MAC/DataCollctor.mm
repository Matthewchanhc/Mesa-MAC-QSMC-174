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
    [DateFormatter setDateFormat:@"yyyyMMddHH"];
    NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
    
    NSString *tmpPath;
    
    if (_folderMode) {
        tmpPath = [NSString stringWithString:[_recordFolder stringByAppendingString:[dateTimeStr stringByAppendingString:@".log"]]];
    }
    else{
        tmpPath = _recordPath;
    }
    
   

    // 创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:tmpPath]) {
        // 如果文件不存在，则创建新文件并写入内容
        [fileManager createFileAtPath:tmpPath contents:nil attributes:nil];
    }

    // 打开文件以进行追加写入
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:tmpPath];
    [fileHandle seekToEndOfFile];

    // 将内容转换为NSData类型，并写入文件
    long datalen =_dataContent.length;
    if(datalen==0)
    {
        [fileHandle closeFile];
        return;
    }
    NSData *subData =[_dataContent subdataWithRange:NSMakeRange(0, datalen)];
     
    
    [fileHandle writeData:_dataContent];

    // 关闭文件句柄
    [fileHandle closeFile];
    
    [_dataContent replaceBytesInRange:NSMakeRange(0, datalen) withBytes:NULL length:0];
    //[_dataContent resetBytesInRange:NSMakeRange(0, datalen)];
      
      
      
}
-(void) writeToLogFile2:(NSString *) msg {
    @try {
        
        
        
        NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss "];
        NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
        
        NSString *content = [NSString stringWithString:dateTimeStr];
        
         
        NSString *tmp  = [msg stringByAppendingString:@"\n"];
        
        content = [content stringByAppendingString:tmp];
        
        
        
        // 获取当前日期
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd"];
        NSString *currentDate = [formatter stringFromDate:[NSDate date]];

        
        // 设置日志文件路径
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *logDirectory = @"/vault/MesaFixture/MesaLog";
        NSString *logFilePath = [logDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_Error2.log", currentDate]];

        // 检查目录是否存在，不存在则创建
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:logDirectory]) {
            [fileManager createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }

        // 将日志写入文件
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        if (!fileHandle) {
            [content writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandle closeFile];
        }
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
    
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
    NSLog(@"%@", msg);
    
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

void writeToLogFile(NSString *logMessage,...)NS_FORMAT_FUNCTION(1,2) {
    @try {
        va_list args;
        va_start(args, logMessage);
        NSString *msg = [[NSString alloc] initWithFormat:logMessage arguments:args];
        va_end(args);
        
        
        NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss "];
        NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
        
        NSString *content = [NSString stringWithString:dateTimeStr];
        
         
        NSString *tmp  = [msg stringByAppendingString:@"\n"];
        
        content = [content stringByAppendingString:tmp];
        
        
        
        // 获取当前日期
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd"];
        NSString *currentDate = [formatter stringFromDate:[NSDate date]];

        
        // 设置日志文件路径
        NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *logDirectory = @"/vault/MesaFixture/MesaLog";
        NSString *logFilePath = [logDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_Error.log", currentDate]];

        // 检查目录是否存在，不存在则创建
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:logDirectory]) {
            [fileManager createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }

        // 将日志写入文件
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        if (!fileHandle) {
            [content writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandle closeFile];
        }
    } @catch (NSException *exception) {
        MESALog(@"Error on writeToLogFile");
        MESALog(@"Error on writeToLogFile %@", exception);
        [defaultSpider writeToLogFile2:@"Error ON writeToLogFile"];
    } @finally {
        
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
