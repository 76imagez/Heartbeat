//
//  Algorithm.m
//  Heartbeat
//
//  Created by Or Maayan on 9/13/13.
//  Copyright (c) 2013 michael leybovich. All rights reserved.
//

#import "Algorithm.h"
#import "Butterworth.h"

@interface Algorithm()
//
@property (nonatomic , readwrite) NSUInteger framesCounter;
@property (nonatomic) NSUInteger firstPeakPlace;// first place peak was determined. if 0 the none found
@property (nonatomic) NSUInteger numOfPeaks;// number of peaks in the last calibrationDuration frames

@property (nonatomic , strong) NSMutableArray *points;// represent the array of color values (doubles) wrapped by NSNumbers
@property (nonatomic , strong) NSMutableArray *bpmValues;// array of the calculated beats per minute values wrapped by NSNumbers
@property (nonatomic , strong) NSMutableArray *bpmAverageValues;// array of average values of the bpm wrapped by NSNumbers;
@property (nonatomic , strong) NSMutableArray *isPeak;// array of the BOOLs represent if the matching point is peak in the graph

//
@property (nonatomic , readwrite) BOOL isCalibrationOver;
@property (nonatomic , readwrite) BOOL isFinalResultDetermined;
@property (nonatomic, readwrite) BOOL isPeakInLastFrame;
@property (nonatomic, readwrite) BOOL isMissedTheLastPeak;
@property (nonatomic , readwrite) BOOL shouldShowLatestResult;

@property (nonatomic) NSUInteger lastPeakPlace;

@end

@implementation Algorithm

#pragma mark - Lifecycle

- (void)dealoc {
    free(self.buttterworthValues[0]);
    free(self.buttterworthValues[1]);
    free(self.buttterworthValues);
}

#pragma mark - Properties

#define FPS 30
#define WINDOW_SIZE 9
#define WINDOW_SIZE_FOR_FILTER_CALCULATION 45// should be at least WINDOW_SIZE*2
#define CALIBRATION_DURATION 90
#define WINDOW_SIZE_FOR_AVERAGE_CALCULATION 75

- (CGFloat)frameRate{
    if (!_frameRate) {
        _frameRate = FPS;
    }
    return _frameRate;
}

- (NSUInteger)windowSize{
    if (!_windowSize) {
        _windowSize = WINDOW_SIZE;
    }
    return _windowSize;
}

- (NSUInteger)filterWindowSize{
    if (!_filterWindowSize) {
        _filterWindowSize = WINDOW_SIZE_FOR_FILTER_CALCULATION;
    }
    return _filterWindowSize;
}

- (NSUInteger)calibrationDuration{
    if (!_calibrationDuration) {
        _calibrationDuration = CALIBRATION_DURATION;
    }
    return _calibrationDuration;
}

- (NSUInteger)windowSizeForAverageCalculation{
    if (!_windowSizeForAverageCalculation) {
        _windowSizeForAverageCalculation = WINDOW_SIZE_FOR_AVERAGE_CALCULATION;
    }
    return _windowSizeForAverageCalculation;
}

- (NSMutableArray *)points
{
    if (!_points) {
        _points = [NSMutableArray array];
    }
    return _points;
}

- (NSMutableArray *)bpmValues
{
    if (!_bpmValues) {
        _bpmValues = [NSMutableArray array];
    }
    return _bpmValues;
}

- (NSMutableArray *)bpmAverageValues
{
    if (!_bpmAverageValues) {
        _bpmAverageValues = [NSMutableArray array];
    }
    return _bpmAverageValues;
}

- (NSMutableArray *)isPeak
{
    if (!_isPeak) {
        _isPeak = [NSMutableArray array];
    }
    return _isPeak;
}

#define FILTER_ORDER 3
#define FILTER_LOWER_BAND 0.0444 //40
#define FILTER_UPPER_BAND 0.2 //180

// butterworth
/* order 7 , lower_band 0.04 , upper_band 0.2
 NumC - {-7.030405, -0.000000, 49.212837, -0.000000, -147.638512, -0.000000, 246.064187, -0.000000, -246.064187, -0.000000, 147.638512, -0.000000, -49.212837, -0.000000}
 DenC - {1.000000, -11.273712, 59.457459, -194.486686, 440.890860, -732.860474, 921.241477, -889.738035, 663.479760, -380.165762, 164.768303, -52.381755, 11.547385, -1.580078}
 */
/* order 5 , lower_band 0.04 , upper_band 0.2
 NumC - {0.000489, 0.000000, -0.002447, 0.000000, 0.004894, 0.000000, -0.004894, 0.000000, 0.002447, 0.000000}
 DenC - {1.000000, -8.042343, 29.422400, -64.519483, 93.955411, -94.965248, 67.480986, -33.290005, 10.912253, -2.146359}
 */
/* order 3 , lower_band 0.04 , upper_band 0.2
 NumC - {0.010183, 0.000000, -0.030548, 0.000000, 0.030548, 0.000000}
 DenC - {1.000000, -4.803318, 9.794540, -10.882236, 6.960506, -2.430979}
 */
/* order 5 , lower_band 0.05 , upper_band 0.2
 NumC - {0.000369, 0.000000, -0.001844, 0.000000, 0.003688, 0.000000, -0.003688, 0.000000, 0.001844, 0.000000}
 DenC - {1.000000, -8.056065, 29.591305, -65.287145, 95.838208, -97.823134, 70.319337, -35.154425, 11.698483, -2.340356}
 */
/* order 3 , lower_band 0.05 , upper_band 0.2
 NumC - {0.008599, 0.000000, -0.025796, 0.000000, 0.025796, 0.000000}
 DenC - {1.000000, -4.812550, 9.874176, -11.076649, 7.174203, -2.544626}
 */
/* order 3 , lower_band 0.04444 , upper_band 0.2
 NumC - {0.009460, 0.000000, -0.028381, 0.000000, 0.028381, 0.000000}
 DenC - {1.000000, -4.807499, 9.830069, -10.968538, 7.054920, -2.480913}
 */


- (double**)buttterworthValues{
    if (!_buttterworthValues) {
        double frequencyBands[2] = {FILTER_LOWER_BAND , FILTER_UPPER_BAND};
        _buttterworthValues = butter(frequencyBands, FILTER_ORDER);
        /*
        NSLog(@"NumC");
        NSString *s = @"";
        for (int i = 0; i<FILTER_ORDER*2; i++) {
            s = [s stringByAppendingString:[NSString stringWithFormat:@"%f, " , _buttterworthValues[0][i]]];
        }
        NSLog(s);
        s = @"";
        NSLog(@"DenC");
        for (int i = 0; i<FILTER_ORDER*2; i++) {
            s = [s stringByAppendingString:[NSString stringWithFormat:@"%f, " , _buttterworthValues[1][i]]];
        }
        NSLog(s);
         */
    }
    return _buttterworthValues;
}

#pragma mark - public methods

- (BOOL)isCalibrationOver{
    if ((self.framesCounter > self.calibrationDuration + self.filterWindowSize) && ((self.framesCounter > (self.calibrationDuration + self.firstPeakPlace + self.windowSize)) && (self.firstPeakPlace != 0))) {
        _isCalibrationOver = YES;
    }
    else {
        _isCalibrationOver = NO;
    }
    return _isCalibrationOver;
}

#define FINAL_RESULT_MARGIN 2.1

- (BOOL)isFinalResultDetermined{
    if (self.isCalibrationOver) {
        if ((fabs(self.bpmLatestResult - [self.bpmAverageValues[self.framesCounter - (int)(self.calibrationDuration/2)-self.windowSize-1] doubleValue]) <= FINAL_RESULT_MARGIN*2/3) &&
            (fabs(self.bpmLatestResult - [self.bpmAverageValues[self.framesCounter - self.calibrationDuration-self.windowSize -1] doubleValue]) <= FINAL_RESULT_MARGIN)) {
                return _isFinalResultDetermined = YES;
        }
        else {
            _isFinalResultDetermined = NO;//*
        }
    }
    else {
        _isFinalResultDetermined = NO;//*
    }
    return _isFinalResultDetermined;
}

- (CGFloat)bpmLatestResult
{
    if (self.isCalibrationOver) {
        return [self.bpmAverageValues[self.framesCounter-self.windowSize - 1] doubleValue];
    }
    return 0;
}

- (BOOL)shouldShowLatestResult
{
    if (self.isCalibrationOver && (self.framesCounter > self.calibrationDuration + self.firstPeakPlace + self.windowSize + self.windowSizeForAverageCalculation)) {

        if (fabs([self.bpmAverageValues[self.framesCounter-self.calibrationDuration-self.windowSize - 1] doubleValue] - [self.bpmAverageValues[self.framesCounter-self.calibrationDuration-self.windowSize - 2] doubleValue]) < 0.125) {

            if (fabs([self.bpmAverageValues[self.framesCounter-self.calibrationDuration/2-self.windowSize - 1] doubleValue] - [self.bpmAverageValues[self.framesCounter-self.calibrationDuration/2-self.windowSize - 2] doubleValue]) < 0.1) {
                
                if (fabs([self.bpmAverageValues[self.framesCounter-self.windowSize - 1] doubleValue] - [self.bpmAverageValues[self.framesCounter-self.windowSize - 2] doubleValue]) < 0.075) {
                    _shouldShowLatestResult = YES;
                }
            }
        }
    }
    return _shouldShowLatestResult;
}

//

- (CGFloat)getColorValueFrom:(UIColor *)color
{
    // default value is green (for iphone 5)
    CGFloat green;
    
    if ([color getRed:nil green:&green blue:nil alpha:nil]) {
        return green*255.0f;
    }
    else {
        //error
        NSLog(@"color error");
        return 0;
    }
}

//

- (void)getLatestPoints:(NSUInteger)numOfPoints andSetIntoDoubleArray:(double *)arrayOfDoubles{
    NSRange range;
    range.length = numOfPoints;
    range.location = [self.points count] - range.length;
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
    
    NSUInteger index = [indexSet firstIndex];
    for (int i=0; index != NSNotFound ; i++ , index = [indexSet indexGreaterThanIndex: index]) {
        arrayOfDoubles[i] = [self.points[index] doubleValue];
    }
}

- (BOOL)isPeak:(double *)graph :(int)window
{
    // graph size should be window*2+1
    // window must be positive
    
    if (self.framesCounter-window-1 - self.lastPeakPlace < window) {
        return NO;
    }
    
    double middlePoint = graph[window];
    for (int i=0; i < window; i++) {
        if (middlePoint <= graph[i]) { // the middle point should be larger from all points detected before it
            return NO;
        }
    }
    for (int i=window+1; i <= 2*window; i++) {
        if (middlePoint < graph[i]) {// the middle point should be larger or equal to all points detected after it
            return NO;
        }
    }
    
    //check if we found extra peak
    if (self.isCalibrationOver && !self.isMissedTheLastPeak) {
        double expectedFramesSinceLastPeak = 1/(self.bpmLatestResult/(60*self.frameRate));
        double marginFactor = 0.5;
        if (self.framesCounter - self.windowSize - 1 - self.lastPeakPlace < (1-marginFactor)*expectedFramesSinceLastPeak) {
            NSLog([NSString stringWithFormat:@"found extra peak: %d" , self.framesCounter-self.windowSize-1]);
            return NO;
        }
    }
    
    return YES;
}

- (double)mean:(double *)points withSize:(int)n
{
    double sum = 0;
    for (int i=0 ; i<n ; i++) {
        sum += points[i];
    }
    return sum/n;
}

- (void)Substract:(double)num fromArray:(double *)points withSize:(int)n
{
    for (int i=0 ; i<n ; i++) {
        points[i] -= num;
        points[i] *= -1;// should be commented when the filter order value is 5 or higher
    }
}

- (BOOL)isMissedPeak
{
    double expectedFramesSinceLastPeak = 1/(self.bpmLatestResult/(60*self.frameRate));
    double marginFactor = 0.5;
    if (self.framesCounter - self.windowSize - 1 - self.lastPeakPlace > (1+marginFactor)*expectedFramesSinceLastPeak) {
        NSLog(@"missed peak");
        return YES;
    }
    return NO;
}

//

#define DEFAULT_BPM_VALUE 72
#define MIN_BPM_VALUE 40
#define MAX_BPM_VALUE 180

- (void)newFrameDetectedWithAverageColor:(UIColor *)color
{
    //
    if (self.isFinalResultDetermined) {
        // do nothing
        //return;
    }
    
    // initial
    self.framesCounter++;
    [self.points addObject:@([self getColorValueFrom:color])];
    [self.isPeak addObject:@(NO)];
    [self.bpmValues addObject:@(DEFAULT_BPM_VALUE)];
    [self.bpmAverageValues addObject:@(DEFAULT_BPM_VALUE)];
    
    // renaming local parameters
    int i = self.framesCounter;
    int w = self.windowSize;
    int calib = self.calibrationDuration;
    
    //
    if (i <= self.filterWindowSize) {
        return;// continue, nothing to be done yet
    }
    
    //
    int dynamicwindowSize = self.filterWindowSize+1;
    double x[dynamicwindowSize] , y[dynamicwindowSize];
    [self getLatestPoints:dynamicwindowSize andSetIntoDoubleArray:x];
    [self Substract:[self mean:x withSize:dynamicwindowSize] fromArray:x withSize:dynamicwindowSize];
    filter(2*FILTER_ORDER, self.buttterworthValues[1], self.buttterworthValues[0], dynamicwindowSize, x, y);
    //filter(2*FILTER_ORDER, [self buttterworthDenC], [self buttterworthNumC], dynamicwindowSize, x, y);
    double *z = y+dynamicwindowSize-2*w-1;
    
    //
    if (!self.firstPeakPlace) {
        
        self.isPeak[i-w-1] = @([self isPeak:z :w]);
        
        self.numOfPeaks += [self.isPeak[i-w-1] boolValue];
        
        if ([self.isPeak[i-w-1] boolValue]) {
            self.firstPeakPlace = i-w-1;
            self.bpmValues[i-w-1] = @(0);
            self.bpmAverageValues[i-w-1] = @(0);
        }
        
        return;// continue
    }
    
    if (i < calib + self.firstPeakPlace + w + 1) {
        
        self.isPeak[i-w-1] = @([self isPeak:z :w]);
        
        self.numOfPeaks += [self.isPeak[i-w-1] integerValue];
        
        NSUInteger frames = i - self.firstPeakPlace-1;
        if (frames > calib) {
            frames = calib;
        }
        
        self.bpmValues[i-w-1] = @(MIN(MAX((self.numOfPeaks/(frames/self.frameRate))*60 , MIN_BPM_VALUE), MAX_BPM_VALUE));
        double k = i-(self.firstPeakPlace+w+1) - 1 + 4.5;// + 4.5 to improve calibration result for low bpm
        double sensitiveFactor = 1.5;// adjust this bigger the make the algorithm more sensitive to changes
        self.bpmAverageValues[i-w-1] = @([self.bpmAverageValues[i-w-2] doubleValue] * k/(k+sensitiveFactor) + [self.bpmValues[i-w-1] doubleValue] * sensitiveFactor/(k+sensitiveFactor));
    }
    
    else {
        //calibration is over
        
        if (i < calib + (self.firstPeakPlace + w + 1) + 2.5*30){
            self.isPeak[i-w-1] = @([self isPeak:z :w]);
        } else {
            if ([self isPeak:z :w]) {
                self.isPeak[i-w-1] = @(1);
                self.isMissedTheLastPeak = NO;
            }
            else {
                if ([self isMissedPeak]) {
                    self.isPeak[i-w-1] = @(1);
                    self.isMissedTheLastPeak = YES;
                }
                else {
                    self.isPeak[i-w-1] = @(0);
                }
            }
        }
        
        self.numOfPeaks += [self.isPeak[i-w-1] integerValue] - [self.isPeak[i-w-1-calib] integerValue];
        
        NSUInteger frames = calib;
        
        self.bpmValues[i-w-1] = @(MIN(MAX((self.numOfPeaks/(frames/self.frameRate))*60 , MIN_BPM_VALUE), MAX_BPM_VALUE));
        
        double tempSum = 0;
        for (int j = 1; j <= self.windowSizeForAverageCalculation; j++) {
            tempSum += [self.bpmValues[i-w-1-self.windowSizeForAverageCalculation+j] doubleValue];
        }
        double average_bpm = tempSum/self.windowSizeForAverageCalculation;
        
        int calibrationWeight = 2.5;// simulate the weight of the calibration calculated results.
        // if it's 0, the calibration is worthless
        double sensitiveFactor = 2.5;// adjust this bigger the make the algorithm more sensitive to changes
        //CGFloat lastResultFactor = fabs(average_bpm/[self.bpmAverageValues[i-w-2] doubleValue] -1) < 0.1 ? 1 : fabs(1 - fabs(average_bpm-[self.bpmAverageValues[i-w-2] doubleValue])/[self.bpmAverageValues[i-w-2] doubleValue]);
        int k = i - (calib + self.firstPeakPlace + w + 1) + calibrationWeight;
        //self.bpmAverageValues[i-w-1] = @([self.bpmAverageValues[i-w-2] doubleValue] * (1-lastResultFactor*sensitiveFactor/(k+sensitiveFactor)) + average_bpm * lastResultFactor * sensitiveFactor/(k+sensitiveFactor));
        self.bpmAverageValues[i-w-1] = @([self.bpmAverageValues[i-w-2] doubleValue] * k/(k+sensitiveFactor) + average_bpm * sensitiveFactor/(k+sensitiveFactor));
        
    }
    
    self.isPeakInLastFrame = [self.isPeak[i-w-1] boolValue];
    
    if ([self.isPeak[i-w-1] boolValue]) {
        self.lastPeakPlace = i-w-1;
        printf("%d\n" , i-w-1);
    }

}

- (NSArray *)getPlotData {
    //filtered version
    if ([self.points count] < self.filterWindowSize+1) {
        return nil;// continue, nothing to be done yet
    }
    int dynamicwindowSize = [self.points count] < 150 ? [self.points count] : 150;
    //dynamicwindowSize = self.filterWindowSize+1;
    double x[dynamicwindowSize] , y[dynamicwindowSize];
    [self getLatestPoints:dynamicwindowSize andSetIntoDoubleArray:x];
    [self Substract:[self mean:x withSize:dynamicwindowSize] fromArray:x withSize:dynamicwindowSize];
    filter(2*FILTER_ORDER, self.buttterworthValues[1], self.buttterworthValues[0], dynamicwindowSize, x, y);
    return [self getArrayFromArray:y withSize:dynamicwindowSize];
    //original version
    NSRange range;
    range.length = [self.points count] < 150 ? [self.points count] : 150;
    range.location = [self.points count] - range.length;
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
    NSMutableArray *temp = [NSMutableArray arrayWithArray:[self.points objectsAtIndexes:indexSet]];
    [self Substract:[self mean:temp] fromArray:temp];
    return temp;
}

- (double)mean:(NSArray *)points
{
    double sum = 0;
    for (int i=0 ; i<[points count] ; i++) {
        sum += [points[i] doubleValue];
    }
    return sum/[points count];
}

- (void)Substract:(double)num fromArray:(NSMutableArray *)points
{
    for (int i=0 ; i<[points count] ; i++) {
        points[i] = @(-([points[i] doubleValue]-num));
    }
}

- (NSArray *)getArrayFromArray:(double *)x withSize:(int)num
{
    NSMutableArray *points = [[NSMutableArray alloc] init];
    int offset = 45;
    for (int i=0 ; i<num-offset ; i++) {
        [points addObject:@(x[i+offset])];
    }
    return points;
}

@end
