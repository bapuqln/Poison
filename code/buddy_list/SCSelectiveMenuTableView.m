#include "Copyright.h"

#import "SCSelectiveMenuTableView.h"

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

@end
