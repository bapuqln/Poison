#include "Copyright.h"

#import "SCRequestDialogController.h"
#import "ObjectiveTox.h"
#import <QuartzCore/QuartzCore.h>

@interface SCRequestDialogController ()
@property (strong) IBOutlet NSView *topView;
@property (strong) IBOutlet NSView *bottomView;

@property (strong) IBOutlet NSImageView *avatarView;
@property (strong) IBOutlet NSTextField *nameHeader;
@property (strong) IBOutlet NSTextField *keyField;
@property (strong) IBOutlet NSScrollView *messageField;
@property (strong) IBOutlet NSTextView *textView;
@end

@implementation SCRequestDialogController

- (void)setRequest:(DESRequest *)request {
    _request = request;
    [self setupUI];
}

- (void)applyMaskIfRequired {
    if (self.avatarView.wantsLayer)
        return;
    self.avatarView.wantsLayer = YES;
    NSImage *mask = SCAvatarMaskImage();
    CALayer *maskLayer = [CALayer layer];
    [CATransaction begin];
    maskLayer.frame = (CGRect){CGPointZero, self.avatarView.frame.size};
    maskLayer.contents = (id)mask;
    self.avatarView.layer.mask = maskLayer;
    [CATransaction commit];
}

- (void)setupUI {
    [self applyMaskIfRequired];
    self.keyField.stringValue = self.request.senderName;
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
