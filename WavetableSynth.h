//
//  WavetableSynth.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/14/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NVDSP/Filters/NVLowpassFilter.h"


@interface WavetableSynth : NSObject {
    
    int waveTableLength;
    int waveTableIdx;
    float *waveTable;
    float *waveTablePhases;
    
    NVLowpassFilter *lpf;       // Anti-aliaising filter
    
    double f_s;                 // Sampling rate
    
    float f_0;                  // Current fundamental freq
    float f_0_max;              // Maximum fundamental freq
    float target_f_0;           // Target fundamental freq
    float f_0_step;             // Ramp value (per sample) to add to fundamental
    
    float a_n;                  // Noise amplitude
    float theta;                // Phase
    float thetaInc;             // Phase increment
    
    int envLength;              // Length in samples of the amplitude envelope
    int envIdx;                 // Current index in the envelope
    float *env;                 // Amplitude envelope
}

@property (readonly) float f_0;
@property float f_0_max;
@property bool enabled;

- (id)initWithSampleRate:(double)fs maxFreq:(float)f0Max;
- (void)setWaveTable:(float *)table length:(int)len;
- (void)setFundamental:(float)f0;
- (void)setNoiseAmplitude:(float)amp;
- (void)setAmplitudeEnvelope:(float *)amp length:(int)len;
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames;

@end
