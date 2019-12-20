//
//  RectangleFinder.m
//  circle_finder_v2
//
//  Created by Charlie on 31/7/15.
//  Copyright (c) 2015 智偉 余. All rights reserved.
//

#import "RectangleFinder.h"

@implementation RectangleFinder


- (edgeError) FindRectangleIn : (Mat) inputImage
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
                     EdgeInfo : (edgeInfo&) edgeResultInfo;{
    // This mm file ignore 6 times "err = edgePointsNotValid" case, need to be un-comment them after finish Yinan test
    
    vector<roiLine> allLines;
    vector<edgePoint> allEdgePoints;
    edgeError err = noError;
    vector<double> allSNR;
    
    if (cx < 0 || cx > inputImage.cols || cy < 0 || cy > inputImage.rows) {
        return ROI_OutOfImage;
    }
    
    if (outerRectHeight <= innerRectHeight || outerRectWidth <= innerRectWidth) {
        return ROI_DefineError;
    }

    // define inner and outer rectangle
    err = [self DefineInnerOuterRectangleIn : inputImage
                                    CenterX : cx
                                    CenterY : cy
                             OuterRectWidth : outerRectWidth
                            OuterRectHeight : outerRectHeight
                             InnerRectWidth : innerRectWidth
                            InnerRectHeight : innerRectHeight
                               LineInterval : lineInterval
                                LinesResult : allLines];
    
    if (err != noError) {
        return err;
    }
    
    // draw inner and outer rectangle
    err = [self DrawInnerOuterRectangleIn : drawingImage
                                  CenterX : cx
                                  CenterY : cy
                           OuterRectWidth : outerRectWidth
                          OuterRectHeight : outerRectHeight
                           InnerRectWidth : innerRectWidth
                          InnerRectHeight : innerRectHeight
                                    Color : 'r'];
    if (err != noError) {
        return err;
    }
    
    // draw lines between inner and outer rectangle
    [EdgeFinder drawAllLinesIn:drawingImage lines:allLines colour:'b'];
    
    
    // find edge points by EdgeFinder class
    err = [EdgeFinder FindEdgePointInImage : inputImage
                                KernelSize : kernelWidth
                                KernelType : kernelType
                        SearchingDirection : direction
                             EdgeThreshold : edgeThreshold
                                  EdgeType : edgeType
                                 WhichEdge : whichEdge
                                  AllLines : allLines
                          EdgePointsResult : allEdgePoints
                                    allSNR : allSNR];
    
    //cal info for Yinan
    [EdgeFinder calcInfo:allEdgePoints allSNR:allSNR edgeInfo:edgeResultInfo] ;
    
    if (err != noError) {
        return err;
    }
    
    // fit rectangle
    err = [self FitRectangleByRansacFilterWithTolerance:3 Rectangle:rect AllEdgePoints:allEdgePoints];
    //err = [self FitRectangleByEdgePoints:allEdgePoints RectangleResult:rect];
    
    if (err != noError) {
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return err;
    }
    
    // check rectangle is inside inner rect and outer rect or not
    int rectWidth = rect.B.x - rect.A.x;
    int rectHeight = rect.C.y - rect.B.y;
    if (outerRectWidth <= rectWidth || outerRectHeight <= rectHeight || innerRectWidth >= rectWidth || innerRectHeight >= rectHeight) {
        // draw edge points
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePointsNotValid;// (need to be un-comment it)
    }
    
    // check rectangle center is inside outer rect or not
    if (rect.Center.x > (cx + outerRectWidth/2) || rect.Center.x < (cx - outerRectWidth/2) || rect.Center.y > (cy + outerRectHeight/2) || rect.Center.x < (cy - outerRectHeight/2)) {
        // draw edge points
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePointsNotValid;// (need to be un-comment it)
    }
    
    // draw fitted rectangle
    [self DrawRectangleIn : drawingImage Rectangle:rect WithColor:'g'];
    
    // draw edge points
    [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
    
    
    // Write edge info on result image
    NSString *edgeMeanString = [NSString stringWithFormat:@"Edge Mean = %.2f", edgeResultInfo.edgeMean];
    NSString *edgemeanSdString = [NSString stringWithFormat:@"Edge mean Sd = %.2f", edgeResultInfo.edgeMeanSD];
    
    NSString *edgeMedianString = [NSString stringWithFormat:@"Edge Abs Mean = %.2f", edgeResultInfo.edgeAbsMean];
    NSString *edgeMedianSDString = [NSString stringWithFormat:@"Edge Abs Mean SD = %.2f", edgeResultInfo.edgeAbsMeanSD];
    
    NSString *edgeDark2BrightString = [NSString stringWithFormat:@"Dark to Bright = %.2f%%", edgeResultInfo.brightPrecentage];
    NSString *edgeBright2DarkString = [NSString stringWithFormat:@"Bright to Dark = %.2f%%", edgeResultInfo.darkPrecentage];
    
    NSString *snrAvgString = [NSString stringWithFormat:@"SNR avg = %.2f", edgeResultInfo.SNR_Avg];
    NSString *snrMinString = [NSString stringWithFormat:@"SNR min = %.2f", edgeResultInfo.SNR_Min];
    
//    putText(drawingImage, [edgeMeanString UTF8String],          CvPoint{100,100}, 1, 2, *new Scalar(128,225,0), 2);
//    putText(drawingImage, [edgemeanSdString UTF8String],        CvPoint{100,130}, 1, 2, *new Scalar(128,225,0), 2);
//    
//    putText(drawingImage, [edgeMedianString UTF8String],        CvPoint{100,160}, 1, 2, *new Scalar(128,225,0), 2);
//    putText(drawingImage, [edgeMedianSDString UTF8String],      CvPoint{100,190}, 1, 2, *new Scalar(128,225,0), 2);
//    
//    putText(drawingImage, [edgeDark2BrightString UTF8String],   CvPoint{100,220}, 1, 2, *new Scalar(128,225,0), 2);
//    putText(drawingImage, [edgeBright2DarkString UTF8String],   CvPoint{100,250}, 1, 2, *new Scalar(128,225,0), 2);
//    
//    putText(drawingImage, [snrAvgString UTF8String],            CvPoint{100,280}, 1, 2, *new Scalar(128,225,0), 2);
//    putText(drawingImage, [snrMinString UTF8String],            CvPoint{100,310}, 1, 2, *new Scalar(128,225,0), 2);
    
    putText(drawingImage, [edgeMeanString UTF8String],          CvPoint{620,300}, 1, 1.5, *new Scalar(255,225,0), 1);
    putText(drawingImage, [edgemeanSdString UTF8String],        CvPoint{620,330}, 1, 1.5, *new Scalar(255,225,0), 1);

    putText(drawingImage, [edgeMedianString UTF8String],        CvPoint{960,300}, 1, 1.5, *new Scalar(255,225,0), 1);
    putText(drawingImage, [edgeMedianSDString UTF8String],      CvPoint{960,330}, 1, 1.5, *new Scalar(255,225,0), 1);
    
    putText(drawingImage, [edgeDark2BrightString UTF8String],   CvPoint{1320,300}, 1, 1.5, *new Scalar(255,225,0), 1);
    putText(drawingImage, [edgeBright2DarkString UTF8String],   CvPoint{1320,330}, 1, 1.5, *new Scalar(255,225,0), 1);
    
    putText(drawingImage, [snrAvgString UTF8String],            CvPoint{1680,300}, 1, 1.5, *new Scalar(255,225,0), 1);
    putText(drawingImage, [snrMinString UTF8String],            CvPoint{1680,330}, 1, 1.5, *new Scalar(255,225,0), 1);
    
    bool upDownFlag = true;
    for(int i = 0; i < edgeResultInfo.rawEdgePts.size(); i++){
        //NSString *edgeStrengthString = [NSString stringWithFormat:@"%d = %f", i, edgeResultInfo.edgeStrengths[i]];
        //putText(drawingImage, [edgeStrengthString UTF8String],   CvPoint{2100,i*30 + 100}, 1, 2, *new Scalar(128,225,0), 2);
        
        NSString *edgeStrengthString = [NSString stringWithFormat:@"%.1f", edgeResultInfo.rawEdgePts[i].strength];
        
        if (edgeResultInfo.rawEdgePts[i].lineName == "AB" || edgeResultInfo.rawEdgePts[i].lineName == "CD") {
            // print edgeStrength in "y-5 y+20 y-5 y+20" pattern when horiziontal line
            if (upDownFlag) {
                putText(drawingImage, [edgeStrengthString UTF8String], {edgeResultInfo.rawEdgePts[i].point.x, edgeResultInfo.rawEdgePts[i].point.y - 5}, 1, 1, *new Scalar(255,255,100), 1);
            }
            else{
                putText(drawingImage, [edgeStrengthString UTF8String], {edgeResultInfo.rawEdgePts[i].point.x, edgeResultInfo.rawEdgePts[i].point.y + 20}, 1, 1, *new Scalar(255,255,100), 1);
            }
            upDownFlag = !upDownFlag;
        }
        else{
            // print edgeStrength near edge point
            putText(drawingImage, [edgeStrengthString UTF8String], edgeResultInfo.rawEdgePts[i].point, 1, 1, *new Scalar(255,255,100), 1);
        }
    }
    
    return noError;
}

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
                  RectangleResult : (fittedRectangle&)rect{
    
    vector<roiLine> allLines;
    vector<edgePoint> allEdgePoints;
    edgeError err = noError;
    vector<double> allSNR;
    
    
    if (cx < 0 || cx > inputImage.cols || cy < 0 || cy > inputImage.rows) {
        return ROI_OutOfImage;
    }
    
    if (outerRectHeight <= innerRectHeight || outerRectWidth <= innerRectWidth) {
        return ROI_DefineError;
    }
    
    // define inner and outer rectangle
    err = [self DefineInnerOuterRectangleIn : inputImage
                                    CenterX : cx
                                    CenterY : cy
                             OuterRectWidth : outerRectWidth
                            OuterRectHeight : outerRectHeight
                             InnerRectWidth : innerRectWidth
                            InnerRectHeight : innerRectHeight
                               LineInterval : lineInterval
                                LinesResult : allLines];
    
    if (err != noError) {
        return err;
    }
    
    // draw inner and outer rectangle
    err = [self DrawInnerOuterRectangleIn : drawingImage
                                  CenterX : cx
                                  CenterY : cy
                           OuterRectWidth : outerRectWidth
                          OuterRectHeight : outerRectHeight
                           InnerRectWidth : innerRectWidth
                          InnerRectHeight : innerRectHeight
                                    Color : 'r'];
    if (err != noError) {
        return err;
    }
    
    // draw lines between inner and outer rectangle
    [EdgeFinder drawAllLinesIn:drawingImage lines:allLines colour:'b'];
    
    
    // find edge points by EdgeFinder class
    err = [EdgeFinder FindEdgePointInImage : inputImage
                                KernelSize : kernelWidth
                                KernelType : originalKernel
                        SearchingDirection : direction
                             EdgeThreshold : edgeThreshold
                                  EdgeType : edgeType
                                 WhichEdge : whichEdge
                                  AllLines : allLines
                          EdgePointsResult : allEdgePoints
                                    allSNR : allSNR];
    
    if (err != noError) {
        return err;
    }
    
    // fit rectangle
    
    err = [self FitRectangleByEdgePoints:allEdgePoints RectangleResult:rect];
    
    if (err != noError) {
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return err;
    }
    
    // check rectangle is inside inner rect and outer rect or not
    int rectWidth = rect.B.x - rect.A.x;
    int rectHeight = rect.C.y - rect.B.y;
    if (outerRectWidth <= rectWidth || outerRectHeight <= rectHeight || innerRectWidth >= rectWidth || innerRectHeight >= rectHeight) {
        // draw edge points
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePointsNotValid; //(need to be un-comment it)
    }
    
    // check rectangle center is inside outer rect or not
    if (rect.Center.x > (cx + outerRectWidth/2) || rect.Center.x < (cx - outerRectWidth/2) || rect.Center.y > (cy + outerRectHeight/2) || rect.Center.x < (cy - outerRectHeight/2)) {
        // draw edge points
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePointsNotValid;// (need to be un-comment it)
    }
    
    // draw fitted rectangle
    [self DrawRectangleIn : drawingImage Rectangle:rect WithColor:'g'];
    
    // draw edge points
    [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
    
    return noError;
}


// Define inner rectange and outer rectanlge as ROI and then save the lines between these 2 rectangles
- (edgeError) DefineInnerOuterRectangleIn : (Mat) inputImage                  // source image
                                  CenterX : (int) cx                          // center x of inner and outer rectanger
                                  CenterY : (int) cy                          // center y of inner and outer rectanger
                           OuterRectWidth : (int) outerRectWidth              // width of outer rectangle
                          OuterRectHeight : (int) outerRectHeight             // height of outer rectangle
                           InnerRectWidth : (int) innerRectWidth              // width of inner rectangle
                          InnerRectHeight : (int) innerRectHeight             // height of inner rectangle
                             LineInterval : (int) lineInterval                // interval of lines between inner rectangle and outer rectangle (unit pixel)
                              LinesResult : (vector<roiLine>&) allLines      // result of lines
{
    
    
    /*
     ------- 0 ------|       A-------------B
     |               |       |             |
     |               |       |             |
     3               1       |             |
     |               |       |             |
     |               |       |             |
     ------- 2 -------       C-------------D
     */
    
    vector<CvPoint> allPointsOn1Line;
    roiLine currentLine;
    
    bool isHorizontal = false;
    int startLine = 0;
    int targetLline = 0;
    int startPoint = 0;
    int targetPoint = 0;
    int direction = 0;
    CvPoint currentPoint;
    string lineName;
    
    for (int d = 0; d < 4; d++){
        
        switch (d) {
            case 0:
                isHorizontal =  false;
                startLine    =  cx - (innerRectWidth / 2);
                targetLline  =  cx + (innerRectWidth / 2);
                startPoint   =  cy - (innerRectHeight / 2);
                targetPoint  =  cy - (outerRectHeight / 2);
                direction    =  -1;
                lineName     =  "AB";
                break;
                
            case 1:
                isHorizontal =  true;
                startLine    =  cy - (innerRectHeight / 2);
                targetLline  =  cy + (innerRectHeight / 2);
                startPoint   =  cx + (innerRectWidth / 2);
                targetPoint  =  cx + (outerRectWidth / 2);
                direction    =  1;
                lineName     =  "BC";
                break;
                
            case 2:
                isHorizontal =  false;
                startLine    =  cx - (innerRectWidth / 2);
                targetLline  =  cx + (innerRectWidth / 2);
                startPoint   =  cy + (innerRectHeight / 2);
                targetPoint  =  cy + (outerRectHeight / 2);
                direction    =  1;
                lineName     =  "CD";
                break;
                
            case 3:
                isHorizontal =  true;
                startLine    =  cy - (innerRectHeight / 2);
                targetLline  =  cy + (innerRectHeight / 2);
                startPoint   =  cx - (innerRectWidth / 2);
                targetPoint  =  cx - (outerRectWidth / 2);
                direction    =  -1;
                lineName     =  "DA";
                break;
        }
        
        for (int i = startLine; i < targetLline; i += lineInterval) {
            for (int j = startPoint; j != targetPoint; j = j + direction){
                if (isHorizontal) {
                    currentPoint.x = j;
                    currentPoint.y = i;
                }
                else{
                    currentPoint.x = i;
                    currentPoint.y = j;
                }
                
                allPointsOn1Line.push_back(currentPoint);
            }
            
            currentLine.allPoints = allPointsOn1Line;
            currentLine.lineName  = lineName;
            allLines.push_back(currentLine);
            allPointsOn1Line.clear();
        }
    }
    
    return noError;
}

// Using the edge points to fit the line of rectangle
- (edgeError) BestFitLineWithEdgePoints : (vector<edgePoint>) oneLineOfRect                   // all edge point of one slide of rectangle
                               SlopeOut : (double&) slope                                   // slope of fitted line
                         Y_InterceptOut : (double&) yIntercept                                    // y intercept of fitted line
                              LineIndex : (int)lineIndex
{
    
    bool enableFilter = lineIndex >= 0 ? true : false;
    enableFilter = false;
    if (enableFilter) {
        /*best fit line with filtering*/
        double mean = 0.0;
        for (int i = 0; i < oneLineOfRect.size(); i++){
            if (lineIndex == 1 || lineIndex == 3) {
                mean += (double)oneLineOfRect[i].point.x;
            }
            else{
                mean += (double)oneLineOfRect[i].point.y;
            }
        }
        mean = mean / oneLineOfRect.size();
        
        //NSLog(@"line index = %d mean x = %f",lineIndex, mean);
        
        Vector<edgePoint> filteredEdgePoints;
        double error = 0.0;
        const int factor = 10;
        
        for (int i = 0; i < oneLineOfRect.size(); i++){
            if (lineIndex == 1 || lineIndex == 3) { //Line BC, DA
                error = abs(oneLineOfRect[i].point.x - mean);
            }
            else{                                   //Line AB, CD
                error = abs(oneLineOfRect[i].point.y - mean);
            }
            
            if ( error <= factor ) {
                filteredEdgePoints.push_back(oneLineOfRect[i]);
            }
        }
        
        int count = (int)filteredEdgePoints.size();
        
        double sumX = 0.0, sumY = 0;
        double sumX2 = 0.0, sumXY = 0, xMean = 0, yMean = 0;
        
        for (int i = 0; i < count; i++){
            sumX += filteredEdgePoints[i].point.x;
            sumY += filteredEdgePoints[i].point.y;
            sumX2 += (filteredEdgePoints[i].point.x * filteredEdgePoints[i].point.x);
            sumXY += (filteredEdgePoints[i].point.x * filteredEdgePoints[i].point.y);
        }
        
        xMean = sumX / count;
        yMean = sumY / count;
        slope = (sumXY - sumX * yMean) / (sumX2 - sumX * xMean);
        yIntercept = yMean - slope * xMean;
        
        return noError;
        
    }
    else{
        
        //best fit line without filtering
        if (oneLineOfRect.size() < 2) {
            return edgePtNotEnough;
        }
        
        // swap x and y before fit line AB & line CD
        if (lineIndex == 1 || lineIndex == 3) { // vertical line case
            int tempX = 0;
            int tempY = 0;
            for (int i = 0; i < oneLineOfRect.size(); i++) {
                // swap x and y and the fit line one by one
                tempX = oneLineOfRect[i].point.y;
                tempY = oneLineOfRect[i].point.x;
                oneLineOfRect[i].point.x = tempX;
                oneLineOfRect[i].point.y = tempY;
            }
        }
        
        int count = (int)oneLineOfRect.size();
        
        double sumX = 0.0, sumY = 0;
        double sumX2 = 0.0, sumXY = 0, xMean = 0, yMean = 0;
        
        for (int i = 0; i < count; i++){
            sumX += oneLineOfRect[i].point.x;
            sumY += oneLineOfRect[i].point.y;
            sumX2 += (oneLineOfRect[i].point.x * oneLineOfRect[i].point.x);
            sumXY += (oneLineOfRect[i].point.x * oneLineOfRect[i].point.y);
        }
        
        xMean = sumX / count;
        yMean = sumY / count;
        slope = (sumXY - sumX * yMean) / (sumX2 - sumX * xMean);
        yIntercept = yMean - slope * xMean;
        
        return noError;
        
    }
}

// Find the intesection of two fitted lines
- (edgeError) FindIntersectionByHorizontalLineSlope : (double) HorSlope                      // slope of fitted horizontal line       (Line 0 and 2 only)
                                  VerticalLineSlope : (double) VerSlope                      // slope of fitter vertical line         (Line 1 and 3 only)
                            HorizontalLineIntercept : (double) yIntercept                    // y intercept of fitted line            (Line 0 and 2 only)
                              VerticalLineIntercept : (double) xIntercept                    // x intercept of fitted line            (Line 1 and 3 only)
                                 IntersectionResult : (CvPoint&) intersection                // intersection of line 1 and line 2
{
    
    /*
     get intersection x and y by sloving below 2 equations
     
     y = m1x + c1 ----(1)      // equation of line 0 or line 2
     x = m2y + c2 ----(2)      // equation of line 1 or line 3
     
     sub (2) into (1) :
     then y = (m1c2 + c1) / (1 - m1m2)
     
     sub y into (1) to obtain x:
     then x = m2y + c2
     
     */
    
    double m1 = HorSlope;
    double m2 = VerSlope;
    double c1 = yIntercept;
    double c2 = xIntercept;
    
    //orinigal method for finding intercept
    //intersection.x = (c2 - c1) / (m1 - m2);
    //intersection.y = ((m1 * c2) - (m2 * c1)) / (m1 - m2);
    
    // new method for finding intercept to solve vertical line has no slope problem
    intersection.y = (m1 * c2 + c1) / (1 - (m1 * m2));
    intersection.x = m2 * intersection.y + c2;
    
    return noError;
    
}

- (edgeError) FindRectangleCenterBySlope1 : (double) slope1
                                   Slope2 : (double) slope2
                             Y_Intercept1 : (double) yIntercept1
                             Y_Intercept2 : (double) yIntercept2
                             CenterResult : (CvPoint&) center{
    
    double m1 = slope1;
    double m2 = slope2;
    double c1 = yIntercept1;
    double c2 = yIntercept2;
    
    center.x = (c2 - c1) / (m1 - m2);
    center.y = ((m1 * c2) - (m2 * c1)) / (m1 - m2);
    
    return noError;
    
}


- (edgeError) FitRectangleByEdgePoints : (vector<edgePoint>) allEdgePoints
                       RectangleResult : (fittedRectangle&) rectangle{
    
    vector<edgePoint> allPtsOnOneSide[4];
    double slope[4];
    double yIntercept[4];
    
    
    // take AB, BC, CD, DA edge point from allEdgePoints vector
    for (int l = 0; l < allEdgePoints.size(); l++){
        if (allEdgePoints[l].lineName == "AB") {
            allPtsOnOneSide[0].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "BC") {
            allPtsOnOneSide[1].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "CD") {
            allPtsOnOneSide[2].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "DA") {
            allPtsOnOneSide[3].push_back(allEdgePoints[l]);
        }
    }
    
    edgeError err = noError;
    
    // best fit each line to get slope and yint
    for (int i = 0; i < 4; i++){
        err = [self BestFitLineWithEdgePoints:allPtsOnOneSide[i] SlopeOut:slope[i] Y_InterceptOut:yIntercept[i] LineIndex:i];
        //NSLog(@"slope = %f, yInt = %f", slope[i], yIntercept[i]);
        if (err != noError)
            return err;
    }
    
    // find intersection to obtain Point A, B, C and D of Rectangle
    [self FindIntersectionByHorizontalLineSlope:slope[0] VerticalLineSlope:slope[3] HorizontalLineIntercept:yIntercept[0] VerticalLineIntercept:yIntercept[3] IntersectionResult:rectangle.A];
    [self FindIntersectionByHorizontalLineSlope:slope[0] VerticalLineSlope:slope[1] HorizontalLineIntercept:yIntercept[0] VerticalLineIntercept:yIntercept[1] IntersectionResult:rectangle.B];
    [self FindIntersectionByHorizontalLineSlope:slope[2] VerticalLineSlope:slope[1] HorizontalLineIntercept:yIntercept[2] VerticalLineIntercept:yIntercept[1] IntersectionResult:rectangle.C];
    [self FindIntersectionByHorizontalLineSlope:slope[2] VerticalLineSlope:slope[3] HorizontalLineIntercept:yIntercept[2] VerticalLineIntercept:yIntercept[3] IntersectionResult:rectangle.D];
    
    double slopeAC = (double)(rectangle.A.y - rectangle.C.y) / (double)(rectangle.A.x - rectangle.C.x);     // m = (y2 - y2) / (x2 - x1)
    double slopeBD = (double)(rectangle.B.y - rectangle.D.y) / (double)(rectangle.B.x - rectangle.D.x);     // m = (y2 - y2) / (x2 - x1)
    double yInterceptAC = rectangle.C.y - (slopeAC * rectangle.C.x);                                        // c = y - mx
    double yInterceptBD = rectangle.D.y - (slopeBD * rectangle.D.x);                                        // c = y - mx
    
    [self FindRectangleCenterBySlope1:slopeBD Slope2:slopeAC Y_Intercept1:yInterceptBD Y_Intercept2:yInterceptAC CenterResult:rectangle.Center];
    
    
    return noError;
}

- (edgeError) FitRectangleByRansacFilterWithTolerance : (double)tolerance
                                            Rectangle : (fittedRectangle&) rectangle
                                        AllEdgePoints : (vector<edgePoint>) allEdgePoints{
    
    bool isFitAgain = true;
    
    vector<edgePoint> allPtsOnOneSide[4];
    double slope[4];
    double yIntercept[4];
    
    
    // take AB, BC, CD, DA edge point from allEdgePoints vector
    for (int l = 0; l < allEdgePoints.size(); l++){
        if (allEdgePoints[l].lineName == "AB") {
            allPtsOnOneSide[0].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "BC") {
            allPtsOnOneSide[1].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "CD") {
            allPtsOnOneSide[2].push_back(allEdgePoints[l]);
        }
        else  if (allEdgePoints[l].lineName == "DA") {
            allPtsOnOneSide[3].push_back(allEdgePoints[l]);
        }
    }
    
    edgeError err = noError;
    
    // best fit each line to get slope and yint
    for (int i = 0; i < 4; i++){
        
        ///////////ransc start---------------------------------------------------------------
        struct RANSAC {
            int rand1;
            int rand2;
            int rand3;
            int RANSAC_validCount;
            double m;
            double c;
            vector<edgePoint> validEdgePts;
        };
        
        Vector<RANSAC> ransacPara;
        
        if (allPtsOnOneSide[i].size() < 3){
            return edgePtNotEnough;
        }
        for (int c = 0; c < 100; c++) {
            
            int rand1 = 0;
            int rand2 = 0;
            int rand3 = 0;
            
            // pick up 3 random edge points
            do{
                rand1 = arc4random() % allPtsOnOneSide[i].size();
                rand2 = arc4random() % allPtsOnOneSide[i].size();
                rand3 = arc4random() % allPtsOnOneSide[i].size();
            }
            while (rand1 == rand2 || rand1 == rand3 || rand2 == rand3);
            //NSLog(@"loop = %d, rand 1 = %d, rand 2 = %d, rand 3 = %d", c, rand1, rand2, rand3);
            
            // use these 3 random edge points for best fit line
            vector<edgePoint> randomEdgePts;
            double slopeRAN;
            double yInterceptRAN;
            
            randomEdgePts.push_back(allPtsOnOneSide[i][rand1]);
            randomEdgePts.push_back(allPtsOnOneSide[i][rand2]);
            randomEdgePts.push_back(allPtsOnOneSide[i][rand3]);
            err = [self BestFitLineWithEdgePoints:randomEdgePts
                                         SlopeOut:slopeRAN
                                   Y_InterceptOut:yInterceptRAN
                                        LineIndex:i];
            
            if (err != noError){
                return err;
            }
            
            //NSLog(@"ran slope = %f, Y inte = %f", slopeRAN, yInterceptRAN);
            
            RANSAC currentRANSAC;
            currentRANSAC.rand1 = rand1;
            currentRANSAC.rand2 = rand2;
            currentRANSAC.rand3 = rand3;
            currentRANSAC.m = slopeRAN;
            currentRANSAC.c = yInterceptRAN;
            currentRANSAC.RANSAC_validCount = 0;
            
            for (int ie = 0; ie < allPtsOnOneSide[i].size(); ie++){
                if (ie == rand1 || ie == rand2 || ie == rand3) {
                    continue;
                }
                else{
                    double A = (currentRANSAC.m * 1);
                    double B = -1;
                    double C = (currentRANSAC.c * 1);
                    double dist = 999;
                    
                    if(i == 0 || i == 2){
                        // horizional line case
                        dist = abs((A * allPtsOnOneSide[i][ie].point.x) + (B * allPtsOnOneSide[i][ie].point.y) + C) / sqrt((A * A) + (B * B));
                    }
                    else if (i == 1 || i == 3){
                        // vertical line case
                        dist = abs((A * allPtsOnOneSide[i][ie].point.y) + (B * allPtsOnOneSide[i][ie].point.x) + C) / sqrt((A * A) + (B * B));
                    }
                    
                    //NSLog(@"dist = %f", dist);
                    if (dist <= tolerance) {
                        if (isFitAgain) {
                            currentRANSAC.validEdgePts.push_back(allPtsOnOneSide[i][ie]);
                        }
                        currentRANSAC.RANSAC_validCount++;
                    }
                }
            }
            ransacPara.push_back(currentRANSAC);
        }
        
        int finalRansacIndex = -1;
        int tempValidCount = 0;
        
        for (int f = 0; f < ransacPara.size(); f++) {
            //NSLog(@"ransacPara index = %d, RANSAC_validCount = %d, lines count =%zu", f, ransacPara[f].RANSAC_validCount,allPtsOnOneSide[i].size());
            if (ransacPara[f].RANSAC_validCount > tempValidCount){// && ransacPara[f].RANSAC_validCount >= allPtsOnOneSide[i].size() * 0.6) {
                tempValidCount = ransacPara[f].RANSAC_validCount;
                finalRansacIndex = f;
            }
        }
        
        if (finalRansacIndex == -1) {
            return edgePointsNotValid; //(need to be un-comment it)
        }
        
        
        
        
        if (isFitAgain) {
            [self BestFitLineWithEdgePoints:ransacPara[finalRansacIndex].validEdgePts
                                   SlopeOut:slope[i]
                             Y_InterceptOut:yIntercept[i]
                                  LineIndex:i];
        }
        else{
            slope[i] = ransacPara[finalRansacIndex].m;
            yIntercept[i] = ransacPara[finalRansacIndex].c;
        }
        
        //NSLog(@"slope = %f, yInt = %f", slope[i], yIntercept[i]);
        
        
        ///////////ransc END-------------------------------------------------------------------------------
        if (err != noError)
            return err;
    }
    
    
    
    // find intersection to obtain Point A, B, C and D of Rectangle
    [self FindIntersectionByHorizontalLineSlope:slope[0] VerticalLineSlope:slope[3] HorizontalLineIntercept:yIntercept[0] VerticalLineIntercept:yIntercept[3] IntersectionResult:rectangle.A];
    [self FindIntersectionByHorizontalLineSlope:slope[0] VerticalLineSlope:slope[1] HorizontalLineIntercept:yIntercept[0] VerticalLineIntercept:yIntercept[1] IntersectionResult:rectangle.B];
    [self FindIntersectionByHorizontalLineSlope:slope[2] VerticalLineSlope:slope[1] HorizontalLineIntercept:yIntercept[2] VerticalLineIntercept:yIntercept[1] IntersectionResult:rectangle.C];
    [self FindIntersectionByHorizontalLineSlope:slope[2] VerticalLineSlope:slope[3] HorizontalLineIntercept:yIntercept[2] VerticalLineIntercept:yIntercept[3] IntersectionResult:rectangle.D];
    
    //    NSLog(@"a = (%d, %d)", rectangle.A.x, rectangle.A.y);
    //    NSLog(@"b = (%d, %d)", rectangle.B.x, rectangle.B.y);
    //    NSLog(@"c = (%d, %d)", rectangle.C.x, rectangle.C.y);
    //    NSLog(@"d = (%d, %d)", rectangle.D.x, rectangle.D.y);
    
    // check the angle CAB and angle BDC is close to 90 degree or not
    double angleCAB = atan(abs((double)(slope[0] - slope[3]) / (1 + (slope[0] * slope[3])))) * 180 / 3.14;
    double angleBDC = atan(abs((double)(slope[1] - slope[2]) / (1 + (slope[1] * slope[2])))) * 180 / 3.14;
    if (angleCAB < 88.5 || angleCAB > 91.5 || angleBDC < 88.5 || angleBDC > 91.5) {
        //return edgePointsNotValid; //(need to be un-comment it)
    }
    
    // find slope AC, BD and Y intercept AC, BD for geting center of rectangle
    double slopeAC = (double)(rectangle.A.y - rectangle.C.y) / (double)(rectangle.A.x - rectangle.C.x);     // m = (y2 - y2) / (x2 - x1)
    double slopeBD = (double)(rectangle.B.y - rectangle.D.y) / (double)(rectangle.B.x - rectangle.D.x);     // m = (y2 - y2) / (x2 - x1)
    double yInterceptAC = rectangle.C.y - (slopeAC * rectangle.C.x);                                        // c = y - mx
    double yInterceptBD = rectangle.D.y - (slopeBD * rectangle.D.x);                                        // c = y - mx
    
    // find intesection of line AC and line BD. ie. center of fitted rectangle
    [self FindRectangleCenterBySlope1:slopeBD Slope2:slopeAC Y_Intercept1:yInterceptBD Y_Intercept2:yInterceptAC CenterResult:rectangle.Center];
    
    return noError;
}


- (edgeError) DrawEdgePointsIn : (Mat)drawingImage
                    EdgePoints : (vector<edgePoint>)edgePoints
                         Colour: (char) color{
    
    Vec3b v_edge_pts;
    
    switch (color) {
        case 'r' :
            v_edge_pts[0] = 0;          //blue
            v_edge_pts[1] = 0;          //green
            v_edge_pts[2] = 255;        //red
            break;
        case 'g' :
            v_edge_pts[0] = 0;
            v_edge_pts[1] = 255;
            v_edge_pts[2] = 0;
            break;
        case 'b' :
            v_edge_pts[0] = 255;
            v_edge_pts[1] = 0;
            v_edge_pts[2] = 0;
            break;
        case 'y' :
            v_edge_pts[0] = 0;
            v_edge_pts[1] = 255;
            v_edge_pts[2] = 255;
            break;
        case 'd' :
            v_edge_pts[0] = 0;
            v_edge_pts[1] = 0;
            v_edge_pts[2] = 0;
            break;
        default:
            v_edge_pts[0] = 0;
            v_edge_pts[1] = 0;
            v_edge_pts[2] = 255;
            break;
    }
    
    for (int i = 0; i < edgePoints.size(); i++){
        drawingImage.at<Vec3b>(edgePoints[i].point) = v_edge_pts;
    }
    
    return noError;
}

- (edgeError) DrawInnerOuterRectangleIn : (Mat) drawingImage
                                CenterX : (int) cx
                                CenterY : (int) cy
                         OuterRectWidth : (int) outerRectWidth
                        OuterRectHeight : (int) outerRectHeight
                         InnerRectWidth : (int) innerRectWidth
                        InnerRectHeight : (int) innerRectHeight
                                  Color : (char) color{
    
    Scalar lineColor;
    
    switch (color) {
        case 'r' :
            lineColor = Scalar(0,0,255);
            break;
        case 'g' :
            lineColor = Scalar(0,255,0);
            break;
        case 'b' :
            lineColor = Scalar(255,0,0);
            break;
        case 'y' :
            lineColor = Scalar(0,255,255);
            break;
        case 'd' :
            lineColor = Scalar(0,0,0);
            break;
        default:
            lineColor = Scalar(0,0,255);
            break;
    }
    
    
    CvPoint innerRectP1 = {cx - innerRectWidth / 2,  cy - innerRectHeight / 2};
    CvPoint innerRectP2 = {cx + innerRectWidth / 2,  cy + innerRectHeight / 2};
    CvPoint outerRectP1 = {cx - outerRectWidth / 2,  cy - outerRectHeight / 2};
    CvPoint outerRectP2 = {cx + outerRectWidth / 2,  cy + outerRectHeight / 2};
    
    rectangle(drawingImage, innerRectP1, innerRectP2, lineColor, 3);
    rectangle(drawingImage, outerRectP1, outerRectP2, lineColor, 3);
    
    
    return noError;
}

- (edgeError) DrawRectangleIn : (Mat) drawingImage
                    Rectangle : (fittedRectangle) rectangle
                    WithColor : (char) color{
    
    
    Scalar lineColor;
    
    switch (color) {
        case 'r' :
            lineColor = Scalar(0,0,255);
            break;
        case 'g' :
            lineColor = Scalar(0,255,0);
            break;
        case 'b' :
            lineColor = Scalar(255,0,0);
            break;
        case 'y' :
            lineColor = Scalar(0,255,255);
            break;
        case 'd' :
            lineColor = Scalar(0,0,0);
            break;
        default:
            lineColor = Scalar(0,0,255);
            break;
    }
    
    
    cv::line(drawingImage, rectangle.A, rectangle.B, lineColor, 1, 8, 0);
    cv::line(drawingImage, rectangle.B, rectangle.C, lineColor, 1, 8, 0);
    cv::line(drawingImage, rectangle.C, rectangle.D, lineColor, 1, 8, 0);
    cv::line(drawingImage, rectangle.D, rectangle.A, lineColor, 1, 8, 0);
    
    cv::line(drawingImage, rectangle.A, rectangle.C, lineColor, 4, 8, 0);
    cv::line(drawingImage, rectangle.B, rectangle.D, lineColor, 4, 8, 0);
    
    // draw center point
    if (rectangle.Center.x > drawingImage.cols || rectangle.Center.x < 0 || rectangle.Center.y > drawingImage.rows || rectangle.Center.y < 0) {
        return centerPointOutOfROI;
    }
    else{
        drawingImage.at<Vec3b>(rectangle.Center) = {255,0,255};
    }
    
    return noError;
}


@end
