//
//  DataCollctor.h
//  Mesa-MAC
//
//  Created by MetronHK_Sylar on 15/9/17.
//  Copyright (c) 2015年 Antonio Yu. All rights reserved.
//

/**
 *  This class will handle the data collection work. Ideally, it will provide an entrance to save down one message. Only NSData will be allowed for now
 *
 *  One force save method is implemented and auto save machanism is also important for system perfoamance. I will like this spiderman auto save file every 5MB NSData is collected.
 */
#import <Foundation/Foundation.h>

@interface DataCollctor : NSObject

@property NSLock *myLock;

/**
 *  The active mode of DataCollector. DataCollctor could save logs in two ways, either save them into one folder or save them to one file.
 */
@property bool folderMode;

/**
 *  Path for file mode, will be changed to NSURL soon
 */
@property NSString *recordPath;
/**
 *  Path for folder mode, will be changed to NSURL soon
 */
@property NSString *recordFolder;
/**
 *  Set true to let the log save with timestamp
 */
@property bool recordedWithTimestamp;

-(id)initWithFilePath:(NSString *)path andAutoSaveSize:(float)size;

-(id)initWithFolderPath:(NSString *)path andAutoSaveSize:(float)size;

/**
 *  Call this method to add new record into the memory of this object. This method may cause auto save if the size of the recorded data is large enough
 *
 *  @param record needed saved data
 */
-(void)addRecordWithData:(NSData *)record;

/**
 *  Call this method will save the collected data to the path set before
 */
-(void)collectData;

-(BOOL)changeAutoSaveSize:(int)size;

/**
 *  This method will save a default DataCollector for log to call. This is implemented to make the MESALog with the same format as NSLog had.
 */
+(void)setDefaultDataCollector:(DataCollctor *)spider;

@end

/**
 *  This method will let the default DataCollector collect the given format input string and log it into system.log at the same time
 *
 *  @param format Format string
 *  @param ...    Format string paras
 *
 *  @return YES if success
 */
FOUNDATION_EXPORT bool MESALog(NSString *format, ...)NS_FORMAT_FUNCTION(1,2);

/**
 *  This method will let the given DataCollector collect the given format input string and log it into system.log at the same time
 *
 *  @param spider The dataCollector
 *  @param format Format string
 *  @param ...    Format string paras
 */
FOUNDATION_EXPORT void MESALog2(DataCollctor *spider,NSString *format, ...)NS_FORMAT_FUNCTION(2,3);
