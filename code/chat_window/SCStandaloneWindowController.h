#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@class DESConversation;
@interface SCStandaloneWindowController : NSWindowController <NSWindowDelegate>
- (instancetype)initWithConversation:(DESConversation *)conv;
- (NSString *)conversationIdentifier;
@end
