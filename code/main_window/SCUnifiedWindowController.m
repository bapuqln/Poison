#include "Copyright.h"

#import <qrencode.h>
#import "SCUnifiedWindowController.h"
#import "SCBuddyListController.h"
#import "SCChatViewController.h"
#import "CGGeometryExtreme.h"
#import "SCQRCodeSheetController.h"
#import "ObjectiveTox.h"
#import "NSURL+Parameters.h"
#import "NSString+CanonicalID.h"
#import "SCBuddyListShared.h"
#import "DESConversation+Poison_CustomName.h"

#define SCUnifiedDefaultWindowFrame ((CGRect){{0, 0}, {700, 400}})
#define SCUnifiedMinimumSize ((CGSize){700, 400})

@interface SCUnifiedWindowController ()
@property (weak) SCNonGarbageSplitView *rootView;
@property (strong) SCBuddyListController *friendsListCont;
@property (strong) SCChatViewController *chatViewCont;
@property (weak) DESToxConnection *tox;
@property CGRect savedFrame;
@end

@implementation SCUnifiedWindowController {
    NSTextField *_dhtCount;
    DESConversation *_watchingConversation;
}

- (instancetype)initWithDESConnection:(DESToxConnection *)tox {
    self = [super initWithDESConnection:tox];
    if (self) {
        SCWidgetedWindow *window = [[SCWidgetedWindow alloc] initWithContentRect:CGRectCentreInRect(SCUnifiedDefaultWindowFrame, [NSScreen mainScreen].visibleFrame) styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:YES];
        window.restorable = NO;
        window.minSize = SCUnifiedMinimumSize;
        [window setFrameUsingName:@"UnifiedWindow"];
        window.frameAutosaveName = @"UnifiedWindow";
        window.title = SCApplicationInfoDictKey(@"CFBundleName");
        window.delegate = self;
        _dhtCount = [self newStyledTextField];
        window.widgetView = _dhtCount;
        window.representedURL = [NSBundle.mainBundle bundleURL];
        [tox addObserver:self forKeyPath:@"closeNodesCount" options:NSKeyValueObservingOptionNew context:NULL];
        self.window = window;
        self.tox = tox;
        [self prepareSplit];
    }
    return self;
}

- (void)prepareSplit {
    SCNonGarbageSplitView *root = [[SCNonGarbageSplitView alloc] initWithFrame:((NSView*)self.window.contentView).frame];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    root.vertical = YES;
    root.frame = ((NSView*)self.window.contentView).frame;
    root.delegate = self;
    [root setDividerStyle:NSSplitViewDividerStyleThin];
    
    self.friendsListCont = [[SCBuddyListController alloc] initWithNibName:@"FriendsPanel" bundle:[NSBundle mainBundle]];
    [self.friendsListCont loadView];
    [self.friendsListCont attachKVOHandlersToConnection:self.tox];
    [self conversationDidBecomeFocused:self.friendsListCont.conversationSelectedInView];
    [root addSubview:self.friendsListCont.view];

    self.chatViewCont = [[SCChatViewController alloc] initWithNibName:@"ChatPanel" bundle:[NSBundle mainBundle]];
    [self.chatViewCont loadView];
    self.chatViewCont.showsVideoPane = NO;
    self.chatViewCont.showsUserList = NO;
    [root addSubview:self.chatViewCont.view];
    [root adjustSubviews];
    [root setPosition:220 ofDividerAtIndex:0];
    
    self.rootView = root;
    [self.window.contentView addSubview:self.rootView];
    [root setAutosaveName:@"UnifiedSplitPane"];
}

- (SCBuddyListController *)buddyListController {
    return self.friendsListCont;
}

- (void)removeKVOHandlers {
    if (!_watchingConversation)
        return;
    [_watchingConversation removeObserver:self forKeyPath:@"presentableTitle"];
    if ([_watchingConversation conformsToProtocol:@protocol(DESFriend)]) {
        [_watchingConversation removeObserver:self forKeyPath:@"status"];
        [_watchingConversation removeObserver:self forKeyPath:@"address"];
        [_watchingConversation removeObserver:self forKeyPath:@"port"];
    }
}

- (void)conversationDidBecomeFocused:(DESConversation *)conversation {
    [self removeKVOHandlers];
    _watchingConversation = conversation;
    [self updateWindowTitle];
    [_watchingConversation addObserver:self forKeyPath:@"presentableTitle" options:NSKeyValueObservingOptionNew context:NULL];
    if ([_watchingConversation conformsToProtocol:@protocol(DESFriend)]) {
        self.window.representedURL = [NSBundle.mainBundle bundleURL];
        NSButton *b = [self.window standardWindowButton:NSWindowDocumentIconButton];
        DESFriendStatus s = ((DESFriend *)_watchingConversation).status;
        b.toolTip = SCStringForFriendStatus(s);
        b.image = SCImageForFriendStatus(s);
        [_watchingConversation addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
        _dhtCount.attributedStringValue = [self styledIndicatorText];
        _dhtCount.toolTip = [self toolTipTextForNodeCount:self.tox.closeNodesCount];
        [_dhtCount sizeToFit];
        [_watchingConversation addObserver:self forKeyPath:@"address" options:NSKeyValueObservingOptionNew context:NULL];
        [_watchingConversation addObserver:self forKeyPath:@"port" options:NSKeyValueObservingOptionNew context:NULL];
    } else {
        self.window.representedURL = nil;
    }
}

#pragma mark - indicator(s)

- (NSAttributedString *)styledIndicatorText {
    NSMutableAttributedString *base;
    base = [[NSMutableAttributedString alloc] initWithString:@""
                                                  attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]}];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"publicSights"]
        && [_watchingConversation conformsToProtocol:@protocol(DESFriend)]
        && ((DESFriend *)_watchingConversation).port != 0) {
        DESFriend *f = (DESFriend *)_watchingConversation;
        NSString *inf = [NSString stringWithFormat:@"%@:%hu • ", f.address,
                         f.port];
        NSAttributedString *a = [[NSAttributedString alloc] initWithString:inf];
        [base appendAttributedString:a];
    }
    NSString *nodes = [NSString stringWithFormat:NSLocalizedString(@"DHT: %lu", nil), (unsigned long)self.tox.closeNodesCount];
    [base appendAttributedString:[[NSAttributedString alloc] initWithString:nodes]];
    return base;
}

- (NSString *)toolTipTextForNodeCount:(NSUInteger)cnodes {
    NSString *fmt;
    if (cnodes > 4) {
        fmt = NSLocalizedString(@"%@ has good connectivity to the network.", nil);
    } else if (cnodes > 0) {
        fmt = NSLocalizedString(@"%@ has okay connectivity to the network.", nil);
    } else {
        fmt = NSLocalizedString(@"%@ has no connectivity to the network.", nil);
    }
    return [NSString stringWithFormat:fmt, SCApplicationInfoDictKey(@"CFBundleName")];
}

- (void)updateWindowTitle {
    if (!_watchingConversation) {
        self.window.title = SCApplicationInfoDictKey(@"CFBundleName");
    } else {
        self.window.title = [NSString stringWithFormat:@"%@ \u2014 %@",
                             _watchingConversation.preferredUIName,
                             SCApplicationInfoDictKey(@"CFBundleName")];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == self.tox) {
            _dhtCount.attributedStringValue = [self styledIndicatorText];
            _dhtCount.toolTip = [self toolTipTextForNodeCount:self.tox.closeNodesCount];
            [_dhtCount sizeToFit];
        } else if ([keyPath isEqualToString:@"presentableTitle"]) {
            [self updateWindowTitle];
        } else {
            if ([_watchingConversation conformsToProtocol:@protocol(DESFriend)]) {
                NSButton *b = [self.window standardWindowButton:NSWindowDocumentIconButton];
                DESFriendStatus s = ((DESFriend *)_watchingConversation).status;
                b.toolTip = SCStringForFriendStatus(s);
                b.image = SCImageForFriendStatus(s);
            }
        }
    });
}

#pragma mark - Split view delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return 220;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return 400;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    CGSize deltas = (CGSize){splitView.frame.size.width - oldSize.width, splitView.frame.size.height - oldSize.height};
    NSView *expands = (NSView*)splitView.subviews[1];
    NSView *doesntExpand = (NSView*)splitView.subviews[0];
    expands.frame = (CGRect){{doesntExpand.frame.size.width + 1, 0}, {expands.frame.size.width + deltas.width, expands.frame.size.height + deltas.height}};
    doesntExpand.frameSize = (CGSize){splitView.frame.size.width - expands.frame.size.width - 1, splitView.frame.size.height};
}

- (NSColor *)dividerColourForSplitView:(SCNonGarbageSplitView *)splitView {
    return [NSColor controlDarkShadowColor];
}

#pragma mark - Window delegate

/*- (void)windowDidResize:(NSNotification *)notification {
    if (self.savedFrame.size.width == ((NSWindow*)notification.object).frame.size.width) {
        return;
    } else {
        CGFloat originalPosition = _friendsListCont.view.frame.size.width;
        [self.rootView setFrameSize:((NSView*)self.window.contentView).frame.size];
        [self.rootView setPosition:originalPosition ofDividerAtIndex:0];
    }
}*/

- (void)dealloc {
    [self removeKVOHandlers];
    [self.tox removeObserver:self forKeyPath:@"closeNodesCount"];
}

@end
