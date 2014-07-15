//
//  FunctionDrawView.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/13/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FunctionDrawViewDelegate;

@interface FunctionDrawView : UIView {
    
    int _length;                    // Length of drawing buffer
    float *_pixelVals;              // Drawing buffer
    int _previousSetIdx;
    CGPoint _previousTouchLoc;
    
}

@property (readonly) int length;
@property id <FunctionDrawViewDelegate> delegate;

- (void)getDrawingWithLength:(int)length pixelVals:(float *)outPixels;
- (void)setDrawingWithLength:(int)length pixelVals:(float *)inPixels;
- (void)resetDrawing;

@end

#pragma mark - FunctionDrawViewDelegate
@protocol FunctionDrawViewDelegate <NSObject>
@optional
- (void)drawingEnded;
- (void)drawingBegan;
- (void)drawingChanged;
@end