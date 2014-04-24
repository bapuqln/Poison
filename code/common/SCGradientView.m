#include "Copyright.h"

#import "SCGradientView.h"

@implementation SCGradientView {
    NSGradient *_chrome;
    NSGradient *_shine;
}

- (void)awakeFromNib {
    if (!self.topColor)
        _topColor = [NSColor blackColor];
    if (!self.bottomColor)
        _bottomColor = [NSColor blackColor];
    if (!self.shadowColor)
        _shadowColor = [NSColor blackColor];
    [self regenChrome];
}

- (void)setTopColor:(NSColor *)topColor {
    _topColor = topColor;
    [self regenChrome];
    [self regenShine];
}

- (void)setBottomColor:(NSColor *)bottomColor {
    _bottomColor = bottomColor;
    [self regenChrome];
}

- (void)setShadowColor:(NSColor *)shadowColor {
    _shadowColor = shadowColor;
    [self regenShine];
}

- (void)regenChrome {
    _shine = nil;
    _chrome = [[NSGradient alloc] initWithStartingColor:self.bottomColor endingColor:self.topColor];
    [self regenShine];
}

- (void)regenShine {
    NSColor *farPoint = nil;
    [_chrome getColor:&farPoint location:NULL atIndex:1];
    if (!farPoint || !self.shadowColor)
        _shine = nil;
    else
        _shine = [[NSGradient alloc] initWithColors:@[farPoint, self.shadowColor, farPoint]];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [_chrome drawInRect:(CGRect){{dirtyRect.origin.x, 0}, {dirtyRect.size.width, self.bounds.size.height}} angle:90];
    if (_shine) {
        [_shine drawInRect:NSMakeRect(0, self.frame.size.height - 1, self.frame.size.width, 1) angle:0];
    }
    if (self.borderColor) {
        [self.borderColor set];
        NSRectFill((CGRect){{0, 0}, {self.frame.size.width, 1}});
    }
}

- (void)dealloc {
    _chrome = nil;
    _shine = nil;
}

@end
