//
//  ViewController.m
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize drawView;
@synthesize finishDrawingButton;
@synthesize drawSelector;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    /* ----------------- */
    /* == Audio Setup == */
    /* ----------------- */
    
    audioOutput = [[AudioOutput alloc] initWithDelegate:self];
    [self allocateRecordingBufferWithLength:kRecordingBufferLengthSeconds*audioOutput.sampleRate];
    phaseZeroOffset = 0;
    
    /* -------------------- */
    /* == TD Scope Setup == */
    /* -------------------- */
    
    [tdScopeView setPlotResolution:tdScopeView.frame.size.width];
    [tdScopeView setHardXLim:-0.00001 max:kMaxPlotMax];
    [tdScopeView setVisibleXLim:tdScopeView.minPlotMin.x max:audioOutput.bufferSizeFrames/audioOutput.sampleRate];
    [tdScopeView setMinPlotRange:CGPointMake(1.0/fundamentalSlider.maximumValue, 0.1)];
    [tdScopeView setMaxPlotRange:CGPointMake(INFINITY, INFINITY)];
    [tdScopeView setPlotUnitsPerXTick:0.005];
    [tdScopeView setDelegate:self];
    [tdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideAbove];
    [tdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    
    [tdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    [self setTDScopeUpdateRate:0.002];
    
    CGRect frame = tdScopeView.frame;
    frame.size.width -= 20;
    FunctionDrawView *dv = [[FunctionDrawView alloc] initWithFrame:tdScopeView.frame];
    [self setDrawView:dv];
    drawingEnvelope = drawingWaveform = false;
    
    /* -------------------- */
    /* == FD Scope Setup == */
    /* -------------------- */
    
    [fdScopeView setPlotResolution:fdScopeView.frame.size.width];
    [fdScopeView setUpFFTWithSize:kFFTSize];      // Set up FFT before setting FD mode
    [fdScopeView setDisplayMode:kMETScopeViewFrequencyDomainMode];
    [fdScopeView setHardXLim:0.0 max:20000];       // Set bounds after FD mode
    [fdScopeView setVisibleXLim:0.0 max:9300];
    [fdScopeView setPlotUnitsPerXTick:2000];
    [fdScopeView setXGridAutoScale:true];
    [fdScopeView setYGridAutoScale:true];
    [fdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideBelow];
    [fdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    [fdScopeView setAxisScale:kMETScopeViewAxesSemilogY];
    [fdScopeView setHardYLim:-80 max:0];
    [fdScopeView setPlotUnitsPerYTick:20];
    [fdScopeView setAxesOn:true];
    
    [fdScopeView setDelegate:self];
    [fdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    [self setFDScopeUpdateRate:0.002];
    
    /* --------------------------- */
    /* == Harmonic Slider Array == */
    /* --------------------------- */
    
    CGPoint sliderSize = CGPointMake(150, 10);  // Height, width (after rotation)
    float sliderYPos = 850;                     // Top edge of slider array
    float sliderXSpace = 34;                    // Leading space on left and right of view
    
    sliderYPos += sliderSize.x/2;
    float sliderXMin = sliderXSpace;
    float sliderXMax = self.view.bounds.size.width - sliderXSpace;
    float sliderXSpacing = (sliderXMax - sliderXMin) / kNumHarmonics;
    CGPoint sliderOrigin = CGPointMake(sliderXMin, sliderYPos);
    
    harmonicSliders = [[NSMutableDictionary alloc] initWithCapacity:kNumHarmonics+1];
    
    for (int i = 0; i < kNumHarmonics+1; i++) {
        
        CGRect sliderFrame = CGRectMake(sliderOrigin.x, sliderOrigin.y, sliderSize.x, sliderSize.y);
        
        UISlider *slider = [[UISlider alloc] initWithFrame:sliderFrame];
        [slider setCenter:sliderFrame.origin];
        [slider addTarget:self action:@selector(beginUpdateHarmonic:) forControlEvents:UIControlEventTouchDown];
        [slider addTarget:self action:@selector(updateHarmonic:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(endUpdateHarmonic:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [slider setBackgroundColor:[UIColor clearColor]];
        [slider setMinimumValue:-80.0f];
        [slider setMaximumValue:0.0f];
        [slider setContinuous:true];
        [slider setValue:-80.0f];
        [slider setTag:i+1];
        slider.transform = CGAffineTransformRotate(slider.transform, 270.0 / 180 * M_PI);
        
        /* Add slider to the subview and the dictionary */
        [self.view addSubview:slider];
        [harmonicSliders setObject:slider forKey:[NSString stringWithFormat:@"%d", i+1]];
        
        sliderOrigin.x += sliderXSpacing;
    }
    
    /* Set first harmonic amplitude */
    UISlider *h1 = [harmonicSliders valueForKey:[NSString stringWithFormat:@"%d", 1]];
    [h1 setValue:-6];
    
    /* ------------------------- */
    /* == Indicator Dot Array == */
    /* ------------------------- */
    
    CGSize dotSize = CGSizeMake(20, 20);
    indicatorDots = [[NSMutableDictionary alloc] initWithCapacity:kNumHarmonics];
    
    for (int i = 0; i < kNumHarmonics; i++) {
        
        /* Get the associated slider */
        UISlider *slider = [harmonicSliders valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        
        /* Its frequency and amplitude */
        float freq = fundamentalSlider.value * [slider tag];
        float amp = powf(10.0f, [slider value] / 20.0f);
        
        IndicatorDot *dot = [[IndicatorDot alloc] initWithParent:fdScopeView size:dotSize pos:CGPointMake(freq, amp) color:[UIColor blueColor]];
        
        [fdScopeView addSubview:dot];
        [indicatorDots setObject:dot forKey:[NSString stringWithFormat:@"%d", i+1]];
    }
    
    /* ----------------- */
    /* == Synth Setup == */
    /* ----------------- */

    /* Additive synth */
    aSynth = [[AdditiveSynth alloc] initWithSampleRate:audioOutput.sampleRate numHarmonics:kNumHarmonics];
    [aSynth setFundamental:fundamentalSlider.value];
    [aSynth setEnabled:true];
    for (int i = 0; i < kNumHarmonics; i++) {
        UISlider *slider = [harmonicSliders valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        [aSynth setAmplitude:powf(10, [slider value]/20.0) forHarmonic:i];
    }
    
    /* Wavetable synth for drawn waveforms */
    wSynth = [[WavetableSynth alloc] initWithSampleRate:audioOutput.sampleRate maxFreq:fundamentalSlider.maximumValue];
    [wSynth setFundamental:fundamentalSlider.value];
    [wSynth setEnabled:false];
    
    /* Fundamental frequency label */
    [fundamentalLabel setText:[NSString stringWithFormat:@"%5.1f", fundamentalSlider.value]];
    
    /* ---------------------- */
    /* == Drawing selector == */
    /* ---------------------- */
    
    NSArray *options = @[@"Draw Waveform", @"Draw Envelope"];
    UISegmentedControl *ds = [[UISegmentedControl alloc] initWithItems:options];
    [ds addTarget:self action:@selector(beginDrawing:) forControlEvents:UIControlEventValueChanged];
    frame = ds.frame;
    frame.origin.x += tdScopeView.frame.size.width - frame.size.width;
    [ds setFrame:frame];
    [self setDrawSelector:ds];
    [tdScopeView addSubview:drawSelector];
    
    frame.size.width = 100;
    frame.origin.x = tdScopeView.frame.size.width - frame.size.width - 6;
    frame.origin.y += 6;
    UIButton *fdb = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [[fdb layer] setBorderWidth:2.0f];
    [[fdb layer] setBorderColor:[UIColor blueColor].CGColor];
    [fdb setFrame:frame];
    [fdb setTitle:@"Done" forState:UIControlStateNormal];
    [fdb addTarget:self action:@selector(endDrawing) forControlEvents:UIControlEventTouchUpInside];
    [self setFinishDrawingButton:fdb];
    [[self drawView] addSubview:finishDrawingButton];
    
    /* -------------------------------- */
    /* == Harmonic Amplitude Presets == */
    /* -------------------------------- */
    
    NSArray *presets = @[@"Sine", @"Square", @"Saw", @"Manual"];
    presetSelector = [[UISegmentedControl alloc] initWithItems:presets];
    [presetSelector addTarget:self action:@selector(setHarmonicPreset:) forControlEvents:UIControlEventValueChanged];
    frame = presetSelector.frame;
    frame.origin.x += fdScopeView.frame.size.width - frame.size.width;
    [presetSelector setFrame:frame];
    [presetSelector setSelectedSegmentIndex:0];
    previouslySelectedPreset = [presetSelector selectedSegmentIndex];
    [fdScopeView addSubview:presetSelector];
    
    previousHarmonics[0] = -6.0;
    for (int i = 1; i < kNumHarmonics; i++) {
        previousHarmonics[i] = -80.0;
    }
    
    /* ----------------- */
    /* == Start audio == */
    /* ----------------- */
    
    [audioOutput setOutputEnabled:true];
}

- (void)dealloc {
    
    if (drawnEnvelope)
        free(drawnEnvelope);
    if (drawnWaveform)
        free(drawnWaveform);
    if (recordingBuffer)
        free(recordingBuffer);
}

# pragma mark - Scope Updates
- (void)setTDScopeUpdateRate:(float)rate {
    
    if ([tdUpdateClock isValid])
        [tdUpdateClock invalidate];
    
    tdUpdateClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                     target:self
                                                   selector:@selector(updateTDScope)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)setFDScopeUpdateRate:(float)rate {
    
    if ([fdUpdateClock isValid])
        [fdUpdateClock invalidate];
    
    fdUpdateClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                     target:self
                                                   selector:@selector(updateFDScope)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)updateTDScope {
    
    /* Extend the time duration we're retrieving from the recording buffer to compensate for the phaze zero offset. Lower fundamental frequencies have larger offsets due to longer wavelengths. */
    float periodsInView = (tdScopeView.visiblePlotMax.x-tdScopeView.visiblePlotMin.x) * aSynth.f_0;
    float maxScale = 1.1;
    
    if (periodsInView < 2.0)
        maxScale = 3.0;
    else if (periodsInView < 5.0)
        maxScale = 2.0;
    else if (periodsInView < 7.0)
        maxScale = 1.5;
    else if (periodsInView < 10.0)
        maxScale = 1.2;
    
    if ([wSynth enabled])
        maxScale *= 2.0;
    
    int startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0) * audioOutput.sampleRate;
    int endIdx = (tdScopeView.visiblePlotMax.x * maxScale) * audioOutput.sampleRate;
    
    int length = endIdx - startIdx;
    
    /* Update the plots if we're not pinching or panning */
    if (!tdScopeView.currentPan && !tdScopeView.currentPinch) {
        
        /* Get buffer of times for each sample */
        float *plotXVals = (float *)malloc(length * sizeof(float));
        [self linspace:fmax(tdScopeView.visiblePlotMin.x, 0.0)
                   max:tdScopeView.visiblePlotMax.x * maxScale
           numElements:length
                 array:plotXVals];
        
        /* Allocate signal buffers */
        float *plotYVals = (float *)malloc(length * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        [self getBuffer:plotYVals withLength:length offset:phaseZeroOffset];
        
        [tdScopeView setPlotDataAtIndex:0
                             withLength:length
                                  xData:plotXVals
                                  yData:plotYVals];
        free(plotXVals);
        free(plotYVals);
    }
}

- (void)updateFDScope {
    
    int length = audioOutput.bufferSizeFrames;
    
    /* Update the plots if we're not pinching or panning */
    if (!fdScopeView.currentPan && !fdScopeView.currentPinch) {
        
        /* Get buffer of times for each sample */
        float *plotXVals = (float *)malloc(length * sizeof(float));
        [self linspace:fmax(fdScopeView.visiblePlotMin.x, 0.0)
                   max:fdScopeView.visiblePlotMax.x
           numElements:length
                 array:plotXVals];
        
        /* Allocate signal buffers */
        float *plotYVals = (float *)malloc(length * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        [self getBuffer:plotYVals withLength:length];
        
        [fdScopeView setPlotDataAtIndex:0
                             withLength:length
                                  xData:plotXVals
                                  yData:plotYVals];
        free(plotXVals);
        free(plotYVals);
    }
}

#pragma mark - Drawing
- (void)beginDrawing:(UISegmentedControl *)sender {
    
    NSString *selectedItem = [sender titleForSegmentAtIndex:[sender selectedSegmentIndex]];
    drawingWaveform = [selectedItem isEqualToString:@"Draw Waveform"];
    drawingEnvelope = [selectedItem isEqualToString:@"Draw Envelope"];
    
    if (!drawingEnvelope && !drawingWaveform)
        return;
    
    /* Deselect all presets if we're drawing a custom waveform */
    if (drawingWaveform)
        [presetSelector setSelectedSegmentIndex:UISegmentedControlNoSegment];
    
    [drawView resetDrawing];
    
    /* Save the old plot scaling parameters to reset them later */
    oldXMin = tdScopeView.visiblePlotMin.x;
    oldXMax = tdScopeView.visiblePlotMax.x;
    oldXGridScale = tdScopeView.tickUnits.x;
    
    /* Set the bounds on interval [0, xMax], where xMax is the length one period of the current f0 (to draw a waveform) or the length the recording buffer (to draw an amplitude envelope) */
    float newXMin = 0.0;
    float newXMax = drawingWaveform ? (1.0f / fundamentalSlider.value) : kMaxPlotMax;
    [tdScopeView setVisibleXLim:newXMin max:newXMax];
    
    /* Place the FunctionDrawView over the time domain scope */
    [tdScopeView setAlpha:0.5];
    [[self view] addSubview:drawView];
    
    /* Remove the draw buttons from the plot while drawing; */
    [drawSelector removeFromSuperview];
    
    /* Disable the output enable switch and fundamental slider while drawing */
    [outputEnableSwitch setEnabled:false];
    [fundamentalSlider setEnabled:false];
}

- (void)endDrawing {
    
    /* If we drew a waveform, sample it and send it to the wavetable synth */
    if (drawingWaveform) {
        [self sampleDrawnWaveform];
        drawnWaveform = false;
        
        if ([aSynth enabled]) {
            [aSynth setEnabled:false];
            [wSynth setEnabled:true];
            [self setIndicatorDotsVisible:false];
        }
    }
    
    /* If we drew an amplitude envelope, sample and set it on the additive and wavetable synths */
    else if (drawingEnvelope) {
        [self sampleDrawnEnvelope];
        drawingEnvelope = false;
    }
    
    /* Remove the function draw view */
    [[self drawView] removeFromSuperview];
    
    /* Put the segmented control back */
    [tdScopeView setAlpha:1.0];
    [tdScopeView addSubview:[self drawSelector]];
    
    /* Set the time domain plot bounds to their original values before the tap */
    [tdScopeView setVisibleXLim:oldXMin max:oldXMax];
    [tdScopeView setPlotUnitsPerXTick:oldXGridScale];
 
    /* Re-enable disabled interface controls */
    [outputEnableSwitch setEnabled:true];
    [fundamentalSlider setEnabled:true];
    
    /* Deselect all items */
    previouslySelectedPreset = [drawSelector selectedSegmentIndex];
    [drawSelector setSelectedSegmentIndex:UISegmentedControlNoSegment];
}

- (void)sampleDrawnEnvelope {
    
    /* Get enough samples of the drawn envelope to cover the visible range of the plot */
    envLength = (int)((tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * audioOutput.sampleRate);
    
    if (drawnEnvelope)
        free(drawnEnvelope);
    
    drawnEnvelope = (float *)calloc(envLength, sizeof(float));
    [drawView getDrawingWithLength:envLength pixelVals:drawnEnvelope];
    
    CGPoint p;
    for (int i = 0; i < envLength; i++) {
        
        /* Convert to plot units and shift to the interval [0, 1] */
        p = [tdScopeView pixelToPlotScale:CGPointMake((CGFloat)i, drawnEnvelope[i])withOffset:tdScopeView.frame.origin];
        drawnEnvelope[i] = p.y - tdScopeView.visiblePlotMin.y;
        drawnEnvelope[i] /= (tdScopeView.visiblePlotMax.y - tdScopeView.visiblePlotMin.y);
    }
    
    /* Set the envelope on the aSynth */
    [aSynth setAmplitudeEnvelope:drawnEnvelope length:envLength];
    [wSynth setAmplitudeEnvelope:drawnEnvelope length:envLength];
}

- (void)sampleDrawnWaveform {
    
    /* Get a number of samples from the drawn waveform sufficient to represent the highest possible fundamental frequency */
    float upsampleFactor = fundamentalSlider.maximumValue / fundamentalSlider.value;
    wavetableLength = (int)(drawView.length * upsampleFactor * 3.0); // *3.0 is a hack
    
    /* Add a few extra samples to interpolate between starting and end points to smooth out discontinuities */
    wavetableLength += kWavetablePadLength;
    
    if (drawnWaveform)
        free(drawnWaveform);
    
    drawnWaveform = (float *)malloc(wavetableLength * sizeof(float));
    [drawView getDrawingWithLength:wavetableLength-kWavetablePadLength pixelVals:drawnWaveform];
    
    /* Convert pixel values to plot units */
    CGPoint p;
    for (int i = 0; i < wavetableLength-kWavetablePadLength; i++) {
        p = [tdScopeView pixelToPlotScale:CGPointMake((CGFloat)i, drawnWaveform[i])withOffset:tdScopeView.frame.origin];
        drawnWaveform[i] = p.y;
    }
    
    int sampOffset = 2;
    
    /* Interpolate the extra samples ensuring continuity between the wave period's endpoints */
    float *wavetablePad = (float *)malloc(kWavetablePadLength+sampOffset * sizeof(float));
    [self linspace:drawnWaveform[wavetableLength-kWavetablePadLength-sampOffset]
               max:drawnWaveform[0]
       numElements:kWavetablePadLength+sampOffset
             array:wavetablePad];
    
    
//    printf("\n\nwavetableLength = %d\n", wavetableLength);
//    printf("wavetablePad = ");
    for (int i = 0; i < kWavetablePadLength+sampOffset; i++) {
//        printf("%f ", wavetablePad[i]);
        drawnWaveform[wavetableLength-kWavetablePadLength-sampOffset+i] = wavetablePad[i];
    }
    
//    printf("\n\nwavetable:\n");
//    for (int i = 0; i < wavetableLength; i++)
//        printf("wt[%d] = %f\n", i, drawnWaveform[i]);
    
    [wSynth setWaveTable:drawnWaveform length:wavetableLength];
}


#pragma mark - Interface Callbacks
- (IBAction)updateFundamental {
    
    /* Update the synths' fundamentals */
    [aSynth setFundamental:fundamentalSlider.value];
    [wSynth setFundamental:fundamentalSlider.value];
    
    /* Update the label */
    [fundamentalLabel setText:[NSString stringWithFormat:@"%5.1f", fundamentalSlider.value]];
    
    /* Update the indicator dots */
    for (int i = 0; i < kNumHarmonics; i++) {
    
        /* Get the i^th slider and dot indicator */
        UISlider *slider = [harmonicSliders valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        CGPoint newPos = dot.position;
        newPos.x = [fundamentalSlider value] * [slider tag];
        [dot setPosition:newPos];
    }
}

- (void)beginUpdateHarmonic:(UISlider *)sender  {
    
    int harmonicNum = (int)[sender tag];
    float linearAmp = powf(10, [sender value]/20.0);
    
    /* Update the associated harmonic amplitude */
    if (harmonicNum <= kNumHarmonics) {
        
        /* If the wavetable synth is active, go back to the additive synth */
        if ([wSynth enabled]) {
            [wSynth setEnabled:false];
            [aSynth setEnabled:true];
            [self setIndicatorDotsVisible:true];
        }
        
        /* Find the "Manual" item and select it */
        for (int i = 0; i < [presetSelector numberOfSegments]; i++) {
            if ([[presetSelector titleForSegmentAtIndex:i] isEqualToString:@"Manual"]) {
                [presetSelector setSelectedSegmentIndex:i];
                previouslySelectedPreset = i;
            }
        }
        
        IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", harmonicNum]];
        
        CGRect infoViewFrame = dot.frame;
        infoViewFrame.size.height = 100.0;
        infoViewFrame.size.width = 250.0;
        infoViewFrame.origin.y -= (infoViewFrame.size.height / 2);
        infoViewFrame.origin.x += 20.0;
        
        /* Keep the info view frame in the FD scope */
        if (infoViewFrame.origin.y < 0.0)
            infoViewFrame.origin.y = 0.0;
        if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
            infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
        if (infoViewFrame.origin.x < 0.0)
            infoViewFrame.origin.x = 0.0;
        if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
            infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        
        /* Create the parameter info view */
        infoView = [[UIView alloc] initWithFrame:infoViewFrame];
        [infoView setFrame:infoViewFrame];
        [infoView setBackgroundColor:[UIColor clearColor]];
        [fdScopeView addSubview:infoView];
        
        CGRect labelFrame;
        labelFrame.origin.x = 10;
        labelFrame.origin.y = 10;
        labelFrame.size.width = 100;
        labelFrame.size.height = 30;
        
        /* Add the parameter labels */
        freqParamLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [freqParamLabel setText:@"Frequency: "];
        [infoView addSubview:freqParamLabel];
        
        labelFrame.origin.y += labelFrame.size.height;
        ampParamLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [ampParamLabel setText:@"Amplitude: "];
        [infoView addSubview:ampParamLabel];
        
        /* And their values */
        labelFrame.origin.y -= labelFrame.size.height;
        labelFrame.origin.x += labelFrame.size.width;
        freqValueLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [freqValueLabel setText:[NSString stringWithFormat:@"%5.1f Hz", fundamentalSlider.value * harmonicNum]];
        [freqValueLabel setTextAlignment:NSTextAlignmentRight];
        [infoView addSubview:freqValueLabel];
        
        labelFrame.origin.y += labelFrame.size.height;
        ampValueLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [ampValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", [sender value]]];
        [ampValueLabel setTextAlignment:NSTextAlignmentRight];
        [infoView addSubview:ampValueLabel];
    }
    
    /* If we're updating the noise amplitude, create a slightly different parameter view */
    else if (harmonicNum == kNumHarmonics+1) {
        
        CGRect infoViewFrame;
        infoViewFrame.size.height = 100.0;
        infoViewFrame.size.width = 250.0;
        infoViewFrame.origin.y = linearAmp;
        infoViewFrame.origin.x = 0.0;
        infoViewFrame.origin = [fdScopeView plotScaleToPixel:infoViewFrame.origin];
        infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        infoViewFrame.origin.y -= (infoViewFrame.size.height / 3);
        
        /* Keep the info view frame in the FD scope */
        if (infoViewFrame.origin.y < 0.0)
            infoViewFrame.origin.y = 0.0;
        if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
            infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
        if (infoViewFrame.origin.x < 0.0)
            infoViewFrame.origin.x = 0.0;
        if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
            infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        
        /* Create the parameter info view */
        infoView = [[UIView alloc] initWithFrame:infoViewFrame];
        [infoView setFrame:infoViewFrame];
        [infoView setBackgroundColor:[UIColor clearColor]];
        [fdScopeView addSubview:infoView];
        
        CGRect labelFrame;
        labelFrame.origin.x = 10;
        labelFrame.origin.y = 10;
        labelFrame.size.width = 130;
        labelFrame.size.height = 30;
        
        /* Add the parameter labels */
        freqParamLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [freqParamLabel setText:@"Noise amplitude: "];
        [infoView addSubview:freqParamLabel];
        
        /* And their values */
        labelFrame.origin.y += labelFrame.size.height;
        freqValueLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [freqValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", [sender value]]];
        [freqValueLabel setTextAlignment:NSTextAlignmentRight];
        [infoView addSubview:freqValueLabel];
    }
}

- (void)updateHarmonic:(UISlider *)sender {
    
    int harmonicNum = (int)[sender tag];
    float linearAmp = powf(10, [sender value]/20.0);
    
    /* Update the associated harmonic amplitude */
    if (harmonicNum <= kNumHarmonics) {
        
        IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", harmonicNum]];
        
        CGRect infoViewFrame = dot.frame;
        infoViewFrame.size.height = 100.0;
        infoViewFrame.size.width = 250.0;
        infoViewFrame.origin.y -= (infoViewFrame.size.height / 3);
        infoViewFrame.origin.x += 20.0;
        
        /* Keep the info view frame in the FD scope */
        if (infoViewFrame.origin.y < 0.0)
            infoViewFrame.origin.y = 0.0;
        if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
            infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
        if (infoViewFrame.origin.x < 0.0)
            infoViewFrame.origin.x = 0.0;
        if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
            infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        
        [infoView setFrame:infoViewFrame];
        [freqValueLabel setText:[NSString stringWithFormat:@"%5.1f Hz", fundamentalSlider.value * harmonicNum]];
        [ampValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", [sender value]]];
        
        /* Update the additive synth */
        [aSynth setAmplitude:linearAmp forHarmonic:harmonicNum-1];
        
        /* Update the indicator dot */
        CGPoint newPos = dot.position;
        newPos.y = linearAmp;
        [dot setPosition:newPos];
    }
    
    /* Otherwise we're updating the noise amplitude */
    else { // if (harmonicNum == kNumHarmonics+1) {
        
        /* Update the noise amplitude */
        [aSynth setNoiseAmplitude:linearAmp];
        
        CGRect infoViewFrame;
        infoViewFrame.size.height = 100.0;
        infoViewFrame.size.width = 250.0;
        infoViewFrame.origin.y = linearAmp;
        infoViewFrame.origin.x = 0.0;
        infoViewFrame.origin = [fdScopeView plotScaleToPixel:infoViewFrame.origin];
        infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        infoViewFrame.origin.y -= (infoViewFrame.size.height / 3);
        
        /* Keep the info view frame in the FD scope */
        if (infoViewFrame.origin.y < 0.0)
            infoViewFrame.origin.y = 0.0;
        if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
            infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
        if (infoViewFrame.origin.x < 0.0)
            infoViewFrame.origin.x = 0.0;
        if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
            infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
        
        /* Update the frame */
        [infoView setFrame:infoViewFrame];
        
        CGRect labelFrame;
        labelFrame.origin.x = 10;
        labelFrame.origin.y = 10;
        labelFrame.size.width = 100;
        labelFrame.size.height = 30;
        
        /* Update the noise amplitude label */
        [freqValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", [sender value]]];
    }
}

/* Remove the parameter subview when not modifying harmonic amplitudes */
- (void)endUpdateHarmonic:(UISlider *)sender  {
    
    int harmonicNum = (int)[sender tag];
    
    if (harmonicNum <= kNumHarmonics)
        [infoView removeFromSuperview];
    else if (harmonicNum == kNumHarmonics+1)
        [infoView removeFromSuperview];
}

#pragma mark - Harmonic Presets
- (void)setHarmonicPreset:(UISegmentedControl *)sender  {
    
    NSString *selectedItem = [sender titleForSegmentAtIndex:[sender selectedSegmentIndex]];
    
    int nHarmonics = kNumHarmonics;
    
    /* If we're drawing a preset shape */
    if (![selectedItem isEqualToString:@"Manual"]) {
        
        if ([[sender titleForSegmentAtIndex:previouslySelectedPreset] isEqualToString:@"Manual"]) {
            /* Save the old harmonic amplitudes when exiting manual mode */
            for (int i = 0; i < kNumHarmonics; i++) {
                UISlider *slider = [harmonicSliders objectForKey:[NSString stringWithFormat:@"%d", i+1]];
                previousHarmonics[i] = slider.value;
            }
        }
        
        /* Use extra harmonics for non-sine presets */
        if (![selectedItem isEqualToString:@"Sine"])
            nHarmonics += nHarmonics;
    }
    
    /* Need even more to make a decent trigangle wave */
    if ([selectedItem isEqualToString:@"Tri"])
        nHarmonics += nHarmonics/2;
    
    float h[nHarmonics];
    [aSynth setNumHarmonics:nHarmonics];
    
    if ([selectedItem isEqualToString:@"Manual"]) {
        for (int i = 0; i < nHarmonics; i++)
            h[i] = previousHarmonics[i];
    }
    
    else if ([selectedItem isEqualToString:@"Sine"]) {
        h[0] = -6.0;
        for (int i = 1; i < nHarmonics; i++)
            h[i] = -80.0;
    }
    
    else if ([selectedItem isEqualToString:@"Saw"]) {
        for (int i = 0; i < nHarmonics; i++) {
            h[i] = 0.3f / (float)(i+1);
            h[i] = 20.0f * log10f(h[i]);
        }
    }
    else if ([selectedItem isEqualToString:@"Square"]) {
        for (int i = 0; i < nHarmonics; i++) {
            /* Odd index <--> even harmonic */
            if (i % 2 == 0) {
                h[i] = 0.5f / (float)(i+1);
                h[i] = 20.0f * log10f(h[i]);
            }
            else
                h[i] = -80.0;
        }
    }
    else if ([selectedItem isEqualToString:@"Tri"]) {
        for (int i = 0; i < nHarmonics; i++) {
            /* Odd index <--> even harmonic */
            if (i % 2 == 0) {
                h[i] = 0.5f / powf((float)(i+1), 2.0f);
                h[i] = 20.0f * log10f(h[i]);
            }
            else
                h[i] = -80.0;
        }
    }
    else
        return;
    
    /* Set the harmonic amplitudes */
    float linearAmp;
    for (int i = 0; i < nHarmonics; i++) {
        
        linearAmp = powf(10, h[i]/20.0);
        
        if (i < kNumHarmonics) {
    
            printf("h[%d] = %f\n", i, h[i]);
            
            /* Update the sliders */
            UISlider *slider = [harmonicSliders objectForKey:[NSString stringWithFormat:@"%d", i+1]];
            [slider setValue:h[i] animated:false];
            
            /* Update the indicator dot */
            IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", i+1]];
            CGPoint newPos = dot.position;
            newPos.y = linearAmp;
            [dot setPosition:newPos];
            [dot setVisible:true];
        }
        
        /* Update the additive synth */
        [aSynth setAmplitude:linearAmp forHarmonic:i];
    }
    
    /* Make sure we're using the additive synth */
    if ([wSynth enabled]) {
        [wSynth setEnabled:false];
        [aSynth setEnabled:true];
    }
    
    previouslySelectedPreset = [sender selectedSegmentIndex];
}

#pragma mark - Audio Render Callbacks
- (void)renderOutputBufferMono:(Float32 *)buffer outNumberFrames:(int)nFrames {
    
    if ([outputEnableSwitch isOn]) {
        
        /* Call the active synth's render method to populate the output buffer with samples */
        if ([aSynth enabled])
            phaseZeroOffset = [aSynth renderOutputBufferMono:buffer outNumberFrames:nFrames];
        else if ([wSynth enabled])
            phaseZeroOffset = [wSynth renderOutputBufferMono:buffer outNumberFrames:nFrames];
        
        /* Append this buffer of audio to the recording buffer */
        [self appendBuffer:buffer withLength:nFrames];
    }
    
    /* If audio is disabled, render for plotting, but send zeros to the output buffer */
    else {
        Float32 *plotYVals = (Float32 *)calloc(nFrames, sizeof(Float32));
        memcpy(buffer, plotYVals, nFrames * sizeof(Float32));
        
        /* Call the active synth's render method to populate the output buffer with samples */
        if ([aSynth enabled])
            phaseZeroOffset = [aSynth renderOutputBufferMono:plotYVals outNumberFrames:nFrames];
        else if ([wSynth enabled])
            phaseZeroOffset = [wSynth renderOutputBufferMono:plotYVals outNumberFrames:nFrames];
        
        [self appendBuffer:plotYVals withLength:nFrames];
        free(plotYVals);
    }
}

- (void)renderOutputBufferStereo:(Float32 *)lBuffer right:(Float32 *)rBuffer outNumberFrames:(int)nFrames {
    
    /* Render into the left channel and copy into the right */
    [self renderOutputBufferMono:lBuffer outNumberFrames:nFrames];
    memcpy(rBuffer, lBuffer, nFrames * sizeof(Float32));
}

#pragma mark - Recording
- (void)allocateRecordingBufferWithLength:(int)length {
    
    recordingBufferLength = length;
    
    if (recordingBuffer) {
        free(recordingBuffer);
        pthread_mutex_destroy(&recordingBufferMutex);
    }
    
    recordingBuffer = (float *)malloc(length * sizeof(float));
    pthread_mutex_init(&recordingBufferMutex, NULL);
}

- (void)appendBuffer:(float *)inBuffer withLength:(int)length {
    
    pthread_mutex_lock(&recordingBufferMutex);
    
    /* Shift old values back */
    for (int i = 0; i < recordingBufferLength - length; i++)
        recordingBuffer[i] = recordingBuffer[i + length];
    
    /* Append new values to the front */
    for (int i = 0; i < length; i++)
        recordingBuffer[recordingBufferLength - (length-i)] = inBuffer[i];
    
    pthread_mutex_unlock(&recordingBufferMutex);
}

- (void)getBuffer:(float *)outBuffer withLength:(int)length {
    [self getBuffer:outBuffer withLength:length offset:0];
}

- (void)getBuffer:(float *)outBuffer withLength:(int)length offset:(int)offset {
    
    pthread_mutex_lock(&recordingBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = recordingBuffer[recordingBufferLength - (length-i) + offset];
    pthread_mutex_unlock(&recordingBufferMutex);
}

#pragma mark - FunctionDrawViewDelegate methods
- (void)drawingBegan {
//    [outputEnableSwitch setEnabled:false];
//    [fundamentalSlider setEnabled:false];
}

- (void)drawingEnded {
//    [outputEnableSwitch setEnabled:true];
//    [fundamentalSlider setEnabled:true];
}

#pragma mark - METScopeviewDelegate methods
- (void)pinchBegan {
    [self rescaleIndicatorDots];
}

- (void)pinchEnded {
    [self rescaleIndicatorDots];
}

- (void)pinchUpdate {
    [self rescaleIndicatorDots];
}

- (void)panBegan {
    [self rescaleIndicatorDots];
}

- (void)panEnded {
    [self rescaleIndicatorDots];
}

- (void)panUpdate {
    [self rescaleIndicatorDots];
}

- (void)rescaleIndicatorDots {
    
    for (int i = 0; i < kNumHarmonics; i++) {
        
        IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        [dot setPosition:dot.position];
    }
}

- (void)setIndicatorDotsVisible:(bool)visible {
    
    for (int i = 0; i < kNumHarmonics; i++) {
        
        IndicatorDot *dot = [indicatorDots valueForKey:[NSString stringWithFormat:@"%d", i+1]];
        [dot setVisible:visible];
    }
}

#pragma mark - Utility
/* Generate a linearly-spaced set of indices for sampling an incoming waveform */
- (void)linspace:(float)minVal max:(float)maxVal numElements:(int)size array:(float*)array {
    
    float step = (maxVal - minVal) / (size - 1);
    array[0] = minVal;
    for (int i = 1; i < size-1; i++)
        array[i] = array[i-1] + step;
    
    array[size-1] = maxVal;
}

/* Linear inerpolation */
- (float)interpolatePoint:(float)x x0:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1 {
    
    return y0 + ((x-x0)*(y1-y0)) / (x1-x0);
}


@end
