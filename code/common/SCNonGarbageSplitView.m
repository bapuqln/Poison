#include "Copyright.h"

#include <objc/runtime.h>
#import "SCNonGarbageSplitView.h"

@interface SCNonGarbageSplitView ()
@property (nonatomic) unsigned char delegateSupports;
@end

@implementation SCNonGarbageSplitView

#define DELEGATE_CAP(c, xpr) (((c) & (xpr)) != 0)

- (void)setDelegate:(id<NSSplitViewDelegate>)delegate {
    [super setDelegate:delegate];
    [self _doCheckSupports];
}

- (void)_doCheckSupports {
    unsigned char nc = 0;
    id<NSSplitViewDelegate> d = self.delegate;

    if ([d respondsToSelector:@selector(dividerColourForSplitView:)])
        nc |= 1;
    if ([self.delegate respondsToSelector:@selector(dividerThicknessForSplitView:)])
        nc |= (1 << 1);
    if ([self.delegate respondsToSelector:@selector(splitView:drawDividerInRect:)])
        nc |= (1 << 2);
    if ([self.delegate respondsToSelector:@selector(splitView:maxPossiblePositionOfDividerAtIndex:)])
        nc |= (1 << 3);
    if ([self.delegate respondsToSelector:@selector(splitView:minPossiblePositionOfDividerAtIndex:)])
        nc |= (1 << 4);

    self.delegateSupports = nc;
}

- (NSColor *)dividerColor {
    if (DELEGATE_CAP(_delegateSupports, 1 << 1))
        return [(id<SCNonGarbageSplitViewDelegate>)self.delegate dividerColourForSplitView:self];
    return [super dividerColor];
}

- (CGFloat)dividerThickness {
    if (DELEGATE_CAP(_delegateSupports, 1 << 1))
        return [(id<SCNonGarbageSplitViewDelegate>)self.delegate dividerThicknessForSplitView:self];
    return [super dividerThickness];
}

- (void)drawDividerInRect:(NSRect)rect {
    if (DELEGATE_CAP(_delegateSupports, 1 << 2))
        return [(id<SCNonGarbageSplitViewDelegate>)self.delegate splitView:self drawDividerInRect:rect];
    return [super drawDividerInRect:rect];
}

- (CGFloat)maxPossiblePositionOfDividerAtIndex:(NSInteger)dividerIndex {
    if (DELEGATE_CAP(_delegateSupports, 1 << 3))
        return [(id<SCNonGarbageSplitViewDelegate>)self.delegate splitView:self maxPossiblePositionOfDividerAtIndex:dividerIndex];
    return [super maxPossiblePositionOfDividerAtIndex:dividerIndex];
}

- (CGFloat)minPossiblePositionOfDividerAtIndex:(NSInteger)dividerIndex {
    if (DELEGATE_CAP(_delegateSupports, 1 << 4))
        return [(id<SCNonGarbageSplitViewDelegate>)self.delegate splitView:self minPossiblePositionOfDividerAtIndex:dividerIndex];
    return [super minPossiblePositionOfDividerAtIndex:dividerIndex];
}

@end
