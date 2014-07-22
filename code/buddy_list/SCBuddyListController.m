#include "Copyright.h"

#import "ObjectiveTox.h"
#import "SCMainWindowing.h"
#import "SCBuddyListController.h"
#import "SCGradientView.h"
#import "SCProfileManager.h"
#import "SCBuddyListShared.h"
#import "SCBuddyListCells.h"
#import "SCAppDelegate.h"
#import "SCBuddyListManager.h"
#import "DESConversation+Poison_CustomName.h"
#import "SCRequestDialogController.h"
#import "SCFillingView.h"
#import "SCAvatarView.h"
#import "SCFriendRequest.h"
#import <Quartz/Quartz.h>

#define SC_MAX_CACHED_ROW_COUNT (50)

@interface SCDoubleClickingImageView : SCAvatarView

@end

@implementation SCDoubleClickingImageView {
    NSTrackingArea *_trackingArea;
    CALayer *_overlayer;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self updateTrackingAreas];
}

- (void)updateTrackingAreas {
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                                   owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if (!_overlayer) {
        _overlayer = [CALayer layer];
        [CATransaction begin];
        _overlayer.frame = (CGRect){CGPointZero, self.frame.size};
        _overlayer.contents = [NSImage imageNamed:@"ellipsis-overlay"];
        [CATransaction commit];
    }
    if ([self.layer.sublayers containsObject:_overlayer])
        return;
    [self.layer addSublayer:_overlayer];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [_overlayer removeFromSuperlayer];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if (self.action)
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:self];
        #pragma clang diagnostic pop
    else
        [super mouseDown:theEvent];
}

@end

@interface SCBuddyListController ()
@property (strong) IBOutlet SCGradientView *userInfo;
@property (strong) IBOutlet SCGradientView *toolbar;
@property (strong) IBOutlet SCGradientView *auxiliaryView;
@property (strong) IBOutlet NSMenu *friendMenu;
@property (strong) IBOutlet NSMenu *selfMenu;
@property (strong) IBOutlet NSSearchField *filterField;
#pragma mark - self info
@property (strong) IBOutlet NSTextField *nameField;
@property (strong) IBOutlet NSTextField *statusField;
@property (strong) IBOutlet NSImageView *statusDot;
@property (strong) IBOutlet NSImageView *avatarView;
#pragma mark - Change name and status
@property (strong) IBOutlet NSPanel *identityEditorSheet;
@property (strong) IBOutlet NSTextField *ieNameField;
@property (strong) IBOutlet NSTextField *ieStatusField;
@property (strong) IBOutlet NSPopUpButton *ieStatusChooser;

@property (strong) IBOutlet NSPanel *nicknameEditorSheet;
@property (strong) IBOutlet NSTextField *origNameLabel;
@property (strong) IBOutlet NSTextField *nicknameField;
@end

@implementation SCBuddyListController {
    DESToxConnection *_watchingConnection;
    NSDateFormatter *_formatter;
    SCBuddyListManager *_dataSource;
    SCRequestDialogController *_requestSheet;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _formatter = [[NSDateFormatter alloc] init];
        _formatter.doesRelativeDateFormatting = YES;
        _formatter.timeStyle = NSDateFormatterShortStyle;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    NSView *backing;

    SCFillingView *b = [[SCFillingView alloc] initWithFrame:self.view.bounds];
    b.wantsLayer = YES;
    b.drawColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    b.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    backing = b;
    [backing addSubview:self.view];
    self.view = backing;

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
    if ([NSVisualEffectView class]) {
        NSView *realView = b.subviews[0];
        [realView removeFromSuperviewWithoutNeedingDisplay];
        realView.autoresizesSubviews = NO;
        CGSize newSize = (CGSize){realView.frame.size.width, realView.frame.size.height + 22};
        realView.frameSize = newSize;
        b.frameSize = newSize;
        self.userInfo.isFlushWithTitlebar = YES;
        self.userInfo.frameSize = (CGSize){self.userInfo.frame.size.width, self.userInfo.frame.size.height + 22};
        [b addSubview:realView];
        realView.autoresizesSubviews = YES;

        NSVisualEffectView *blurView = [[NSVisualEffectView alloc] initWithFrame:b.bounds];
        blurView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        blurView.state = NSVisualEffectStateActive;
        
        [blurView addSubview:b];
        b.drawColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.2];
        self.view = blurView;
    }
#endif
}

- (void)applyColoursBelowYosemite {
    self.userInfo.topColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    self.userInfo.bottomColor = [NSColor colorWithCalibratedWhite:0.09 alpha:1.0];
    self.userInfo.shadowColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];

    self.toolbar.topColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    self.toolbar.bottomColor = [NSColor colorWithCalibratedWhite:0.15 alpha:1.0];
    self.toolbar.shadowColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];

    self.auxiliaryView.topColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
    self.auxiliaryView.bottomColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    self.auxiliaryView.borderColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
    self.auxiliaryView.shadowColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];
}

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
- (void)applyColoursAboveYosemite {
    self.userInfo.topColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.7];
    self.userInfo.bottomColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.4];

    self.toolbar.topColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.0];
    self.toolbar.bottomColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.3];

    self.auxiliaryView.topColor = nil;
    self.auxiliaryView.bottomColor = nil;
    self.filterField.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
}
#endif

- (void)awakeFromNib {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
    if ([NSVisualEffectView class])
        [self applyColoursAboveYosemite];
    else
#endif
        [self applyColoursBelowYosemite];

    self.userInfo.dragsWindow = YES;
    self.toolbar.dragsWindow = YES;
    self.auxiliaryView.dragsWindow = YES;
    self.filterField.delegate = self;

    self.friendListView.target = self;
    self.friendListView.doubleAction = @selector(openAuxiliaryWindowForSelectedRow:);
    self.friendListView.action = @selector(didClickButNotSelect:);
    self.selfMenu.delegate = self;

    SCAvatar *avatar = [SCProfileManager currentProfile].avatar;
    self.avatarView.image = avatar.rep;
}

- (void)detachHandlersFromConnection {
    [_watchingConnection removeObserver:self forKeyPath:@"name"];
    [_watchingConnection removeObserver:self forKeyPath:@"statusMessage"];
    [_watchingConnection removeObserver:self forKeyPath:@"status"];
    [_dataSource removeObserver:self forKeyPath:@"orderingList"];
    _dataSource = nil;
    self.friendListView.dataSource = nil;
}

- (void)attachKVOHandlersToConnection:(DESToxConnection *)tox {
    [self detachHandlersFromConnection];
    _watchingConnection = tox;
    [tox addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
    [tox addObserver:self forKeyPath:@"statusMessage" options:NSKeyValueObservingOptionNew context:NULL];
    [tox addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    _dataSource = [[SCBuddyListManager alloc] initWithConnection:tox];
    [_dataSource addObserver:self forKeyPath:@"orderingList" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
    self.friendListView.dataSource = _dataSource;

    if (tox.isActive) {
        self.nameField.stringValue = tox.name;
        self.statusField.stringValue = tox.statusMessage;
        self.statusDot.image = SCImageForFriendStatus(tox.status);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    change = [change copy];
    if (object == _dataSource) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger selectedIndex = self.friendListView.selectedRow;
            [self.friendListView reloadData];
            if ([change[NSKeyValueChangeOldKey] count] < [change[NSKeyValueChangeNewKey] count]) {
                selectedIndex = MAX(selectedIndex - 1, 0);
            }
            [self.friendListView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
            /*if (change[NSKeyValueChangeOldKey] == [NSNull null]) {
                [self.friendListView reloadData];
                return;
            }
            
            NSMutableArray *shadowOrder = [change[NSKeyValueChangeOldKey] mutableCopy];

            NSArray *newValues = change[NSKeyValueChangeNewKey];
            NSMutableIndexSet *opList = [NSMutableIndexSet indexSet];

            for (int i = 0; i < shadowOrder.count; ++i) {
                if (![newValues containsObject:shadowOrder[i]])
                    [opList addIndex:i];
            }
            [shadowOrder removeObjectsAtIndexes:opList];
            [self.friendListView beginUpdates];
            [self.friendListView removeRowsAtIndexes:opList withAnimation:NSTableViewAnimationEffectGap | NSTableViewAnimationSlideUp];
            [self.friendListView endUpdates];

            [opList removeAllIndexes];
            for (int i = 0; i < newValues.count; ++i) {
                if (![shadowOrder containsObject:newValues[i]])
                    [opList addIndex:i];
            }
            [self.friendListView beginUpdates];
            [self.friendListView insertRowsAtIndexes:opList withAnimation:NSTableViewAnimationEffectGap | NSTableViewAnimationSlideDown];
            [self.friendListView endUpdates];

            [self.friendListView beginUpdates];
            NSIndexSet *allIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newValues.count)];
            [self.friendListView reloadDataForRowIndexes:allIndexes columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            [self.friendListView noteHeightOfRowsWithIndexesChanged:allIndexes];
            [self.friendListView endUpdates];*/
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([keyPath isEqualToString:@"name"]) {
            self.nameField.stringValue = change[NSKeyValueChangeNewKey];
        } else if ([keyPath isEqualToString:@"statusMessage"]) {
            self.statusField.stringValue = change[NSKeyValueChangeNewKey];
        } else if ([keyPath isEqualToString:@"status"]) {
            self.statusDot.image = SCImageForFriendStatus((DESFriendStatus)((NSNumber *)change[NSKeyValueChangeNewKey]).intValue);
        }
    });
}

- (DESConversation *)conversationSelectedInView {
    if (self.friendListView.selectedRow == -1)
        return nil;
    return [_dataSource objectAtRowIndex:self.friendListView.selectedRow];
}

#pragma mark - ui crap

- (IBAction)changeName:(id)sender {
    [self presentChangeSheetHighlightingField:0];
}

- (IBAction)changeStatus:(id)sender {
    [self presentChangeSheetHighlightingField:1];
}

- (void)presentChangeSheetHighlightingField:(NSInteger)field {
    self.ieNameField.stringValue = _watchingConnection.name;
    self.ieStatusField.stringValue = _watchingConnection.statusMessage;
    [self.ieStatusChooser selectItemAtIndex:(NSInteger)_watchingConnection.status];

    [NSApp beginSheet:self.identityEditorSheet
       modalForWindow:self.view.window
        modalDelegate:self
       didEndSelector:@selector(commitIdentityChangesFromSheet:returnCode:userInfo:)
          contextInfo:NULL];

    switch (field) {
        case 0:
            [self.ieNameField selectText:self];
            [self.ieNameField becomeFirstResponder];
            break;
        case 1:
            [self.ieStatusField selectText:self];
            [self.ieStatusField becomeFirstResponder];
            break;
        default:
            break;
    }
}

- (void)commitIdentityChangesFromSheet:(NSWindow *)sheet returnCode:(NSInteger)ret userInfo:(void *)ignored {
    [sheet orderOut:self];
    if (!ret)
        return;
    if ((![self.ieNameField.stringValue isEqualToString:_watchingConnection.name])
        || [self.ieNameField.stringValue isEqualToString:@""]) {
        _watchingConnection.name = [self.ieNameField.stringValue isEqualToString:@""]?
                                    ((SCAppDelegate *)[NSApp delegate]).profileName
                                    : self.ieNameField.stringValue;
    }
    if ((![self.ieStatusField.stringValue isEqualToString:_watchingConnection.statusMessage])
        || [self.ieStatusField.stringValue isEqualToString:@""]) {
        _watchingConnection.statusMessage = [self.ieStatusField.stringValue isEqualToString:@""]?
                                             SCStringForFriendStatus(self.ieStatusChooser.selectedTag)
                                             : self.ieStatusField.stringValue;
    }
    if (self.ieStatusChooser.selectedTag != _watchingConnection.status) {
        _watchingConnection.status = self.ieStatusChooser.selectedTag;
    }
}

- (IBAction)finishAndCommit:(NSButton *)sender {
    [NSApp endSheet:self.view.window.attachedSheet returnCode:sender.tag];
}

#pragma mark - table

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    NSTableRowView *rowView;
    if ([self tableView:tableView isGroupRow:row]) {
        rowView = [tableView makeViewWithIdentifier:@"GroupMarkRow" owner:self];
        if (!rowView) {
            rowView = [[SCGroupRowView alloc] initWithFrame:CGRectZero];
            rowView.identifier = @"GroupMarkRow";
        }
    } else {
        rowView = [tableView makeViewWithIdentifier:@"FriendRow" owner:self];
        if (!rowView) {
            rowView = [[SCFriendRowView alloc] initWithFrame:CGRectZero];
            rowView.identifier = @"FriendRow";
        }
    }
    return rowView;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([self tableView:tableView isGroupRow:row]) {
        return [tableView makeViewWithIdentifier:@"GroupMarker" owner:nil];
    } else {
        id objectValue = [_dataSource objectAtRowIndex:row];
        NSString *cellKind;
        if ([objectValue isKindOfClass:[DESRequest class]])
            cellKind = @"RequestCell";
        else
            cellKind = @"FriendCell";
        /* it could be any kind of cell, really
         * we don't judge */
        SCFriendCellView *dequeued = [tableView makeViewWithIdentifier:cellKind
                                                                 owner:nil];
        dequeued.manager = self;
        if ([cellKind isEqualToString:@"RequestCell"]) {
            ((SCRequestCellView *)dequeued).acceptButton.target = self;
            ((SCRequestCellView *)dequeued).acceptButton.action = @selector(acceptRequestFromCell:);
            ((SCRequestCellView *)dequeued).declineButton.target = self;
            ((SCRequestCellView *)dequeued).declineButton.action = @selector(declineRequestFromCell:);
        }
        return dequeued;
    }
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    return (BOOL)([_dataSource objectAtRowIndex:row] == nil);
}

- (NSMenu *)tableView:(NSTableView *)tableView menuForRow:(NSInteger)row {
    id thing = [_dataSource objectAtRowIndex:row];
    if ([thing conformsToProtocol:@protocol(DESConversation)]) {
        id<DESConversation> conv = thing;
        if (conv.type == DESConversationTypeFriend)
            return self.friendMenu;
        else
            return nil; /* FIXME: implement */
    }
    return nil;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (![_dataSource objectAtRowIndex:row])
        return 17;
    else
        return 40;
}

- (void)openAuxiliaryWindowForSelectedRow:(NSTableView *)sender {
    id model = [_dataSource objectAtRowIndex:sender.selectedRow];
    if (![model conformsToProtocol:@protocol(DESConversation)])
        return;
    else
        [(SCAppDelegate *)[NSApp delegate] focusWindowForConversation:model];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    id model = [_dataSource objectAtRowIndex:row];
    if ([model conformsToProtocol:@protocol(DESConversation)]) {
        if ([self.view.window.windowController respondsToSelector:@selector(conversationDidBecomeFocused:)]) {
            [self.view.window.windowController conversationDidBecomeFocused:model];
        }
        return YES;
    }
    return NO;
}

- (void)didClickButNotSelect:(NSTableView *)sender {
    id model = [_dataSource objectAtRowIndex:sender.clickedRow];
    if ([model isKindOfClass:[DESRequest class]]) {
        if (!_requestSheet)
            _requestSheet = [[SCRequestDialogController alloc] initWithWindowNibName:@"RequestDialog"];
        [_requestSheet loadWindow];
        _requestSheet.request = model;
        [NSApp beginSheet:_requestSheet.window modalForWindow:self.view.window modalDelegate:self didEndSelector:@selector(requestSheet:didEndWithReturnCode:contextInfo:) contextInfo:NULL];
    }
}

//- (void)tableViewSelectionDidChange:(NSNotification *)notification {
//    if ([self.view.window.windowController respondsToSelector:@selector(conversationDidBecomeFocused:)]) {
//        DESConversation *cv = [_dataSource objectAtRowIndex:self.friendListView.selectedRow];
//        [self.view.window.windowController conversationDidBecomeFocused:cv];
//    }
//}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == self.selfMenu) {
        [[menu itemAtIndex:0] setTitle:[NSString stringWithFormat:@"PIN: %@", _watchingConnection.PIN]];
    } else {
        NSUInteger ci = ((SCSelectiveMenuTableView *)self.friendListView).menuSelectedRow;
        DESConversation *conv = [_dataSource objectAtRowIndex:ci];
        [menu itemAtIndex:0].title = conv.preferredUIName;
    }
}

- (NSRect)positionOfSelectedRow {
    if (self.friendListView.selectedRow != -1) {
        NSView *sel = [self.friendListView viewAtColumn:0 row:self.friendListView.selectedRow makeIfNecessary:NO];
        if (sel) {
            return [sel convertRect:sel.bounds toView:self.view];
        }
    }
    return CGRectNull;
}

#pragma mark - cell server

- (NSString *)formatDate:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *now = [cal components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                   fromDate:[NSDate date]];
    NSDateComponents *then = [cal components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                    fromDate:date];
    if (now.day == then.day && now.month == then.month && now.year == then.year)
        _formatter.dateStyle = NSDateFormatterNoStyle;
    else
        _formatter.dateStyle = NSDateFormatterShortStyle;
    return [_formatter stringFromDate:date];
}

- (void)dealloc {
    [self detachHandlersFromConnection];
}

#pragma mark - misc menus
- (IBAction)confirmRandomizeNospam:(id)sender {
    NSAlert *prompt = [[NSAlert alloc] init];
    prompt.messageText = NSLocalizedString(@"Change PIN", nil);
    prompt.informativeText = NSLocalizedString(@"People will no longer be able to add you using your current ID. However, friends that you have already confirmed will not be affected. Are you sure you want to do this?", nil);
    [prompt addButtonWithTitle:NSLocalizedString(@"Change", nil)];
    [prompt addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [prompt beginSheetModalForWindow:self.view.window modalDelegate:self didEndSelector:@selector(commitChangingNospam:returnCode:userInfo:) contextInfo:NULL];
}

- (IBAction)showAddFriend:(id)sender {
    [(SCAppDelegate *)[NSApp delegate] addFriend:self];
}

- (IBAction)proxyCopyToxID:(id)sender {
    [(SCAppDelegate *)[NSApp delegate] copyPublicID:self];
}

- (IBAction)removeFriendConfirm:(id)sender {
    DESFriend *f = (DESFriend *)[_dataSource objectAtRowIndex:((SCSelectiveMenuTableView *)self.friendListView).selectedRow];
    if (![f conformsToProtocol:@protocol(DESFriend)])
        return;
    [(SCAppDelegate *)[NSApp delegate] deleteFriend:f confirmingInWindow:self.view.window];
}

- (IBAction)presentNicknameEditor:(id)sender {
    DESFriend *f = (DESFriend *)[_dataSource objectAtRowIndex:((SCSelectiveMenuTableView *)self.friendListView).menuSelectedRow];
    if (![f conformsToProtocol:@protocol(DESFriend)])
        return;

    NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *displayName = f.name;
    if ([[displayName stringByTrimmingCharactersInSet:cs] isEqualToString:@""])
        displayName = [NSString stringWithFormat:NSLocalizedString(@"Unknown (%@)", nil), [f.publicKey substringToIndex:8]];

    CGFloat frameHeightNormal = (self.nicknameEditorSheet.frame.size.height
                                 - self.origNameLabel.frame.size.height);
    CGRect bb = [displayName boundingRectWithSize:(NSSize){self.origNameLabel.frame.size.width}
                             options:NSStringDrawingUsesLineFragmentOrigin
                             attributes:@{NSFontAttributeName: self.origNameLabel.font}];
    [self.nicknameEditorSheet setFrame:(CGRect){CGPointZero, {self.nicknameEditorSheet.frame.size.width, frameHeightNormal + bb.size.height}} display:NO];

    self.origNameLabel.stringValue = displayName;
    self.nicknameField.stringValue = f.customName;
    ((NSTextFieldCell *)self.nicknameField.cell).placeholderString = displayName;
    [NSApp beginSheet:self.nicknameEditorSheet modalForWindow:self.view.window modalDelegate:self didEndSelector:@selector(commitNicknameFromSheet:returnCode:userInfo:) contextInfo:(__bridge void *)(f)];
    [self.nicknameField becomeFirstResponder];
    [self.nicknameField selectText:self];
}

- (void)commitNicknameFromSheet:(NSWindow *)sheet returnCode:(NSInteger)ret userInfo:(void *)friend {
    //NSLog(@"commit %@ for %@", self.nicknameField.stringValue, (__bridge id)friend);
    DESFriend *f = (__bridge DESFriend *)friend;
    NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *dn = [self.nicknameField.stringValue stringByTrimmingCharactersInSet:cs];
    SCProfileManager *p = [SCProfileManager currentProfile];

    if (ret == 0) {
        [sheet orderOut:self];
        self.nicknameField.stringValue = @"";
        return;
    }

    NSMutableDictionary *map = [[p privateSettingForKey:@"nicknames"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (ret == 2 || [dn isEqualToString:@""]) {
        [map removeObjectForKey:f.publicKey];
    } else if (ret == 1) {
        map[f.publicKey] = dn;
    }

    [p setPrivateSetting:map forKey:@"nicknames"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [p commitPrivateSettings];
    });

    self.nicknameField.stringValue = @"";
    [sheet orderOut:self];
    [self.friendListView reloadData];
}

- (void)commitChangingNospam:(NSWindow *)sheet returnCode:(NSInteger)ret userInfo:(void *)unused {
    if (ret == NSAlertFirstButtonReturn) {
        uint8_t newpin[4];
        arc4random_buf(&newpin, 4);
        [_watchingConnection setPIN:[NSData dataWithBytes:newpin length:4]];
    }
}

#pragma mark - searching

- (void)controlTextDidChange:(NSNotification *)obj {
    _dataSource.filterString = self.filterField.stringValue;
}

#pragma mark - avatars

- (IBAction)clickAvatarImage:(id)sender {
    NSEvent *orig = [NSApp currentEvent];
    [self.selfMenu popUpMenuPositioningItem:nil
                                 atLocation:orig.locationInWindow
                                     inView:self.view.window.contentView];
}

- (IBAction)changeAvatar:(id)sender {
    IKPictureTaker *taker = [IKPictureTaker pictureTaker];
    taker.inputImage = self.avatarView.image;
    [taker beginPictureTakerSheetForWindow:self.view.window withDelegate:self
                            didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                               contextInfo:NULL];
}

- (void)pictureTakerDidEnd:(IKPictureTaker *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSImage *im = sheet.outputImage;
        SCProfileManager *profile = [SCProfileManager currentProfile];
        profile.avatar = im;
        self.avatarView.image = profile.avatar.rep;
        [(SCAppDelegate *)[NSApplication sharedApplication].delegate sendAvatarPacket:nil];
    }
}

#pragma mark - the friend request sheet

- (void)requestSheet:(NSWindow *)sheet didEndWithReturnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode) {
        /* FIXME: this should go somewhere else */
        [_requestSheet.request accept];
    }
    [sheet orderOut:self];
    _requestSheet = nil;
}

#pragma mark - request cell buttons

- (IBAction)acceptRequestFromCell:(NSView *)sender {
    SCFriendRequest *model = ((NSTableCellView *)sender.superview.superview).objectValue;
    if (!_requestSheet)
        _requestSheet = [[SCRequestDialogController alloc] initWithWindowNibName:@"RequestDialog"];
    [_requestSheet loadWindow];
    _requestSheet.request = model;
    [NSApp beginSheet:_requestSheet.window modalForWindow:self.view.window modalDelegate:self didEndSelector:@selector(requestSheet:didEndWithReturnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)declineRequestFromCell:(NSView *)sender {
    DESRequest *model = ((NSTableCellView *)sender.superview.superview).objectValue;
    [model decline];
}

@end
