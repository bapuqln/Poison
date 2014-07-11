#import "SCAudioVideoRecorder.h"

#if !TARGET_OS_IPHONE

@interface SCScreenDevice ()
@property (strong) NSScreen *screen;
@end

@implementation SCScreenDevice

- (instancetype)initWithScreen:(NSScreen *)screen {
    self = [super init];
    if (self) {
        self.screen = screen;
    }
    return self;
}

@end

NSString *const SCScreenVideoDevice = @"__USING SCREEN CAPTURE__";

#endif

@implementation SCAudioVideoRecorder {
    NSHashTable *_observers;
    AVCaptureInput *_videoIn;
    AVCaptureInput *_audioIn;
    
    BOOL _wantsVideo;
    BOOL _wantsAudio;

    AVCaptureVideoDataOutput *_linkerVideo;
    AVCaptureAudioDataOutput *_linkerAudio;
    dispatch_queue_t _processingQueue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observers = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality capacity:1];
        [self selectDevices];
    }
    return self;
}

- (void)selectDevices {
    /* select the proper devices from preferences */
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *videoID = [defaults stringForKey:@"orangeVideoDevice"];
    NSString *audioID = [defaults stringForKey:@"orangeAudioDevice"];

    AVCaptureDevice *vd;
#if !TARGET_OS_IPHONE
    if ([videoID isEqualToString:SCScreenVideoDevice]) {
        CGDirectDisplayID sid = (CGDirectDisplayID)[[NSUserDefaults standardUserDefaults] integerForKey:@"orangeScreenID"];
        NSScreen *selectedScreen = nil;
        for (NSScreen *screen in [NSScreen screens]) {
            if ([screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue] == sid) {
                selectedScreen = screen;
                break;
            }
        }
        if (!selectedScreen)
            vd = [[SCScreenDevice alloc] initWithScreen:[NSScreen mainScreen]];
        else
            vd = [[SCScreenDevice alloc] initWithScreen:selectedScreen];
    } else {
#endif
        vd = [AVCaptureDevice deviceWithUniqueID:videoID];
        if (![vd hasMediaType:AVMediaTypeVideo]) {
            vd = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if (vd)
                CFPreferencesSetValue(CFSTR("orangeVideoDevice"),
                                      (__bridge CFPropertyListRef)(vd.uniqueID),
                                      kCFPreferencesCurrentApplication,
                                      kCFPreferencesCurrentUser,
                                      kCFPreferencesCurrentHost);
            else NSLog(@"the video device appears to be kill");
        }
#if !TARGET_OS_IPHONE
    }
#endif

    AVCaptureDevice *ad = [AVCaptureDevice deviceWithUniqueID:audioID];
    if (![ad hasMediaType:AVMediaTypeAudio]) {
        ad = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if (ad)
            CFPreferencesSetValue(CFSTR("orangeAudioDevice"),
                                  (__bridge CFPropertyListRef)(ad.uniqueID),
                                  kCFPreferencesCurrentApplication,
                                  kCFPreferencesCurrentUser,
                                  kCFPreferencesCurrentHost);
        else NSLog(@"the audio device appears to be kill");
    }
    CFPreferencesSynchronize(kCFPreferencesCurrentApplication,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesCurrentHost);
    self.videoDevice = vd;
    self.audioDevice = ad;
}

- (void)setVideoDevice:(AVCaptureDevice *)videoDevice {
    NSError *error;
    AVCaptureInput *nIn;
#if !TARGET_OS_IPHONE
    if ([videoDevice isKindOfClass:[SCScreenDevice class]]) {
        SCScreenDevice *scr = (SCScreenDevice *)videoDevice;
        CGDirectDisplayID devid = [scr.screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
        CFPreferencesSetValue(CFSTR("orangeScreenID"), (__bridge CFPropertyListRef)(@(devid)),
                              kCFPreferencesCurrentApplication,
                              kCFPreferencesCurrentUser,
                              kCFPreferencesCurrentHost);

        nIn = [[AVCaptureScreenInput alloc] initWithDisplayID:devid];

        CGRect rect = CGRectZero;
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"orangeScreenRect"], &rect);
        if (CGRectIsEmpty(rect)) {
            CGRect screenRes = CGDisplayBounds(devid);
            rect = (CGRect){CGPointZero, screenRes.size};
            CFDictionaryRef r = CGRectCreateDictionaryRepresentation(rect);
            CFPreferencesSetValue(CFSTR("orangeScreenRect"), r,
                                  kCFPreferencesCurrentApplication,
                                  kCFPreferencesCurrentUser,
                                  kCFPreferencesCurrentHost);
            CFRelease(r);
        }

        ((AVCaptureScreenInput *)nIn).cropRect = rect;
        CFPreferencesSynchronize(kCFPreferencesCurrentApplication,
                                 kCFPreferencesCurrentUser,
                                 kCFPreferencesCurrentHost);
    } else {
#endif
        nIn = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&error];
        if (!nIn) {
            NSLog(@"error initializing video device: %@", error);
            return;
        }
#if !TARGET_OS_IPHONE
    }
#endif

    _videoDevice = videoDevice;

    [self.session beginConfiguration];
    if (_videoIn)
        [self.session removeInput:_videoIn];
    if (_wantsVideo)
        [self.session addInput:nIn];
    [self.session commitConfiguration];
    
    _videoIn = nIn;
}

- (void)setAudioDevice:(AVCaptureDevice *)audioDevice {
    NSError *error;
    AVCaptureInput *nIn = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (!nIn) {
        NSLog(@"error initializing video device: %@", error);
        return;
    }

    _audioDevice = audioDevice;
    
    [self.session beginConfiguration];
    if (_audioIn)
        [self.session removeInput:_audioIn];
    if (_wantsAudio)
        [self.session addInput:nIn];
    [self.session commitConfiguration];
    
    _audioIn = nIn;
}

- (void)beginSession {
    _session = [[AVCaptureSession alloc] init];
    if (_wantsVideo)
        [_session addInput:_videoIn];
    if (_wantsAudio)
        [_session addInput:_audioIn];
    _processingQueue = dispatch_queue_create("ca.kirara.SCAVProcessing", DISPATCH_QUEUE_SERIAL);
    _linkerVideo = [[AVCaptureVideoDataOutput alloc] init];
    _linkerAudio = [[AVCaptureAudioDataOutput alloc] init];
    [_linkerVideo setSampleBufferDelegate:self queue:_processingQueue];
    [_linkerAudio setSampleBufferDelegate:self queue:_processingQueue];
    [_session addOutput:_linkerVideo];
    [_session addOutput:_linkerAudio];
    for (id<SCAudioVideoReceiving> ob in _observers) {
        if ([ob respondsToSelector:@selector(recorderDidBeginSession:)])
            [ob recorderDidBeginSession:self];
    }
    [_session startRunning];
}

- (void)endSession {
    [_session stopRunning];
    for (id<SCAudioVideoReceiving> ob in _observers) {
        if ([ob respondsToSelector:@selector(recorderWillInvalidateSession:)])
            [ob recorderWillInvalidateSession:self];
    }
    [_session removeInput:_audioIn];
    [_session removeInput:_videoIn];
    [_session removeOutput:_linkerVideo];
    [_session removeOutput:_linkerAudio];
    _linkerVideo = nil;
    _linkerAudio = nil;
    _session = nil;
    _processingQueue = nil;
}

- (void)configureSessionAccordingToRequirements {
    if (!_wantsAudio && !_wantsVideo) {
        [self endSession];
    } else if (!_session) {
        [self beginSession];
    } else {
        [self reorganizeInputs];
        [self.session startRunning];
    }
}

- (void)reorganizeInputs {
    [_session beginConfiguration];
    if (_wantsVideo && ![_session.inputs containsObject:_videoIn])
        [_session addInput:_videoIn];
    else if (!_wantsVideo && [_session.inputs containsObject:_videoIn])
        [_session removeInput:_videoIn];
    
    if (_wantsAudio && ![_session.inputs containsObject:_audioIn])
        [_session addInput:_audioIn];
    else if (!_wantsAudio && [_session.inputs containsObject:_audioIn])
        [_session removeInput:_audioIn];
    [_session commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    /* TODO: optimize */
    SEL selector = NULL;
    if (captureOutput == _linkerVideo) {
        selector = @selector(recorder:didProduceVideoFrame:);
    } else {
        selector = @selector(recorder:didProduceAudioFrame:);
    }

    for (id ob in _observers) {
        if ([ob respondsToSelector:selector])
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [ob performSelector:selector withObject:self withObject:(__bridge id)(sampleBuffer)];
#pragma clang diagnostic pop
    }
}

#pragma mark - observing

- (void)addObserver:(id<SCAudioVideoReceiving>)observer {
    [_observers addObject:observer];
    [self noteObserverRequirementsChanged:observer];
}

- (void)removeObserver:(id<SCAudioVideoReceiving>)observer {
    [_observers removeObject:observer];
    [self noteObserverRequirementsChanged:observer];
}

- (void)noteObserverRequirementsChanged:(id<SCAudioVideoReceiving>)observer {
    _wantsAudio = NO;
    _wantsVideo = NO;
    for (id<SCAudioVideoReceiving> ob in _observers) {
        if ([ob needsAudioSamplesFromRecorder:self])
            _wantsAudio = YES;
        if ([ob needsVideoFramesFromRecorder:self])
            _wantsVideo = YES;
    }
    [self configureSessionAccordingToRequirements];
}

- (void)dealloc {
    [self endSession];
}

@end
