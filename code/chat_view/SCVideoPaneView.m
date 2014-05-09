#include "Copyright.h"

#import "SCVideoPaneView.h"
#import "CGGeometryExtreme.h"
#import <QuartzCore/QuartzCore.h>

@interface SCVideoPaneView ()
@property (weak) IBOutlet NSView *videoSquare;
@end

@implementation SCVideoPaneView

- (void)awakeFromNib {
    self.wantsLayer = YES;
    /*_blurLayer = [CALayer layer];
    _blurLayer.frame = self.bounds;
    _blurLayer.contents = ((NSImageView *)self.videoSquare).image;

    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:@(15.0) forKey:@"inputRadius"];
    CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
    NSAffineTransform *trans = [NSAffineTransform transform];
    [clamp setValue:trans forKey:@"inputTransform"];

    if (SCIsMavericksOrHigher())
        self.layerUsesCoreImageFilters = YES;
    _blurLayer.filters = @[clamp, blur];
    [self.layer addSublayer:_blurLayer];*/

    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowOffset = (CGSize){0, -2};
    shadow.shadowColor = [NSColor blackColor];
    shadow.shadowBlurRadius = 3.0;
    self.videoSquare.shadow = shadow;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    /* Taking padding into account... */
    CGRect usableRect = CGRectInset(self.bounds, 58, 0);
    CGFloat squareLargest = fmin(usableRect.size.width, usableRect.size.height);
    CGRect almostFinal = (CGRect){CGPointZero, {squareLargest, squareLargest}};
    self.videoSquare.frame = CGRectCentreInRect(almostFinal, self.bounds);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    CGFloat fromLeft = self.frame.size.width - 48;
    [self.shadowColor set];
    NSRectFill((CGRect){{fromLeft, 0}, {1, self.frame.size.height}});
}

@end
