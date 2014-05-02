#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "ObjectiveTox.h"
#import "SCChatViewController.h"

@interface SCConversation : NSObject
@property (strong, readonly) DESConversation *underlyingConversation;
@property (strong, readonly) NSArray *log;
@property (strong) NSDate *lastAlive;
@property (strong) NSOrderedSet *completionOrder;
@property (strong) NSArray *offlineSendQueue;

@property (weak) SCChatViewController *container;
@end

@interface SCConversationManager : NSObject <DESConversationDelegate>
- (void)addConversation:(DESConversation *)conv;
- (void)deleteConversation:(DESConversation *)conv;
- (SCConversation *)conversationFor:(DESConversation *)llconv;
@end
