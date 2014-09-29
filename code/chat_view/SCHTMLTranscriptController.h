#import <Cocoa/Cocoa.h>
#import "SCFillingView.h"

@class SCTextField, WebView, SCConversation;

@interface SCResponderProxyView : SCFillingView
@property (weak) SCTextField *responder;
@end

@interface SCHTMLTranscriptController : NSViewController
//@property (strong) SCResponderProxyView *view;
@property (strong) SCConversation *conversation;
- (void)reloadTheme;
- (void)reloadConversation;
- (void)throwEvent:(NSString *)eventName withObject:(id)object;
- (void)scrollByPoints:(CGFloat)points;
@end
