#include "Copyright.h"

#import "SCConversationManager.h"
#import "DESConversation+Poison_CustomName.h"
#import "SCMessages.h"

#define MARK_MESSAGE_SEARCH_LIMIT (100)

@implementation SCConversation {
    DESConversation *_underlyingConversation;
    NSMutableArray *_chatHistory;
    NSMutableArray *_pendingMessages;
    NSMutableOrderedSet *_nameSet;
}

#pragma mark - WebKit scripting methods

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
    return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return NO;
}

- (NSURL *)getAppResourceNamed:(NSString *)name {
    return [[NSBundle mainBundle] URLForResource:name withExtension:@""];
}

#pragma mark - Other stuff

- (instancetype)initWithConv:(DESConversation *)conv {
    self = [super init];
    if (self) {
        _underlyingConversation = conv;
        _chatHistory = [NSMutableArray arrayWithCapacity:[[NSUserDefaults standardUserDefaults] integerForKey:@"backlogSize"]];
        _pendingMessages = [[NSMutableArray alloc] initWithCapacity:10];
        _lastAlive = [NSDate dateWithTimeIntervalSince1970:0];
        _nameSet = [[NSMutableOrderedSet alloc] initWithSet:conv.participants];
    }
    return self;
}

- (DESConversation *)underlyingConversation {
    return _underlyingConversation;
}

#pragma mark - Delegate-Delegate methods

- (void)markDeliveryOfMessage:(uint32_t)messageNumber {
    int i = 0;
    for (id<SCMessage> msg in _chatHistory.reverseObjectEnumerator) {
        if (i++ > MARK_MESSAGE_SEARCH_LIMIT)
            break;
        if ([msg isKindOfClass:[SCChatMessage class]]
            && ((SCChatMessage *)msg).messageNumber == messageNumber) {
            break;
        }
    }
}

@end

@implementation SCConversationManager {
    NSMutableDictionary *_conversations;
}

- (id)init {
    self = [super init];
    if (self) {
        _conversations = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    return self;
}

- (void)addConversation:(DESConversation *)conv {
    if (_conversations[conv.conversationIdentifier])
        [self deleteConversation:[_conversations[conv.conversationIdentifier] underlyingConversation]];
    conv.delegate = self;
    _conversations[conv.conversationIdentifier] = [[SCConversation alloc] initWithConv:conv];
    NSLog(@"note: became delegate for %@", conv.conversationIdentifier);
}

- (void)deleteConversation:(DESConversation *)conv {
    if (conv.delegate == self) {
        conv.delegate = nil;
    }
    [_conversations removeObjectForKey:conv.conversationIdentifier];
}

- (SCConversation *)conversationFor:(DESConversation *)llconv {
    if (!_conversations[llconv.conversationIdentifier])
        [self addConversation:llconv];
    return _conversations[llconv.conversationIdentifier];
}


- (void)conversation:(DESConversation *)con didFailToSendMessageWithID:(uint32_t)messageID ofType:(DESMessageType)type_ {
    [self conversationFor:con];
}

- (void)conversation:(DESConversation *)con didReceiveDeliveryNotificationForMessageID:(uint32_t)messageID {
    [[self conversationFor:con] markDeliveryOfMessage:messageID];
}

/*- (void)conversation:(DESConversation *)con didReceiveMessage:(NSString *)message ofType:(DESMessageType)type_ fromSender:(DESFriend *)sender {
    [[self conversationFor:con] postChatMessage:message ofType:type_ sender:sender];
}*/

@end
