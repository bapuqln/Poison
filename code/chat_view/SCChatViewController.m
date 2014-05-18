#include "Copyright.h"

#import <objc/runtime.h> /* i have a good reason for this, swear to god */
#import "SCChatViewController.h"
#import "SCGradientView.h"
#import "SCThemeManager.h"
#import "SCFillingView.h"
#import "SCConversationManager.h"
#import <WebKit/WebKit.h>

NS_INLINE NSColor *SCDarkenedColor(NSColor *color, CGFloat factor) {
    CGFloat compo[3];
    [color getRed:&compo[0] green:&compo[1] blue:&compo[2] alpha:NULL];
    for (int i = 0; i < 4; ++i) {
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

@interface SCChatViewController ()
@property (strong) IBOutlet NSSplitView *transcriptSplitView;
@property (strong) IBOutlet NSSplitView *splitView;
@property (strong) IBOutlet SCGradientView *statusBar;
@property (strong) IBOutlet WebView *webView;
@property (strong) IBOutlet NSView *transcriptView;
@property (strong) IBOutlet SCDraggingView *chatEntryView;
@property (strong) IBOutlet NSTextField *chatTitle;
@property (strong) IBOutlet SCGradientView *videoBackground;
@property (strong) IBOutlet NSScrollView *userListContainer;
@property (strong) IBOutlet NSTableView *userList;
@property (strong) IBOutlet NSTextField *textField;

@property (strong) NSCache *nameCompletionCache;
@property NSInteger userListRememberedSplitPosition; /* from the right */
@property NSInteger videoPaneRememberedSplitPosition; /* from the top */

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
}

- (void)reloadTheme {
    SCThemeManager *tm = [SCThemeManager sharedManager];
    self.statusBar.topColor = [tm barTopColorOfCurrentTheme];
    self.statusBar.bottomColor = [tm barBottomColorOfCurrentTheme];
    self.statusBar.shadowColor = [tm barHighlightColorOfCurrentTheme];
    self.statusBar.borderColor = [tm barBorderColorOfCurrentTheme];
    self.statusBar.dragsWindow = YES;
    self.chatTitle.textColor = [tm barTextColorOfCurrentTheme];
    
    ((SCFillingView*)self.webView.superview).drawColor = [tm backgroundColorOfCurrentTheme];
    self.userList.backgroundColor = [tm backgroundColorOfCurrentTheme];
    self.videoBackground.topColor = SCDarkenedColor([tm barTopColorOfCurrentTheme], 0.10);
    self.videoBackground.bottomColor = SCDarkenedColor([tm barTopColorOfCurrentTheme], 0.15);
    self.videoBackground.borderColor = nil;
    self.videoBackground.shadowColor = SCDarkenedColor([tm barTopColorOfCurrentTheme], 0.3);
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

- (IBAction)_testTogglingUserList:(id)sender {
    self.showsUserList = self.showsUserList ? NO: YES;
}

- (IBAction)_testTogglingVideoList:(id)sender {
    self.showsVideoPane = self.showsVideoPane ? NO: YES;
}

#pragma mark - splitview

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView == self.splitView)
        return 150;
    else
        return splitView.frame.size.width - 200;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView == self.splitView)
        return self.splitView.frame.size.height - 150;
    else
        return splitView.frame.size.width - 100;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    CGSize deltas = (CGSize){splitView.frame.size.width - oldSize.width, splitView.frame.size.height - oldSize.height};
    if (splitView == self.splitView) {
        [self.splitView adjustSubviews];
    } else if (self.showsUserList) {
        NSView *expands = (NSView*)splitView.subviews[0];
        NSView *doesntExpand = (NSView*)splitView.subviews[1];
        expands.frameSize = (CGSize){expands.frame.size.width + deltas.width, expands.frame.size.height + deltas.height};
        doesntExpand.frame = (CGRect){{expands.frame.size.width + 1, 0}, {splitView.frame.size.width - expands.frame.size.width - 1, splitView.frame.size.height}};
    } else {
        [splitView adjustSubviews];
    }
}

- (NSColor *)dividerColourForSplitView:(SCNonGarbageSplitView *)splitView {
    if (splitView == self.splitView)
        return [NSColor controlDarkShadowColor];
    else
        return [[SCThemeManager sharedManager] barBorderColorOfCurrentTheme];
}

#pragma mark - webview stuff

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    NSScrollView *mainScrollView = sender.mainFrame.frameView.documentView.enclosingScrollView;
    mainScrollView.verticalScrollElasticity = NSScrollElasticityAllowed;
    mainScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    [self injectThemeLib];
}

- (void)injectThemeLib {
    NSString *base = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"themelib" ofType:@"js"]
                                               encoding:NSUTF8StringEncoding error:nil];
    if (base)
        [self.webView.mainFrame.windowObject evaluateWebScript:base];
}

#pragma mark - textfield delegate

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
            NSLog(@"textfield:cmd-enter");
            return YES;
        }
    } else if (commandSelector == @selector(insertTab:)) {
        NSRange selRange = textView.selectedRange;
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
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeKVOHandlers];
}

#pragma mark - chat stuff

- (void)setConversation:(SCConversation *)conversation {
    if (_conversation)
        [self removeKVOHandlers];
    _conversation = conversation;
    _conversation.container = self;
    [self addKVOHandlers];
    [self updateHeader];
}

- (void)addKVOHandlers {
    [_conversation.underlyingConversation addObserver:self
                                           forKeyPath:@"presentableTitle"
                                              options:NSKeyValueObservingOptionNew
                                              context:NULL];
    [_conversation.underlyingConversation addObserver:self
                                           forKeyPath:@"presentableSubtitle"
                                              options:NSKeyValueObservingOptionNew
                                              context:NULL];
}

- (void)removeKVOHandlers {
    [_conversation.underlyingConversation removeObserver:self forKeyPath:@"presentableTitle"];
    [_conversation.underlyingConversation removeObserver:self forKeyPath:@"presentableSubtitle"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self updateHeader];
}

- (void)updateHeader {
    NSMutableAttributedString *header;
    header = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", _conversation.underlyingConversation.presentableTitle]];
    NSAttributedString *sub;
    sub = [[NSMutableAttributedString alloc] initWithString:_conversation.underlyingConversation.presentableSubtitle
                                                 attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:11]}];
    [header appendAttributedString:sub];
    self.chatTitle.attributedStringValue = header;
}

@end
