//
//  CV_image_procrssing.m
//  MESA_V1_1
//
//  Created by MESA on 25/9/14.
//  Copyright (c) 2014 智偉 余. All rights reserved.
//

#import "CV_image_processing.h"
//#import "AppDelegate.h"

@implementation CV_image_processing

-(id)init{
    cf = [[CircleFinder alloc] init];
    rf = [[RectangleFinder alloc] init];
    
    // read para form plist
    _rectParaDictionary = [Util ReadParamsFromPlist:@"RectPara"];
    _circleParaDictionary = [Util ReadParamsFromPlist:@"CirclePara"];
    
    MESALog(@"Initializing image processing library");
    return self;
}

-(tPvFrame)multi_frames_denoise : (vector<tPvFrame>)source_frames{
    long num_of_frames = source_frames.size();
    long buffer_size = source_frames[1].ImageSize;
    long all_images_current_intensity = 0;
    UInt8 intensity_after_denoise;
    UInt8 *denoised_data = NULL;
    denoised_data = (uint8*)calloc(buffer_size, sizeof(uint8));
    tPvFrame denoised_frame = source_frames[1];
    
    
    for (long xy = 0; xy < buffer_size; xy++) {
        for (int i = 0; i < num_of_frames; i++) {
            all_images_current_intensity += (long)((UInt8*)source_frames[i].ImageBuffer)[xy];
        }
        intensity_after_denoise = (UInt8)(all_images_current_intensity / num_of_frames);
        denoised_data[xy] = intensity_after_denoise;
        all_images_current_intensity = 0;
    }
    
    denoised_frame.ImageBuffer = denoised_data;
    free(denoised_data);
    return denoised_frame;
}


-(Mat)find_brightest_and_darkest_region : (Mat)source_image{
    
    int img_width = source_image.cols;
    int img_height = source_image.rows;
    
    Rect_<int> grid = {0,0,100,100};
    
    Rect_<int> current_grid;
    int intensity_average = 0;
    
    int max_aveg = 0;
    Rect_<int> max_aveg_grid;
    
    int min_aveg = 255;
    Rect_<int> min_aveg_grid;
    
    
    for (int y = 0; y <= img_height - grid.height; y += grid.height) {
        for (int x = 0; x <= img_width - grid.width; x += grid.width) {
            grid.x = x;
            grid.y = y;
            
            current_grid = {grid.x, grid.y, grid.width, grid.height};
            
            // find each grid's average intensity
            intensity_average = [self calculate_ROI_intensity_average_in:source_image ROI:current_grid];
            
            //find max aveg grid
            if (intensity_average >= max_aveg) {
                max_aveg = intensity_average;
                max_aveg_grid.x = grid.x;
                max_aveg_grid.y = grid.y;
                max_aveg_grid.width = grid.width;
                max_aveg_grid.height = grid.height;
            }
            
            //find min aveg grid
            if (intensity_average <= min_aveg) {
                min_aveg = intensity_average;
                min_aveg_grid.x = grid.x;
                min_aveg_grid.y = grid.y;
                min_aveg_grid.width = grid.width;
                min_aveg_grid.height = grid.height;
            }
        }
    }

    return [self highlight_min_and_max_aveg_area_in : source_image
                                      min_aveg_grid : min_aveg_grid
                                      max_aveg_grid : max_aveg_grid];
}


-(int)calculate_ROI_intensity_average_in : (Mat)source_image ROI : (Rect_<int>) mask{
    
    int intensity_average = 0;
    long all_pixel_value = 0;
    
    int number_of_pixels = mask.width * mask.height;
    
    for (int y = mask.y; y < mask.y + mask.height; y++) {
        for (int x = mask.x; x < mask.x + mask.width; x++) {
            all_pixel_value += (long)source_image.at<uchar>(cv::Point(x, y));
        }
    }
    
    intensity_average = (int)(all_pixel_value / (long)number_of_pixels);
    
    return intensity_average;
}

-(Mat)highlight_min_and_max_aveg_area_in:(Mat)source_img min_aveg_grid : (Rect_<int>) min_aveg_grid max_aveg_grid : (Rect_<int>) max_aveg_grid{
    
    Mat output_img;
    cvtColor(source_img, output_img, CV_GRAY2RGB);
    
    rectangle(output_img, min_aveg_grid, Scalar(0,255,0),8,8,0);  //Green in darkest region
    rectangle(output_img, max_aveg_grid, Scalar(0,0,255),8,8,0);  //Red in brightest region

    return output_img;
}

-(Mat)find_circle_in :(Mat)source_image{

    @try {
        
        Mat output_image = Mat(source_image.rows, source_image.cols, CV_8UC3);
        cvtColor(source_image, output_image, CV_GRAY2RGB);
        
        /* apply parameter from plist */
        _circleParaDictionary = [Util ReadParamsFromPlist:@"CirclePara"];
        
        int innerCircleRad =    [[_circleParaDictionary objectForKey:@"Inner circle width"] intValue];
        int outerCircleRad =    [[_circleParaDictionary objectForKey:@"Outer circle width"] intValue];
        int deltaAng =          [[_circleParaDictionary objectForKey:@"Delta Angle"] intValue];
        int kernelType =        [[_circleParaDictionary objectForKey:@"Kernel Type"] intValue];
        int kernelWidth =       [[_circleParaDictionary objectForKey:@"Kernel Width"] intValue];
        int direction =         [[_circleParaDictionary objectForKey:@"Direction"] intValue];
        int threshold =         [[_circleParaDictionary objectForKey:@"Threshold"] intValue];
        int edgeType =          [[_circleParaDictionary objectForKey:@"Edge type"] intValue];
        int whichEdge =         [[_circleParaDictionary objectForKey:@"Which edge"] intValue];

        MESALog(@"Source image height = %d", source_image.rows);
        MESALog(@"Source image width = %d", source_image.cols);
        MESALog(@"Inner circle radius = %d", innerCircleRad);
        MESALog(@"Outer circle radius = %d", outerCircleRad);
        MESALog(@"Delta angle = %d", deltaAng);
        MESALog(@"Kernel Type = %d", kernelType);
        MESALog(@"Kernel Width = %d", kernelWidth);
        MESALog(@"Direction = %d", direction);
        MESALog(@"Threshold = %d", threshold);
        MESALog(@"Edge type = %d", edgeType);
        MESALog(@"Which edge = %d", whichEdge);

        edgeError err;
        fittedCircle mesaButton;
        edgeInfo edgeResultInfo;
        
        err = [cf FindCircleIn:source_image
                   ResultImage:output_image
                       CenterX:source_image.cols/2
                       CenterY:source_image.rows/2
             InnerCircleRadius:innerCircleRad
             OuterCircleRadius:outerCircleRad
                   DetltaAngle:deltaAng
                    KernelType:kernelType
                   kernelWidth:kernelWidth
            SearchingDirection:direction
                 EdgeThreshold:threshold
                      EdgeType:edgeType
                     WhichEdge:whichEdge
                  CircleResult:mesaButton
                      EdgeInfo:edgeResultInfo];
        

        if (err == noError){
            _x = mesaButton.cx;
            _y = mesaButton.cy;
        }
        else{
            _x = -1;
            _y = -1;
        
        }
        

        MESALog(@"Error = %d", err);
        MESALog(@"circle center = (%f, %f)", _x,_y);
    /*
        if (IMAGESAVING){
            [self saveImagelogs:source_image resultImage:output_image cx:mesaButton.cx cy:mesaButton.cy radius:mesaButton.radius];
        }
    */
        return output_image;
    } @catch (NSException *exception) {
        MESALog(@"Error  on find_circle_in ");
        MESALog(@"Error  on find_circle_in= %d", exception);
        writeToLogFile( @"Error  on find_circle_in.");
        writeToLogFile(@"Error  on find_circle_in= %d", exception);
        
         
    } @finally {
    }
}

-(Mat)find_rectangle_in :(Mat)source_image{
    
    Mat output_image = Mat(source_image.rows, source_image.cols, CV_8UC3);
    cvtColor(source_image, output_image, CV_GRAY2RGB);
    
    /* apply parameter from plist */
    _rectParaDictionary = [Util ReadParamsFromPlist:@"RectPara"];
    
    int outRectW =      [[_rectParaDictionary objectForKey:@"Outer rect width"] intValue];
    int outRectH =      [[_rectParaDictionary objectForKey:@"Outer rect height"] intValue];
    int inRectW =       [[_rectParaDictionary objectForKey:@"Inner rect width"] intValue];
    int inRectH =       [[_rectParaDictionary objectForKey:@"Inner rect height"] intValue];
    int interval =      [[_rectParaDictionary objectForKey:@"Line Interval"] intValue];
    int kernelType =    [[_rectParaDictionary objectForKey:@"Kernel Type"] intValue];
    int kernelWidth =   [[_rectParaDictionary objectForKey:@"Kernel Width"] intValue];
    int direction =     [[_rectParaDictionary objectForKey:@"Direction"] intValue];
    int threshold =     [[_rectParaDictionary objectForKey:@"Threshold"] intValue];
    int edgeType =      [[_rectParaDictionary objectForKey:@"Edge type"] intValue];
    int whichEdge =     [[_rectParaDictionary objectForKey:@"Which edge"] intValue];
    
    edgeError err;
    fittedRectangle mesaButton;
    edgeInfo edgeResultInfo;
    
    err = [rf FindRectangleIn:source_image
                  ResultImage:output_image
                      CenterX:source_image.cols/2
                      CenterY:source_image.rows/2
               OuterRectWidth:outRectW
              OuterRectHeight:outRectH
               InnerRectWidth:inRectW
              InnerRectHeight:inRectH
                 LineInterval:interval
                   KernelType:kernelType
                  kernelWidth:kernelWidth
           SearchingDirection:direction
                EdgeThreshold:threshold
                     EdgeType:edgeType
                    WhichEdge:whichEdge
              RectangleResult:mesaButton
                     EdgeInfo:edgeResultInfo];
    
    // draw a "+" in center for user to calibration
    CvPoint center = cvPoint(output_image.cols / 2, output_image.rows / 2);
    for (int l = -7; l <= 7; l++){
        line(output_image, cvPoint(center.x + l, center.y - 50), cvPoint(center.x + l, center.y + 50), Scalar(0,0,255));
        line(output_image, cvPoint(center.x - 50, center.y + l), cvPoint(center.x + 50, center.y + l ), Scalar(0,0,255));
    }

    if (err == noError){
        _x = mesaButton.Center.x;
        _y = mesaButton.Center.y;
    }
    else{
        _x = -1;
        _y = -1;
    }
    
    MESALog(@"rectangle center = (%f, %f)", _x,_y);
    
/*
    if (IMAGESAVING){
        //Mat croppedImage = drawingImage(cv::Rect(internalImage.cols/2 - 710, internalImage.rows/2 - 710, 1420, 1420));
        //14,March,2016 : save a cropped result image to reduce image size
        Mat croppedImage = output_image(cv::Rect(source_image.cols/2 - (outRectW/2+10), source_image.rows/2 - (outRectH/2+10), outRectW+20, outRectH+20));
        [self saveImagelogs:source_image resultImage:croppedImage cx:mesaButton.Center.x cy:mesaButton.Center.y radius:-100];
    }
*/
    return output_image;

}

-(void)saveImagelogs : (Mat)sourceImage resultImage: (Mat)resultImage cx:(float)cx cy:(float)cy radius:(float)radius{
    
    // create current time string
    NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
    [DateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];

    
    
    //-------------------save source image-------------------
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = @"/vault/MesaFixture/MesaPic";
    if([fm fileExistsAtPath:path]==NO){
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    path = [path stringByAppendingString:@"/"];
    
    //  NSString *path = @"/vault/MesaFixture/MesaPic/";
    path = [path stringByAppendingString:dateTimeStr];
    path = [path stringByAppendingString:@".png"];
    
    
    if(imwrite([path UTF8String], sourceImage))
        MESALog(@"write image suc");
    else
        MESALog(@"write image fail");
    //-------------------save source image END -------------------

    
    
    
    //------------------- save result image ----------------------
    NSString *resultPath = @"/vault/MesaFixture/MesaPic/Result";
    resultPath = [resultPath stringByAppendingString:@"/"];
    resultPath = [resultPath stringByAppendingString:dateTimeStr];
    resultPath = [resultPath stringByAppendingString:@".jpg"];
    
    if(imwrite([resultPath UTF8String], resultImage))
        MESALog(@"write result image suc");
    else
        MESALog(@"write result image fail");
    //------------------- save result image END----------------------
    
    
    
    
    //-------------------- save cx, cy in csv file -----------------
    NSString* outHeader;
    NSString* outMsg;
    
    if (radius == -100) {   // in find rectangle mode
        outHeader = [NSString stringWithFormat:@"Image name, Cx, Cy\n"];
        outMsg = [NSString stringWithFormat:@"%@.png, %f, %f\n", dateTimeStr, cx, cy];
    }
    else{
        outHeader = [NSString stringWithFormat:@"Image name, Cx, Cy, Radius\n"];
        outMsg = [NSString stringWithFormat:@"%@.png, %f, %f, %f\n", dateTimeStr, cx, cy, radius];
    }
    
    
    NSString *csvPath = @"/vault/MesaFixture/MesaPic/rect_result.csv";
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:csvPath];
    
    if (fileHandler == nil){
        [fileHandler closeFile];
        
        NSString *firstData = [NSString stringWithFormat:@"%@%@", outHeader, outMsg];
        [firstData writeToFile:csvPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    else{
        [fileHandler seekToEndOfFile];
        [fileHandler writeData:[outMsg dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandler closeFile];
    }
    //-------------------- save cx, cy in csv file END -----------------

}


@end
