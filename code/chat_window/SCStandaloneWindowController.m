#include "Copyright.h"

#import "SCStandaloneWindowController.h"
#import "SCWidgetedWindow.h"
#import "CGGeometryExtreme.h"
#import "ObjectiveTox.h"
#import "SCAppDelegate.h"
#import "DESConversation+Poison_CustomName.h"
#import "SCBuddyListShared.h"
#import "SCChatViewController.h"
#import <QuartzCore/QuartzCore.h>

#define SCStandaloneDefaultWindowFrame ((CGRect){{0, 0}, {500, 400}})
#define SCStandaloneMinimumSize ((CGSize){500, 400})

@implementation SCStandaloneWindowController {
    DESConversation *_watchingFriend;
    SCChatViewController *_chatView;
}

- (instancetype)initWithConversation:(DESConversation *)conv {
    self = [super init];
    if (self) {
        self.window = [self makeWindow];
        self.window.delegate = self;
        _watchingFriend = conv;
        if ([conv conformsToProtocol:@protocol(DESFriend)]) {
            ((SCWidgetedWindow *)self.window).widgetView = [self makeStyledTextField];
        }
        _chatView = [[SCChatViewController alloc] initWithNibName:@"ChatPanel" bundle:[NSBundle mainBundle]];
        [_chatView loadView];
        _chatView.view.frame = [self.window.contentView bounds];
        [self.window.contentView addSubview:_chatView.view];
        [self addKVOHandlers];
    }
    return self;
}

- (DESConversation *)conversation {
    return _watchingFriend;
}

- (NSString *)conversationIdentifier {
    return _watchingFriend.conversationIdentifier;
}

- (SCChatViewController *)chatView {
    return _chatView;
}

- (void)addKVOHandlers {
    [self updateTitle];
    [_watchingFriend addObserver:self forKeyPath:@"presentableTitle" options:NSKeyValueObservingOptionNew context:NULL];
    if ([_watchingFriend conformsToProtocol:@protocol(DESFriend)]) {
        [self updateLight];
        [_watchingFriend addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
        [self updateWidget];
        [_watchingFriend addObserver:self forKeyPath:@"address" options:NSKeyValueObservingOptionNew context:NULL];
        [_watchingFriend addObserver:self forKeyPath:@"port" options:NSKeyValueObservingOptionNew context:NULL];
    }
}

- (void)removeKVOHandlers {
    [_watchingFriend removeObserver:self forKeyPath:@"presentableTitle"];
    if ([_watchingFriend conformsToProtocol:@protocol(DESFriend)]) {
        [_watchingFriend removeObserver:self forKeyPath:@"status"];
        [_watchingFriend removeObserver:self forKeyPath:@"address"];
        [_watchingFriend removeObserver:self forKeyPath:@"port"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"address"] || [keyPath isEqualToString:@"port"]) {
        [self updateWidget];
    } else if ([keyPath isEqualToString:@"presentableTitle"]) {
        [self updateTitle];
    } else if ([keyPath isEqualToString:@"status"]) {
        [self updateLight];
    }
}

- (void)updateWidget {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"publicSights"])
        return;

    SCWidgetedWindow *w = (SCWidgetedWindow *)self.window;
    DESFriend *f = (DESFriend *)_watchingFriend;
    [CATransaction begin];
    if (f.port != 0) {
        NSString *as = [NSString stringWithFormat:@"%@:%hu", f.address,
                        f.port];
        ((NSTextField *)w.widgetView).stringValue = as;
    } else {
        if ([f.address isEqualToString:@"tcprelay"]) {
            ((NSTextField *)w.widgetView).stringValue = @"(relayed)";
        } else {
            ((NSTextField *)w.widgetView).stringValue = @"";
        }
    }
    [((NSTextField *)w.widgetView) sizeToFit];
    [CATransaction commit];
}

- (void)updateTitle {
    self.window.title = [_watchingFriend preferredUIName];
}

- (void)updateLight {
    self.window.representedURL = [NSBundle mainBundle].bundleURL;
    NSButton *b = [self.window standardWindowButton:NSWindowDocumentIconButton];
    DESFriendStatus s = ((DESFriend *)_watchingFriend).status;
    b.toolTip = SCStringForFriendStatus(s);
    b.image = SCImageForFriendStatus(s);
}

- (NSWindow *)makeWindow {
    SCWidgetedWindow *w;
    CGRect screenRect = [[NSScreen mainScreen] visibleFrame];
    CGRect size = SCStandaloneDefaultWindowFrame;
    w = [[SCWidgetedWindow alloc] initWithContentRect:CGRectCentreInRect(size, screenRect) styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:YES];
    w.minSize = SCStandaloneMinimumSize;
    return w;
}

- (NSTextField *)makeStyledTextField {
    NSTextField *ret = [[NSTextField alloc] initWithFrame:CGRectZero];
    ret.bezeled = NO;
    ret.drawsBackground = NO;
    ret.editable = NO;
    ret.textColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];
    ret.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    ret.wantsLayer = YES;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGColorRef color = CGColorCreate(cs, (CGFloat[]){1.0, 1.0});
    ret.layer.shadowColor = color;
    CGColorRelease(color);
    CGColorSpaceRelease(cs);
    ret.layer.shadowOffset = (CGSize){0, 0.7};
    ret.layer.shadowOpacity = 0.7;
    ret.layer.shadowRadius = 0.3;
    return ret;
}

- (void)windowWillClose:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [(SCAppDelegate *)[NSApp delegate] removeAuxWindowFromService:self];
    });
}

- (void)dealloc {
    [self removeKVOHandlers];
    NSLog(@"SCStandaloneWindowController deallocated!");
}

@end
