//
//  AdditiveSynth.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/12/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AdditiveSynth : NSObject {
    
    double f_s;                 // Sampling rate
    int n_h;                    // Number of harmonics
    
    float f_0;                  // Current fundamental freq
    float target_f_0;           // Target fundamental freq
    float f_0_step;             // Ramp value (per sample) to add to fundamental
    
    float *a_h;                 // Harmonic amplitudes
    float a_n;                  // Noise amplitude
    float theta;                // Phase
    float thetaInc;             // Phase increment
    
    int envLength;              // Length in samples of the amplitude envelope
    int envIdx;                 // Current index in the envelope
    float *env;                 // Amplitude envelope
}

@property (readonly) float f_0;
@property bool enabled;

- (id)initWithSampleRate:(double)fs numHarmonics:(int)n;
- (void)setNumHarmonics:(int)n;
- (void)setFundamental:(float)f0;
- (void)setAmplitude:(float)amp forHarmonic:(int)n;
- (void)setNoiseAmplitude:(float)amp;
- (void)setAmplitudeEnvelope:(float *)amp length:(int)len;
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames;

@end
