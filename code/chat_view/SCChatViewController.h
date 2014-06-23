#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "SCNonGarbageSplitView.h"

@class SCConversation;
@interface SCChatViewController : NSViewController <SCNonGarbageSplitViewDelegate, NSTextFieldDelegate>
@property (nonatomic) BOOL showsVideoPane;
@property (nonatomic) BOOL showsUserList;

@property (nonatomic) SCConversation *conversation;

- (void)throwEvent:(NSString *)eventName withObject:(id)object;
@end
