#import "SCAvatarView.h"
#import <QuartzCore/QuartzCore.h>

@implementation SCAvatarView {
    CALayer *_maskLayer;
    NSTrackingArea *_trackingArea;
    NSPopover *_largerView;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self awakeFromNib];
    }
    return self;
}

- (void)awakeFromNib {
    [self applyMaskIfRequired];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults addObserver:self
               forKeyPath:@"avatarShape"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
    [self updateTrackingAreas];
}

- (void)updateTrackingAreas {
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                                                   owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)applyMaskIfRequired {
    self.wantsLayer = YES;
    NSImage *mask = SCAvatarMaskImage();
    _maskLayer = [CALayer layer];
    [CATransaction begin];
    _maskLayer.frame = self.bounds;
    _maskLayer.contents = (id)mask;
    self.layer.mask = _maskLayer;
    [CATransaction commit];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSImage *newMask = SCAvatarMaskImage();
    _maskLayer.contents = (id)newMask;
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [self popoverIfStillHovering];
}

- (void)popoverIfStillHovering {
    /* hovering is deprecated */
    _largerView = [[NSPopover alloc] init];
    _largerView.contentViewController = [[NSViewController alloc] init];
    _largerView.animates = YES;
    NSImageView *image = [[NSImageView alloc] initWithFrame:(CGRect){CGPointZero, {128, 128}}];
    image.imageScaling = NSImageScaleProportionallyUpOrDown;
    image.image = self.image;
    _largerView.contentViewController.view = image;

    [_largerView showRelativeToRect:CGRectInset(self.frame, -15, -15) ofView:self.superview preferredEdge:NSMinXEdge];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [_largerView performClose:self];
    _largerView = nil;
}

- (void)dealloc {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObserver:self forKeyPath:@"avatarShape"];
}

@end
