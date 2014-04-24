#include "Copyright.h"

#import "SCWidgetedWindow.h"

@implementation SCWidgetedWindow
- (NSInteger)titlebarHeight {
    return 22;
}

- (void)setWidgetView:(NSView *)widgetView {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:_widgetView];
    [self.widgetView removeFromSuperview];
    if (widgetView) {
        _widgetView = widgetView;
        _widgetView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
        [[self.contentView superview] setAutoresizesSubviews:YES];
        [[self.contentView superview] addSubview:widgetView];
        //[self updatePositionOfWidgetView:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePositionOfWidgetView:) name:NSViewFrameDidChangeNotification object:_widgetView];
        [self updatePositionOfWidgetView:nil];
    }
}
- (void)updatePositionOfWidgetView:(NSNotification *)unused {
    CGFloat y = floor(self.frame.size.height - self.widgetView.bounds.size.height - ((self.titlebarHeight - self.widgetView.bounds.size.height) / 2));
    if ([self.screen respondsToSelector:@selector(backingScaleFactor)] && self.screen.backingScaleFactor > 1.0)
        y -= 0.5; /* Small alignment fix for HiDPI to match the fullscreen widget */
    CGFloat fullScreenOffset = [self collectionBehavior] == NSWindowCollectionBehaviorFullScreenPrimary ? 20 : 0;
    self.widgetView.frameOrigin = (NSPoint){self.frame.size.width - 4 - fullScreenOffset - self.widgetView.bounds.size.width, y};
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
