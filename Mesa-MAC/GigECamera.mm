//
//  camera_driver.m
//  cam_test
//
//  Created by Charlie on 24/7/14.
//
//  Edited by Sylar on 29/1/15
//  Q: = question    W: = warning    C: = comment    E: = edit
//
//  Copyright (c) 2014 智偉 余. All rights reserved.
//

#import "GigECamera.h"
#import "CV_image_processing.h"

/* frmae callback function(s), cannot be put inside class */

id refToSelf_A;
id refToSelf_B;

void PVDECL frame_received_callback_A(tPvFrame* pFrame){
    tPvFrame current_frame = *pFrame;
    [refToSelf_A frame_received : current_frame];
}

void PVDECL frame_received_callback_B(tPvFrame* pFrame){
    tPvFrame current_frame = *pFrame;
    [refToSelf_B frame_received : current_frame];
}


@implementation GigECamera

- (long)find_camera_ID:(const char *)cam_name
{
    tPvCameraInfoEx   camList[10];
    unsigned long     numCameras;
    long cam_ID = 0;
    
    camera_name = [[NSString alloc]initWithUTF8String:cam_name];
    
    numCameras = PvCameraListEx(camList, 10, NULL,sizeof(tPvCameraInfoEx));
    // Print a list of the connected cameras
    if(numCameras == 1)
        return camList[0].UniqueId;
    for (unsigned long i = 0; i < numCameras; i++)
    {
        if(strcmp(camList[i].CameraName, cam_name) == 0)
        {
            cam_ID = camList[i].UniqueId;
        }
    }
    return cam_ID;
}

- (tPvErr)open_camera:(long)cam_ID{
    MESALog(@"Opening camera with ID %lu.", cam_ID);
    
    // Open the camera
    cam = nil;
    err = PvCameraOpen(cam_ID, ePvAccessMaster, &cam);
    if(err != ePvErrSuccess){
        MESALog(@"cannot open camera, err =  %d", err);
        return err;
    }
    MESALog(@"Set camera packet size to %d.", CAMERA_PACKET_SIZE);
    err = PvAttrUint32Set(cam, "PacketSize", CAMERA_PACKET_SIZE);
    if(err != ePvErrSuccess) return err;
    
    tPvUint32 pktSize;
    PvAttrUint32Get(cam, "PacketSize", &pktSize);
    MESALog(@"Packet size set to %ld.", pktSize);
    
    MESALog(@"Set GvspRetries to 10.");
    err = PvAttrUint32Set(cam, "GvspRetries", 10);
    if(err != ePvErrSuccess) return err;
    
    MESALog(@"Set Stream Bytes per second to %d.", CAMERA_STREAM_BYTES_PER_SECOND);
    err = PvAttrUint32Set(cam, "StreamBytesPerSecond", CAMERA_STREAM_BYTES_PER_SECOND);
    if(err != ePvErrSuccess) return err;

    
    for (int f = 0; f < 10; f++){
        s_frames[f].ImageBuffer = 0;
    }
    s_frame_count = 0;
    if(s_frames[0].ImageBufferSize == 0)
    {
        MESALog(@"Setting width to %d.", CAMERA_ROI_W);
        [self setUint32:"Width" :CAMERA_ROI_W];
        img_width = CAMERA_ROI_W;
        
        MESALog(@"Setting height to %d.", CAMERA_ROI_H);
        [self setUint32:"Height" :CAMERA_ROI_H];
        img_height = CAMERA_ROI_H;
        
        MESALog(@"Setting RegionX to %d.", CAMERA_ROI_X);
        [self setUint32:"RegionX" :CAMERA_ROI_X];
        
        MESALog(@"Setting RegionY to %d.", CAMERA_ROI_Y);
        [self setUint32:"RegionY" :CAMERA_ROI_Y];
        
        // Get image size, ROI width and ROI height
        err = PvAttrUint32Get(cam, "TotalBytesPerFrame", &img_size);
        if(err != ePvErrSuccess) return err;
        MESALog(@"Camera image size = %lu", img_size);
        
        for (int f = 0; f < 10; f++){
            s_frames[f].ImageBuffer = new char[img_size];
            s_frames[f].ImageBufferSize = img_size;
        }
    }


    
    //for frame callback use
   refToSelf_A = self;
    

    /*
    if(strcmp(camera_name.UTF8String, CAM_A_NAME)){
        refToSelf_A = self;
        MESALog(@"ref to self A");
    }
    else if(strcmp(camera_name.UTF8String, CAM_B_NAME)){
        MESALog(@"ref to self B");
        refToSelf_B = self;
    }
    else if(camera_name.UTF8String == CAM_A_NAME){
        refToSelf_A = self;
        MESALog(@"ref to self AC");
    }
    else{
    }
    */
    
    cv_imgproc = [[CV_image_processing alloc]init];
   
    return ePvErrSuccess;
}

- (void)close_camera
{
    [NSThread sleepForTimeInterval:1];
    
    MESALog(@"Set trigger mode to freerun.");
    err = PvAttrEnumSet(cam, "FrameStartTriggerMode", "Freerun");
    
    MESALog(@"Camera closed.");
    
    PvCameraClose(cam);
    return;
}


- (tPvErr)capture_image_in_mode :(unsigned)capture_mode num_of_frames : (unsigned long)num_of_frames ns_img_view : (NSImageView*)img_view image_process_mode:(int)image_processing_mode{
    
    
    @try {
        img_proc_mode = image_processing_mode;
        
        MESALog(@"\n\n\n");
        loop_count = 0;
        //[self stop_capture];
        
        which_capture_mode = capture_mode;
        target_frame_count = num_of_frames;
        
        displayView = img_view;
        ik_disp_view.autoresizes = YES;
        [ik_disp_view setDoubleClickOpensImageEditPanel: NO];
        [ik_disp_view setCurrentToolMode : IKToolModeSelect];
        
        _is_capturing = true;
        
        err = PvCaptureEnd(cam);
        err = PvCommandRun(cam, "AcquisitionAbort");
        
        err = PvCaptureQueueClear(cam);
        if(err != ePvErrSuccess) MESALog(@"fail to clear queue, err code = %d", err);
        
        if (num_of_frames == camera_free_run_capture) {                                               //set to continuous capture
            err = PvAttrEnumSet(cam, "AcquisitionMode", "Continuous");
            if(err != ePvErrSuccess) return err;
            
            err = PvAttrUint32Set(cam, "AcquisitionFrameCount", 1);
            if(err != ePvErrSuccess) return err;
            
            //E: Feb/6th/2015, Sylar, try to change the FrameStartTriggerMode to fix frame mode for source saving, set the frame rate to 10 for now, which matches the time interval delate(0.1s) in the calibration's updateUI thread
            err = PvAttrEnumSet(cam, "FrameStartTriggerMode", "FixedRate");
            if(err != ePvErrSuccess){
                MESALog(@" err of set cam to fixed rate mode, code = %d", err);
                return err;
            }
            else{
                MESALog(@"[camera] set to fixed rate mode");
            }
            
            err = PvAttrFloat32Set(cam, "FrameRate", 7);
            if(err != ePvErrSuccess){
                MESALog(@" err of set cam to 7 frame rate, code = %d", err);
                return err;
            }
            else{
                MESALog(@"[camera] set frame rate to 7");

            }
            
        }
        
        else if(num_of_frames == camera_single_frame_capture) {                                           //set to single frame capture
            err = PvAttrEnumSet(cam, "AcquisitionMode", "SingleFrame");
            if(err != ePvErrSuccess) return err;
            
            err = PvAttrUint32Set(cam, "AcquisitionFrameCount", 1);
            if(err != ePvErrSuccess) return err;
            MESALog(@"setting fin in single mode");
        }
        else if (num_of_frames > 1){                                                            //set to multi-frame
            err = PvAttrEnumSet(cam, "AcquisitionMode", "MultiFrame");
            if(err != ePvErrSuccess) return err;
            
            err = PvAttrUint32Set(cam, "AcquisitionFrameCount", num_of_frames);
            if(err != ePvErrSuccess) return err;
        }
        
        char mode[12];
        unsigned long char_length_of_mode = 0;
        [self getEnum : "AcquisitionMode" : mode :12 :&char_length_of_mode];
        MESALog(@"AcquisitionMode set to '%s' mode", mode);
        
        
        
        if (capture_mode == camera_software_trigger) {                     //set to software trigger
            err = PvAttrEnumSet(cam, "AcqStartTriggerMode", "Disabled");
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Set Acquisition mode to software trigger.");
            
            err = PvCaptureStart(cam);
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Capture Start!!");
            
            err = PvCommandRun(cam, "AcquisitionStart");
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Acquisition start");
        }
        else if(capture_mode == camera_hardware_trigger){                  //set to hardware trigger
            err = PvAttrEnumSet(cam, "AcqStartTriggerMode", "SyncIn2");
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Set Acquisition mode to hardware trigger.");
            
            // Set the trigger event to EdgeRising
            MESALog(@"Set trigger event to EdgeRising.");
            err = PvAttrEnumSet(cam, "AcqStartTriggerEvent", "EdgeFalling");
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Set Acquisition event to falling edge");
            
            err = PvCaptureStart(cam);
            if(err != ePvErrSuccess) return err;
            else MESALog(@"Capture Start!!");
            
            MESALog(@"Waiting for electronic signal.....");
        }
        
        multi_source_frames.clear();
        
        err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_A);
        /*
        if (strcmp(camera_name.UTF8String, CAM_A_NAME)){
            err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_A);
        }
        else if (strcmp(camera_name.UTF8String, CAM_B_NAME)){
            err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_B);
        }
        */
        
        if (image_processing_mode == find_circle_mode || image_processing_mode == find_rectangle_mode || image_processing_mode == calculate_roi_intensity_average){

            isCompleteCalculation = false;
            
            while (isCompleteCalculation == false) {
                [NSThread sleepForTimeInterval:0.005];
            }
        }
        
        
    } @catch (NSException *exception) {
        writeToLogFile( @"Error on capture_image_in_mode" );
        writeToLogFile( @"Error on capture_image_in_mode: %@", exception.name);
        writeToLogFile( @"Error on capture_image_in_mode Reason: %@", exception.reason );
        
    } @finally {
        
    }
    
    
    return ePvErrSuccess;
}


- (void) display_image_to_GUI : (tPvFrame)in_frame;{
    // convert frame buffer to opencv Mat
    cv_source_img = Mat((int)img_height, (int)img_width, CV_8UC1, in_frame.ImageBuffer);    //for find circle
    cv_drawing_img = Mat((int)img_height, (int)img_width, CV_8UC3);                         //for display
    cvtColor(cv_source_img, cv_drawing_img, CV_GRAY2RGB);
    
    if (img_proc_mode == find_circle_mode) {
        cv_drawing_img = [cv_imgproc find_circle_in:cv_source_img];
        
        _centerX = cv_imgproc.x;
        _centerY = cv_imgproc.y;
        
        isCompleteCalculation = true;
        is_save_image = true;
        
    }
    else if (img_proc_mode == find_rectangle_mode){
        cv_drawing_img = [cv_imgproc find_rectangle_in:cv_source_img];
        
        _centerX = cv_imgproc.x;
        _centerY = cv_imgproc.y;
        
        isCompleteCalculation = true;
        is_save_image = true;
    }
    else if (img_proc_mode == find_min_max_area_mode){
        //[cv_imgproc imrotate:cv_source_img :cv_source_img :180];
        cv_drawing_img = [cv_imgproc find_brightest_and_darkest_region:cv_source_img];
    }
    else if (img_proc_mode == calculate_roi_intensity_average){
        
        NSDictionary *rectParaDictionary = [Util ReadParamsFromPlist:@"RectPara"];
        
        int inRectW =       [[rectParaDictionary objectForKey:@"Inner rect width"] intValue];
        int inRectH =       [[rectParaDictionary objectForKey:@"Inner rect height"] intValue];

        Rect_<int> *roi = new Rect_<int>();
        roi->width = inRectW;
        roi->height = inRectH;
        roi->x = (img_width - inRectW) / 2;
        roi->y = (img_height - inRectH) / 2;
        
        MESALog(@"ROI for intensity calculation: (%d, %d), w = %d, h = %d.", roi->x, roi->y, roi->width, roi->height);

        _roiAvgIntensity = [cv_imgproc calculate_ROI_intensity_average_in:cv_source_img ROI:*roi];
        
        isCompleteCalculation = true;
        delete roi;
    }
    // 2023-10-16 Matthew always save image
    if (is_save_image == true){
        
        NSDateFormatter *DateFormatter=[[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        NSString *dateTimeStr = [[NSString alloc]initWithFormat:@"%@",[DateFormatter stringFromDate:[NSDate date]]];
        
        NSString* path = [[NSString alloc]initWithFormat:@"%@%@%@", @"/Vault/MesaFixture/MesaPic/Result/", dateTimeStr, @".png"];
        NSString* path1 = [[NSString alloc]initWithFormat:@"%@%@%@", @"/Vault/MesaFixture/MesaPic/", dateTimeStr, @".png"];
        imwrite([path UTF8String], cv_drawing_img);
        imwrite([path1 UTF8String], cv_source_img);
        //E: Jan/30th/2015, Sylar, change the is_save_image to NO to make sure the photo saving do once per click
        is_save_image = false;
    }
    
    cvtColor(cv_drawing_img, cv_drawing_img, CV_BGR2RGB);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, cv_drawing_img.data, (img_width * img_height * 3), NULL);
    CGImageRef Image_CG_Ref = CGImageCreate(img_width, img_height,8, 8*3, img_width*3, CGColorSpaceCreateDeviceRGB(), kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    
    // convert frame buffer to CGimage
    //CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, in_frame.ImageBuffer, (img_width * img_height), NULL);
    //CGImageRef Image_CG_Ref = CGImageCreate(img_width, img_height,8, 8, img_width, CGColorSpaceCreateDeviceGray(), kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    @autoreleasepool {
        img = [[NSImage alloc]initWithCGImage:Image_CG_Ref size:{(CGFloat)img_width, (CGFloat)img_height}];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [displayView setImage:img];
        });
    }
    
    CGDataProviderRelease(provider);
    CGImageRelease(Image_CG_Ref);

    _is_capturing = false;

   // MESALog(@"Circle results = (%f, %f)", _centerX, _centerY);
}

- (void) frame_received : (tPvFrame)in_frame{
    
    
    @try {
        
        if (in_frame.Status != 0) {
            MESALog(@"error code is : %@", [self err_code_to_txt_msg:in_frame.Status]);
        }
        else {
            MESALog(@"frame count = %lu, loop count = %lu, lost frame = %lu", in_frame.FrameCount, ++loop_count, in_frame.FrameCount - loop_count);
        }
        
        
        /* determine the next step base on current capture mode :
         
         * Software trigger : freerun           keep capturing
                              single frame      end capture
                              multi-frame       if receive all frames -> end capture, else -> keep capturing
         
         * Hareware trigger : freerun           keep capturing
                              single frame      reset the "frame->FrameCount", then keep capturing
                              multi-frame       if receive all frames -> reset the "frame->FrameCount", then keep capturing
                                                                 else -> keep capturing
         
         *** The reason why software trigger no need to reset FrameCount is it will be reseted automatically in the next SW trigger signal
        */
        NSString *state;
        bool is_display_now = false;
        
        switch (which_capture_mode) {
            case camera_software_trigger:
                if (target_frame_count == camera_free_run_capture){
                    state = @"keep capturing";
                    is_display_now = true;
                }
                else if (target_frame_count == camera_single_frame_capture){
                    state = @"end capture";
                    is_display_now = true;
                }
                else if (target_frame_count > 1){
                    multi_source_frames.push_back(in_frame);
                    if (in_frame.FrameCount == target_frame_count){
                        in_frame = [cv_imgproc multi_frames_denoise:multi_source_frames];
                        multi_source_frames.clear();
                        state = @"end capture";
                        is_display_now = true;
                    }
                    else{
                        state = @"keep capturing";
                        is_display_now = false;
                    }
                }
                break;
                
            case camera_hardware_trigger:
                if (target_frame_count == camera_free_run_capture){
                    state = @"keep capturing";
                    is_display_now = true;
                }
                else if (target_frame_count == camera_single_frame_capture){
                    state = @"reset framecount";
                    is_display_now = true;
                }
                else if (target_frame_count > 1){
                    multi_source_frames.push_back(in_frame);
                    if (in_frame.FrameCount == target_frame_count){
                        in_frame = [cv_imgproc multi_frames_denoise:multi_source_frames];
                        multi_source_frames.clear();
                        state = @"reset framecount";            //reset frame.FrameCount which is read from camera
                        is_display_now = true;
                    }
                    else{
                        state = @"keep capturing";
                        is_display_now = false;
                    }
                }
                break;
        }
        
        
        //reset frame->FrameCount that read from camera, only do it in HW trigger
        if ([state isEqualToString:@"reset framecount"]) {
            PvCaptureEnd(cam);
            err = PvCaptureStart(cam);
            loop_count = 0;
            state = @"keep capturing";
        }
        
        
        if ([state isEqualToString:@"keep capturing"]) {
            err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_A);
            s_frame_count++;
            if (s_frame_count < 10) {
                s_frame_count = 0;
            }
            
            /*
            if (strcmp(camera_name.UTF8String, CAM_A_NAME)){
                err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_A);
                s_frame_count = !s_frame_count;
            }
            else if (strcmp(camera_name.UTF8String, CAM_B_NAME)) {
                err = PvCaptureQueueFrame(cam, &s_frames[s_frame_count], frame_received_callback_B);
                s_frame_count = !s_frame_count;
            }
             */
        }
        else if ([state isEqualToString:@"end capture"]){
            PvCaptureEnd(cam);
        }
        
        if (is_display_now == true){
            [self display_image_to_GUI : in_frame];
        }
        
        
    } @catch (NSException *exception) {
        writeToLogFile( @"Error on frame_received" );
        writeToLogFile( @"Error on frame_received: %@", exception.name);
        writeToLogFile( @"Error on frame_received Reason: %@", exception.reason );
        
    } @finally {
        
    }
    
  

}


- (tPvErr)stop_capture
{
    err = PvCaptureQueueClear(cam);
    if(err != ePvErrSuccess) return err;
    
    err = PvCommandRun(cam, "AcquisitionStop");
    if(err != ePvErrSuccess) return err;
    
    err = PvCaptureEnd(cam);
    if(err != ePvErrSuccess) return err;
    
    return ePvErrSuccess;
    
}

- (void)set_image_processing_to_mode:(int)mode{
    img_proc_mode = mode;
}

- (void)find_brightest_and_darkest_area : (bool)is_enable{
    is_find_max_and_min_intensity_average = is_enable;
}

- (void) save_image : (bool)is_save{
    is_save_image = is_save;
}



- (NSString*)err_code_to_txt_msg:(tPvErr)error_code{

    NSString* err_msg;
    
    switch (error_code) {
       case ePvErrSuccess:
           err_msg = @"No error";
           break;
            
       case ePvErrCameraFault:
           err_msg = @"Unexpected camera fault";
           break;
            
       case ePvErrInternalFault:
           err_msg = @"Unexpected fault in PvApi or driver";
           break;
            
       case ePvErrBadHandle:
           err_msg = @"Bad parameter to API call";
           break;
           
       case ePvErrBadSequence:
           err_msg = @"Sequence of API calls is incorrect";
           break;
            
       case ePvErrNotFound:
           err_msg = @"Camera or attribute not found";
           break;
            
       case ePvErrAccessDenied:
           err_msg = @"Camera cannot be opened in the specified mode";
           break;
            
       case ePvErrUnplugged:
           err_msg = @"Camera was unplugged";
           break;
            
       case ePvErrInvalidSetup:
           err_msg = @"Setup is invalid (an attribute is invalid)";
           break;
            
       case ePvErrResources:
           err_msg = @"System/network resources or memory not available";
           break;
            
       case ePvErrBandwidth:
           err_msg = @"1394 bandwidth not available";
           break;
            
       case ePvErrQueueFull:
           err_msg = @"Too many frames on queue";
           break;
            
       case ePvErrBufferTooSmall:
           err_msg = @"Frame buffer is too small";
           break;
        
       case ePvErrCancelled:
           err_msg = @"Frame cancelled by user";
           break;
            
       case ePvErrDataLost:
           err_msg = @"The data for the frame was lost";
           break;
            
       case ePvErrDataMissing:
           err_msg = @"Some data in the frame is missing";
           break;
            
       case ePvErrTimeout:
           err_msg = @"Timeout during wait";
           break;
            
       case ePvErrOutOfRange:
           err_msg = @"Attribute value is out of the expected range";
           break;
            
       case ePvErrWrongType:
           MESALog(@"Attribute is not this type (wrong access function)");
           break;
            
       case ePvErrForbidden:
           err_msg = @"Attribute write forbidden at this time";
           break;
            
       case ePvErrUnavailable:
           err_msg = @"Attribute is not available at this time";
           break;
            
       case ePvErrFirewall:
           err_msg = @"A firewall is blocking the traffic (Windows only)";
           break;
            
       default:
           err_msg = nil;
           break;
       }
        
       return err_msg;
}


- (tPvErr)getUint32:(const char *) attr :(tPvUint32 *)val
{
    err = PvAttrUint32Get(cam, attr, val);
    
    if(err != ePvErrSuccess)
        MESALog(@"Get attr %s error. Code = %d.",  attr, err);
    
    return err;
    
}   // end (tPvErr) GetUint32:(const char *) attr :(tPvUint32 *)val



- (tPvErr)getUint32Range:(const char *) attr :(tPvUint32 *)min :(tPvUint32 *)max
{
    err = PvAttrRangeUint32(cam, attr, min, max);
    
    if(err != ePvErrSuccess)
        MESALog(@"Get attr %s range error: code = %d", attr, err);
    
    return err;
    
}   // end (tPvErr) GetUint32Range:(const char *) attr :(tPvUint32 *)min :(tPvUint32 *)max



- (tPvErr)setUint32:(const char *) attr :(tPvUint32)val
{
    err = PvAttrUint32Set(cam, attr, val);
    
    if(err != ePvErrSuccess)
        MESALog(@"Set attr %s to %lu error. Code = %d.", attr, val, err);
    
    return err;
    
}   // end (tPvErr) SetUint32:(const char *) attr :(tPvUint32)val



- (tPvErr)getFloat32:(const char *) attr :(tPvFloat32 *)val
{
    err = PvAttrFloat32Get(cam, attr, val);
    
    if(err != ePvErrSuccess)
        MESALog(@"Get attr %s error. Code = %d.",  attr, err);
    
    return err;
    
}   // end (tPvErr) GetFloat32:(const char *) attr :(tPvFloat32 *)val



- (tPvErr)getFloat32Range:(const char *) attr :(tPvFloat32 *)min :(tPvFloat32 *)max
{
    err = PvAttrRangeFloat32(cam, attr, min, max);
    
    if(err != ePvErrSuccess)
        MESALog(@"Get attr %s range error. Code = %d.", attr, err);
    
    return err;
    
}   // end (tPvErr) GetFloat32Range:(const char *) attr :(tPvFloat32 *)min :(tPvFloat32 *)max



- (tPvErr)setFloat32:(const char *) attr :(tPvFloat32)val
{
    err = PvAttrFloat32Set(cam, attr, val);
    
    if(err != ePvErrSuccess)
        MESALog(@"Set attr %s to %f error. Code = %d.", attr, val, err);
    
    return err;
    
}   // end (tPvErr) SetFloat32:(const char *) attr :(tPvFloat32)val



- (tPvErr)getEnum:(const char *) attr :(char *)val :(unsigned long)bufferSize :(unsigned long *)pSize
{
    err = PvAttrEnumGet(cam, attr, val, bufferSize, pSize);
    
    if(err != ePvErrSuccess)
        MESALog(@"Get attr %s error. Code = %d.", attr, err);
    
    return err;
    
}   // end (tPvErr) GetEnum:(const char *) attr :(char *)val :(unsigned long)bufferSize :(unsigned long *)pSize



- (tPvErr)setEnum:(const char *) attr :(char *)val
{
    err = PvAttrEnumSet(cam, attr, val);
    
    if(err != ePvErrSuccess)
        MESALog(@"Set attr %s to %s error. Code = %u.", attr, val, err);
    
    return err;
    
}   // end (tPvErr) SetEnum:(const char *) attr :(char *)val


@end
