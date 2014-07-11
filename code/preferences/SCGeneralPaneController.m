#import "SCGeneralPaneController.h"
#import "SCAppDelegate.h"

@interface SCGeneralPaneController ()
#pragma mark - Selecting mainWindow Style
@property (strong) IBOutlet NSButton *checkBoxBLOnly;
@property (strong) IBOutlet NSButton *checkBoxUnified;
#pragma mark - Selecting Avatar Style
@property (strong) IBOutlet NSButton *checkBoxCircle;
@property (strong) IBOutlet NSButton *checkBoxSquircle;
@property (strong) IBOutlet NSButton *checkBoxRRect;
@property (strong) IBOutlet NSButton *checkBoxSquare;
#pragma mark - other
@property (strong) IBOutlet NSButton *checkBoxPublicSights;
@property (strong) IBOutlet NSTextField *postfixEntry;
@property (strong) IBOutlet NSTextField *postfixExample;
@property (strong) IBOutlet NSButton *checkBoxMenubar;
@end

@implementation SCGeneralPaneController {
    NSArray *_avatarCheckboxes;
    NSArray *_windowStyleCheckboxes;
}

- (void)awakeFromNib {
    self.postfixEntry.delegate = self;
    self.postfixEntry.stringValue = SCStringPreference(@"nameCompletionDelimiter");
    [self updatePostfixExample];
    _avatarCheckboxes = @[_checkBoxCircle, _checkBoxSquircle, _checkBoxRRect, _checkBoxSquare];
    _windowStyleCheckboxes = @[_checkBoxUnified, _checkBoxBLOnly];

    [self updateWindowSelection];
    [self updateAvatarSelection];

    self.checkBoxPublicSights.state = SCBoolPreference(@"publicSights")? NSOnState : NSOffState;
    self.checkBoxMenubar.state = SCBoolPreference(@"menuIcon")? NSOnState : NSOffState;
}

#pragma mark - window style

- (IBAction)changeWindowSelection:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[sender tag]? YES : NO forKey:@"forcedMultiWindowUI"];
    [(SCAppDelegate *)[NSApp delegate] reopenMainWindow];
    [self.view.window makeKeyAndOrderFront:self];

    [self updateWindowSelection];
}

- (void)updateWindowSelection {
    for (NSButton *b in _windowStyleCheckboxes) {
        b.state = NSOffState;
    }
    ((NSButton *)_windowStyleCheckboxes[SCBoolPreference(@"forcedMultiWindowUI")? 1 : 0]).state = NSOnState;
}

#pragma mark - avatar selection

- (IBAction)changeAvatarSelection:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"avatarShape"];

    [self updateAvatarSelection];
}

- (void)updateAvatarSelection {
    for (NSButton *b in _avatarCheckboxes) {
        b.state = NSOffState;
    }
    ((NSButton *)_avatarCheckboxes[SCIntegerPreference(@"avatarShape") - 1]).state = NSOnState;
}

#pragma mark - ps

- (IBAction)changePSState:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState)? YES : NO forKey:@"publicSights"];
}

#pragma mark - postfix control

- (void)controlTextDidChange:(NSNotification *)obj {
    [[NSUserDefaults standardUserDefaults] setObject:self.postfixEntry.stringValue forKey:@"nameCompletionDelimiter"];
    [self updatePostfixExample];
}

- (void)updatePostfixExample {
    NSString *delim = SCStringPreference(@"nameCompletionDelimiter");
    self.postfixExample.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Looks like this: \"Natsuki%@ ...\"", @"preview for nameCompletionDelimiter setting"), delim];
}

#pragma mark - menu bar icon

- (IBAction)changeMBState:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState)? YES : NO forKey:@"menubarIcon"];
}


@end
