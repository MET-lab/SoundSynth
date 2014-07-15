//
//  AudioOutput.h
//  AudioControllerTest
//
//  Created by Jeff Gregorio on 7/9/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

/* ===== Scope/Bus use in I/O units (Adamson, Chris. "Learning Core Audio" Table 8.1) ===== */
/* ---------------------------------------------------------------------------------------- */
/* Scope        Bus         Semantics                                           Access      */
/* ---------------------------------------------------------------------------------------- */
/* Input        1 (in)      Input from hardware to I/O unit                     Read-only   */
/* Output       1 (in)      Output from I/O unit to program or other units      Read/write  */
/* Input        0 (out)     Input to I/O unit from program or other units       Read/write  */
/* Output       0 (out)     Output from I/O unit to hardware                    Read-only   */
/* ---------------------------------------------------------------------------------------- */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import <pthread.h>

@protocol AudioOutputDelegate;

#pragma mark - AudioOutput
@interface AudioOutput : NSObject {
    bool _wasRunning;
}

/* These are only of interest internally, but must be accessible publicly by the audio callback, which must be a non-member C method because Core Audio sucks */
@property (readonly) AudioUnit outputUnit;
@property (readonly) AudioStreamBasicDescription asbd;

@property id <AudioOutputDelegate> delegate;            /* Delegate must implement the
                                                         renderOutputBuffer: method to
                                                         send data to the DAC */

@property (readonly) AVAudioSession *audioSession;      /* Use to query sample rate, buffer
                                                         length (seconds), number of
                                                         input/output channels, etc. */

@property (readonly) double sampleRate;         // Audio sampling rate
@property (readonly) int bufferSizeFrames;      // Buffer length in samples
@property (readonly) bool isRunning;            // Input currently enabled
@property Float32 outputGain;                   // Scale factor for all output samples (settalbe)

/* Constructor */
- (id)initWithDelegate:(id)delegate;

/* Start/Stop audio output */
- (void)setOutputEnabled:(bool)enabled;

@end

#pragma mark - AudioOutputDelegate
@protocol AudioOutputDelegate <NSObject>
- (void)renderOutputBufferMono:(Float32 *)buffer outNumberFrames:(int)nFrames;
- (void)renderOutputBufferStereo:(Float32 *)lBuffer right:(Float32 *)rBuffer outNumberFrames:(int)nFrames;
@end