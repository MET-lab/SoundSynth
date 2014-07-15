//
//  ViewController.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "METScopeView.h"
#import "AudioOutput.h"
#import "AdditiveSynth.h"
#import "WavetableSynth.h"
#import "IndicatorDot.h"
#import "FunctionDrawView.h"

#define kFFTSize 1024
#define kRecordingBufferLengthSeconds 5.0
#define kMaxPlotMax 2.0
#define kNumHarmonics 10
#define kWavetablePadLength 4

@interface ViewController : UIViewController
    <METScopeViewDelegate, FunctionDrawViewDelegate, AudioOutputDelegate> {
    
    AudioOutput *audioOutput;
    AdditiveSynth *aSynth;
    WavetableSynth *wSynth;
    
    IBOutlet METScopeView *tdScopeView;
    NSTimer *tdUpdateClock;
    
    UISegmentedControl *drawSelector;
    UIButton *finishDrawingButton;
    FunctionDrawView *drawView;
    int envLength;
    float *drawnEnvelope;
    int wavetableLength;
    float *drawnWaveform;
    bool drawingEnvelope;
    bool drawingWaveform;
    float oldXMin, oldXMax;
    float oldXGridScale;
    
    UISegmentedControl *presetSelector;
    NSInteger previouslySelectedPreset;
    float previousHarmonics[kNumHarmonics];
    
    IBOutlet METScopeView *fdScopeView;
    NSTimer *fdUpdateClock;
    
    IBOutlet UISlider *fundamentalSlider;
    IBOutlet UILabel *fundamentalLabel;
    NSMutableDictionary *harmonicSliders;
    NSMutableDictionary *indicatorDots;
    UIView *infoView;
    UILabel *freqParamLabel;
    UILabel *freqValueLabel;
    UILabel *ampParamLabel;
    UILabel *ampValueLabel;
    
    int recordingBufferLength;
    float *recordingBuffer;
    pthread_mutex_t recordingBufferMutex;
    int phaseZeroOffset;
    
    IBOutlet UISwitch *outputEnableSwitch;
}

@end
