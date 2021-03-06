#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "SCNonGarbageSplitView.h"

@class SCConversation;
@interface SCChatViewController : NSViewController <SCNonGarbageSplitViewDelegate, NSTextFieldDelegate>
@property (nonatomic) BOOL showsVideoPane;
@property (nonatomic) BOOL showsUserList;
@property (strong) IBOutlet NSMenu *secretActionMenu;
@property (nonatomic) SCConversation *conversation;
@end
