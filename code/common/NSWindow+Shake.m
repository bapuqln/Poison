#include "Copyright.h"

#import "NSWindow+Shake.h"
#import <QuartzCore/QuartzCore.h>



@implementation NSWindow (Shake)

- (void)shakeWindow:(void (^)(void))completionHandler {
    self.animations = @{@"frameOrigin": [self shakeAnimation:self.frame]};
    [self.animator setFrameOrigin:self.frame.origin];
    if (!completionHandler)
        return;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        completionHandler();
    });
}

- (CAKeyframeAnimation *)shakeAnimation:(NSRect)frame {
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
	for (int index = 0; index < 2; index++) {
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * 0.08f, NSMinY(frame));
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * 0.08f, NSMinY(frame));
	}
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = 0.3f;
    CGPathRelease(shakePath);
    return shakeAnimation;
}

@end
