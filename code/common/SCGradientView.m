#include "Copyright.h"

#import "SCGradientView.h"

@implementation SCGradientView

- (void)awakeFromNib {
    if (!self.topColor)
        _topColor = [NSColor blackColor];
    if (!self.bottomColor)
        _bottomColor = [NSColor blackColor];
    if (!self.shadowColor)
        _shadowColor = nil;
}

- (void)setShadowColor:(NSColor *)shadowColor {
    if (SCIsYosemiteOrHigher()) {
        _shadowColor = nil;
    } else {
        _shadowColor = shadowColor;
    }
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    NSGradient *chrome;
    if (self.topColor && self.bottomColor) {
        chrome = [[NSGradient alloc] initWithStartingColor:self.bottomColor endingColor:self.topColor];
        [chrome drawInRect:(CGRect){{dirtyRect.origin.x, 0}, {dirtyRect.size.width, self.bounds.size.height}} angle:90];
    }
    if (self.shadowColor && chrome) {
        NSColor *farPoint = nil;
        [chrome getColor:&farPoint location:NULL atIndex:1];
        NSGradient *shine = [[NSGradient alloc] initWithColors:@[farPoint, self.shadowColor, farPoint]];
        [shine drawInRect:NSMakeRect(0, self.frame.size.height - 1, self.frame.size.width, 1) angle:0];
    }
    if (self.borderColor) {
        [self.borderColor set];
        NSRectFill((CGRect){{0, 0}, {self.frame.size.width, 1}});
    }
}

@end
