#import "SCTextField.h"
#import <QuartzCore/QuartzCore.h>

@interface SCTextFieldCell : NSTextFieldCell

@end

@implementation SCTextFieldCell

- (void)drawFocusRingMaskWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [[NSBezierPath bezierPathWithRoundedRect:CGRectInset(cellFrame, 0.6, 0.6)
                                     xRadius:4.0 yRadius:4.0] fill];
}

@end

@implementation SCTextField {
    NSRange _selectedRange;
    NSColor *_focusedCachedColour;
    NSColor *_unfocusedCachedColour;
    NSGradient *_cachedGradient;
    NSShadow *_innerShadow;
    NSShadow *_outerShadow;
    NSShadow *_outerShadowYosemite;
}

+ (Class)cellClass {
    return [SCTextFieldCell class];
}

- (void)awakeFromNib {
    self.bezeled = YES;
    self.drawsBackground = NO;
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:self.window];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(focusChanged:) name:NSWindowDidBecomeKeyNotification object:newWindow];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(focusChanged:) name:NSWindowDidResignKeyNotification object:newWindow];
}

- (void)focusChanged:(NSNotification *)notification {
    self.needsDisplay = YES;
}

#pragma mark - selection

- (void)clearSelection {
    _selectedRange = NSMakeRange(0, 0);
}

- (void)saveSelection {
    _selectedRange = [self.window fieldEditor:YES forObject:self].selectedRange;
}

- (void)restoreSelection {
    [self.window fieldEditor:YES forObject:self].selectedRange = _selectedRange;
}

#pragma mark - draw parameters

- (NSColor *)focusedColorForTextField {
    if (!_focusedCachedColour)
        _focusedCachedColour = [NSColor colorWithCalibratedWhite:87.0 / 255.0 alpha:0.85];
    return _focusedCachedColour;
}

- (NSColor *)unfocusedColorForTextField {
    if (!_unfocusedCachedColour)
        _unfocusedCachedColour = [NSColor colorWithCalibratedWhite:100.0 / 255.0 alpha:0.4];
    return _unfocusedCachedColour;
}

- (NSGradient *)gradientOfTextField {
    if (!_cachedGradient)
        _cachedGradient = [[NSGradient alloc] initWithColorsAndLocations:
                           [NSColor colorWithCalibratedWhite:0.9 alpha:1.0],
                           0.0, [NSColor whiteColor], 1.0, nil];
    return _cachedGradient;
}

- (NSShadow *)innerShadowOfTextField {
    if (!_innerShadow) {
        _innerShadow = [[NSShadow alloc] init];
        _innerShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0
                                                               alpha:1.0];
        _innerShadow.shadowBlurRadius = 2.0;
        _innerShadow.shadowOffset = (NSSize){0, -1.0};
    }
    return _innerShadow;
}

- (NSShadow *)outerShadowOfTextField {
    if (!_outerShadow) {
        _outerShadow = [[NSShadow alloc] init];
        _outerShadow.shadowBlurRadius = 1.0;
        _outerShadow.shadowOffset = (CGSize){0, -0.7};
        _outerShadow.shadowColor = [NSColor colorWithCalibratedWhite:1.0
                                                               alpha:0.56];
    }
    return _outerShadow;
}

- (NSShadow *)outerShadowOfYosemiteTextField {
    if (!_outerShadowYosemite) {
        _outerShadowYosemite = [[NSShadow alloc] init];
        _outerShadowYosemite.shadowBlurRadius = 1.0;
        _outerShadowYosemite.shadowOffset = (CGSize){0, -0.7};
        _outerShadowYosemite.shadowColor = [NSColor colorWithCalibratedWhite:0.0
                                                               alpha:0.13];
    }
    return _outerShadowYosemite;
}

- (CGRect)actualBounds {
    return CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - 1);
}

- (void)drawRectBelowYosemite:(NSRect)dirtyRect {
    CGRect ab = self.actualBounds;

    /* fill it */
    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(ab, 1, 1)
                                                              xRadius:3.42
                                                              yRadius:3.42];
    [self.gradientOfTextField drawInBezierPath:innerPath angle:90.0];

    [NSGraphicsContext saveGraphicsState];
    [innerPath addClip];
    /* draw the shadow's caster entirely outside the path */
    NSBezierPath *shadowDraw = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(ab, -1, -1)
                                                               xRadius:3.42
                                                               yRadius:3.42];
    [self.innerShadowOfTextField set];
    [shadowDraw stroke];
    [NSGraphicsContext restoreGraphicsState];

    /* outline */
    [NSGraphicsContext saveGraphicsState];
    [self.outerShadowOfTextField set];
    if (self.window.isKeyWindow && self.window.isMainWindow)
        [self.focusedColorForTextField set];
    else
        [self.unfocusedColorForTextField set];
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(ab, 0.6, 0.6)
                                                               xRadius:4.0
                                                               yRadius:4.0];
    [borderPath stroke];
    [NSGraphicsContext restoreGraphicsState];

    [self.cell drawInteriorWithFrame:ab inView:self];
}

- (void)drawRectAboveYosemite:(NSRect)dirtyRect {
    CGRect ab = self.actualBounds;
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:ab
                                                         xRadius:4.0
                                                         yRadius:4.0];
    if (self.window.isKeyWindow && self.window.isMainWindow) {
        [[NSColor whiteColor] set];
        [self.outerShadowOfYosemiteTextField set];
        [path fill];
    } else {
        [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] set];
        [path fill];
        path = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(ab, 0.5, 0.5)
                                               xRadius:3.42
                                               yRadius:3.42];
        [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] set];
        [path stroke];
    }

    [NSGraphicsContext restoreGraphicsState];
    [self.cell drawInteriorWithFrame:ab inView:self];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (SCIsYosemiteOrHigher())
        [self drawRectAboveYosemite:dirtyRect];
    else
        [self drawRectBelowYosemite:dirtyRect];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
