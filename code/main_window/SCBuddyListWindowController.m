#include "Copyright.h"

#import "SCBuddyListWindowController.h"
#import "SCBuddyListController.h"
#import "DESToxConnection.h"
#import "CGGeometryExtreme.h"

#define SCBuddyListDefaultWindowFrame ((CGRect){{0, 0}, {290, 400}})
#define SCBuddyListMinimumSize ((CGSize){290, 142})

@interface SCBuddyListWindowController ()
@property (strong) SCBuddyListController *friendsListCont;
@property (weak) DESToxConnection *tox;
@end

@implementation SCBuddyListWindowController {
    NSTextField *_dhtCount;
}

- (instancetype)initWithDESConnection:(DESToxConnection *)tox {
    self = [super initWithDESConnection:tox];
    if (self) {
        SCWidgetedWindow *window = [[SCWidgetedWindow alloc] initWithContentRect:CGRectCentreInRect(SCBuddyListDefaultWindowFrame, [NSScreen mainScreen].visibleFrame) styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:YES];
        window.restorable = NO;
        window.minSize = SCBuddyListMinimumSize;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
        if (SCIsYosemiteOrHigher()) {
            window.titlebarAppearsTransparent = YES;
            window.titleVisibility = NSWindowTitleHidden;
        }
#endif
        [window setFrameUsingName:@"MainWindow"];
        window.frameAutosaveName = @"MainWindow";
        window.title = [NSString stringWithFormat:NSLocalizedString(@"%@ \u2014 Friends", @"friends list window title"), SCApplicationInfoDictKey(@"CFBundleName")];
        _dhtCount = [self newStyledTextField];
        _dhtCount.attributedStringValue = [self styledIndicatorText];
        _dhtCount.toolTip = [self toolTipTextForNodeCount:self.tox.closeNodesCount];
        [_dhtCount sizeToFit];
        [tox addObserver:self forKeyPath:@"closeNodesCount" options:NSKeyValueObservingOptionNew context:NULL];
        window.widgetView = _dhtCount;
        self.window = window;
        self.tox = tox;
        self.friendsListCont = [[SCBuddyListController alloc] initWithNibName:@"FriendsPanel" bundle:[NSBundle mainBundle]];
        [self.friendsListCont loadView];
        [self.friendsListCont attachKVOHandlersToConnection:tox];
        self.friendsListCont.view.frame = ((NSView*)window.contentView).frame;
        self.window.contentView = self.friendsListCont.view;
    }
    return self;
}

- (NSAttributedString *)styledIndicatorText {
    NSMutableAttributedString *base;
    base = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"DHT:", nil)
            attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]}];
    NSString *nodes = [NSString stringWithFormat:@" %lu", (unsigned long)self.tox.closeNodesCount];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        _dhtCount.attributedStringValue = [self styledIndicatorText];
        _dhtCount.toolTip = [self toolTipTextForNodeCount:[change[NSKeyValueChangeNewKey] unsignedIntegerValue]];
        [_dhtCount sizeToFit];
    });
}

- (SCBuddyListController *)buddyListController {
    return self.friendsListCont;
}

- (void)dealloc {
    [self.tox removeObserver:self forKeyPath:@"closeNodesCount"];
}

@end
