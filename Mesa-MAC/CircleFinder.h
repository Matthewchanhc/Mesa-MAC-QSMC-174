//
//  circle_finder.h
//  MESA_V1_1
//
//  Created by Charlie on 24/9/14.
//  Copyright (c) 2014 智偉 余. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>
#import <math.h>
#import <vector>
#import "EdgeFinder.h"

#define pi 3.141592654

using namespace std;
using namespace cv;



struct fittedCircle {
    double cx;
    double cy;
    double radius;
};

@interface CircleFinder : NSObject{
    
}

- (edgeError) FindCircleIn : (Mat) inputImage
               ResultImage : (Mat) drawingImage
                   CenterX : (int) cx
                   CenterY : (int) cy
         InnerCircleRadius : (int) innerRadius
         OuterCircleRadius : (int) outerRadius
               DetltaAngle : (int) deltaAngle
                KernelType : (int) kernelType
               kernelWidth : (int) kernelWidth
        SearchingDirection : (int) direction
             EdgeThreshold : (double) edgeThreshold
                  EdgeType : (int) edgeType
                 WhichEdge : (int) whichEdge
              CircleResult : (fittedCircle&)circle
                  EdgeInfo : (edgeInfo&)edgeResultInfo;

- (void)drawCircleIn : (Mat) drawingImage Cx : (int)cx Cy : (int)cy radius : (int) radius colour: (char) color;


@end
