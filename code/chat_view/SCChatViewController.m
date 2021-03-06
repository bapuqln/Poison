#include "Copyright.h"

#import <objc/runtime.h> /* i have a good reason for this, swear to god */
#import "SCChatViewController.h"
#import "SCGradientView.h"
#import "SCThemeManager.h"
#import "SCFillingView.h"
#import "SCConversationManager.h"
#import "SCTextField.h"
#import "SCFileListController.h"
#import "SCHTMLTranscriptController.h"
#import "DESConversation+Poison_CustomName.h"

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

@interface SCChatViewController ()
@property (strong) IBOutlet SCGradientView *convInfoBG;
@property (strong) IBOutlet NSTextField *convInfoName;
@property (strong) IBOutlet NSTextField *convInfoStatus;

@property (strong) IBOutlet NSSplitView *transcriptSplitView;
@property (strong) IBOutlet NSSplitView *splitView;
@property (strong) IBOutlet SCDraggingView *chatEntryView;
@property (strong) IBOutlet SCGradientView *videoBackground;
@property (strong) IBOutlet NSScrollView *userListContainer;
@property (strong) IBOutlet NSTableView *userList;
@property (strong) IBOutlet SCTextField *textField;

@property (strong) SCHTMLTranscriptController *webController;

@property (strong) NSCache *nameCompletionCache;
@property NSInteger userListRememberedSplitPosition; /* from the right */
@property NSInteger videoPaneRememberedSplitPosition; /* from the top */

@property (strong) NSPopover *fileListWindow;
@property (strong) SCFileListController *fileList;
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
    self.webController = [[SCHTMLTranscriptController alloc] init];
    [self.transcriptSplitView addSubview:self.webController.view positioned:NSWindowBelow relativeTo:nil];
    self.nextResponder = self.textField;
    ((SCResponderProxyView *)self.webController.view).responder = self.textField;
    self.splitView.delegate = self;
    [self.view setFrameSize:(NSSize){
        MAX(self.splitView.frame.size.width, self.chatEntryView.frame.size.width),
        self.splitView.frame.size.height + self.chatEntryView.frame.size.height
    }];

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
    self.userList.backgroundColor = [tm backgroundColorOfCurrentTheme];
    self.videoBackground.topColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.10);
    self.videoBackground.bottomColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.15);
    self.videoBackground.borderColor = nil;
    self.videoBackground.shadowColor = SCCreateDarkenedColor([tm barTopColorOfCurrentTheme], 0.3);
    self.videoBackground.dragsWindow = YES;

    self.convInfoBG.topColor = [tm barTopColorOfCurrentTheme];
    self.convInfoBG.bottomColor = [tm barBottomColorOfCurrentTheme];
    self.convInfoBG.borderColor = [tm barBorderColorOfCurrentTheme];
    self.convInfoName.textColor = [tm barTextColorOfCurrentTheme];
    self.convInfoStatus.textColor = [tm barTextColorOfCurrentTheme];
    self.convInfoBG.needsDisplay = YES;
    self.convInfoBG.dragsWindow = YES;
    self.convInfoBG.isFlushWithTitlebar = YES;

    [self.webController reloadTheme];
    
    _currentTheme = [tm pathOfCurrentThemeDirectory];
}

- (void)layoutSubviews_ {
    CGFloat before = self.chatEntryView.frame.size.height;
    [self adjustEntryBounds];
    CGFloat os = self.chatEntryView.frame.size.height;
    [self.chatEntryView.window setContentBorderThickness:os forEdge:NSMinYEdge];
    self.splitView.frame = (CGRect){{0, os},
                                    {self.splitView.frame.size.width,
                                     self.view.frame.size.height - os}};

    CGFloat change;
    if ((change = (os - before)) > 0)
        [self.webController scrollByPoints:change];
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
        return self.splitView.frame.size.height - 150;
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

//- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
//    [splitView adjustSubviews];
//    if (splitView.subviews.count < 2)
//        return;
//
//    CGFloat incorrectPos = ((NSView *)splitView.subviews[0]).frame.size.height;
//    CGFloat correctPos = [self splitView:splitView constrainSplitPosition:incorrectPos ofSubviewAt:0];
//    [splitView setPosition:correctPos ofDividerAtIndex:0];
//}

- (NSColor *)dividerColourForSplitView:(SCNonGarbageSplitView *)splitView {
    if (splitView == self.splitView)
        return SCCreateDarkenedColor([[SCThemeManager sharedManager] barTopColorOfCurrentTheme], 0.15);
    else
        return [[SCThemeManager sharedManager] barBorderColorOfCurrentTheme];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view {
    if (view == self.videoBackground || view == self.userList.superview.superview)
        return NO;
    else
        return YES;
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
    [self layoutSubviews_];
    _completeCycle = nil;
    _completeIndex = 0;
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.textField saveSelection];
}

- (IBAction)sendMessage:(id)sender {
    NSTextField *tf = self.textField;

    if ([tf.stringValue isEqualToString:@""]) {
        NSBeep();
        return;
    }

    if ([NSEvent modifierFlags] & NSCommandKeyMask)
        [self.conversation sendAction:tf.stringValue];
    else
        [self.conversation sendMessage:tf.stringValue];
    tf.stringValue = @"";
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
    CGFloat currentCEHeight = self.chatEntryView.frame.size.height;
    CGFloat actualHeight = fmin(requiredSize.size.height, fourLines);
    CGFloat baseHeight = currentCEHeight - self.textField.frame.size.height;
    /*        h without text field + size of text + textfield padding */
    CGFloat newHeight = baseHeight + actualHeight + 6;
    self.textField.frameSize = (CGSize){self.textField.frame.size.width,
                                        actualHeight + 6};
    self.chatEntryView.frameSize = (CGSize){self.chatEntryView.frame.size.width,
        newHeight};
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self detachKVO];
}

#pragma mark - chat stuff

- (void)attachKVO {
    [_conversation.underlyingConversation addObserver:self forKeyPath:@"presentableTitle" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];
    [_conversation.underlyingConversation addObserver:self forKeyPath:@"presentableSubtitle" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];
}

- (void)detachKVO {
    [_conversation.underlyingConversation removeObserver:self forKeyPath:@"presentableTitle"];
    [_conversation.underlyingConversation removeObserver:self forKeyPath:@"presentableSubtitle"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSDictionary *change_ = [change copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([keyPath isEqualToString:@"presentableTitle"])
            self.convInfoName.stringValue = [(DESConversation *)object preferredUIName];
        if ([keyPath isEqualToString:@"presentableSubtitle"]) {
            NSString *status = change_[NSKeyValueChangeNewKey];
            if ([[status stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""])
                status = NSLocalizedString(@"No status", @"");
            self.convInfoStatus.stringValue = status;
        }
    });
}

- (void)setConversation:(SCConversation *)conversation {
    [_conversation removeContainer:self.webController];
    [self detachKVO];
    _conversation = conversation;
    [self attachKVO];
    [conversation addContainer:self.webController];
    self.webController.conversation = conversation;
    [self.webController reloadConversation];
}

#pragma mark - selecting actions

- (IBAction)doActionFromButtons:(NSSegmentedControl *)sender {
    NSLog(@"%ld", (long)sender.selectedSegment);
    switch (sender.selectedSegment) {
        case 0:
            if (!self.fileListWindow)
                self.fileListWindow = [[NSPopover alloc] init];
            if (!self.fileList) {
                self.fileList = [[SCFileListController alloc] initWithNibName:@"FileTransfer" bundle:[NSBundle mainBundle]];

                self.fileListWindow.contentViewController = self.fileList;
                self.fileListWindow.contentSize = self.fileList.view.frame.size;
                self.fileListWindow.behavior = NSPopoverBehaviorTransient;
            }
            [self.fileListWindow showRelativeToRect:[sender.cell rectForSegment:0 inFrame:sender.bounds] ofView:sender preferredEdge:NSMaxYEdge];
            break;
        case 1:
            [NSMenu popUpContextMenu:self.secretActionMenu withEvent:[[NSApplication sharedApplication] currentEvent] forView:sender];
            break;
        default:
            break;
    }
}

@end
