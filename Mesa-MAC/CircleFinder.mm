//
//  circle_finder.m
//  MESA_V1_1
//
//  Created by Charlie on 24/9/14.
//  Copyright (c) 2014 智偉 余. All rights reserved.
//

#import "CircleFinder.h"

@implementation CircleFinder


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
                  EdgeInfo : (edgeInfo&)edgeResultInfo{
    

    vector<roiLine> allLines;
    vector<edgePoint> allEdgePoints;
    edgeError err = noError;
    vector<double> allSNR;
    
    if (cx < 0 || cx > inputImage.cols || cy < 0 || cy > inputImage.rows) {
        return ROI_OutOfImage;
    }
    
    if (innerRadius >= outerRadius) {
        return ROI_DefineError;
    }

    // define inner and outer circle as ROI
    err = [self DefineInnerOuterCircleIn:inputImage
                                 CenterX:cx
                                 CenterY:cy
                       InnerCircleRadius:innerRadius
                       OuterCircleRadius:outerRadius
                              DeltaAngle:deltaAngle
                             LinesResult:allLines];
    
    if (err != noError) {
        return err;
    }

    // draw inner and outer circle
    [self drawCircleIn:drawingImage Cx:cx Cy:cy radius:innerRadius colour:'r'];
    [self drawCircleIn:drawingImage Cx:cx Cy:cy radius:outerRadius colour:'r'];
    
    // draw lines between inner and outer circle
    [EdgeFinder drawAllLinesIn:drawingImage
                         lines:allLines
                        colour:'b'];
    
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
    [EdgeFinder calcInfo:allEdgePoints allSNR:allSNR edgeInfo:edgeResultInfo];

    if (err != noError) {
        return err;
    }
    
    // fit circle with RANSAC
    err = [self fitCircleByRansacFilterWithTolerance:3
                                              Circle:circle
                                       AllEdgePoints:allEdgePoints
                                     OutValidEdgePts:edgeResultInfo.ransacValidEdgePts];
    
    //err = [self fitCircleByRadiusFilterWithTolerance:10 Circle:circle EdgePointsIn:allEdgePoints];
    
    if (err != noError) {
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePtNotEnough;
    }
    
    // check circle is valid or not;
    if (circle.radius >= outerRadius || circle.radius <= innerRadius) {
        [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
        return edgePointsNotValid;
    }
    
    // draw fitted circle
    [self drawCircleIn:drawingImage Cx:circle.cx Cy:circle.cy radius:circle.radius colour:'g'];
    
    // draw fitted circle's center point with 'X'
    int xOffset = int(round(50 * sin(45)));
    int yOffset = int(round(50 * cos(45)));
    cv::line(drawingImage, cv::Point(circle.cx-xOffset, circle.cy+yOffset), cv::Point(circle.cx+xOffset, circle.cy-yOffset), Scalar(0,255,0),5);
    cv::line(drawingImage, cv::Point(circle.cx-xOffset, circle.cy-yOffset), cv::Point(circle.cx+xOffset, circle.cy+yOffset), Scalar(0,255,0),5);

    
    // draw edge point
    [EdgeFinder drawEdgePointsIn:drawingImage allEdgePoints:allEdgePoints colour:'y'];
    
    
    // Write edge info on result image
    NSString *edgeMeanString = [NSString stringWithFormat:@"Edge Mean = %f", edgeResultInfo.edgeMean];
    NSString *edgemeanSdString = [NSString stringWithFormat:@"Edge mean Sd = %f", edgeResultInfo.edgeMeanSD];
    
    NSString *edgeMedianString = [NSString stringWithFormat:@"Edge Abs Mean = %f", edgeResultInfo.edgeAbsMean];
    NSString *edgeMedianSDString = [NSString stringWithFormat:@"Edge Abs Mean SD = %f", edgeResultInfo.edgeAbsMeanSD];
    
    NSString *edgeDark2BrightString = [NSString stringWithFormat:@"Dark to Bright = %.2f%%", edgeResultInfo.brightPrecentage];
    NSString *edgeBright2DarkString = [NSString stringWithFormat:@"Bright to Dark = %.2f%%", edgeResultInfo.darkPrecentage];
    
    NSString *snrAvgString = [NSString stringWithFormat:@"SNR avg = %f", edgeResultInfo.SNR_Avg];
    NSString *snrMinString = [NSString stringWithFormat:@"SNR min = %f", edgeResultInfo.SNR_Min];

    putText(drawingImage, [edgeMeanString UTF8String],          CvPoint{100,100}, 1, 2, *new Scalar(128,225,0), 2);
    putText(drawingImage, [edgemeanSdString UTF8String],        CvPoint{100,130}, 1, 2, *new Scalar(128,225,0), 2);
    
    putText(drawingImage, [edgeMedianString UTF8String],        CvPoint{100,160}, 1, 2, *new Scalar(128,225,0), 2);
    putText(drawingImage, [edgeMedianSDString UTF8String],      CvPoint{100,190}, 1, 2, *new Scalar(128,225,0), 2);

    putText(drawingImage, [edgeDark2BrightString UTF8String],   CvPoint{100,220}, 1, 2, *new Scalar(128,225,0), 2);
    putText(drawingImage, [edgeBright2DarkString UTF8String],   CvPoint{100,250}, 1, 2, *new Scalar(128,225,0), 2);
    
    putText(drawingImage, [snrAvgString UTF8String],            CvPoint{100,280}, 1, 2, *new Scalar(128,225,0), 2);
    putText(drawingImage, [snrMinString UTF8String],            CvPoint{100,310}, 1, 2, *new Scalar(128,225,0), 2);

    return err;
}


- (edgeError) DefineInnerOuterCircleIn : (Mat) inputImage                  // source image
                               CenterX : (int) cx                          // center x of inner and outer rectanger
                               CenterY : (int) cy                          // center y of inner and outer rectanger
                     InnerCircleRadius : (int) innerRadius             // width of outer rectangle
                     OuterCircleRadius : (int) outerRadius             // height of outer rectangle
                            DeltaAngle : (int) deltaAngle                // interval of lines between inner rectangle and outer rectangle (unit pixel)
                           LinesResult : (vector<roiLine>&) allLines      // result of lines
{
    Vector<CvPoint> allPointsOn1Line;
    roiLine currentLine;
    
    for (double i = 0; i < 359; i = i + deltaAngle){
        
        int startX = cx + (innerRadius * (cos(i/180*pi)));
        int startY = cy + (innerRadius * (sin(i/180*pi)));
        
        int targetX = cx + (outerRadius * (cos(i/180*pi)));
        int targetY = cy + (outerRadius* (sin(i/180*pi)));
        
        
        // ------------------bresenham draw line START--------------------
        int x0 = startX;
        int x1 = targetX;
        int y0 = startY;
        int y1 = targetY;
        
        int sx,sy;
        
        int dx = abs(x1-x0);
        int dy = abs(y1-y0);
        if (x0 < x1) {
            sx = 1;
        }
        else{
            sx = -1;
        }
        
        if (y0 < y1) {
            sy = 1;
        }
        else{
            sy = -1;
        }
        
        int err = dx-dy;
        
        while (!(x0 == x1 && y0 == y1)) {
            
            CvPoint currentPoint;
            currentPoint.x = x0;
            currentPoint.y = y0;
            if (currentPoint.x > 0 && currentPoint.x < inputImage.cols && currentPoint.y > 0 && currentPoint.y < inputImage.rows){
                allPointsOn1Line.push_back(currentPoint);
            }
            
            
            int e2 = 2*err;
            
            if (e2 > -dy) {
                err = err - dy;
                x0 = x0 + sx;
            }
            
            if (e2 < dx){
                err = err + dx;
                y0 = y0 + sy;
            }
        }
        // -----------------------bresenham draw line END-----------------------
        
        allPointsOn1Line.copyTo(currentLine.allPoints);
        allLines.push_back(currentLine);
        allPointsOn1Line.clear();
    }
    
    return noError;
}



- (edgeError) leastSquareCircleFit : (vector<edgePoint>) input_edge_pts CircleResult : (fittedCircle&) circle{
    
    if (input_edge_pts.size() < 3) {
        return edgePtNotEnough;
    }
    
    long N = input_edge_pts.size();
    double U = 0, V = 0;
    double aveg_x = 0, aveg_y = 0;
    double uu = 0, uv = 0, vv = 0, uuu = 0, vvv = 0, uvv = 0, vuu = 0;
    double Uc = 0, Vc = 0;
    
    circle.radius = 0;
    circle.cx = 0;
    circle.cy = 0;
    
    double y1, y2;
    
    vector<double> Ui;
    vector<double> Vi;
    
    // find aveg_x and aveg_y
    for (long i = 0; i < N; i++){
        aveg_x = (double)input_edge_pts[i].point.x + aveg_x;
        aveg_y = (double)input_edge_pts[i].point.y + aveg_y;
    }
    aveg_x = aveg_x / (double)N;
    aveg_y = aveg_y / (double)N;
    
    
    for (long i = 0; i < N; i++){
        //ui = xi − aveg_x,
        U = (double)input_edge_pts[i].point.x - aveg_x;
        Ui.push_back(U);
        
        //vi = yi − aveg_y
        V = (double)input_edge_pts[i].point.y - aveg_y;
        Vi.push_back(V);
    }
    
    for (int i = 0; i < N; i++) {
        uu = uu + (Ui[i] * Ui[i]);
        uv = uv + (Ui[i] * Vi[i]);
        vv = vv + (Vi[i] * Vi[i]);
        uuu = uuu + (Ui[i] * Ui[i] * Ui[i]);
        vvv = vvv + (Vi[i] * Vi[i] * Vi[i]);
        uvv = uvv + (Ui[i] * Vi[i] * Vi[i]);
        vuu = vuu + (Vi[i] * Ui[i] * Ui[i]);
    }
    
    y1 = (uuu + uvv) / 2;
    y2 = (vvv + vuu) / 2;
    
    Vc = ((y1 * uv) - (y2 * uu)) / ((uv * uv) - (vv * uu));
    Uc = (y1 - (Vc * uv)) / uu;
    
    circle.radius = sqrt((Uc * Uc) + (Vc * Vc) + ((uu + vv) / N));
    
    circle.cx = Uc + aveg_x;
    circle.cy = Vc + aveg_y;
    
    return noError;
}

- (edgeError) filterEdgePtsOutsideTolerance : (double)tolerance Circle : (fittedCircle&) circle EdgePointsIn : (vector<edgePoint>) allEdgePoints EdgePointOut : (vector<edgePoint>&) filteredEdgePoints{
    
    // compare each edge pt's distance with the radius, if the distance is larger +/- tolerance, reject it.
    for (int i = 0; i < allEdgePoints.size(); i++){
        double dist = sqrt(pow((allEdgePoints[i].point.x - circle.cx), 2) + pow((allEdgePoints[i].point.y - circle.cy), 2)) ;
        
        //only save the edge pts whcih are within the tolerance
        if (abs(dist - circle.radius) < tolerance){
            filteredEdgePoints.push_back(allEdgePoints[i]);
        }
    }
    
    return noError;
}


- (edgeError) fitCircleByRadiusFilterWithTolerance : (double) tolerance Circle : (fittedCircle&) circle EdgePointsIn : (vector<edgePoint>) allEdgePoints{
    
    edgeError err = noError;
    
    vector<edgePoint> filteredEdgePoints;
    
    // use edge pts to get the real cx,cy and r first
    err = [self leastSquareCircleFit:allEdgePoints CircleResult:circle];
    if (err != noError) {
        return err;
    }
    
    // filter some edge points and the find the circle again
    err = [self filterEdgePtsOutsideTolerance:tolerance Circle:circle EdgePointsIn:allEdgePoints EdgePointOut:filteredEdgePoints];
    if (err != noError) {
        return err;
    }
    
    err = [self leastSquareCircleFit:filteredEdgePoints CircleResult:circle];
    if (err != noError) {
        return err;
    }
    
    return noError;
    
}

- (edgeError) fitCircleByRansacFilterWithTolerance : (double) tolerance
                                            Circle : (fittedCircle&) circle
                                     AllEdgePoints : (Vector<edgePoint>) allEdgePoints
                                   OutValidEdgePts : (Vector<edgePoint>&) validEdgePoints{
    
    struct RANSAC {
        int rand1;
        int rand2;
        int rand3;
        int RANSAC_validCount;
        double cx;
        double cy;
        double r;
        vector<edgePoint> validEdgePts;
    };
    
    bool isFitAgain = true;
    
    Vector<RANSAC> ransacPara;
    
    if (allEdgePoints.size() < 3){
        return edgePtNotEnough;
    }
    
    for (int c = 0; c < 100; c++) {
        
        int rand1 = 0;
        int rand2 = 0;
        int rand3 = 0;
    
        // pick up 3 random edge points
        do{
            rand1 = arc4random() % allEdgePoints.size();
            rand2 = arc4random() % allEdgePoints.size();
            rand3 = arc4random() % allEdgePoints.size();
        }
        while (rand1 == rand2 || rand1 == rand3 || rand2 == rand3);

        // use these 3 random edge points for
        vector<edgePoint> randomEdgePts;
        randomEdgePts.push_back(allEdgePoints[rand1]);
        randomEdgePts.push_back(allEdgePoints[rand2]);
        randomEdgePts.push_back(allEdgePoints[rand3]);
        [self leastSquareCircleFit:randomEdgePts CircleResult:circle];

        //get cx, cy and r; define acceptable inner and outer circle
        RANSAC currentRANSAC;
        
        currentRANSAC.rand1 = rand1;
        currentRANSAC.rand2 = rand2;
        currentRANSAC.rand3 = rand3;
        currentRANSAC.cx = circle.cx;
        currentRANSAC.cy = circle.cy;
        currentRANSAC.r = circle.radius;
        currentRANSAC.RANSAC_validCount = 0;
        double innerDist = currentRANSAC.r - tolerance;
        double outerDist = currentRANSAC.r + tolerance;
        
        for (int i = 0; i < allEdgePoints.size(); i++){
            if (i == rand1 || i == rand2 || i == rand3) {
                continue;
            }
            else{
                double dist = sqrt(pow((double)(allEdgePoints[i].point.x - currentRANSAC.cx), 2) + pow((double)(allEdgePoints[i].point.y - currentRANSAC.cy), 2));
                if (dist >= innerDist && dist <= outerDist) {
                    currentRANSAC.validEdgePts.push_back(allEdgePoints[i]);
                    currentRANSAC.RANSAC_validCount++;
                }
            }
        }
        ransacPara.push_back(currentRANSAC);
        //NSLog(@"loop = %d, cx = %d, cy = %d, r = %d, valid count = %d", c, currentRANSAC.cx, currentRANSAC.cy, currentRANSAC.r, currentRANSAC.RANSAC_validCount);
    }
    
    int finalRansacIndex = -1;
    int tempValidCount = 0;
    
    for (int f = 0; f < ransacPara.size(); f++) {
        if (ransacPara[f].RANSAC_validCount > tempValidCount) {
            tempValidCount = ransacPara[f].RANSAC_validCount;
            finalRansacIndex = f;
        }
    }
    
    if (finalRansacIndex == -1) {
        return edgePointsNotValid;
    }
    
    if (isFitAgain) {
        
        [self leastSquareCircleFit:ransacPara[finalRansacIndex].validEdgePts CircleResult:circle];
        
        // save valid edgePoint for Yinan to fit ellipse
        for (int i = 0; i < ransacPara[finalRansacIndex].validEdgePts.size(); i++) {
            //copy valid edge point 1 by 1, don't use validEdgePoints = ransacPara[finalRansacIndex].validEdgePts; Otherwirse, some element may disappear
            validEdgePoints.push_back(ransacPara[finalRansacIndex].validEdgePts[i]);
        }
    }
    else{
        circle.cx = ransacPara[finalRansacIndex].cx;
        circle.cy = ransacPara[finalRansacIndex].cy;
        circle.radius = ransacPara[finalRansacIndex].r;
    }
    return noError;
}

- (void)drawCircleIn : (Mat) drawingImage Cx : (int)cx Cy : (int)cy radius : (int) radius colour: (char) color{
    
    Scalar circleColor;
    
    switch (color) {
        case 'r' :
            circleColor = Scalar(0,0,255);
            break;
        case 'g' :
            circleColor = Scalar(0,255,0);
            break;
        case 'b' :
            circleColor = Scalar(255,0,0);
            break;
        case 'y' :
            circleColor = Scalar(0,255,255);
            break;
        case 'd' :
            circleColor = Scalar(0,0,0);
            break;
        default:
            circleColor = Scalar(0,0,255);
            break;
    }
    
    cv::circle(drawingImage, cv::Point(cx, cy),radius, circleColor, 1,8,0);
}

- (double)abs : (double) x{
    if (x < 0){
        x = -x;
    }
    return x;
}


@end
