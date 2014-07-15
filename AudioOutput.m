//
//  AudioOutput.m
//  AudioControllerTest
//
//  Created by Jeff Gregorio on 7/9/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "AudioOutput.h"

@implementation AudioOutput

static OSStatus outputRenderCallback(void *inRefCon, // Reference to the calling object
                                     AudioUnitRenderActionFlags   *ioActionFlags,
                                     const AudioTimeStamp 		  *inTimeStamp,
                                     UInt32                       inBusNumber,
                                     UInt32                       inNumberFrames,
                                     AudioBufferList              *ioData) {
    
    OSStatus status = noErr;
    
    /* Cast void to AudioController input object and get stream information */
	AudioOutput *audioOutput = (__bridge AudioOutput *)inRefCon;
    
    /* Call AudioOutput's delegate method to render audio */
    if (audioOutput.delegate) {
        
        /* Mono */
        if (audioOutput.audioSession.outputNumberOfChannels == 1)
            [audioOutput.delegate renderOutputBufferMono:(Float32 *)ioData->mBuffers[0].mData outNumberFrames:inNumberFrames];
        
        /* Stereo */
        else if (audioOutput.audioSession.outputNumberOfChannels == 2)
            [audioOutput.delegate renderOutputBufferStereo:(Float32 *)ioData->mBuffers[0].mData right:(Float32 *)ioData->mBuffers[1].mData outNumberFrames:inNumberFrames];
    }
    
    return status;
}

@synthesize outputGain = _outputGain;

#pragma mark - AVAudioSessionDelegate Methods
- (void)beginInterruption {
    if (_isRunning) {
        _wasRunning = true;
        [self setOutputEnabled:false];
    }
}

- (void)endInterruption {
    if (_wasRunning)
        [self setOutputEnabled:true];
}

#pragma mark - Constructor
- (id)initWithDelegate:(id)delegate {
    
    self = [super init];
    if (self) {
        _delegate = delegate;
        _isRunning = false;
        _outputGain = 1.0;
        [self setUpAudioSession];
        [self setUpOutputUnit];
    }
    return self;
}

#pragma mark - Setup
/* Set up fancy new AVAudioSession API that replaces the old Core Audio AudioSession API */
- (void)setUpAudioSession {
    
    bool success = true;
    NSError *error = nil;
    
    _audioSession = [AVAudioSession sharedInstance];
    
    /* Set the category and mode of the audio session */
    success = [_audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    success = [_audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    
    /* Set sample rate, buffer duration, and number of IO channels */
    success = [_audioSession setPreferredSampleRate:44100 error:&error];
    success = [_audioSession setPreferredIOBufferDuration:0.023 error:&error];
    success = [_audioSession setPreferredOutputNumberOfChannels:2 error:&error];
    success = [_audioSession setPreferredInputNumberOfChannels:1 error:&error];
    
    /* Activate the audio session */
    [_audioSession setActive:true error:&error];
    
    /* Get the sample rate */
    _sampleRate = _audioSession.sampleRate;
    
    /* Size of a single audio buffer in samples */
    _bufferSizeFrames = (int)roundf(_audioSession.sampleRate * _audioSession.IOBufferDuration);
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"inputAvailable = %s", _audioSession.inputAvailable ? "true" : "false");
    NSLog(@"maximumInputNumberOfChannels = %d", _audioSession.maximumInputNumberOfChannels);
    NSLog(@"maximumOutputNumberOfChannels = %d", _audioSession.maximumOutputNumberOfChannels);
    NSLog(@"audioSession.outputNumberOfChannels = %d", _audioSession.outputNumberOfChannels);
    NSLog(@"audioSession.inputNumberOfChannels  = %d", _audioSession.inputNumberOfChannels);
    NSLog(@"audioSession.sampleRate             = %f", _audioSession.sampleRate);
    NSLog(@"audioSession.IOBufferDuration       = %f", _audioSession.IOBufferDuration);
    NSLog(@"bufferSizeFrames                    = %d", (unsigned int)_bufferSizeFrames);
}

- (void)setUpOutputUnit {
    
    OSStatus status;
    AudioUnitScope outputBus = 0;
    UInt32 enableFlag = 1;
    
    /* --------------------------------- */
    /* == Instantiate a RemoteIO unit == */
    /* --------------------------------- */
    
    /* Create description of the Remote IO unit */
    AudioComponentDescription outputcd  = {0};
    outputcd.componentType              = kAudioUnitType_Output;
    outputcd.componentSubType           = kAudioUnitSubType_RemoteIO;
    outputcd.componentManufacturer      = kAudioUnitManufacturer_Apple;
    outputcd.componentFlags             = 0;
    outputcd.componentFlagsMask         = 0;
    
    /* Find the audio component from the description */
    AudioComponent comp = AudioComponentFindNext(NULL, &outputcd);
    if (comp == NULL) {
        NSLog(@"%s: Error getting RemoteIO unit", __PRETTY_FUNCTION__);
        return;
    }
    
    /* Create an instance of the remote IO unit from the audio componenet */
    status = AudioComponentInstanceNew(comp, &_outputUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AudioComponentInstanceNew[_inputUnit] failed" withStatus:status];
    }
    
    /* ------------------- */
    /* == Enable output == */
    /* ------------------- */
    
    status = AudioUnitSetProperty(_outputUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputBus,
                                  &enableFlag,
                                  sizeof(enableFlag));
    if (status != noErr) {
        [self printErrorMessage:@"Enable/disable input failed" withStatus:status];
    }
    
    /* ----------------------- */
    /* == Get Stream Format == */
    /* ----------------------- */
    
    /* Get the ASBD for the remote IO unit */
    size_t asbdSize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription asbd = {0};
    AudioUnitGetProperty(_outputUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         outputBus,
                         &asbd,
                         &asbdSize);
    NSLog(@"ASBD for input scope, output bus:");
    
    /* ------------------------ */
    /* == Set input callback == */
    /* ------------------------ */
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = outputRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void*) self;
    
    status = AudioUnitSetProperty(_outputUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  outputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    if (status != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty[kAudioUnitProperty_SetRenderCallback] failed" withStatus:status];
    }
    
    /* ---------------- */
    /* == Initialize == */
    /* ---------------- */
    
    status = AudioUnitInitialize(_outputUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AudioUnitInitialize[_inputUnit] failed" withStatus:status];
    }
}

#pragma mark - Interface Methods
/* Start/Stop audio input */
- (void)setOutputEnabled:(bool)enabled {
    
    OSStatus status;
    
    if (enabled) {
        status = AudioOutputUnitStart(_outputUnit);
        if (status != noErr) {
            [self printErrorMessage:@"AudioOutputUnitStart[_outputUnit] failed" withStatus:status];
        }
        else _isRunning = true;
    }
    else {
        status = AudioOutputUnitStop(_outputUnit);
        if (status != noErr) {
            [self printErrorMessage:@"AudioOutputUnitStop[_outputUnit] failed" withStatus:status];
        }
        else _isRunning = false;
    }
}

#pragma mark Utility Methods
- (void)printErrorMessage:(NSString *)errorString withStatus:(OSStatus)result {
    
    char errorDetail[20];
    
    /* Check if the error is a 4-character code */
    *(UInt32 *)(errorDetail + 1) = CFSwapInt32HostToBig(result);
    if (isprint(errorDetail[1]) && isprint(errorDetail[2]) && isprint(errorDetail[3]) && isprint(errorDetail[4])) {
        
        errorDetail[0] = errorDetail[5] = '\'';
        errorDetail[6] = '\0';
    }
    else /* Format is an integer */
        sprintf(errorDetail, "%d", (int)result);
    
    fprintf(stderr, "Error: %s (%s)\n", [errorString cStringUsingEncoding:NSASCIIStringEncoding], errorDetail);
}

- (void)printASBD:(AudioStreamBasicDescription)asbd {
    
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    (unsigned int)asbd.mBitsPerChannel);
}

@end
