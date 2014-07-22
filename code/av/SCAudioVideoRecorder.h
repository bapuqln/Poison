#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/* Screen capture is MacOSX only. */
#if !TARGET_OS_IPHONE

extern NSString *const SCScreenVideoDevice;

@interface SCScreenDevice : AVCaptureDevice
- (instancetype)initWithScreen:(NSScreen *)screen;
@end

#endif

@class SCAudioVideoRecorder;
@protocol SCAudioVideoReceiving <NSObject>

@optional
- (void)recorder:(SCAudioVideoRecorder *)aRecorder didProduceVideoFrame:(CMSampleBufferRef)frame;
- (void)recorder:(SCAudioVideoRecorder *)aRecorder didProduceAudioFrame:(CMSampleBufferRef)frame;
- (void)recorder:(SCAudioVideoRecorder *)aRecorder willChangeToVideoSize:(CGSize)newSize;
- (void)recorderDidBeginSession:(SCAudioVideoRecorder *)aRecorder;
- (void)recorderWillInvalidateSession:(SCAudioVideoRecorder *)aRecorder;

@required
- (BOOL)needsVideoFramesFromRecorder:(SCAudioVideoRecorder *)aRecorder;
- (BOOL)needsAudioSamplesFromRecorder:(SCAudioVideoRecorder *)aRecorder;

@end

@interface SCAudioVideoRecorder : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate,
                                            AVCaptureAudioDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureDevice *videoDevice;
@property (strong, nonatomic) AVCaptureDevice *audioDevice;
@property (strong, readonly) AVCaptureSession *session;

- (void)addObserver:(id<SCAudioVideoReceiving>)observer;
- (void)removeObserver:(id<SCAudioVideoReceiving>)observer;
- (void)noteObserverRequirementsChanged:(id<SCAudioVideoReceiving>)observer;
@end
