#include "Copyright.h"

#import "SCMainWindowController.h"
#import "NSString+CanonicalID.h"
#import "NSURL+Parameters.h"
#import "ObjectiveTox.h"
#import "SCValidationHelpers.h"
#import "SCProfileManager.h"

void *const SCAddFriendSheetContext = (void *)1;

@interface SCMainWindowController ()
@property (weak) DESToxConnection *tox;
@end

@implementation SCMainWindowController

- (instancetype)initWithDESConnection:(DESToxConnection *)tox {
    self = [super init];
    if (self) {
        self.tox = tox;
    }
    return self;
}

- (SCBuddyListController *)buddyListController {
    return nil;
}

- (NSTextField *)newStyledTextField {
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

#pragma mark - sheets

- (void)displayQRCode {
    if (!self.qrPanel)
        self.qrPanel = [[SCQRCodeSheetController alloc] initWithWindowNibName:@"QRSheet"];
    self.qrPanel.friendAddress = self.tox.friendAddress;
    self.qrPanel.name = self.tox.name;
    [NSApp beginSheet:self.qrPanel.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)displayAddFriend {
    if (!self.addPanel)
        self.addPanel = [[SCAddFriendSheetController alloc] initWithWindowNibName:@"AddFriend"];
    [self.addPanel loadWindow];
    [self.addPanel resetFields:YES];
    NSArray *objects = [[NSPasteboard generalPasteboard] readObjectsForClasses:@[[NSString class]] options:nil];
    for (NSString *item in objects) {
        NSString *canonical = item.canonicalToxID;
        if (canonical) {
            self.addPanel.toxID = canonical;
            break;
        }
        if ([item rangeOfString:@"tox://"].location == 0) {
            [self displayAddFriendWithToxSchemeURL:[NSURL URLWithString:item]];
            return;
        }
    }
    [NSApp beginSheet:self.addPanel.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:SCAddFriendSheetContext];
}

- (void)displayAddFriendWithToxSchemeURL:(NSURL *)url {
    if (!self.addPanel)
        self.addPanel = [[SCAddFriendSheetController alloc] initWithWindowNibName:@"AddFriend"];
    [self.addPanel loadWindow];
    [self.addPanel resetFields:YES];

    NSString *cmp = url.host;
    if (url.user)
        cmp = [url.user stringByAppendingString:[NSString stringWithFormat:@"@%@", url.host]];
    if (!(SCQuickValidateID(cmp) || SCQuickValidateDNSDiscoveryID(cmp))) {
        NSAlert *error = [[NSAlert alloc] init];
        error.alertStyle = NSInformationalAlertStyle;
        error.messageText = NSLocalizedString(@"Invalid Tox ID", nil);
        error.informativeText = NSLocalizedString(@"That Tox URL doesn't look right. Are you sure that it's correct?", nil);
        [error addButtonWithTitle:NSLocalizedString(@"Dismiss", nil)];
        [error beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        return;
    }
    [self.addPanel fillWithURL:url];
    [NSApp beginSheet:self.addPanel.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:SCAddFriendSheetContext];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [sheet orderOut:self];
    if (returnCode && contextInfo == SCAddFriendSheetContext) {
        NSString *id_ = self.addPanel.toxID;
        NSString *proposedName = self.addPanel.proposedName;

        if (proposedName) {
            SCProfileManager *p = [SCProfileManager currentProfile];
            NSMutableDictionary *map = [[p privateSettingForKey:@"nicknames"] mutableCopy]?
                                        : [NSMutableDictionary dictionary];
            map[[id_ substringToIndex:DESPublicKeySize * 2]] = proposedName;
            [p setPrivateSetting:map forKey:@"nicknames"];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [p commitPrivateSettings];
            });
        }

        [self.tox addFriendPublicKey:id_ message:self.addPanel.message];
    }
}

@end
