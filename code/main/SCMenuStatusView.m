#include "Copyright.h"

#import "SCMenuStatusView.h"

@interface SCMenuStatusView ()
@property (strong) IBOutlet NSTextField *nameDisplay;
@property (strong) IBOutlet NSTextField *statusDisplay;
@end

@implementation SCMenuStatusView {
    NSDictionary *_nameAttrs;
    NSDictionary *_smsgAttrs;
}

- (void)awakeFromNib {
    _nameAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]};
    _smsgAttrs = @{NSFontAttributeName: [NSFont menuFontOfSize:14]};
}

- (void)setName:(NSString *)name {
    if (name)
        self.nameDisplay.stringValue = [name copy];
    [self adjustSize];
}

- (void)setStatusMessage:(NSString *)statusMessage {
    if (statusMessage)
        self.statusDisplay.stringValue = [statusMessage copy];
    [self adjustSize];
}

- (void)adjustSize {
    [self.nameDisplay sizeToFit];
    [self.statusDisplay sizeToFit];
    CGFloat requiredWidth = MAX(self.nameDisplay.frame.size.width, self.statusDisplay.frame.size.width);
    self.frameSize = (CGSize){requiredWidth + (self.nameDisplay.frame.origin.x * 2), self.frame.size.height};
}

@end
