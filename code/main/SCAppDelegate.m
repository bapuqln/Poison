#include "Copyright.h"

#import "DESToxConnection.h"
#import "SCAppDelegate.h"
#import "SCBuddyListWindowController.h"
#import "SCUnifiedWindowController.h"
#import "SCNewUserWindowController.h"
#import "SCGradientView.h"
#import "SCShadowedView.h"
#import "SCProfileManager.h"
#import "SCWidgetedWindow.h"
#import "SCResourceBundle.h"
#import "SCMenuStatusView.h"
#import "SCFriendRequest.h"
#import "SCStandaloneWindowController.h"
#import "DESConversation+Poison_CustomName.h"
#import "SCConversationManager.h"

/* note: this is hard-coded to make tampering harder. */
#define SCApplicationDownloadPage (@"http://download.tox.im/")

@interface SCAppDelegate ()
@property (strong) DESToxConnection *toxConnection;
@property (strong) NSString *profileName;
@property (strong) NSString *profilePass;
@property (weak) IBOutlet NSMenuItem *akiUserInfoMenuItemPlaceholder;
@property (weak) IBOutlet SCMenuStatusView *userInfoMenuItem;
#pragma mark - Tox menu
@property (weak) IBOutlet NSMenuItem *changeNameMenuItem;
@property (weak) IBOutlet NSMenuItem *changeStatusMenuItem;
@property (weak) IBOutlet NSMenuItem *savePublicAddressMenuItem;
@property (weak) IBOutlet NSMenuItem *genQRCodeMenuItem;
@property (weak) IBOutlet NSMenuItem *addFriendMenuItem;
@property (weak) IBOutlet NSMenuItem *logOutMenuItem;
#pragma mark - Dock menu
@property (weak) IBOutlet NSMenu *dockMenu;
@property (strong) NSMenuItem *dockNameMenuItem;
@property (strong) NSMenuItem *dockStatusMenuItem;
#pragma mark - AboutWindow
@property (weak) IBOutlet SCGradientView *aboutHeader;
@property (weak) IBOutlet SCShadowedView *aboutFooter;
@property (unsafe_unretained) IBOutlet NSWindow *aboutWindow;
@property (weak) IBOutlet NSTextField *aboutWindowApplicationNameLabel;
@property (weak) IBOutlet NSTextField *aboutWindowVersionLabel;
@property (unsafe_unretained) IBOutlet NSWindow *ackWindow;
@property (unsafe_unretained) IBOutlet NSTextView *ackTextView;
#pragma mark - Misc. state
@property (strong) id activityToken;
@property BOOL userIsWaitingOnApplicationExit;
@property (strong) NSURL *waitingToxURL;
@end

@implementation SCAppDelegate {
    NSMutableDictionary *_requests;
    NSMutableDictionary *_auxiliaryChatWindows;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    NSAppleEventManager *ae = [NSAppleEventManager sharedAppleEventManager];
    [ae setEventHandler:self
            andSelector:@selector(handleURLEvent:withReplyEvent:)
          forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"DefaultDefaults" withExtension:@"plist"]];
    NSLog(@"Default settings loaded: %@", defaults);
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

    if (SCCodeSigningStatus == SCCodeSigningStatusInvalid) {
        NSAlert *warning = [[NSAlert alloc] init];
        warning.messageText = NSLocalizedString(@"Code Signature Invalid", nil);
        [warning addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
        NSString *downloadText = [NSString stringWithFormat:NSLocalizedString(@"Download %@", nil),
                                  SCApplicationInfoDictKey(@"CFBundleName")];
        [warning addButtonWithTitle:NSLocalizedString(@"Ignore", nil)];
        [warning addButtonWithTitle:downloadText];
        NSString *infoText = NSLocalizedString(@"This copy of %1$@ DID NOT pass code signature verification!\n"
                                               @"It probably has a botnet in it. Please download %1$@ again from %2$@.", nil);
        warning.informativeText = [NSString stringWithFormat:infoText,
                                   SCApplicationInfoDictKey(@"CFBundleName"), SCApplicationDownloadPage];
        warning.alertStyle = NSCriticalAlertStyle;
        NSInteger ret = [warning runModal];
        if (ret == NSAlertFirstButtonReturn) {
            [NSApp terminate:self];
        } else if (ret == NSAlertThirdButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SCApplicationDownloadPage]];
            [NSApp terminate:self];
        }
    }

    NSString *autologinUsername = [[NSUserDefaults standardUserDefaults] stringForKey:@"autologinUsername"];
    SCNewUserWindowController *login = [[SCNewUserWindowController alloc] initWithWindowNibName:@"NewUser"];
    [login loadWindow];
    self.mainWindowController = login;
    if ([SCProfileManager profileNameExists:autologinUsername]) {
        [login tryAutomaticLogin:autologinUsername];
    } else {
        [login showWindow:self];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (![self.mainWindowController conformsToProtocol:@protocol(SCMainWindowing)]) {
        if (menuItem.action == @selector(copyPublicID:)
            || menuItem.action == @selector(showQRCode:)
            || menuItem.action == @selector(logOutFromUI:)
            || menuItem.action == @selector(changeName:)
            || menuItem.action == @selector(changeStatus:))
            return NO;
    }
    return YES;
}

- (void)makeApplicationReadyForToxing:(txd_intermediate_t)userProfile name:(NSString *)profileName password:(NSString *)pass {
    self.profileName = profileName;
    self.profilePass = pass;
    self.toxConnection = [[DESToxConnection alloc] init];
    self.toxConnection.delegate = self;
    self.akiUserInfoMenuItemPlaceholder.view = self.userInfoMenuItem;
    self.conversationManager = [[SCConversationManager alloc] init];
    _auxiliaryChatWindows = [[NSMutableDictionary alloc] initWithCapacity:5];

    [self.dockMenu removeItemAtIndex:0];
    if (!self.dockStatusMenuItem)
        self.dockStatusMenuItem = [[NSMenuItem alloc] init];
    [self.dockMenu insertItem:self.dockStatusMenuItem atIndex:0];
    if (!self.dockNameMenuItem)
        self.dockNameMenuItem = [[NSMenuItem alloc] init];
    [self.dockMenu insertItem:self.dockNameMenuItem atIndex:0];

    [self.toxConnection addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
    [self.toxConnection addObserver:self forKeyPath:@"statusMessage" options:NSKeyValueObservingOptionNew context:NULL];
    if (userProfile) {
        [self.toxConnection restoreDataFromTXDIntermediate:userProfile];
        txd_intermediate_free(userProfile);
    } else {
        self.toxConnection.name = profileName;
        NSString *defaultStatus = [NSString stringWithFormat:NSLocalizedString(@"Toxing on %@ %@", @"default status message"),
                                   SCApplicationInfoDictKey(@"SCDevelopmentName"),
                                   SCApplicationInfoDictKey(@"CFBundleShortVersionString")];
        self.toxConnection.statusMessage = defaultStatus;
        [self saveProfile];
    }
    [self prepareFriendRequests];
    [self.toxConnection start];
    if ([self.mainWindowController isKindOfClass:[SCNewUserWindowController class]])
        [self.mainWindowController close];
    Class preferredWindowClass = SCBoolPreference(@"forcedMultiWindowUI")?
        [SCBuddyListWindowController class] : [SCUnifiedWindowController class];
    self.mainWindowController = [[preferredWindowClass alloc] initWithDESConnection:self.toxConnection];
    [self.mainWindowController showWindow:self];
    if (self.waitingToxURL && [self.mainWindowController conformsToProtocol:@protocol(SCMainWindowing)]) {
        [(id<SCMainWindowing>)self.mainWindowController displayAddFriendWithToxSchemeURL:self.waitingToxURL];
        self.waitingToxURL = nil;
    }
}

- (void)removeFriend:(DESFriend *)f {
    [self.toxConnection deleteFriend:f];
}

#pragma mark - friend requests

- (NSSet *)requests {
    return [NSSet setWithArray:[_requests allValues]];
}

- (void)prepareFriendRequests {
    [self willChangeValueForKey:@"requests"];
    NSArray *presRequests = [SCProfileManager privateSettingForKey:@"friendRequests"];
    if (!presRequests || ![presRequests isKindOfClass:[NSArray class]]) {
        _requests = [[NSMutableDictionary alloc] init];
    } else {
        _requests = [[NSMutableDictionary alloc] initWithCapacity:presRequests.count];
        for (SCFriendRequest *fr in presRequests) {
            if ([self.toxConnection friendWithKey:fr.senderName])
                continue;
            _requests[fr.senderName] = fr;
        }
    }
    [self didChangeValueForKey:@"requests"];
}

- (void)archiveFriendRequests {
    [SCProfileManager setPrivateSetting:[_requests allValues] forKey:@"friendRequests"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [SCProfileManager commitPrivateSettings];
    });
}

- (void)destroyFriendRequest:(SCFriendRequest *)request {
    [self willChangeValueForKey:@"requests"];
    [_requests removeObjectForKey:request.senderName];
    [self didChangeValueForKey:@"requests"];
    [self archiveFriendRequests];
}

#pragma mark - Opening stuff

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    NSLog(@"whoops, not implemented");
    return NO;
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    NSURL *url = [NSURL URLWithString:urlString relativeToURL:[NSURL URLWithString:@"tox:///"]];
    NSLog(@"%@ %@ %@", [url host] ?: [url path], [url scheme], [url query]);
    if ([self.mainWindowController conformsToProtocol:@protocol(SCMainWindowing)])
        [(id<SCMainWindowing>)self.mainWindowController displayAddFriendWithToxSchemeURL:url];
    else
        self.waitingToxURL = url; /* We'll look at this later. */
}

#pragma mark - other appdelegate stuff

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    if ([self.mainWindowController conformsToProtocol:@protocol(SCMainWindowing)])
        return NO;
    else
        return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [self.mainWindowController.window performClose:self];
    if (self.mainWindowController.window.isVisible)
        return NSTerminateCancel; /* if the main window won't close then we shouldn't pretend we can quit either */
    /* todo: close aux. windows */
    if (self.toxConnection) {
        self.userIsWaitingOnApplicationExit = YES;
        [self logOut];
        return NSTerminateLater;
    } else {
        return NSTerminateNow;
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self.mainWindowController.window makeKeyAndOrderFront:self];
    return YES;
}

#pragma mark - des delegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    change = [change copy];
    /* safeguard against segfaults due to KVO from foreign thread */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self saveProfile];
        if ([keyPath isEqualToString:@"name"]) {
            NSString *displayStr;
            if ([change[NSKeyValueChangeNewKey] isEqualToString:self.profileName])
                displayStr = self.profileName;
            else
                displayStr = [NSString stringWithFormat:@"%@ (%@)",
                              self.profileName, change[NSKeyValueChangeNewKey]];
            self.userInfoMenuItem.name = displayStr;
            self.dockNameMenuItem.title = displayStr;
        } else {
            self.userInfoMenuItem.statusMessage = change[NSKeyValueChangeNewKey];
            self.dockStatusMenuItem.title = change[NSKeyValueChangeNewKey];
        }
    });
}

- (void)saveProfile {
    if (!self.toxConnection)
        return;
    [[NSProcessInfo processInfo] disableSuddenTermination];
    txd_intermediate_t data = [self.toxConnection createTXDIntermediate];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [SCProfileManager saveProfile:data name:self.profileName password:self.profilePass];
        txd_intermediate_free(data);
        [[NSProcessInfo processInfo] enableSuddenTermination];
    });
}

- (void)didReceiveFriendRequest:(DESRequest *)request onConnection:(DESToxConnection *)connection {
    [self willChangeValueForKey:@"requests"];
    _requests[request.senderName] = [[SCFriendRequest alloc] initWithDESRequest:request];
    [self archiveFriendRequests];
    [self didChangeValueForKey:@"requests"];
}

- (void)didReceiveGroupChatInvite:(DESRequest *)request fromFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection {

}

- (void)connectionDidBecomeActive:(DESToxConnection *)connection {
    [[NSProcessInfo processInfo] disableAutomaticTermination:@"DESConnection"];
    self.activityToken = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep reason:@"DESConnection"];
}

- (void)connectionDidBecomeInactive:(DESToxConnection *)connection {
    [[NSProcessInfo processInfo] enableAutomaticTermination:@"DESConnection"];
    [[NSProcessInfo processInfo] endActivity:self.activityToken];
    self.activityToken = nil;
    [self saveProfile];
    [SCProfileManager commitPrivateSettings];
    [SCProfileManager purgePrivateSettingsFromMemory];
    [connection removeObserver:self forKeyPath:@"name"];
    [connection removeObserver:self forKeyPath:@"statusMessage"];
    
    self.akiUserInfoMenuItemPlaceholder.view = nil;

    [self.dockMenu removeItem:self.dockNameMenuItem];
    [self.dockMenu removeItem:self.dockStatusMenuItem];
    self.dockNameMenuItem = nil;
    self.dockStatusMenuItem = nil;
    NSMenuItem *placeholder = [[NSMenuItem alloc] init];
    placeholder.title = self.akiUserInfoMenuItemPlaceholder.title;
    [self.dockMenu insertItem:placeholder atIndex:0];

    self.conversationManager = nil;
    self.toxConnection = nil;
    self.profileName = nil;
    self.profilePass = nil;
    self.mainWindowController = nil;
    if (self.userIsWaitingOnApplicationExit) {
        [NSApp replyToApplicationShouldTerminate:YES];
    } else {
        SCNewUserWindowController *login = [[SCNewUserWindowController alloc] initWithWindowNibName:@"NewUser"];
        self.mainWindowController = login;
        [login showWindow:self];
    }
}

- (void)didAddFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection {
    [self.conversationManager addConversation:friend];
    if (_requests[friend.publicKey] != nil) {
        [self willChangeValueForKey:@"requests"];
        [_requests removeObjectForKey:friend.publicKey];
        [self didChangeValueForKey:@"requests"];
        [self archiveFriendRequests];
    }
    [self saveProfile];
}

- (void)didRemoveFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection {
    [self.conversationManager deleteConversation:friend];

    SCStandaloneWindowController *wc = _auxiliaryChatWindows[friend.conversationIdentifier];
    if (wc)
        [self removeAuxWindowFromService:wc];

    NSMutableDictionary *map = [[SCProfileManager privateSettingForKey:@"nicknames"] mutableCopy] ?: [NSMutableDictionary dictionary];
    [map removeObjectForKey:friend.publicKey];
    [SCProfileManager setPrivateSetting:map forKey:@"nicknames"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [SCProfileManager commitPrivateSettings];
    });
    [self saveProfile];
}

- (void)friend:(DESFriend *)friend nameDidChange:(NSString *)newName onConnection:(DESToxConnection *)connection {
    [self saveProfile];
}

- (void)didFailToAddFriendWithError:(NSError *)error onConnection:(DESToxConnection *)connection {
    if (!([self.mainWindowController.window isVisible] && [self.mainWindowController.window isKeyWindow]))
        [self.mainWindowController.window makeKeyAndOrderFront:self];
    NSAlert *a = [[NSAlert alloc] init];
    a.alertStyle = NSCriticalAlertStyle;
    a.messageText = NSLocalizedString(@"Failed To Add Friend", nil);
    NSString *f;
    switch (error.code) {
        case DESFriendAddOwnKey:
            f = NSLocalizedString(@"Failed to add the friend because the Tox ID belonged to you.", nil);
            break;
        case DESFriendAddInvalidID:
            f = NSLocalizedString(@"Failed to add the friend because the Tox ID was invalid.", nil);
            break;
        case DESFriendAddAlreadySent:
            f = NSLocalizedString(@"Failed to add the friend because the Tox ID is already in your friends list.", nil);
            break;
        default:
            f = NSLocalizedString(@"Failed to add the friend because an error occurred.", nil);
            break;
    }
    a.informativeText = [NSString stringWithFormat:@"%@ (%@ %d)",
                         f, error.domain, (int)error.code];
    [a beginSheetModalForWindow:self.mainWindowController.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)logOut {
    [self.toxConnection stop];
}

- (IBAction)logOutFromUI:(id)sender {
    [self.mainWindowController.window performClose:self];
    self.userIsWaitingOnApplicationExit = NO;
    if (!self.mainWindowController.window.isVisible) {
        for (NSWindowController *owner in _auxiliaryChatWindows.allValues) {
            [owner close];
        }
        _auxiliaryChatWindows = nil;
        [self logOut];
    }
}

#pragma mark - UI Management

- (void)deleteFriend:(DESFriend *)friend confirmingInWindow:(NSWindow *)window {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"deleteFriendsImmediately"] || !window) {
        [self removeFriend:friend];
        return;
    }

    NSAlert *confirmation = [[NSAlert alloc] init];
    confirmation.messageText = NSLocalizedString(@"Remove Friend", nil);
    NSString *template = NSLocalizedString(@"Do you really want to remove %@ from your friends list?", nil);
    confirmation.informativeText = [NSString stringWithFormat:template, friend.preferredUIName];
    NSButton *checkbox = [[NSButton alloc] initWithFrame:CGRectZero];
    checkbox.buttonType = NSSwitchButton;
    checkbox.title = NSLocalizedString(@"Don't ask me whether to remove friends again", nil);
    [checkbox sizeToFit];
    confirmation.accessoryView = checkbox;
    [confirmation addButtonWithTitle:NSLocalizedString(@"Yes", nil)];
    [confirmation addButtonWithTitle:NSLocalizedString(@"No", nil)];
    [confirmation beginSheetModalForWindow:window
                             modalDelegate:self
                            didEndSelector:@selector(commitDeletingFriendFromSheet:returnCode:userInfo:)
                               contextInfo:(__bridge void *)friend];
}

- (void)commitDeletingFriendFromSheet:(NSAlert *)sheet returnCode:(NSInteger)ret userInfo:(void *)friend {
    if (((NSButton *)sheet.accessoryView).state == NSOnState)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"deleteFriendsImmediately"];
    if (ret == NSAlertFirstButtonReturn) {
        [self removeFriend:(__bridge DESFriend *)friend];
    }
}

#pragma mark - Auxiliary Windows

- (IBAction)showAboutWindow:(id)sender {
    self.aboutHeader.topColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    self.aboutHeader.bottomColor = [NSColor colorWithCalibratedWhite:0.09 alpha:1.0];
    self.aboutHeader.shadowColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    self.aboutHeader.dragsWindow = YES;
    self.aboutFooter.backgroundColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
    self.aboutFooter.shadowColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    self.aboutWindowApplicationNameLabel.stringValue = SCApplicationInfoDictKey(@"SCDevelopmentName");
    self.aboutWindowVersionLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil),
                                                SCApplicationInfoDictKey(@"CFBundleShortVersionString")];
    [self.aboutWindow makeKeyAndOrderFront:self];
}

- (IBAction)showPreferencesWindow:(id)sender {
    
}

- (void)focusWindowForConversation:(DESConversation *)conv {
    NSString *key = conv.conversationIdentifier;
    SCStandaloneWindowController *ctl = _auxiliaryChatWindows[key];
    if (!ctl) {
        ctl = [[SCStandaloneWindowController alloc] initWithConversation:conv];
        ctl.chatView.conversation = [self.conversationManager conversationFor:conv];
        _auxiliaryChatWindows[key] = ctl;
    }
    [ctl showWindow:self];
}

- (void)removeAuxWindowFromService:(SCStandaloneWindowController *)w {
    [_auxiliaryChatWindows removeObjectForKey:w.conversationIdentifier];
    [w close];
}

#pragma mark - AboutWindow click-throughs

- (IBAction)aboutWindowDidOpenGitHubURL:(id)sender {
    NSURL *github = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[@"ProjectHomepage"]];
    [[NSWorkspace sharedWorkspace] openURL:github];
}

- (IBAction)aboutWindowDidOpenToxURL:(id)sender {
    NSURL *tox_im = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[@"ToxHomepage"]];
    [[NSWorkspace sharedWorkspace] openURL:tox_im];
}

- (IBAction)aboutWindowDidOpenAcknowledgements:(id)sender {
    [self.ackTextView readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"friends" ofType:@"rtf"]];
    [self.ackWindow makeKeyAndOrderFront:self];
}

#pragma mark - Tox menu

- (IBAction)copyPublicID:(id)sender {
    if (!self.toxConnection) {
        NSBeep();
    } else {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:@[self.toxConnection.friendAddress]];
    }
}

- (IBAction)showQRCode:(id)sender {
    if ([self.mainWindowController respondsToSelector:@selector(displayQRCode)]) {
        [(id<SCMainWindowing>)self.mainWindowController displayQRCode];
    } else {
        NSBeep();
    }
}

- (IBAction)changeName:(id)sender {
    if (![self.mainWindowController respondsToSelector:@selector(buddyListController)])
        return;
    SCBuddyListController *list = ((id<SCMainWindowing>)self.mainWindowController).buddyListController;
    [list changeName:sender];
}

- (IBAction)changeStatus:(id)sender {
    if (![self.mainWindowController respondsToSelector:@selector(buddyListController)])
        return;
    SCBuddyListController *list = ((id<SCMainWindowing>)self.mainWindowController).buddyListController;
    [list changeName:sender];
}

- (IBAction)addFriend:(id)sender {
    if ([self.mainWindowController respondsToSelector:@selector(displayAddFriend)]) {
        [(id<SCMainWindowing>)self.mainWindowController displayAddFriend];
    } else {
        NSBeep();
    }
}

- (IBAction)renameFriend:(id)sender {
}

- (IBAction)menuRemoveFriend:(id)sender {
    NSWindow *activeWindow = [NSApp keyWindow];
    if ([activeWindow.windowController conformsToProtocol:@protocol(SCMainWindowing)]) {
        DESConversation *conv = ((id<SCMainWindowing>)activeWindow.windowController).buddyListController.conversationSelectedInView;
        if ([conv conformsToProtocol:@protocol(DESFriend)]) {
            [self deleteFriend:(DESFriend *)conv confirmingInWindow:activeWindow];
            return;
        }
    } else if ([activeWindow.windowController isKindOfClass:[SCStandaloneWindowController class]]) {
        SCStandaloneWindowController *wc = activeWindow.windowController;
        DESConversation *conv = wc.conversation;
        if ([conv conformsToProtocol:@protocol(DESFriend)]) {
            [self deleteFriend:(DESFriend *)conv confirmingInWindow:activeWindow];
            return;
        }
    }
    NSBeep();
}

#pragma mark - Data Export

- (IBAction)showDataExportWindow:(id)sender {

}

@end
