#include "Copyright.h"

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
#import "SCAppDelegate.h"
#import "SCConversationManager.h"
#import "SCThemeManager.h"

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
        SCWidgetedWindow *window = [[SCWidgetedWindow alloc] initWithContentRect:CGRectCentreInRect(SCUnifiedDefaultWindowFrame, [NSScreen mainScreen].visibleFrame) styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSFullSizeContentViewWindowMask backing:NSBackingStoreBuffered defer:YES];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
        if (SCIsYosemiteOrHigher()) {
            window.titlebarAppearsTransparent = YES;
            window.titleVisibility = NSWindowTitleHidden;
        }
#endif
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
    self.chatViewCont.view.frameSize = (CGSize){300, root.frame.size.height};
    self.chatViewCont.showsVideoPane = NO;
    self.chatViewCont.showsUserList = NO;
    [root addSubview:self.chatViewCont.view];
    [root adjustSubviews];
    [root setPosition:220 ofDividerAtIndex:0];
    
    self.rootView = root;
    [self.window.contentView addSubview:self.rootView];
    [root setAutosaveName:@"UnifiedSplitPane"];

    DESConversation *selected = self.friendsListCont.conversationSelectedInView;
    if (selected)
        self.chatViewCont.conversation = [((SCAppDelegate *)[NSApp delegate]).conversationManager conversationFor:selected];
    self.friendsListCont.friendListView.superview.postsBoundsChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invalidateDivider) name:NSViewBoundsDidChangeNotification object:self.friendsListCont.friendListView.superview];
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

- (void)updateKeyViewAndRepostTypingEvent:(NSEvent *)event {
    [self.chatViewCont.nextResponder becomeFirstResponder];
    [[NSApplication sharedApplication] postEvent:event atStart:YES];
}

- (void)conversationDidBecomeFocused:(DESConversation *)conversation {
    [self removeKVOHandlers];
    _watchingConversation = conversation;
    if (!conversation)
        return;
    [self updateWindowTitle];
    [_watchingConversation addObserver:self forKeyPath:@"presentableTitle" options:NSKeyValueObservingOptionNew context:NULL];
    self.chatViewCont.conversation = [((SCAppDelegate *)[NSApp delegate]).conversationManager conversationFor:conversation];
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
    [self invalidateDivider];
}

#pragma mark - indicator(s)

- (NSAttributedString *)styledIndicatorText {
    NSMutableAttributedString *base;
    base = [[NSMutableAttributedString alloc] initWithString:@""
                                                  attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]}];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"publicSights"]
        && [_watchingConversation conformsToProtocol:@protocol(DESFriend)]) {
        DESFriend *f = (DESFriend *)_watchingConversation;
        NSString *inf;
        if (f.port != 0) {
            inf = [NSString stringWithFormat:@"%@:%hu • ", f.address, f.port];
        } else if ([f.address isEqualToString:@"tcprelay"]) {
            inf = @"(relayed)";
        } else {
            inf = @"";
        }
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

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view {
    if (view == self.buddyListController.view)
        return NO;
    else
        return YES;
}

//- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
//    CGSize deltas = (CGSize){splitView.frame.size.width - oldSize.width, splitView.frame.size.height - oldSize.height};
//    NSView *expands = (NSView*)splitView.subviews[1];
//    NSView *doesntExpand = (NSView*)splitView.subviews[0];
//    expands.frame = (CGRect){{doesntExpand.frame.size.width + 1, 0}, {expands.frame.size.width + deltas.width, expands.frame.size.height + deltas.height}};
//    doesntExpand.frameSize = (CGSize){splitView.frame.size.width - expands.frame.size.width - 1, splitView.frame.size.height};
//}

- (void)splitView:(SCNonGarbageSplitView *)splitView drawDividerInRect:(NSRect)aRect {
    [[NSColor controlDarkShadowColor] set];
    NSRectFill(aRect);

    CGRect selRect = [self.buddyListController positionOfSelectedRow];
    if (CGRectIsNull(selRect))
        return;
    CGRect tableReg = self.buddyListController.friendListView.superview.superview.frame;
    CGRect tableBoundsInDivider = CGRectMake(aRect.origin.x, aRect.size.height
                                             - tableReg.origin.y - tableReg.size.height,
                                             1, tableReg.size.height);
    [[[SCThemeManager sharedManager] backgroundColorOfCurrentTheme] set];
    NSRectFill(CGRectIntersection(tableBoundsInDivider,
                                  CGRectMake(aRect.origin.x, aRect.size.height -
                                             selRect.origin.y - selRect.size.height,
                                             1, selRect.size.height)));
}

#pragma mark - Window delegate

- (void)invalidateDivider {
    CGRect div = CGRectMake(((NSView *)self.rootView.subviews[0]).frame.size.width,
                            0, 1, self.rootView.frame.size.height);
    [self.rootView setNeedsDisplayInRect:div];
}

- (void)dealloc {
    [self removeKVOHandlers];
    [self.tox removeObserver:self forKeyPath:@"closeNodesCount"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
