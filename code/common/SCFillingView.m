/* It just fills, yo. */
#include "Copyright.h"

#import "SCFillingView.h"

@implementation SCFillingView

- (void)drawRect:(NSRect)dirtyRect {
    if (self.drawColor) {
        [self.drawColor set];
        NSRectFill(dirtyRect);
    }
}

- (BOOL)isOpaque {
    return (self.drawColor.alphaComponent >= 1.0) ? YES : NO;
}

@end
