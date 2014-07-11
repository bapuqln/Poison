#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@interface SCDraggingView : NSView
@property BOOL dragsWindow;
/* note: makes the top 22 pixels undraggable */
@property BOOL isFlushWithTitlebar;
@end
