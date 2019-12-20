//
//  RectangleFinder.h
//
//
//  Created by Charlie on 31/7/15.
//
//

#import <Foundation/Foundation.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>
#import <math.h>
#import <vector>
#import "EdgeFinder.h"

using namespace std;
using namespace cv;


@interface RectangleFinder : NSObject{
    
}

struct fittedRectangle{
    CvPoint A;
    CvPoint B;
    CvPoint C;
    CvPoint D;
    CvPoint Center;
};


/* Finding rectangle by using below parameters
 ------- 0 ------|       A-------------B
 |               |       |             |
 |               |       |             |
 3               1       |             |
 |               |       |             |
 |               |       |             |
 ------- 2 -------       C-------------D
 
 (i)  use "BestFitLine" method to find out line 0, 1, 2, 3
 (ii) find out intersection of each line to obtain point A, B, C & D
 (iii)obtain the center point of rectangle by finding intersection of line AD and CB
 */

- (edgeError) FindRectangleIn : (Mat) inputImage        // source image
                  ResultImage : (Mat) drawingImage
                      CenterX : (int) cx
                      CenterY : (int) cy
               OuterRectWidth : (int) outerRectWidth
              OuterRectHeight : (int) outerRectHeight
               InnerRectWidth : (int) innerRectWidth
              InnerRectHeight : (int) innerRectHeight
                 LineInterval : (int) lineInterval
                   KernelType : (int) kernelType
                  kernelWidth : (int) kernelWidth
           SearchingDirection : (int) direction
                EdgeThreshold : (double) edgeThreshold
                     EdgeType : (int) edgeType
                    WhichEdge : (int) whichEdge
              RectangleResult : (fittedRectangle&)rect
                     EdgeInfo : (edgeInfo&) edgeResultInfo;

- (edgeError) OLD_FindRectangleIn : (Mat) inputImage
                      ResultImage : (Mat) drawingImage
                          CenterX : (int) cx
                          CenterY : (int) cy
                   OuterRectWidth : (int) outerRectWidth
                  OuterRectHeight : (int) outerRectHeight
                   InnerRectWidth : (int) innerRectWidth
                  InnerRectHeight : (int) innerRectHeight
                     LineInterval : (int) lineInterval
                       WithKernel : (int) kernelWidth
               SearchingDirection : (int) direction
                    EdgeThreshold : (double) edgeThreshold
                         EdgeType : (int) edgeType
                        WhichEdge : (int) whichEdge
                  RectangleResult : (fittedRectangle&)rect;


// Draw out the rectangle obtain in "FitRectangleByEdgePoints" method
- (edgeError) DrawRectangleIn : (Mat) drawingImage                            // result image
                  Rectangle : (fittedRectangle) rectangle                   // rectangle fitted in "FitRectangleByEdgePoints" method
                  WithColor : (char) color;                                 // colour of rectangle


// Draw out the inner rectangle and outer rectanlge obtain in "DefineInnerOuterRectangleIn" method
- (edgeError) DrawInnerOuterRectangleIn : (Mat) drawingImage                  // result image
                              CenterX : (int) cx                            // center x of inner and outer rectanger
                              CenterY : (int) cy                            // center y of inner and outer rectanger
                       OuterRectWidth : (int) outerRectWidth                // width of outer rectangle
                      OuterRectHeight : (int) outerRectHeight               // height of outer rectangle
                       InnerRectWidth : (int) innerRectWidth                // width of inner rectangle
                      InnerRectHeight : (int) innerRectHeight               // height of inner rectangle
                                Color : (char) color;                       // color of inner rectangle and outer rectangle

@end

