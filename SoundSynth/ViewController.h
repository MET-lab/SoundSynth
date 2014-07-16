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

#define kPlotUpdateRate 0.002
#define kFFTSize 1024
#define kRecordingBufferLengthSeconds 5.0
#define kMaxPlotMax 2.0
#define kNumHarmonics 10
#define kWavetablePadLength 10

@interface ViewController : UIViewController <METScopeViewDelegate, FunctionDrawViewDelegate, AudioOutputDelegate> {
    
    /* Audio/Synthesis */
    AudioOutput *audioOutput;
    AdditiveSynth *aSynth;
    WavetableSynth *wSynth;
    IBOutlet UISwitch *outputEnableSwitch;
    
    /* Recording */
    int recordingBufferLength;
    float *recordingBuffer;
    pthread_mutex_t recordingBufferMutex;
    int phaseZeroOffset;
    
    /* Time-domain Scope */
    IBOutlet METScopeView *tdScopeView;
    NSTimer *tdUpdateClock;
    bool tdHold;
    
    /* Waveform/Envelope Drawing */
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
    
    /* Frequency-domain Scope */
    IBOutlet METScopeView *fdScopeView;
    NSTimer *fdUpdateClock;
    bool fdHold;
    
    /* Harmonic Presets */
    UISegmentedControl *presetSelector;
    NSInteger previouslySelectedPreset;
    float previousHarmonics[kNumHarmonics];
    
    /* Synth Parameters */
    IBOutlet UISlider *fundamentalSlider;
    IBOutlet UILabel *fundamentalLabel;
    NSMutableDictionary *harmonicSliders;
    NSMutableDictionary *indicatorDots;
    
    /* Parameter Information Views */
    UIView *harmonicInfoView;
    UILabel *freqValueLabel;
    UILabel *ampValueLabel;
    UIView *noiseInfoView;
    UILabel *noiseAmpValueLabel;
}

@end
