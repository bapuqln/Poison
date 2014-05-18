#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "SCDraggingView.h"

@interface SCGradientView : SCDraggingView

@property (nonatomic) NSColor *topColor;
@property (nonatomic) NSColor *bottomColor;
@property (nonatomic) NSColor *shadowColor;
@property (nonatomic) NSColor *borderColor;

@end
