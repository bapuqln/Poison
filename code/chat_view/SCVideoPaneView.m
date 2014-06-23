#include "Copyright.h"

#import "SCVideoPaneView.h"
#import "CGGeometryExtreme.h"
#import <QuartzCore/QuartzCore.h>

@interface SCScaryRedButtonCell : NSButtonCell
@end

@implementation SCScaryRedButtonCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [[NSColor redColor] set];
    NSRectFill(cellFrame);
    [self drawTitle:self.attributedStringValue withFrame:cellFrame inView:controlView];
}

@end

@interface SCVideoPaneView ()
@property (weak) IBOutlet NSView *videoSquare;
@property (weak) IBOutlet NSView *smallVideoSquare;

@property (weak) IBOutlet NSTextField *callInfo;
@property (weak) IBOutlet NSButton *endButton;
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

    NSShadow *anotherShadow = [[NSShadow alloc] init];
    anotherShadow.shadowOffset = (CGSize){0, -1};
    anotherShadow.shadowColor = [NSColor blackColor];
    anotherShadow.shadowBlurRadius = 1.0;
    self.smallVideoSquare.shadow = anotherShadow;
}

- (void)layoutVideo:(NSSize)oldSize {
    /* Taking padding into account... */
    CGRect usableRect = CGRectInset(self.bounds, 32, 32);
    CGFloat µ, biggest;
    NSInteger x = usableRect.size.width - self.videoSquare.frame.size.width;
    NSInteger y = usableRect.size.height - self.videoSquare.frame.size.height;
    if (x > y) {
        µ = usableRect.size.height;
        biggest = self.videoSquare.frame.size.height;
    } else {
        µ = usableRect.size.width;
        biggest = self.videoSquare.frame.size.width;
    }
    double vector = µ / biggest;

    CGRect sized = (CGRect){CGPointZero, {self.videoSquare.frame.size.width * vector,
        self.videoSquare.frame.size.height * vector}};
    self.videoSquare.frame = CGRectCentreInRect(sized, self.frame);
}

- (void)layoutMini:(NSSize)oldSize {

}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    if (self.frame.size.height >= 150.0) {
        [self layoutVideo:oldSize];
    } else {
        [self layoutMini:oldSize];
    }
}

- (void)configureForAspectRatio:(CGSize)ratio {
    self.videoSquare.frameSize = ratio;
    self.smallVideoSquare.frameSize = ratio;
    [self resizeSubviewsWithOldSize:self.frame.size];
}

@end
