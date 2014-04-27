#include "Copyright.h"

@class SCBuddyListController;

@interface SCGroupRowView : NSTableRowView

@end

@interface SCFriendRowView : NSTableRowView

@end

@interface SCGroupCellView : NSTableCellView
@property (strong) IBOutlet NSTextField *auxLabel;
@end

@interface SCFriendCellView : NSTableCellView
@property (strong) IBOutlet NSTextField *mainLabel;
@property (strong) IBOutlet NSTextField *auxLabel;
@property (strong) IBOutlet NSImageView *light;
@property (strong) IBOutlet NSImageView *avatarView;

@property (weak) SCBuddyListController *manager;
- (void)applyMaskIfRequired;
@end

@interface SCRequestCellView : NSTableCellView
@property (strong) IBOutlet NSTextField *mainLabel;
@property (strong) IBOutlet NSTextField *auxLabel;
@property (strong) IBOutlet NSImageView *avatarView;
@property (strong) IBOutlet NSView *accessoryView;

@property (strong) IBOutlet NSButton *acceptButton;
@property (strong) IBOutlet NSButton *declineButton;

@property (weak) SCBuddyListController *manager;
- (void)applyMaskIfRequired;
@end