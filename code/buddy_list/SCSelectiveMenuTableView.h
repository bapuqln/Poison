#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@protocol SCSelectiveMenuTableViewing <NSTableViewDelegate>
- (NSMenu *)tableView:(NSTableView *)tableView menuForRow:(NSInteger)row;
@end

@interface SCSelectiveMenuTableView : NSTableView
@property (readonly) NSInteger menuSelectedRow;
@end
