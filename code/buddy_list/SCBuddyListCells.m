#include "Copyright.h"

#import "SCBuddyListCells.h"
#import "ObjectiveTox.h"
#import "SCBuddyListShared.h"
#import "SCBuddyListController.h"
#import "SCBuddyListManager.h"
#import "DESConversation+Poison_CustomName.h"
#import <QuartzCore/QuartzCore.h>

@class SCGroupMarker;
@implementation SCGroupRowView {
    NSGradient *_grad;
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
        if ([NSVisualEffectView class])
            _grad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.1 alpha:0.7]
                                                  endingColor:[NSColor colorWithCalibratedWhite:0.1 alpha:0.7]];
        else
#endif
            _grad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0]
                                                  endingColor:[NSColor colorWithCalibratedWhite:0.2 alpha:0.5]];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    if (self.isFloating)
        [_grad drawInRect:(CGRect){{dirtyRect.origin.x, 0}, {dirtyRect.size.width, self.frame.size.height}} angle:90.0];
}

@end

@implementation SCFriendRowView {
    NSGradient *_shadow;
}

- (void)drawRect:(NSRect)dirtyRect {
//    if (self.isSelected) {
//        [[NSColor colorWithCalibratedWhite:0.04 alpha:1.0] set];
//        [[NSBezierPath bezierPathWithRect:NSMakeRect(-2, 0, self.bounds.size.width + 2, self.bounds.size.height)] stroke];
//        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.35] set];
//        [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 1, self.bounds.size.width, 1)] fill];
//        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.20] set];
//        [[NSBezierPath bezierPathWithRect:NSMakeRect(0, self.bounds.size.height - 2, self.bounds.size.width, 1)] fill];
//        NSGradient *bodyGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.20]];
//        [bodyGrad drawInBezierPath:[NSBezierPath bezierPathWithRect:NSMakeRect(-2, 2, self.bounds.size.width + 2, self.bounds.size.height - 4)] angle:-90.0];
//    }
    if (self.isSelected) {
        if (!SCIsYosemiteOrHigher()) {
            if (!_shadow)
                _shadow = [[NSGradient alloc] initWithStartingColor:[NSColor clearColor] endingColor:[NSColor colorWithCalibratedWhite:0.071 alpha:0.3]];
            [[NSColor colorWithCalibratedWhite:0.118 alpha:1.0] set];
            NSRectFill(dirtyRect);
            [_shadow drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, -4, self.bounds.size.width, 8)] angle:-90.0];
            [_shadow drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, self.bounds.size.height - 4, self.bounds.size.width, 8)] angle:90.0];
        } else {
            [[NSColor colorWithCalibratedWhite:0.2 alpha:0.8] set];
            NSRectFill(dirtyRect);
        }
    }
}

@end

@implementation SCGroupCellView

- (void)setObjectValue:(SCGroupMarker *)objectValue {
    self.textField.stringValue = [objectValue.name uppercaseString] ?: @"";
    self.auxLabel.stringValue = [objectValue.other uppercaseString] ?: @"";
}

@end

@implementation SCFriendCellView {
    DESConversation *_watchingFriend;
}

- (void)removeKVOHandlers {
    [_watchingFriend removeObserver:self forKeyPath:@"presentableTitle"];
    [_watchingFriend removeObserver:self forKeyPath:@"presentableSubtitle"];
    if ([_watchingFriend conformsToProtocol:@protocol(DESFriend)])
        [_watchingFriend removeObserver:self forKeyPath:@"status"];
}

- (void)attachKVOHandlers {
    [_watchingFriend addObserver:self forKeyPath:@"presentableTitle" options:NSKeyValueObservingOptionNew context:NULL];
    [_watchingFriend addObserver:self forKeyPath:@"presentableSubtitle" options:NSKeyValueObservingOptionNew context:NULL];
    if ([_watchingFriend conformsToProtocol:@protocol(DESFriend)])
        [_watchingFriend addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        DESConversation *obj = object;
        if ([keyPath isEqualToString:@"presentableTitle"]) {
            self.mainLabel.attributedStringValue = [obj preferredUIAttributedNameWithColour:[NSColor whiteColor]
                                                                           backgroundColour:[NSColor disabledControlTextColor]];
        } else if ([keyPath isEqualToString:@"presentableSubtitle"]) {
            [self displayStringForStatusMessage:obj.presentableSubtitle];
        } else if ([keyPath isEqualToString:@"status"]) {
            [self updateTooltipAgainstFriend:((DESFriend *)object)];
            self.light.image = SCImageForFriendStatus(((DESFriend *)object).status);
        }
    });
}

- (void)updateTooltipAgainstFriend:(DESFriend *)f {
    if (f.status != DESFriendStatusOffline) {
        NSString *address = f.address;
        uint16_t port = f.port;
        self.toolTip = [NSString stringWithFormat:
                        NSLocalizedString(@"Public Key: %@\n"
                                          "Address: %@:%hu", nil),
                        f.publicKey, address, port];
    } else {
        self.toolTip = [NSString stringWithFormat:
                        NSLocalizedString(@"Public Key: %@\n"
                                          "IP Address: None (friend is offline)", nil),
                        f.publicKey];
    }
}

- (void)displayStringForStatusMessage:(NSString *)def {
    if (![_watchingFriend conformsToProtocol:@protocol(DESFriend)]) {
        self.auxLabel.stringValue = def;
        return;
    }

    /* convert it for type-checking purposes */
    DESFriend *wf = (DESFriend *)_watchingFriend;
    if (wf.status == DESFriendStatusOffline) {
        if (wf.lastSeen.timeIntervalSince1970 == 0)
            self.auxLabel.stringValue = NSLocalizedString(@"Request sent...", nil);
        else
            self.auxLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Offline since: %@", nil),
                                         [self.manager formatDate:wf.lastSeen]];
    } else {
        NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        if ([[def stringByTrimmingCharactersInSet:cs] isEqualToString:@""]) {
            self.auxLabel.stringValue = SCStringForFriendStatus(wf.status);
        } else {
            self.auxLabel.stringValue = def;
        }
    }
}

- (void)applyMaskIfRequired {
    if (self.avatarView.wantsLayer)
        return;
    self.avatarView.wantsLayer = YES;
    NSImage *mask = SCAvatarMaskImage();
    CALayer *maskLayer = [CALayer layer];
    [CATransaction begin];
    maskLayer.frame = (CGRect){CGPointZero, self.avatarView.frame.size};
    maskLayer.contents = (id)mask;
    self.avatarView.layer.mask = maskLayer;
    [CATransaction commit];
}

- (void)setObjectValue:(id)objectValue {
    [self removeKVOHandlers];
    _watchingFriend = objectValue;
    if (_watchingFriend) {
        self.mainLabel.attributedStringValue = [_watchingFriend preferredUIAttributedNameWithColour:[NSColor whiteColor]
                                                                                   backgroundColour:[NSColor disabledControlTextColor]];
        [self displayStringForStatusMessage:_watchingFriend.presentableSubtitle];
        if ([_watchingFriend conformsToProtocol:@protocol(DESFriend)]) {
            DESFriend *f = (DESFriend *)_watchingFriend;
            self.light.hidden = NO;
            self.light.image = SCImageForFriendStatus(f.status);
            [self updateTooltipAgainstFriend:f];
        } else {
            self.light.hidden = YES;
            self.toolTip = nil;
        }
        [self attachKVOHandlers];
    }
}

@end

@implementation SCRequestCellView {
    NSTrackingArea *_tracking;
}

- (void)applyMaskIfRequired {
    if (self.avatarView.wantsLayer)
        return;
    self.accessoryView.wantsLayer = YES;
    self.accessoryView.alphaValue = 0.0;
    self.avatarView.wantsLayer = YES;
    NSImage *mask = SCAvatarMaskImage();
    CALayer *maskLayer = [CALayer layer];
    [CATransaction begin];
    maskLayer.frame = (CGRect){CGPointZero, self.avatarView.frame.size};
    maskLayer.contents = (id)mask;
    self.avatarView.layer.mask = maskLayer;
    [CATransaction commit];
}

- (void)updateTrackingAreas {
    if (_tracking)
        [self removeTrackingArea:_tracking];

    _tracking = [[NSTrackingArea alloc] initWithRect:self.accessoryView.frame
                                             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                               owner:self
                                            userInfo:nil];
    [self addTrackingArea:_tracking];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    self.accessoryView.alphaValue = 0.0;
    self.accessoryView.hidden = NO;
    [NSAnimationContext beginGrouping];
    [NSAnimationContext currentContext].duration = 0.2;
    [self.accessoryView animator].alphaValue = 1.0;
    [NSAnimationContext endGrouping];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [NSAnimationContext beginGrouping];
    [NSAnimationContext currentContext].duration = 0.2;
    [NSAnimationContext currentContext].completionHandler = ^{
        self.accessoryView.hidden = YES;
    };
    [self.accessoryView animator].alphaValue = 0.0;
    [NSAnimationContext endGrouping];
}

- (void)setObjectValue:(id)objectValue {
    [super setObjectValue:objectValue];
    if (self.objectValue) {
        DESRequest *r = objectValue;
        self.mainLabel.stringValue = [r.senderName substringToIndex:8];
        self.auxLabel.stringValue = r.message;
    }
}

@end

@interface _SCRequestCellBlurView : NSView
@end

@implementation _SCRequestCellBlurView

- (void)drawRect:(NSRect)dirtyRect {
    static NSGradient *blurGrad = nil;
    if (!blurGrad) {
        NSColor *s = [NSColor colorWithCalibratedWhite:0.20 alpha:0.0];
        NSColor *e = [NSColor colorWithCalibratedWhite:0.20 alpha:1.0];
        blurGrad = [[NSGradient alloc] initWithStartingColor:s endingColor:e];
    }
    [blurGrad drawInRect:self.bounds angle:0.0];
}

@end