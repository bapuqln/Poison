#import "SCHTMLTranscriptController.h"
#import "SCTextField.h"
#import "SCThemeManager.h"
#import "SCConversationManager.h"
#import <WebKit/WebKit.h>

@interface SCHTMLTranscriptController ()
@property (strong) WebView *webView;
@end

@implementation SCHTMLTranscriptController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.view = [[SCResponderProxyView alloc] initWithFrame:CGRectZero];
        self.webView = [[WebView alloc] initWithFrame:CGRectZero];
        [self.view addSubview:self.webView];

        self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.webView.drawsBackground = NO;
        self.webView.frameLoadDelegate = self;
    }
    return self;
}

- (void)reloadTheme {
    SCThemeManager *tm = [SCThemeManager sharedManager];
    ((SCResponderProxyView *)self.view).drawColor = [tm backgroundColorOfCurrentTheme];
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:[tm baseTemplateURLOfCurrentTheme]]];
}

- (void)reloadConversation {
    [self.webView reload:self];
}

#pragma mark - webview stuff

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    NSScrollView *mainScrollView = sender.mainFrame.frameView.documentView.enclosingScrollView;
    mainScrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    mainScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    [self injectThemeLib];
    [self.conversation replayHistoryIntoContainer:self];
}

- (void)injectThemeLib {
    NSString *base = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"themelib" ofType:@"js"]
                                               encoding:NSUTF8StringEncoding error:nil];
    if (base) {
        [self.webView.mainFrame.windowObject evaluateWebScript:base];
        [self.webView.mainFrame.windowObject setValue:_conversation forKey:@"Conversation"];

        /* you should not rely on this value being available.
         * it's a better idea to hardcode "In the name of the moon, I
         * will punish you!" into your own JS. */
        [self throwEvent:@"SCThemeLibDidInitializeEvent" withObject:@{
            @"": @"In the name of the moon, I will punish you!"
        }];
    }
}

- (void)throwEvent:(NSString *)eventName withObject:(id)object {
    [self.webView.mainFrame.windowObject callWebScriptMethod:@"__SCPostEvent" withArguments:@[eventName, object]];
}

- (void)scrollByPoints:(CGFloat)points {
    [self.webView.mainFrame.windowObject callWebScriptMethod:@"__SCScrollByPointNumber" withArguments:@[@(points)]];
    NSLog(@"did scroll by %lf pts", points);
}

@end

@implementation SCResponderProxyView

- (void)keyDown:(NSEvent *)theEvent {
    if (!self.responder) {
        [super keyDown:theEvent];
    } else {
        [self.responder becomeFirstResponder];
        [self.responder restoreSelection];
        [[NSApplication sharedApplication] postEvent:theEvent atStart:YES];
    }
}

@end