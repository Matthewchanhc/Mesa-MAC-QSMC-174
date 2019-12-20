//
//  EdgeFinder.m
//  circle_finder_v2
//
//  Created by Charlie on 9/12/15.
//  Copyright © 2015 智偉 余. All rights reserved.
//

#import "EdgeFinder.h"

@implementation EdgeFinder

+ (edgeError) FindEdgePointInImage : (Mat) internalImage
                        KernelSize : (int) kernelWidth
                        KernelType : (int) kernelType
                SearchingDirection : (int) direction
                     EdgeThreshold : (double) edgeThreshold
                          EdgeType : (int) edgeType
                         WhichEdge : (int) whichEdge
                          AllLines : (vector<roiLine>) allLines
                  EdgePointsResult : (vector<edgePoint>&) allEdgePoints
                            allSNR : (vector<double>&) allSNR{
    
    
    // create a kernel
    double kernel[kernelWidth] ;
    
    if (kernelType == originalKernel) {
        // create a kernel
        for (int i = -((kernelWidth-1)/2), j = 0 ; i <= (kernelWidth-1)/2 ; i++, j++){
            kernel[j] = i;
        }
    }
    else if(kernelType == reversedKernel) {
        for (int i = 0, j = 0 ; j < kernelWidth ; j++){
            
            if (j < kernelWidth / 2 ) {
                i--;
            }
            else if(j == (kernelWidth / 2 )){
                i = 0;
            }
            else{
                i = kernel[kernelWidth - 1 - j] * -1;
            }
            kernel[j] = i;
        }
    }
    else if(kernelType == gaussianKernel){

        double sigma = 0.5;
        
        switch (kernelWidth){
            case 5:
                sigma = 0.5;
                break;
            case 9:
                sigma = 1;
                break;
            case 15:
                sigma = 2;
                break;
            case 25:
                sigma = 4;
                break;
            case 35:
                sigma = 5;
                break;
        }

        for (int i = 0; i < kernelWidth; i++) {
            double x = i - ceil(kernelWidth/2);
            kernel[i] = -1 * (-x / ((sqrt(2.0 * 3.1416) * pow(sigma, 3.0)) * exp(pow(-x, 2.0) / (2 * pow(sigma, 2.0)))));
        }
        
    }
    
    //kernel normalization
    double sumK = 0;
    for(int sk = 0; sk < kernelWidth ; sk++){
        sumK += abs(kernel[sk]);
    }
    for (int sk = 0; sk < kernelWidth; sk++) {
        kernel[sk] = kernel[sk] / sumK;
    }
    
    vector<CvPoint> allPtsOn1Line;
    vector<pointV> kernelResultOn1Line;
    vector<pointV> allMaxLocationOn1Line;
    vector<pointV> allMaxLocationOn1LineBefore;

    
    
    int numOfDirectionLoop = 0;
    int finalEdgeType = edgeType;
    
    //for auto threshold
    double BestEdgeThreshold = 0;
    
    // set the numOfDirectionLoop
    if(direction == in2Out || direction == out2In){
        numOfDirectionLoop = 1;
    }
    else if (direction == bidirectional){
        //first loop : in2out    second loop : out2in
        numOfDirectionLoop = 2;
    }
    
    
    
    
    for (int k = 0; k < allLines.size(); k++){
        for (int direction_count = 0; direction_count < numOfDirectionLoop; direction_count++) {
            CvPoint in2outEdgePt; // only be used in bidirectional case
            CvPoint out2inEdgePt; // only be used in bidirectional case
            
            // get current line
            if (direction == in2Out) {
                allPtsOn1Line = allLines[k].allPoints;
                finalEdgeType = edgeType;
            }
            else if (direction == out2In){
                allPtsOn1Line = allLines[k].allPoints;
                reverse(allPtsOn1Line.begin(),allPtsOn1Line.end());
                finalEdgeType = edgeType;
            }
            else if (direction == bidirectional){
                if (direction_count == 0) {
                    // bidirectional : in2out state
                    allPtsOn1Line = allLines[k].allPoints;
                    finalEdgeType = edgeType;
                }
                else if (direction_count == 1){
                    //bidirectional : out2in state
                    allPtsOn1Line = allLines[k].allPoints;
                    reverse(allPtsOn1Line.begin(),allPtsOn1Line.end());
                    
                    // invert edge type
                    if (edgeType == bright2Dark) {
                        finalEdgeType = dark2Bright;
                    }
                    else if (edgeType == dark2Bright){
                        finalEdgeType = bright2Dark;
                    }
                }
            }
            
            
            // check the number of pts on current line is enough or not
            if (allPtsOn1Line.size() < kernelWidth){
                continue;
            }
            
            
            //use kernel and strength to do calculation
            int pixelValue = 0;
            double pixelValueTimesKernel = 0;
            double currentKernelResult = 0;
            int xPosition = 0;
            int yPosition = 0;
            
            for (int m = 0; m < (allPtsOn1Line.size() - kernelWidth); m++){
                // convolution with kernel
                for(int n = 0; n < kernelWidth; n++){
                    xPosition = allPtsOn1Line[m+n].x;
                    yPosition = allPtsOn1Line[m+n].y;
                    
                    if (xPosition < 0 || xPosition >= internalImage.cols || yPosition < 0 || yPosition >= internalImage.rows) {
                        // if the position of pt is outside the image, return false
                        continue;
                    }
                    else {
                        pixelValue = internalImage.at<uchar>(cv::Point(xPosition, yPosition));
                        pixelValueTimesKernel = (double)pixelValue * kernel[n];
                        currentKernelResult = currentKernelResult + pixelValueTimesKernel;
                    }
                }
                
                currentKernelResult = (double)currentKernelResult;// / (double)kernelWidth;
                
                
                pointV kernel_result_pt;
                kernel_result_pt.x = (double)allPtsOn1Line[m + (kernelWidth/2) + 1].x;
                kernel_result_pt.y = (double)allPtsOn1Line[m + (kernelWidth/2) + 1].y;
                kernel_result_pt.value = currentKernelResult;
                
                
                
                //*****************[save conv result to txt file for debug]********************************
//                NSString* outMsg = [NSString stringWithFormat:@"%d, %d, %f, %d\n", kernel_result_pt.x,  kernel_result_pt.y,  kernel_result_pt.value, internalImage.at<uchar>(cv::Point(kernel_result_pt.x, kernel_result_pt.y))];
//                
//                NSString *path = [NSString stringWithFormat:@"%@/%d.csv", @"/Users/PatrickYu/Desktop/test2", k];
//                
//                FILE * fs = fopen([path UTF8String], "a");
//                
//                if (fs == NULL) {
//                    fclose(fs);
//                    fs = fopen([path UTF8String], "w+");
//                    fprintf(fs, [outMsg UTF8String]);
//                }
//                else{
//                    fprintf(fs, [outMsg UTF8String]);
//                }
//                fclose(fs);
                
                //*****************[save conv result to txt file for debug END]********************************

                
                
                kernelResultOn1Line.push_back(kernel_result_pt);
                currentKernelResult = 0;
            }
            
            
            //find all local maximum
            double prevValue = 0.0;
            double currentValue = 0.0;
            double nextValue = 0.0;
            
            double prevValueBefore = 0.0;
            double currentValueBefore = 0.0;
            double nextValueBefore = 0.0;
            
            pointV maxLocation;
            pointV maxLocationBefore;

            
            for (int q = 1; q < kernelResultOn1Line.size()-1; q++){
                
                if (finalEdgeType == dark2Bright){
                    prevValue = kernelResultOn1Line[q-1].value;
                    currentValue = kernelResultOn1Line[q].value;
                    nextValue = kernelResultOn1Line[q+1].value;
                    
                    prevValueBefore = kernelResultOn1Line[q-1].value;
                    currentValueBefore = kernelResultOn1Line[q].value;
                    nextValueBefore = kernelResultOn1Line[q+1].value;
                }
                else if (finalEdgeType == bright2Dark){
                    prevValue = kernelResultOn1Line[q-1].value * -1;
                    currentValue = kernelResultOn1Line[q].value * -1;
                    nextValue = kernelResultOn1Line[q+1].value * -1;
                    
                    prevValueBefore = kernelResultOn1Line[q-1].value;
                    currentValueBefore = kernelResultOn1Line[q].value;
                    nextValueBefore = kernelResultOn1Line[q+1].value;
                }
                else if (finalEdgeType == bothEdge){
                    prevValue = abs(kernelResultOn1Line[q-1].value);
                    currentValue = abs(kernelResultOn1Line[q].value);
                    nextValue = abs(kernelResultOn1Line[q+1].value);
                    
                    prevValueBefore = kernelResultOn1Line[q-1].value;
                    currentValueBefore = kernelResultOn1Line[q].value;
                    nextValueBefore = kernelResultOn1Line[q+1].value;
                }
                
                // save all local maximum
                if (kernelType == originalKernel) {
                    if (currentValue >= prevValue && currentValue >= nextValue){
                        maxLocation.x = kernelResultOn1Line[q].x;
                        maxLocation.y = kernelResultOn1Line[q].y;
                        maxLocation.value = currentValue;
                        allMaxLocationOn1Line.push_back(maxLocation);
                        
                        maxLocationBefore.x = kernelResultOn1Line[q].x;
                        maxLocationBefore.y = kernelResultOn1Line[q].y;
                        maxLocationBefore.value = currentValueBefore;
                        allMaxLocationOn1LineBefore.push_back(maxLocationBefore);
                    }
                }
                else{
                    if (currentValue > prevValue && currentValue > nextValue){
                        maxLocation.x = kernelResultOn1Line[q].x;
                        maxLocation.y = kernelResultOn1Line[q].y;
                        maxLocation.value = currentValue;
                        allMaxLocationOn1Line.push_back(maxLocation);
                        
                        maxLocationBefore.x = kernelResultOn1Line[q].x;
                        maxLocationBefore.y = kernelResultOn1Line[q].y;
                        maxLocationBefore.value = currentValueBefore;
                        allMaxLocationOn1LineBefore.push_back(maxLocationBefore);
                        
                        //NSLog(@"current value = %f, before value = %f", currentValue, currentValueBefore);
                    }
                }
            }
            
            
            //find edge point base on which edge
            //pointV edgePoint;
            edgePoint edgePt;
            double max_edge = 0;
            bool isBestEdgeFound = false;
            int edgePtIndex = -1;
            
            for (int w = 0; w < allMaxLocationOn1Line.size(); w++){
                if (whichEdge == firstEdge) {
                    if (allMaxLocationOn1Line[w].value >= edgeThreshold){
                        edgePt.point.x = allMaxLocationOn1Line[w].x;
                        edgePt.point.y = allMaxLocationOn1Line[w].y;
                        edgePt.strength = allMaxLocationOn1LineBefore[w].value;             // ******************** use the strenght that befor abs
                        edgePt.lineName = allLines[k].lineName;
                        edgePtIndex = w;
                        
                        if (direction == bidirectional) {
                            if (direction_count == 0) {
                                in2outEdgePt = edgePt.point;
                            }
                            else if(direction_count == 1){
                                out2inEdgePt = edgePt.point;
                                
                                // find out the distance
                                double dist_x = in2outEdgePt.x - out2inEdgePt.x;
                                double dist_y = in2outEdgePt.y - out2inEdgePt.y;
                                double two_direction_edge_pt_distance = sqrt((dist_x * dist_x) + (dist_y * dist_y));
                                
                                // save the edge pt if dist <= 5 pixel in bidirectional case
                                if (two_direction_edge_pt_distance <= 5) {
                                    allEdgePoints.push_back(edgePt);
                                }
                            }
                        }
                        else if (direction == in2Out || direction == out2In) {
                            //save the edge pt directly in in2out || out2in case
                            allEdgePoints.push_back(edgePt);
                        }
                        
                        break;
                    }
                    
                }
                else if (whichEdge == bestEdge){
                    if (allMaxLocationOn1Line[w].value >= max_edge && allMaxLocationOn1Line[w].value >= edgeThreshold){
                        max_edge = allMaxLocationOn1Line[w].value;
                        
                        edgePt.point.x = allMaxLocationOn1Line[w].x;
                        edgePt.point.y = allMaxLocationOn1Line[w].y;
                        edgePt.strength = allMaxLocationOn1Line[w].value;
                        edgePt.lineName = allLines[k].lineName;
                        isBestEdgeFound = true;
                    }
                }
            }
            
            if (whichEdge == bestEdge && isBestEdgeFound == true){
                allEdgePoints.push_back(edgePt);
                BestEdgeThreshold = edgePt.strength + BestEdgeThreshold;
            }
            
            //*******************
            
            double peakStrength = abs(edgePt.strength);
            double noiseAvg = 0.0;
            double noiseCount = 1;
            double SNR = 0;
            for (int nos = 0; nos < edgePtIndex; nos++){
                noiseAvg = abs(allMaxLocationOn1Line[nos].value) + noiseAvg;
                noiseCount++;
            }
            
            if (edgePtIndex == -1){
                continue;
            }
            
            noiseAvg = noiseAvg / noiseCount;
            SNR = peakStrength / noiseAvg;
            
            //NSLog(@"size = %zu, edge pt index = %d, noise AVG = %f, peak = %f, current SNR = %f", allMaxLocationOn1Line.size(), edgePtIndex, noiseAvg, peakStrength, SNR);
            
            if (noiseAvg > 0) {
                allSNR.push_back(SNR);
            }
            
            //*******************
            
            
            kernelResultOn1Line.clear();
            allMaxLocationOn1Line.clear();
            allPtsOn1Line.clear();
            
            allMaxLocationOn1LineBefore.clear();
            
        }
    }
    
    if (whichEdge == bestEdge && allEdgePoints.size() > 0) {
        BestEdgeThreshold = BestEdgeThreshold / allEdgePoints.size();
    }
    else{
        BestEdgeThreshold = 0;
    }
    
    if (allEdgePoints.size() < 3){
        return edgePtNotEnough;
    }
    
    return noError;
}

+ (void) drawAllLinesIn : (Mat)drawingImage lines: (vector<roiLine>) lines colour: (char) color{
    
    Vec3b v;    //edge point (yellow)
    
    switch (color) {
        case 'r' :
            v[0] = 0;          //blue
            v[1] = 0;          //green
            v[2] = 255;        //red
            break;
        case 'g' :
            v[0] = 0;
            v[1] = 255;
            v[2] = 0;
            break;
        case 'b' :
            v[0] = 255;
            v[1] = 0;
            v[2] = 0;
            break;
        case 'y' :
            v[0] = 0;
            v[1] = 255;
            v[2] = 255;
            break;
        case 'd' :
            v[0] = 0;
            v[1] = 0;
            v[2] = 0;
            break;
        default:
            v[0] = 0;
            v[1] = 0;
            v[2] = 255;
            break;
    }
    
    for (int i = 0; i < lines.size(); i++){
        for (int j = 0; j <lines[i].allPoints.size(); j++){
            if (j == 0){
                Vec3b b;
                b[0] = 255; b[1] = 255; b[2] = 255;
                drawingImage.at<Vec3b>(cv::Point(lines[i].allPoints[j].x, lines[i].allPoints[j].y)) = b;
            }
            else{
                drawingImage.at<Vec3b>(cv::Point(lines[i].allPoints[j].x, lines[i].allPoints[j].y)) = v;
            }
        }
    }
}

+ (void) drawEdgePointsIn : (Mat)drawingImage allEdgePoints : (vector<edgePoint>)allEdgePts colour: (char) color{
    
    Vec3b v;
    
    switch (color) {
        case 'r' :
            v[0] = 0;          //blue
            v[1] = 0;          //green
            v[2] = 255;        //red
            break;
        case 'g' :
            v[0] = 0;
            v[1] = 255;
            v[2] = 0;
            break;
        case 'b' :
            v[0] = 255;
            v[1] = 0;
            v[2] = 0;
            break;
        case 'y' :
            v[0] = 0;
            v[1] = 255;
            v[2] = 255;
            break;
        case 'd' :
            v[0] = 0;
            v[1] = 0;
            v[2] = 0;
            break;
        default:
            v[0] = 0;
            v[1] = 0;
            v[2] = 255;
            break;
    }
    
    for (int i = 0; i < allEdgePts.size(); i++){
        drawingImage.at<Vec3b>(cv::Point((int)allEdgePts[i].point.x, (int)allEdgePts[i].point.y)) = v;
    }
}

+ (void) calcInfo : (Vector<edgePoint>) allEdgePoints allSNR : (vector<double>)SNR edgeInfo : (edgeInfo&)edgeResultInfo{
    //********** cal all edge pt strength mean & meanSd
    double mean = 0.0;
    double meanSd = 0.0;
    double absMeanSD = 0.0;
    double absMean = 0.0;
    
    int numOfBright = 0;
    int numOfDark = 0;
    
    for (int i = 0; i < allEdgePoints.size(); i++){
        mean = allEdgePoints[i].strength + mean;
        absMean = abs(allEdgePoints[i].strength) + absMean;
        
        if (allEdgePoints[i].strength == abs(allEdgePoints[i].strength)) {
            // strength = +ve; dark2bright case
            numOfBright++;
        }
        else{
            // strength = -ve; bright2dark case
            numOfDark++;
        }
    }
    mean = mean / allEdgePoints.size();
    absMean = absMean / allEdgePoints.size();
    
    edgeResultInfo.brightPrecentage   = (double(numOfBright) / double(allEdgePoints.size())) * 100.0;
    edgeResultInfo.darkPrecentage     = (double(numOfDark) / double(allEdgePoints.size())) * 100;
    
    //    sort(allAbsStrength.begin(), allAbsStrength.end());
    //
    //    if (allAbsStrength.size()%2 == 1){ // = odd number
    //        medain = allAbsStrength[allAbsStrength.size() / 2];
    //    }
    //    else{
    //        medain = (allAbsStrength[allAbsStrength.size() / 2 - 1] + allAbsStrength[allAbsStrength.size() / 2]) / 2.0;
    //    }
    
    for (int i = 0; i < allEdgePoints.size(); i++) {
        meanSd = meanSd + ((allEdgePoints[i].strength - mean) * (allEdgePoints[i].strength - mean));
        absMeanSD = absMeanSD + (abs(allEdgePoints[i].strength) - absMean) * (abs(allEdgePoints[i].strength) - absMean);
    }
    meanSd = 1/(double)(allEdgePoints.size()) * meanSd;
    meanSd = sqrt(meanSd);
    
    absMeanSD = 1/(double)(allEdgePoints.size()) * absMeanSD;
    absMeanSD = sqrt(absMeanSD);
    
    double meanSNRAvg = 0;
    double tempSNRMin = 100000000;
    for (int i = 0; i < SNR.size(); i++){
        meanSNRAvg = SNR[i] + meanSNRAvg;
        
        if (SNR[i] <= tempSNRMin) {
            tempSNRMin = SNR[i];
        }
    }
    meanSNRAvg = meanSNRAvg / double(SNR.size());
    //NSLog(@"SNR = %f", meanSNR);
    
    
    edgeResultInfo.edgeMean = mean;
    edgeResultInfo.edgeMeanSD = meanSd;
    edgeResultInfo.edgeAbsMean = absMean;
    edgeResultInfo.edgeAbsMeanSD= absMeanSD;
    edgeResultInfo.SNR_Avg = meanSNRAvg;
    edgeResultInfo.SNR_Min = tempSNRMin;
    
    
    //NSLog(@"edge mean = %f, edge meanSd = %f, median = %f, bright precentage = %f, dark precentage = %f", _edgeMean, _edgemeanSd, _edgeMedian, _brightPrecentage, _darkPrecentage);
    
    //********** cal all edge pt strength mean & meanSd END
    
    for (int i  = 0; i < allEdgePoints.size(); i++){
        // don't use : edgeResultInfo.rawEdgePts = allEdgePoints; to copy vector. Otherwirse, some elements may disappear.
        edgeResultInfo.rawEdgePts.push_back(allEdgePoints[i]);
    }
}

@end
