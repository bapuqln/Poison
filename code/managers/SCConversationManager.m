#include "Copyright.h"

#import "SCConversationManager.h"
#import "DESConversation+Poison_CustomName.h"

@implementation SCConversation {
    DESConversation *__weak _underlyingConversation;
    NSMutableOrderedSet *_nameSet;
}

- (instancetype)initWithConv:(DESConversation *)conv {
    self = [super init];
    if (self) {
        _underlyingConversation = conv;
        _lastAlive = [NSDate dateWithTimeIntervalSince1970:0];
        _nameSet = [[NSMutableOrderedSet alloc] initWithSet:conv.participants];
    }
    return self;
}

- (DESConversation *)underlyingConversation {
    return _underlyingConversation;
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
        [self deleteConversation:_conversations[conv.conversationIdentifier]];
    conv.delegate = self;
    _conversations[conv.conversationIdentifier] = [[SCConversation alloc] initWithConv:conv];
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

}

- (void)conversation:(DESConversation *)con didReceiveDeliveryNotificationForMessageID:(uint32_t)messageID {

}

- (void)conversation:(DESConversation *)con didReceiveMessage:(NSString *)message ofType:(DESMessageType)type_ fromSender:(DESFriend *)sender {

}

@end
