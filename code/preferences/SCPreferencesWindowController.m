// You will not find the licensing jibber-jabber here.
// Go read it elsewhere.

#import "SCPreferencesWindowController.h"

@implementation SCPreferencesWindowController {
    NSViewController *currentPane;
    NSString *previousSelectedItemIdentifier;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    for (NSToolbarItem *toolbarItem in [self.toolbar items]) {
        toolbarItem.target = self;
        toolbarItem.action = @selector(didChangeSettingsPane:);
    }
    previousSelectedItemIdentifier = @"";
    self.toolbar.selectedItemIdentifier = @"GeneralPane";
    [self didChangeSettingsPane:self.toolbar.items[0]];
}

- (IBAction)didChangeSettingsPane:(NSToolbarItem *)sender {
    NSString *nibToLoad = sender.itemIdentifier;
    if ([nibToLoad isEqualToString:previousSelectedItemIdentifier]) return;
    CGFloat chromeHeight = self.window.frame.size.height - ((NSView*)self.window.contentView).bounds.size.height;
    NSNib *theNib = [[NSNib alloc] initWithNibNamed:nibToLoad bundle:[NSBundle mainBundle]];
    NSArray *objects = nil;
    BOOL success = NO;
    if (SCIsMountainLionOrHigher()) {
        success = [theNib instantiateWithOwner:self topLevelObjects:&objects];
    } else {
        success = [theNib instantiateNibWithOwner:self topLevelObjects:&objects];
    }
    if (success && [objects count] > 0) {
        /* hack; retain the current prefcontroller to avoid a premature-release crash. */
        NSViewController *willShow;
        for (id theView in objects) {
            if ([theView isKindOfClass:[NSViewController class]]) {
                willShow = (NSViewController*)theView;
                break;
            }
        }
        [self.window.contentView setHidden:YES];
        [self.window setFrame:(NSRect){{self.window.frame.origin.x, self.window.frame.origin.y - (willShow.view.frame.size.height + chromeHeight - self.window.frame.size.height)}, {willShow.view.frame.size.width, willShow.view.frame.size.height + chromeHeight}} display:YES animate:YES];
        [self.window setContentView:willShow.view];
        currentPane = willShow;
        [self.window.contentView setHidden:NO];
    }
}

@end
