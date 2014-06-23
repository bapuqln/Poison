#import "ObjectiveTox-Private.h"

const uint32_t DESMaximumMessageLength = TOX_MAX_MESSAGE_LENGTH;

@implementation DESFriend
- (NSString *)name { DESAbstractWarning; return nil; }
- (NSString *)statusMessage { DESAbstractWarning; return nil; }
- (DESFriendStatus)status { DESAbstractWarning; return 0; }
- (NSString *)publicKey { DESAbstractWarning; return nil; }
- (DESConversation *)conversation { DESAbstractWarning; return nil; }
- (DESToxConnection *)connection { DESAbstractWarning; return nil; }
- (int32_t)peerNumber { DESAbstractWarning; return -1; }
- (BOOL)isTyping { DESAbstractWarning; return -1; }
- (NSDate *)lastSeen { DESAbstractWarning; return nil; }
- (NSString *)address { DESAbstractWarning; return nil; }
- (uint16_t)port { DESAbstractWarning; return 0; }

- (NSString *)presentableTitle { DESAbstractWarning; return nil; }
- (NSString *)presentableSubtitle { DESAbstractWarning; return nil; }
- (NSSet *)participants { DESAbstractWarning; return nil; }
- (id<DESConversationDelegate>)delegate { DESAbstractWarning; return nil; }
- (void)setDelegate:(id<DESConversationDelegate>)delegate { DESAbstractWarning; }
- (DESConversationType)type { DESAbstractWarning; return 0; }

- (uint32_t)sendAction:(NSString *)action { DESAbstractWarning; return 0; }
- (uint32_t)sendMessage:(NSString *)message { DESAbstractWarning; return 0; }
@end

@implementation DESConcreteFriend {
    uint32_t _cMessageID;
    NSString *_addr;
    uint16_t _port;
    NSString *_pk;
}
@synthesize connection = _connection;
@synthesize peerNumber = _peerNumber;
@synthesize delegate = _delegate;

- (instancetype)initWithNumber:(int32_t)friendNum
                  onConnection:(DESToxConnection *)connection {
    self = [super init];
    if (self) {
        _connection = connection;
        _peerNumber = friendNum;
        _cMessageID = 1;
        _addr = @"";
        uint8_t *buf = malloc(DESPublicKeySize);
        tox_get_client_id(_connection._core, _peerNumber, buf);
        _pk =  DESConvertPublicKeyToString(buf);
        free(buf);
    }
    return self;
}

- (NSString *)name {
    uint16_t sz = tox_get_name_size(_connection._core, _peerNumber);
    uint8_t *buf = malloc(sz);
    tox_get_name(_connection._core, _peerNumber, buf);
    while (sz > 0 && buf[sz - 1] == 0) {
        --sz;
    }
    if (sz == 0) {
        free(buf);
        return @"";
    }
    return [[NSString alloc] initWithBytesNoCopy:buf length:sz
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:YES];
}

- (NSString *)statusMessage {
    uint16_t sz = tox_get_status_message_size(_connection._core, _peerNumber);
    uint8_t *buf = malloc(sz);
    tox_get_status_message(_connection._core, _peerNumber, buf, sz);
    while (sz > 0 && buf[sz - 1] == 0) {
        --sz;
    }
    if (sz == 0) {
        free(buf);
        return @"";
    }
    return [[NSString alloc] initWithBytesNoCopy:buf length:sz
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:YES];
}

- (DESFriendStatus)status {
    //DESInfo(@"%d", tox_get_friend_connection_status(_connection._core, _peerNumber));
    if (tox_get_friend_connection_status(_connection._core, _peerNumber)) {
        //DESInfo(@"friend is online, all right");
        return DESToxToFriendStatus(tox_get_user_status(_connection._core, _peerNumber));
    } else {
        return DESFriendStatusOffline;
    }
}

- (NSString *)publicKey {
    return _pk;
}

- (DESConversation *)conversation {
    return (DESConversation*)self;
}

- (BOOL)isTyping {
    return tox_get_is_typing(_connection._core, _peerNumber)? YES : NO;
}

- (NSDate *)lastSeen {
    uint64_t lastPing = tox_get_last_online(_connection._core, _peerNumber);
    return [NSDate dateWithTimeIntervalSince1970:lastPing];
}

- (NSString *)address {
    return _addr;
}

- (uint16_t)port {
    return _port;
}

#pragma mark - DESConversation

- (NSString *)presentableTitle {
    return self.name;
}

- (NSString *)presentableSubtitle {
    return self.statusMessage;
}

- (NSSet *)participants {
    return [[NSSet alloc] initWithObjects:self, nil];
}

- (DESConversationType)type {
    return DESConversationTypeFriend;
}

- (uint32_t)sendMessage:(NSString *)message {
    uint32_t mid;
    @synchronized(self) {
        mid = ++_cMessageID;
    }
    dispatch_async(_connection._messengerQueue, ^{
        NSUInteger mlen = [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        uint32_t ret = 0;
        if (mlen <= DESMaximumMessageLength) {
            ret = tox_send_message_withid(self->_connection._core, self->_peerNumber, mid, (uint8_t*)[message UTF8String], (uint32_t)mlen);
        }
        if (ret == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(conversation:didFailToSendMessageWithID:ofType:)])
                    [self.delegate conversation:(DESConversation*)self didFailToSendMessageWithID:mid ofType:DESMessageTypeText];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(conversation:didSendMessageWithID:ofType:)])
                    [self.delegate conversation:(DESConversation*)self didSendMessageWithID:mid ofType:DESMessageTypeText];
            });
        }
    });
    return mid;
}

- (uint32_t)sendAction:(NSString *)action {
    uint32_t mid;
    @synchronized(self) {
        mid = ++_cMessageID;
    }
    dispatch_async(_connection._messengerQueue, ^{
        NSUInteger mlen = [action lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        uint32_t ret = 0;
        if (mlen <= DESMaximumMessageLength) {
            ret = tox_send_action_withid(self->_connection._core, self->_peerNumber, mid, (uint8_t*)[action UTF8String], (uint32_t)mlen);
        }
        if (ret == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(conversation:didFailToSendMessageWithID:ofType:)])
                [self.delegate conversation:(DESConversation*)self didFailToSendMessageWithID:mid ofType:DESMessageTypeAction];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(conversation:didSendMessageWithID:ofType:)])
                [self.delegate conversation:(DESConversation*)self didSendMessageWithID:mid ofType:DESMessageTypeAction];
            });
        }
    });
    return mid;
}

#pragma mark - private

- (void)updatePeernum:(int32_t)newpeernum {
    [self willChangeValueForKey:@"peerNumber"];
    _peerNumber = newpeernum;
    [self didChangeValueForKey:@"peerNumber"];
}

- (void)updateAddress:(NSString *)newAddr port:(uint16_t)newPort {
    [self willChangeValueForKey:@"address"];
    _addr = newAddr;
    [self didChangeValueForKey:@"address"];
    [self willChangeValueForKey:@"port"];
    _port = newPort;
    [self didChangeValueForKey:@"port"];
}

- (void)dealloc {
    DESInfo(@"deallocated!");
}

@end
