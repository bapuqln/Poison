#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@class DESConversation, SCChatViewController;
@interface SCStandaloneWindowController : NSWindowController <NSWindowDelegate>
@property (readonly) DESConversation *conversation;
@property (readonly) NSString *conversationIdentifier;

- (instancetype)initWithConversation:(DESConversation *)conv;
- (SCChatViewController *)chatView;
@end
