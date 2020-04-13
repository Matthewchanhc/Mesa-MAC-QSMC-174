//
//  camera_driver.h
//  cam_test
//
//  Created by Charlie on 24/7/14.
//
//  Edited by Sylar on 29/1/15
//  Q: = question    W: = warning    C: = comment    E: = edit
//
//  Copyright (c) 2014 智偉 余. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "PvAPI.h"
#import <Quartz/Quartz.h>
#import "CV_image_processing.h"
#import "DataCollctor.h"


//#define EE
#define MESA

#ifdef EE

    #define CAM_A_NAME "02-5000B"
    #define CAM_B_NAME "Mako G-125B"

    #define CAMERA_DISCOVERY_INTERVAL 500000
    #define CAMERA_PACKET_SIZE 8000
    #define CAMERA_STREAM_BYTES_PER_SECOND 40000000
    #define CAMERA_CAPTURE_TIMEOUT 500000

    #define CAMERA_ROI_W 2000
    #define CAMERA_ROI_H 2000
    #define CAMERA_ROI_X 224
    #define CAMERA_ROI_Y 25
#endif

#ifdef MESA
    //E: Jan/29th/2015, Sylar, change to real cam model
    #define CAM_A_NAME "MA04 G-2590B  "
    #define CAM_B_NAME "Mako G-503B"

    #define CAMERA_DISCOVERY_INTERVAL 500000
    #define CAMERA_PACKET_SIZE 9000
    #define CAMERA_STREAM_BYTES_PER_SECOND 115000000
    #define CAMERA_CAPTURE_TIMEOUT 500000

    #define CAMERA_ROI_W 2592
    #define CAMERA_ROI_H 1944
    #define CAMERA_ROI_X 0
    #define CAMERA_ROI_Y 0

#endif

enum camera_capture_mode {
    camera_free_run_capture = 0,
    camera_single_frame_capture = 1,
    camera_software_trigger = 2,
    camera_hardware_trigger = 3
    //FrameStartTriggerMode
    };

enum image_processing_mode{
    normal_run = 0,
    find_circle_mode = 1,
    find_min_max_area_mode = 2,
    find_rectangle_mode = 3,
    calculate_roi_intensity_average = 4,
};

@interface GigECamera : NSObject{
    
    @private
    
    bool isCompleteCalculation;
    
    tPvHandle cam;
    tPvErr err;
    tPvFrame s_frames[10];
    int s_frame_count;
    
    tPvUint32 img_size;
    tPvUint32 img_width;
    tPvUint32 img_height;
    
    unsigned long which_capture_mode;
    unsigned long loop_count;
    unsigned long target_frame_count;
    
    NSImage* img;
    NSImageView *displayView;
    IKImageView *ik_disp_view;
    unsigned char* img_array;
    
    NSString *camera_name;
    
    bool is_find_max_and_min_intensity_average;
    bool is_save_image;
    
    // OpenCV and image processing variables
    CV_image_processing* cv_imgproc;
    
    Mat cv_source_img;                      //for find circle
    Mat cv_drawing_img;                     //for display
    int img_proc_mode;
    vector<tPvFrame> multi_source_frames;
    int save_count;
    // End of OpenCV and image processingvariables
}
//E: Jan/29th/2015, Sylar, Add circle x, y attr
@property (assign) float centerX;
@property (assign) float centerY;

// 14/11/2018, Antonio
@property (assign) float roiAvgIntensity;

- (long)find_camera_ID:(const char *)cam_name;
- (tPvErr)open_camera:(long)camID;
- (void)close_camera;

- (tPvErr)capture_image_in_mode :(unsigned)capture_mode
                  num_of_frames : (unsigned long)num_of_frames
                    ns_img_view : (NSImageView*)img_view
             image_process_mode : (int)image_processing_mode;

- (tPvErr)stop_capture;

- (void) frame_received : (tPvFrame)in_frame;
- (void) display_image_to_GUI : (tPvFrame)in_frame;;

- (void) find_brightest_and_darkest_area : (bool)is_enable;
- (void) save_image : (bool)is_save;
- (void) set_image_processing_to_mode : (int)mode;

- (NSString*)err_code_to_txt_msg:(tPvErr)error_code;


- (tPvErr)getUint32:(const char *) attr :(tPvUint32 *)val;
- (tPvErr)getUint32Range:(const char *) attr :(tPvUint32 *)min :(tPvUint32 *)max;
- (tPvErr)setUint32:(const char *) attr :(tPvUint32)val;

- (tPvErr)getFloat32:(const char *) attr :(tPvFloat32 *)val;
- (tPvErr)getFloat32Range:(const char *) attr :(tPvFloat32 *)min :(tPvFloat32 *)max;
- (tPvErr)setFloat32:(const char *) attr :(tPvFloat32)val;

- (tPvErr)getEnum:(const char *) attr :(char *)val :(unsigned long)bufferSize :(unsigned long *)pSize;
- (tPvErr)setEnum:(const char *) attr :(char *)val;

@property (assign) bool is_capturing;

@end
