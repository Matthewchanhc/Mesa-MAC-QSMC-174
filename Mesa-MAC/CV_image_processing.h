//
//  CV_image_procrssing.h
//  MESA_V1_1
//
//  Created by MESA on 25/9/14.
//  Copyright (c) 2014 智偉 余. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>
#import "CircleFinder.h"
#import "PvAPI.h"
#import "DataCollctor.h"
#import "RectangleFinder.h"
#import "Util.h"


using namespace cv;

@interface CV_image_processing : NSObject{
    CircleFinder* cf;
    RectangleFinder* rf;
    
}

-(id)init;


-(tPvFrame)multi_frames_denoise : (Vector<tPvFrame>)source_frames;

-(Mat)find_brightest_and_darkest_region : (Mat)source_image;
-(int)calculate_ROI_intensity_average_in : (Mat)source_image ROI : (Rect_<int>) mask;
-(Mat)highlight_min_and_max_aveg_area_in:(Mat)source_img min_aveg_grid : (Rect_<int>) min_aveg_grid max_aveg_grid: (Rect_<int>) max_aveg_grid;

-(Mat)find_circle_in :(Mat)source_image;
-(Mat)find_rectangle_in :(Mat)source_image;

-(void)saveImagelogs : (Mat)sourceImage resultImage: (Mat)resultImage cx:(float)cx cy:(float)cy radius:(float)radius;

@property (assign) float x;
@property (assign) float y;
@property (assign) float roiAvgIntensity;

@property (strong) NSMutableDictionary * rectParaDictionary;
@property (strong) NSMutableDictionary * circleParaDictionary;


@end
