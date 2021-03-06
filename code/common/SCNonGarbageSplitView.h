#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@class SCNonGarbageSplitView;
@protocol SCNonGarbageSplitViewDelegate <NSSplitViewDelegate>
@optional
- (NSColor *)dividerColourForSplitView:(SCNonGarbageSplitView *)splitView;
- (CGFloat)dividerThicknessForSplitView:(SCNonGarbageSplitView *)splitView;
- (void)splitView:(SCNonGarbageSplitView *)splitView drawDividerInRect:(NSRect)aRect;
- (CGFloat)splitView:(SCNonGarbageSplitView *)splitView maxPossiblePositionOfDividerAtIndex:(NSInteger)dividerIndex;
- (CGFloat)splitView:(SCNonGarbageSplitView *)splitView minPossiblePositionOfDividerAtIndex:(NSInteger)dividerIndex;
@end

/* simply put, a split view that isn't shit */
@interface SCNonGarbageSplitView : NSSplitView

@end
