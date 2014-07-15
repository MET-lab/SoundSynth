//
//  AdditiveSynth.m
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/12/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "AdditiveSynth.h"

@implementation AdditiveSynth

@synthesize f_0;
@synthesize enabled;

- (id)initWithSampleRate:(double)fs numHarmonics:(int)n {
    
    self = [super init];
    if (self) {
        f_s = fs;
        n_h = n;
        f_0 = 440.0f;
        target_f_0 = f_0;
        f_0_step = 0.0f;
        a_h = (float *)calloc(n_h, sizeof(float));
        a_n = 0.0f;
        theta = 0.0f;
        thetaInc = 2.0f * M_PI * f_0 / f_s;
        envLength = 0;
        envIdx = 0;
    }
    return self;
}

- (void)setNumHarmonics:(int)n {
    
    n_h = n;
    
    if (a_h)
        free(a_h);
    
    a_h = (float *)calloc(n_h, sizeof(float));
}

- (void)setFundamental:(float)f0 {
    
    target_f_0 = f0;
    f_0_step = (target_f_0 - f_0) / (0.1 * f_s);
}

- (void)setAmplitude:(float)amp forHarmonic:(int)n {
    
    if (n >= n_h) {
        NSLog(@"%s: Invalid harmonic number %d. Synth has %d harmonics", __PRETTY_FUNCTION__, n, n_h);
        return;
    }
    
    a_h[n] = amp;
}

- (void)setNoiseAmplitude:(float)amp {
    a_n = amp;
}

- (void)setAmplitudeEnvelope:(float *)amp length:(int)len {
    
    if (env)
        free(env);
    
    envLength = len;
    env = (float *)malloc(envLength * sizeof(float));
    memcpy(env, amp, envLength * sizeof(float));
    
    envIdx = 0;
}

/* Render a buffer of audio via additive synthesis. Return the index in the buffer of the first phase zero for waveform stabilization when plotting */
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames {
    
    int phaseZeroIdx = -1;
    
    for (int i = 0; i < nFrames; i++) {
        
        /* Ramp the fundamental if needed */
        if ((f_0_step > 0 && f_0 < target_f_0) || (f_0_step < 0 && f_0 > target_f_0)) {
            f_0 += f_0_step;
            thetaInc = 2.0f * M_PI * f_0 / f_s;
        }
        
        /* Noise */
        buffer[i] = a_n * [self generateAWGN];
        
        /* Harmonics */
        for (int n = 0; n < n_h; n++) {
            if (f_0 * (n+1) < 20000.0)
                buffer[i] += (a_h[n] * sin((n+1) * theta));
        }
        
        if (env) {
            /* Envelope */
            buffer[i] *= env[envIdx];
            
            envIdx++;
            if (envIdx >= (envLength-1))
                envIdx = 0;
        }
        
        /* Update phase */
        theta += thetaInc;
        if (theta >= 2 * M_PI) {
            theta -= 2 * M_PI;
            if (phaseZeroIdx < 0) {
                phaseZeroIdx = i;
            }
        }
    }
    
    return phaseZeroIdx;
}

/* Generates additive white Gaussian Noise samples from the standard normal distribution (borrowed from http://www.embeddedrelated.com/showcode/311.php) */
- (float)generateAWGN {
    
    float temp1;
    float temp2 = 0.0;
    float result;
    int p;
    
    p = 1;
    
    while( p > 0 ) {
        
        temp2 = (rand() / ((float)RAND_MAX));   /*  rand() function generates an
                                                    integer between 0 and  RAND_MAX,
                                                    which is defined in stdlib.h.
                                                 */
        // temp2 is >= (RAND_MAX / 2)
        if (temp2 == 0)
            p = 1;

        // temp2 is < (RAND_MAX / 2)
        else
            p = -1;
    }
    
    temp1 = cos((2.0 * (float)M_PI ) * rand() / ((float)RAND_MAX));
    result = sqrt(-2.0 * log(temp2)) * temp1;
    
    return result;
}

@end















