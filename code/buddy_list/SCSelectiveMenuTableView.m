#include "Copyright.h"

#import "SCSelectiveMenuTableView.h"
#import "SCMainWindowing.h"

NS_INLINE int SCIsTypingKey(unsigned short k) {
    return !(k == 48 || (k > 122 && k < 127));
}

@implementation SCSelectiveMenuTableView {
    NSInteger _clickedRow;
}

- (NSInteger)menuSelectedRow {
    return _clickedRow;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSPoint loc = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = [self rowAtPoint:loc];
    _clickedRow = row;
    if ([self.delegate respondsToSelector:@selector(tableView:menuForRow:)]) {
        return [(id<SCSelectiveMenuTableViewing>)self.delegate tableView:self menuForRow:row];
    }
    return nil;
}

- (void)keyDown:(NSEvent *)theEvent {
    if (SCIsTypingKey(theEvent.keyCode) && [self.window.windowController conformsToProtocol:@protocol(SCMainWindowing)])
        [(id<SCMainWindowing>)self.window.windowController updateKeyViewAndRepostTypingEvent:theEvent];
    else
        [super keyDown:theEvent];
}

@end
