//
//  EdgeFinder.h
//  circle_finder_v2
//
//  Created by Charlie on 9/12/15.
//  Copyright © 2015 智偉 余. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>
#import <math.h>
#import <vector>

using namespace std;
//using namespace cv;

@interface EdgeFinder : NSObject{
    
}
//all points on 1 line
struct roiLine {
    vector<CvPoint> allPoints;
    string lineName;            //line name can be : AB, BC, CD, DA
};



struct pointV {
    int x;
    int y;
    double value;
};

struct edgePoint{
    CvPoint point;
    double strength;
    string lineName;
};

struct edgeInfo {
    double edgeMean;
    double edgeMeanSD;
    double edgeAbsMean;
    double edgeAbsMeanSD;
    double darkPrecentage;
    double brightPrecentage;
    double SNR_Avg;
    double SNR_Min;
    vector<edgePoint> rawEdgePts;
    vector<edgePoint> ransacValidEdgePts;
};

typedef enum
{
    noError = 1,
    edgePtNotEnough = 2,
    centerPointOutOfROI = 3,
    ROI_OutOfImage = 4,
    ROI_DefineError = 5,
    edgePointsNotValid = 6,
}edgeError ;

typedef enum {
    // para for find edge function
    in2Out = 0,
    out2In = 1,
    bidirectional = 2,
    bright2Dark = 3,
    dark2Bright = 4,
    bestEdge = 5,
    firstEdge = 6,
    bothEdge = 7,
} edgePara ;

typedef enum{
    // para for find edge kernel
    originalKernel = 0,
    reversedKernel = 1,
    gaussianKernel = 2,
}kernelType;

// Find edge point of each line
+ (edgeError) FindEdgePointInImage : (cv::Mat) internalImage                      // source image
                        KernelSize : (int) kernelWidth                        // the size of kernel for convolution
                        KernelType : (int) kernelType                         // which kernel to be used : Original : [-2 -1 0 1 2]; Reveresed : [-1 -2 0 2 1]
                SearchingDirection : (int) direction                          // edge searching direction : in2out, out2in, bidirectional
                     EdgeThreshold : (double) edgeThreshold                   // strength threshold of edge, value large than this para will become valid edge point
                          EdgeType : (int) edgeType                           // define what type of edge : bright2dark, dark2bright
                         WhichEdge : (int) whichEdge                          // define what kind of edge : fist edge, best edge
                          AllLines : (vector<roiLine>) allLines               // result of lines obtained from "DefineInnerOuterRectangleIn" method
                  EdgePointsResult : (vector<edgePoint>&) allEdgePoints
                            allSNR : (vector<double>&) allSNR;      // result of edge points of each line

+ (void) drawAllLinesIn : (cv::Mat)drawingImage lines: (vector<roiLine>) lines colour: (char) color;

+ (void) drawEdgePointsIn : (cv::Mat)drawingImage allEdgePoints : (vector<edgePoint>)allEdgePts colour: (char) color;

+ (void) calcInfo : (vector<edgePoint>) allEdgePoints allSNR : (vector<double>)SNR edgeInfo : (edgeInfo&)edgeResultInfo;

@end
