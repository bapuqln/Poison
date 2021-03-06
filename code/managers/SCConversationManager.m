#include "Copyright.h"

#import "SCAppDelegate.h"
#import "SCConversationManager.h"
#import "DESConversation+Poison_CustomName.h"
#import "SCMessages.h"
#import "SCProfileManager.h"
#import "SCDiary.h"

#define MARK_MESSAGE_PLAYBACK_LIMIT (100)

@implementation SCConversation {
    DESConversation *_underlyingConversation;
    NSMutableArray *_chatHistory;
    NSMutableDictionary *_pendingMessages;
    NSMutableOrderedSet *_nameSet;
    NSInteger _backlogSize;
    NSHashTable *_containerBacking;
}

#pragma mark - WebKit scripting methods

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
    return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return NO;
}

- (NSString *)getAppResourceNamed:(NSString *)name {
    return [[NSBundle mainBundle] URLForResource:name withExtension:@""].absoluteString;
}

- (NSString *)avatarImageFor:(NSString *)senderuid {
    return [[SCProfileManager currentProfile] avatarForUID:senderuid].url.absoluteString;
}

#pragma mark - Other stuff

- (instancetype)initWithConv:(DESConversation *)conv {
    // NSLog(@"note: SCConversation init for %@", conv.conversationIdentifier);
    self = [super init];
    if (self) {
        _underlyingConversation = conv;
        _backlogSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"backlogSize"];
        _chatHistory = [NSMutableArray arrayWithCapacity:_backlogSize];
        _pendingMessages = [[NSMutableDictionary alloc] initWithCapacity:1];
        _lastAlive = [NSDate dateWithTimeIntervalSince1970:0];
        _nameSet = [[NSMutableOrderedSet alloc] initWithSet:conv.participants];
        _containerBacking = [[NSHashTable alloc] initWithOptions:NSHashTableWeakMemory capacity:1];
    }
    return self;
}

- (DESConversation *)underlyingConversation {
    return _underlyingConversation;
}

- (void)sendMessage:(NSString *)message {
    uint32_t mid = [_underlyingConversation sendMessage:message];
    SCPendingMessage *msg = [[SCPendingMessage alloc] initWithString:message id:mid];
    _pendingMessages[@(mid)] = msg;
    self.lastAlive = [NSDate date];
}

- (void)sendAction:(NSString *)message {
    uint32_t aid = [_underlyingConversation sendAction:message];
    SCPendingMessage *msg = [[SCPendingMessage alloc] initWithString:message id:aid];
    _pendingMessages[@(aid)] = msg;
    self.lastAlive = [NSDate date];
}

- (void)replayHistoryIntoContainer:(SCHTMLTranscriptController *)container {
    if ([self containsContainer:container] && _chatHistory.count > 0) {
        [container throwEvent:@"SCMessagePostedEvent" withObject:_chatHistory];
    }
}

/* TODO: instead of removing messages outright, move them to the diary */
- (void)manageChatHistory {
    NSInteger removedCount = 0;
    if (_chatHistory.count > _backlogSize) {
        removedCount = _chatHistory.count - _backlogSize;
        [_chatHistory removeObjectsInRange:NSMakeRange(0, removedCount)];
    }
    if (_containerBacking.count > 0 && removedCount > 0) {
        for (SCHTMLTranscriptController *c in _containerBacking) {
            [c throwEvent:@"SCMessagesPrunedEvent" withObject:@(removedCount)];
        }
    }
}

#pragma mark - Delegate-Delegate methods

- (void)conversation:(DESConversation *)con didFailToSendMessageWithID:(uint32_t)messageID ofType:(DESMessageType)type_ {
    NSNumber *wrappedMID = @(messageID);
    SCPendingMessage *previouslySentMessage = _pendingMessages[wrappedMID];

    if (!previouslySentMessage)
        return;

    SCChatMessage *msg = [[SCChatMessage alloc] initWithString:previouslySentMessage.messageString type:type_ sender:con.connection.me id:messageID];
    [_chatHistory addObject:msg];

    [self manageChatHistory];

    for (SCHTMLTranscriptController *c in _containerBacking) {
        [c throwEvent:@"SCFailedMessagePostedEvent" withObject:@[msg]];
    }
}

- (void)conversation:(DESConversation *)con didReceiveDeliveryNotificationForMessageID:(uint32_t)messageID {
    NSInteger iteration = 0;
    for (SCChatMessage *msg in _chatHistory.reverseObjectEnumerator) {
        ++iteration;
        if (![msg isKindOfClass:[SCChatMessage class]])
            continue;
        if (iteration > MARK_MESSAGE_PLAYBACK_LIMIT)
            return;
        if (msg.messageID == messageID) {
            self.lastAlive = [NSDate date];
            msg.successfullyDelivered = YES;
            for (SCHTMLTranscriptController *c in _containerBacking) {
                [c throwEvent:@"SCMessageDeliveredEvent" withObject:@(messageID)];
            }
        }
    }
}

- (void)conversation:(DESConversation *)con didReceiveMessage:(NSString *)message ofType:(DESMessageType)type_ fromSender:(DESFriend *)sender {
    SCChatMessage *msg = [[SCChatMessage alloc] initWithString:message type:type_ sender:sender];
    [_chatHistory addObject:msg];

    [self manageChatHistory];
    self.lastAlive = [NSDate date];
    for (SCHTMLTranscriptController *c in _containerBacking) {
        [c throwEvent:@"SCMessagePostedEvent" withObject:@[msg]];
    }
}

- (void)conversation:(DESConversation *)con didSendMessageWithID:(uint32_t)messageID ofType:(DESMessageType)type_ {
    NSNumber *wrappedMID = @(messageID);
    SCPendingMessage *previouslySentMessage = _pendingMessages[wrappedMID];
    [_pendingMessages removeObjectForKey:wrappedMID];

    if (!previouslySentMessage)
        return;

    SCChatMessage *msg = [[SCChatMessage alloc] initWithString:previouslySentMessage.messageString type:type_ sender:con.connection.me id:messageID];
    [_chatHistory addObject:msg];

    [self manageChatHistory];
    self.lastAlive = [NSDate date];

    for (SCHTMLTranscriptController *c in _containerBacking) {
        [c throwEvent:@"SCMessagePostedEvent" withObject:@[msg]];
    }
}

- (void)conversation:(DESConversation *)con didReceiveFileTransferRequest:(DESFileTransfer *)transferIn {
    return;

    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"test_2"];
    NSLog(@"%@", path);
    [transferIn acceptFileTransferIntoFile:path append:NO];
}

- (void)conversation:(DESConversation *)con fileTransfer:(DESFileTransfer *)transfer didChangeState:(DESTransferState)newState {
    
}

- (void)noteStatusMessageChanged:(NSString *)oldValue {
    SCAttributeMessage *msg = [[SCAttributeMessage alloc] initWithOldValue:oldValue
                                                               sender:(DESFriend *)self.underlyingConversation
                                                            attribute:SCAttributeStatusMessage];
    [_chatHistory addObject:msg];
    [self manageChatHistory];
    self.lastAlive = [NSDate date];
    for (SCHTMLTranscriptController *c in _containerBacking) {
        [c throwEvent:@"SCMessagePostedEvent" withObject:@[msg]];
    }
}

- (void)noteNameChanged:(NSString *)oldValue {
    if ([oldValue isEqualToString:((DESFriend *)self.underlyingConversation).name]
        || [oldValue isEqualToString:@""])
        return;

    SCAttributeMessage *msg = [[SCAttributeMessage alloc] initWithOldValue:oldValue
                                                               sender:(DESFriend *)self.underlyingConversation
                                                            attribute:SCAttributeName];
    [_chatHistory addObject:msg];
    [self manageChatHistory];
    self.lastAlive = [NSDate date];
    for (SCHTMLTranscriptController *c in _containerBacking) {
        [c throwEvent:@"SCMessagePostedEvent" withObject:@[msg]];
    }
}

- (NSOrderedSet *)completionOrder {
    if (self.underlyingConversation.type == DESConversationTypeFriend) {
        return [NSOrderedSet orderedSetWithObjects:((DESFriend *)self.underlyingConversation).name, nil];
    } else {
        return [NSOrderedSet orderedSet];
    }
}

#pragma mark - Hold containers

- (void)addContainer:(SCHTMLTranscriptController *)container {
    [_containerBacking addObject:container];
}

- (void)removeContainer:(SCHTMLTranscriptController *)container {
    [_containerBacking removeObject:container];
}

- (BOOL)containsContainer:(SCHTMLTranscriptController *)container {
    return [_containerBacking containsObject:container];
}

@end

@interface SCAppDelegate ()
- (NSString *)profileName;
- (NSString *)profilePass;
@end

@implementation SCConversationManager {
    NSMutableDictionary *_conversations;
    SCDiary *_diary;
}

- (id)init {
    self = [super init];
    if (self) {
        _conversations = [[NSMutableDictionary alloc] initWithCapacity:10];
        SCProfileManager *profile = [SCProfileManager currentProfile];
        NSURL *diaryPath = [profile.profileDirectory URLByAppendingPathComponent:@"diary"];
        SCAppDelegate *appDelegate = (SCAppDelegate *)[NSApp delegate];
        _diary = [[SCDiary alloc] initWithURL:diaryPath password:appDelegate.profilePass];
    }
    return self;
}

- (void)addConversation:(DESConversation *)conv {
    SCConversation *sc;
    if (!(sc = _conversations[conv.conversationIdentifier]))
        sc = [[SCConversation alloc] initWithConv:conv];
    conv.delegate = sc;
    _conversations[conv.conversationIdentifier] = sc;
}

- (void)deleteConversation:(DESConversation *)conv {
    [_conversations removeObjectForKey:conv.conversationIdentifier];
}

- (SCConversation *)conversationFor:(DESConversation *)llconv {
    if (!_conversations[llconv.conversationIdentifier])
        [self addConversation:llconv];
    return _conversations[llconv.conversationIdentifier];
}

@end
