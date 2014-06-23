#include "Copyright.h"

#import "SCChatView.h"

@implementation SCChatView

- (void)viewDidMoveToWindow {
    [self.window setContentBorderThickness:self.frame.size.height forEdge:NSMinYEdge];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (newWindow)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(redisplay) name:NSWindowDidBecomeKeyNotification object:newWindow];
}

- (void)redisplay {
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (SCIsYosemiteOrHigher()) {
        if (self.window.isKeyWindow && self.window.isMainWindow) {
            NSGradient *grad = [[NSGradient alloc] initWithColors:@[
                [NSColor colorWithCalibratedWhite:0.75 alpha:1.0],
                [NSColor colorWithCalibratedWhite:0.85 alpha:1.0]
            ]];
            [grad drawInRect:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height - 1) angle:90.0];
        }
        //[[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] set];
        //NSRectFill(NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height - 1));
    }
}

@end
