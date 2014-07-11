#include "Copyright.h"

#import "SCVideoPaneView.h"
#import "CGGeometryExtreme.h"
#import <QuartzCore/QuartzCore.h>

#define SC_RGBA(r, g, b, a) ([NSColor colorWithCalibratedRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a])

@interface SCScaryRedButton : NSButton
@end

@implementation SCScaryRedButton

- (void)drawRect:(NSRect)dirtyRect {
    [SC_RGBA(213, 25, 32, 1.0) set];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:3.0 yRadius:3.0] fill];
    NSGradient *g = [[NSGradient alloc] initWithStartingColor:SC_RGBA(231, 21, 44, 1.0)
                                                  endingColor:SC_RGBA(168, 22, 22, 1.0)];
    [g drawInBezierPath:[NSBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 1, 1)
                                                        xRadius:3.0 yRadius:3.0]
                  angle:90.0];

    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    ps.alignment = NSCenterTextAlignment;

    NSDictionary *attributes = @{NSForegroundColorAttributeName: [NSColor whiteColor],
                                 NSFontAttributeName: [NSFont labelFontOfSize:13.0],
                                 NSParagraphStyleAttributeName: ps};
    CGSize s = [self.title sizeWithAttributes:attributes];
    CGRect r = CGRectIntegral(CGRectCentreInRect((CGRect){CGPointZero, s}, self.bounds));

    [self.title drawInRect:r withAttributes:attributes];
}

@end

@interface SCVideoPaneView ()
@property (strong) IBOutlet NSView *videoSquare;
@property (strong) IBOutlet NSView *smallVideoSquare;

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
    anotherShadow.shadowBlurRadius = 2.0;
    self.smallVideoSquare.shadow = anotherShadow;

    self.endButton.title = NSLocalizedString(@"End Call", nil);
}

- (void)layoutVideo:(NSSize)oldSize {
    if (oldSize.height < 150) {
        [self addSubview:self.videoSquare];
        [self addSubview:self.smallVideoSquare];
    }

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

    CGRect snf = (CGRect){CGPointZero, (CGSize){sized.size.width * (1.0 / 4), sized.size.height * (1.0 / 4)}};
    snf = CGRectCentreInRect(snf, self.frame);
    snf.origin.y = 16;
    self.smallVideoSquare.frame = CGRectIntegral(snf);
}

- (void)layoutMini:(NSSize)oldSize {
    CGRect bounds = self.bounds;
    CGFloat mid = (bounds.size.height - self.endButton.frame.size.height) / 2;
    self.endButton.frameOrigin = (CGPoint){bounds.size.width - 20 - self.endButton.frame.size.width, mid};

    if (oldSize.height >= 150) {
        [self.videoSquare removeFromSuperview];
        [self.smallVideoSquare removeFromSuperview];

        self.callInfo.font = [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
        self.callInfo.textColor = [NSColor whiteColor];
        [self.callInfo sizeToFit];
        CGRect centered = CGRectIntegral(CGRectCentreInRect(self.callInfo.bounds, self.bounds));
        centered.origin = (CGPoint){20, centered.origin.y};
        self.callInfo.frame = centered;
    }
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
