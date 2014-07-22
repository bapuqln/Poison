#include "Copyright.h"

#import <objc/runtime.h> /* i have a good reason for this, swear to god */
#import "SCChatViewController.h"
#import "SCGradientView.h"
#import "SCThemeManager.h"
#import "SCFillingView.h"
#import "SCConversationManager.h"
#import "SCTextField.h"
#import "SCFileListController.h"
#import <WebKit/WebKit.h>

NS_INLINE NSColor *SCCreateDarkenedColor(NSColor *color, CGFloat factor) {
    CGFloat compo[3];
    [color getRed:&compo[0] green:&compo[1] blue:&compo[2] alpha:NULL];
    for (int i = 0; i < 3; ++i) {
        compo[i] *= factor;
    }
    return [NSColor colorWithCalibratedRed:compo[0] green:compo[1] blue:compo[2] alpha:1.0];
}

NS_INLINE NSString *SCMakeStringCompletionAlias(NSString *input) {
    static NSMutableCharacterSet *masterSet = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        masterSet = [NSMutableCharacterSet symbolCharacterSet];
        [masterSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    });
    NSMutableString *out_ = [[NSMutableString alloc] initWithCapacity:[input length]];
    NSUInteger il = [input length];
    for (int i = 0; i < il; ++i) {
        if ([masterSet characterIsMember:[input characterAtIndex:i]])
            continue;
        else
            [out_ appendString:[input substringWithRange:NSMakeRange(i, 1)]];
    }
    return (NSString*)out_;
}

@interface NSSegmentedControl (ApplePrivate)
- (NSRect)rectForSegment:(NSInteger)arg1 inFrame:(NSRect)arg2;
@end

@interface SCResponderProxyView : SCFillingView
@property (weak) SCTextField *responder;
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

@interface SCChatViewController ()
@property (strong) IBOutlet NSSplitView *transcriptSplitView;
@property (strong) IBOutlet NSSplitView *splitView;
@property (strong) IBOutlet WebView *webView;
@property (strong) IBOutlet NSView *transcriptView;
@property (strong) IBOutlet SCDraggingView *chatEntryView;
@property (strong) IBOutlet SCGradientView *videoBackground;
@property (strong) IBOutlet NSScrollView *userListContainer;
@property (strong) IBOutlet NSTableView *userList;
@property (strong) IBOutlet SCTextField *textField;
@property (strong) IBOutlet SCResponderProxyView *webSuperview;

@property (strong) NSCache *nameCompletionCache;
@property NSInteger userListRememberedSplitPosition; /* from the right */
@property NSInteger videoPaneRememberedSplitPosition; /* from the top */

@property (strong) IBOutlet NSPopover *fileListWindow;
@property (strong) IBOutlet SCFileListController *fileList;

@end

@implementation SCChatViewController {
    NSArray *_completeCycle;
    NSUInteger _completeIndex;
    NSRange _completeClobber;
    NSString *_currentTheme;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.nameCompletionCache = [[NSCache alloc] init];
        _showsUserList = YES;
        _showsVideoPane = YES;
    }
    return self;
}

- (void)awakeFromNib {
    self.nextResponder = self.textField;
    self.webSuperview.responder = self.textField;
    self.splitView.delegate = self;
    [self.view setFrameSize:(NSSize){
        MAX(self.splitView.frame.size.width, self.chatEntryView.frame.size.width),
        self.splitView.frame.size.height + self.chatEntryView.frame.size.height
    }];
    self.webView.drawsBackground = NO;
    self.webView.frameLoadDelegate = self;
    [self reloadTheme];
    SCThemeManager *tm = [SCThemeManager sharedManager];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(textFieldDidResize:)
               name:NSViewFrameDidChangeNotification
             object:self.textField];
    [nc addObserver:self selector:@selector(reloadTheme)
               name:SCTranscriptThemeDidChangeNotification
             object:tm];
    self.textField.delegate = self;
    [self.splitView setFrameOrigin:(CGPoint){0, self.chatEntryView.frame.size.height}];
    [self.chatEntryView setFrameOrigin:(CGPoint){0, 0}];
    self.chatEntryView.dragsWindow = YES;
    [self.view addSubview:self.splitView];
    [self.view addSubview:self.chatEntryView];
    [self.splitView adjustSubviews];
    [self.transcriptSplitView adjustSubviews];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
    if ([NSVisualEffectView class])
        self.videoBackground.isFlushWithTitlebar = YES;
#endif
}

- (void)reloadTheme {
    SCThemeManager *tm = [SCThemeManager sharedManager];
    ((SCFillingView*)self.webView.superview).drawColor = [tm backgroundColorOfCurrentTheme];
    self.userList.backgroundColor = [tm backgroundColorOfCurrentTheme];
    self.videoBackground.topColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.10);
    self.videoBackground.bottomColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.15);
    self.videoBackground.borderColor = nil;
    self.videoBackground.shadowColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.3);
    self.videoBackground.dragsWindow = YES;
    
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:[tm baseTemplateURLOfCurrentTheme]]];
    _currentTheme = [tm pathOfCurrentThemeDirectory];
}

- (void)layoutSubviews_ {
    CGFloat os = self.chatEntryView.frame.size.height;
    [self.chatEntryView.window setContentBorderThickness:os forEdge:NSMinYEdge];
    self.splitView.frame = (CGRect){{0, os},
                                    {self.splitView.frame.size.width,
                                     self.view.frame.size.height - os}};
}

#pragma mark - management of auxilary panes

- (void)setShowsUserList:(BOOL)showsUserList {
    if (showsUserList && !self.showsUserList) {
        NSLog(@"Showing the userlist");
        [self.transcriptSplitView addSubview:self.userListContainer];
        [self.transcriptSplitView adjustSubviews];
        [self.transcriptSplitView setPosition:self.transcriptSplitView.frame.size.width - self.userListRememberedSplitPosition ofDividerAtIndex:0];
    } else if (!showsUserList && self.showsUserList) {
        NSLog(@"Hiding the userlist");
        self.userListRememberedSplitPosition = self.userListContainer.frame.size.width + 1;
        [self.userListContainer removeFromSuperview];
    }
    _showsUserList = showsUserList;
}

- (void)setShowsVideoPane:(BOOL)showsVideoPane {
    if (showsVideoPane && !self.showsVideoPane) {
        NSLog(@"Showing the userlist");
        [self.splitView addSubview:self.videoBackground positioned:NSWindowBelow relativeTo:self.splitView.subviews[0]];
        [self.splitView adjustSubviews];
        [self.splitView setPosition:self.videoPaneRememberedSplitPosition ofDividerAtIndex:0];
    } else if (!showsVideoPane && self.showsVideoPane) {
        NSLog(@"Hiding the userlist");
        self.videoPaneRememberedSplitPosition = self.videoBackground.frame.size.height;
        [self.videoBackground removeFromSuperview];
    }
    _showsVideoPane = showsVideoPane;
}

#pragma mark - splitview

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView == self.splitView)
        return 32;
    else
        return splitView.frame.size.width - 200;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView == self.splitView)
        return self.splitView.frame.size.height - 32;
    else
        return splitView.frame.size.width - 100;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView != self.splitView)
        return proposedPosition;

    if (proposedPosition < 130) {
        return 32;
    } else {
        return MAX(150, proposedPosition);
    }
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    [splitView adjustSubviews];
    if (splitView.subviews.count < 2)
        return;

    CGFloat incorrectPos = ((NSView *)splitView.subviews[0]).frame.size.height;
    CGFloat correctPos = [self splitView:splitView constrainSplitPosition:incorrectPos ofSubviewAt:0];
    [splitView setPosition:correctPos ofDividerAtIndex:0];
}

//- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
//    CGSize deltas = (CGSize){splitView.frame.size.width - oldSize.width, splitView.frame.size.height - oldSize.height};
//    if (splitView == self.splitView) {
//        [self.splitView adjustSubviews];
//    } else if (self.showsUserList) {
//        NSView *expands = (NSView*)splitView.subviews[0];
//        NSView *doesntExpand = (NSView*)splitView.subviews[1];
//        expands.frameSize = (CGSize){expands.frame.size.width + deltas.width, expands.frame.size.height + deltas.height};
//        doesntExpand.frame = (CGRect){{expands.frame.size.width + 1, 0}, {splitView.frame.size.width - expands.frame.size.width - 1, splitView.frame.size.height}};
//    } else {
//        [splitView adjustSubviews];
//    }
//}

- (NSColor *)dividerColourForSplitView:(SCNonGarbageSplitView *)splitView {
    if (splitView == self.splitView)
        return [NSColor controlDarkShadowColor];
    else
        return [[SCThemeManager sharedManager] barBorderColorOfCurrentTheme];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view {
    if (view == self.videoBackground || view == self.userList)
        return NO;
    else
        return YES;
}

#pragma mark - webview stuff

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    NSScrollView *mainScrollView = sender.mainFrame.frameView.documentView.enclosingScrollView;
    mainScrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    mainScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    [self injectThemeLib];
    [self.webView.mainFrame.windowObject setValue:_conversation forKey:@"Conversation"];
    [_conversation replayHistoryIntoContainer:self];
}

- (void)injectThemeLib {
    NSString *base = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"themelib" ofType:@"js"]
                                               encoding:NSUTF8StringEncoding error:nil];
    if (base) {
        [self.webView.mainFrame.windowObject evaluateWebScript:base];
    }
}

- (void)throwEvent:(NSString *)eventName withObject:(id)object {
    [self.webView.mainFrame.windowObject callWebScriptMethod:@"__SCPostEvent" withArguments:@[eventName, object]];
}

#pragma mark - textfield delegate

/*- (NSResponder *)nextResponder {
    return self.textField;
}*/

- (NSArray *)candidatesForTabCompletion:(NSString *)s {
    NSString *fragment = [s lowercaseString];
    const char *frag = [fragment UTF8String];
    NSUInteger len = [fragment lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *completes = [NSMutableArray arrayWithCapacity:10];
    for (NSString *possibleName in (self.conversation.completionOrder ?: [NSOrderedSet orderedSet])) {
        NSString *actualComparator = [possibleName lowercaseString];
        if ([actualComparator lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= len
            && memcmp(frag, [actualComparator UTF8String], len) == 0) {
            [completes addObject:possibleName];
            continue;
        }
        /* Try it with a string that has symbols stripped
         * that way, you can tabcomp "[420]xXxKuShG@m3R9001xXx"
         * by just typing "420" */
        NSString *strippedComp = [self.nameCompletionCache objectForKey:actualComparator];
        if (!strippedComp) {
            strippedComp = SCMakeStringCompletionAlias(actualComparator);
            [self.nameCompletionCache setObject:strippedComp forKey:actualComparator];
        }
        if ([strippedComp lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= len
            && memcmp(frag, [strippedComp UTF8String], len) == 0) {
            [completes addObject:possibleName];
            continue;
        }
    }
    return completes.count? completes : nil;
}

- (NSString *)nextTabCompletionCandidate:(NSString *)s {
    if (!_completeCycle) {
        _completeCycle = [self candidatesForTabCompletion:s];
        _completeIndex = 0;
    }
    NSUInteger n = _completeCycle.count;
    if (n == 0) {
        return nil;
    } else {
        _completeIndex = (_completeIndex % n);
    }
    return _completeCycle[_completeIndex++];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    if (sel_isEqual(commandSelector, @selector(noop:))) {
    #pragma clang diagnostic pop
        if ([NSEvent modifierFlags] & NSCommandKeyMask) {
            [self sendMessage:(NSTextField *)control];
            return YES;
        }
    } else if (commandSelector == @selector(insertTab:)) {
        NSRange selRange = textView.selectedRange;

        if ([textView.string isEqualToString:@""]) {
            [textView insertTab:self];
            return YES;
        }

        NSUInteger psUpperBound = selRange.location + selRange.length;
        [textView selectWord:self];
        NSUInteger newSelRangeLoc = textView.selectedRange.location;
        NSRange replaceRange;
        if (!_completeCycle)
            replaceRange = NSMakeRange(newSelRangeLoc, psUpperBound - newSelRangeLoc);
        else
            replaceRange = _completeClobber;
        NSString *completionResult = [self nextTabCompletionCandidate:[textView.string substringWithRange:replaceRange]];
        if (!completionResult) {
            NSBeep();
            textView.selectedRange = selRange;
            return YES;
        }
        NSString *repString;
        if (replaceRange.location == 0)
            repString = [NSString stringWithFormat:@"%@%@ ", completionResult,
                         [[NSUserDefaults standardUserDefaults] stringForKey:@"nameCompletionDelimiter"]];
        else
            repString = [NSString stringWithFormat:@"%@ ", completionResult];
        textView.string = [textView.string stringByReplacingCharactersInRange:replaceRange withString:repString];
        _completeClobber = NSMakeRange(replaceRange.location, repString.length);
        [self adjustEntryBounds];
        return YES;
    } else if (sel_isEqual(commandSelector, @selector(insertNewline:))
               && [NSEvent modifierFlags] & NSShiftKeyMask) {
        /* Force a newline on shift-enter. */
        [textView insertNewlineIgnoringFieldEditor:self];
        return YES;
    } else if ([textView respondsToSelector:commandSelector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [textView performSelector:commandSelector withObject:control];
        #pragma clang diagnostic pop
        return YES;
    }
    return NO;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self adjustEntryBounds];
    [self layoutSubviews_];
    _completeCycle = nil;
    _completeIndex = 0;
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.textField saveSelection];
}

- (IBAction)sendMessageFromButton:(id)sender {
    [self sendMessage:self.textField];
}

- (IBAction)sendMessage:(NSTextField *)sender {
    if ([sender.stringValue isEqualToString:@""]) {
        NSBeep();
        return;
    }

    if ([NSEvent modifierFlags] & NSCommandKeyMask)
        [self.conversation sendAction:sender.stringValue];
    else
        [self.conversation sendMessage:sender.stringValue];
    sender.stringValue = @"";
    [self adjustEntryBounds];
    [self layoutSubviews_];
}

- (void)textFieldDidResize:(NSNotification *)obj {
    [self adjustEntryBounds];
}

- (void)adjustEntryBounds {
    static NSMutableParagraphStyle *cached = nil;
    if (!cached) {
        cached = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        cached.lineBreakMode = NSLineBreakByWordWrapping;
    }
    static CGFloat fourLines = 0.0;
    if (!fourLines) {
        fourLines = [@"\n\n\n" sizeWithAttributes:
                     @{NSFontAttributeName: self.textField.font,
                       NSParagraphStyleAttributeName: cached}].height;
    }
    NSStringDrawingOptions scOpts = (NSStringDrawingUsesLineFragmentOrigin
                                     | NSStringDrawingDisableScreenFontSubstitution);
    CGRect requiredSize = [self.textField.stringValue boundingRectWithSize:
                           (CGSize){self.textField.frame.size.width - 8, 9001}
                           options:scOpts
                        attributes:@{NSFontAttributeName: self.textField.font}];
    CGFloat actualHeight = fmin(requiredSize.size.height, fourLines);
    CGFloat baseHeight = self.chatEntryView.frame.size.height - self.textField.frame.size.height;
    /*        h without text field + size of text + textfield padding */
    CGFloat newHeight = baseHeight + actualHeight + 6;
    self.textField.frameSize = (CGSize){self.textField.frame.size.width,
                                        actualHeight + 6};
    self.chatEntryView.frameSize = (CGSize){self.chatEntryView.frame.size.width,
        newHeight};

    //[self.webView.mainFrame.frameView.documentView.enclosingScrollView scroll:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - chat stuff

- (void)setConversation:(SCConversation *)conversation {
    [_conversation removeContainer:self];
    _conversation = conversation;
    [conversation addContainer:self];
    [self.webView reload:self];
}

#pragma mark - selecting actions

- (IBAction)doActionFromButtons:(NSSegmentedControl *)sender {
    NSLog(@"%ld", (long)sender.selectedSegment);
    switch (sender.selectedSegment) {
        case 2:
            if (!self.fileListWindow)
                self.fileListWindow = [[NSPopover alloc] init];
            if (!self.fileList) {
                self.fileList = [[SCFileListController alloc] initWithNibName:@"FileTransfer" bundle:[NSBundle mainBundle]];

                self.fileListWindow.contentViewController = self.fileList;
                self.fileListWindow.contentSize = self.fileList.view.frame.size;
                self.fileListWindow.behavior = NSPopoverBehaviorTransient;
            }
            [self.fileListWindow showRelativeToRect:[sender.cell rectForSegment:2 inFrame:sender.bounds] ofView:sender preferredEdge:NSMaxYEdge];
            break;
        case 3:
            [NSMenu popUpContextMenu:self.secretActionMenu withEvent:[[NSApplication sharedApplication] currentEvent] forView:sender];
            break;
        default:
            break;
    }
}

@end
