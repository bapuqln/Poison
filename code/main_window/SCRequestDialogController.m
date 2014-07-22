#include "Copyright.h"

#import "SCRequestDialogController.h"
#import "ObjectiveTox.h"
#import "SCFriendRequest.h"
#import <QuartzCore/QuartzCore.h>

@interface SCRequestDialogController ()
@property (strong) IBOutlet NSView *topView;
@property (strong) IBOutlet NSView *bottomView;

@property (strong) IBOutlet NSImageView *avatarView;
@property (strong) IBOutlet NSTextField *nameHeader;
@property (strong) IBOutlet NSTextField *keyField;
@property (strong) IBOutlet NSTextField *dateField;
@property (strong) IBOutlet NSScrollView *messageField;
@property (strong) IBOutlet NSTextView *textView;
@end

@implementation SCRequestDialogController

- (void)setRequest:(SCFriendRequest *)request {
    _request = request;
    [self setupUI];
}

- (void)setupUI {
    self.keyField.stringValue = self.request.senderName;

    static NSDateFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
    }
    self.dateField.stringValue = [formatter stringFromDate:self.request.dateReceived];

    self.textView.string = self.request.message;
    [self.textView.layoutManager glyphRangeForTextContainer:self.textView.textContainer];

    NSView *v = self.window.contentView;
    CGFloat nominal = v.frame.size.height - self.messageField.frame.size.height;
    CGFloat prefer = MIN([self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size.height, 600);
    CGRect frame = self.window.frame;
    frame.size.height = prefer + nominal;
    [self.window setFrame:frame display:YES animate:NO];
}

- (IBAction)endSheet:(NSButton *)sender {
    [NSApp endSheet:self.window returnCode:sender.tag];
}

@end
