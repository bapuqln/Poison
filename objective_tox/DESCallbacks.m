#import "ObjectiveTox-Private.h"

static inline DESEventType _DESExtendedGroupChatChangeTypeToDESEventType(uint8_t changeType) {
    switch (changeType) {
        case TOX_CHAT_CHANGE_PEER_ADD:
            return DESEventTypeGroupUserJoined;
        case TOX_CHAT_CHANGE_PEER_DEL:
            return DESEventTypeGroupUserLeft;
        case TOX_CHAT_CHANGE_PEER_NAME:
            return DESEventTypeGroupUserNameChanged;
        default:
            return 0;
    }
}

void _DESCallbackFriendRequest(Tox *tox, uint8_t *from, uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESFriendRequest *req = [[DESFriendRequest alloc] initWithSenderKey:from message:payload length:payloadLength connection:connection];
    DESInfo(@"Friend request. -->");
    DESInfo(@"%@", [req senderName]);
    DESInfo(@"%@", [req message]);
    DESInfo(@"<----------------->");
    //[req accept];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([connection.delegate respondsToSelector:@selector(didReceiveFriendRequest:onConnection:)]) {
            [connection.delegate didReceiveFriendRequest:req onConnection:connection];
        }
    });
}

/* ATTRIBUTES */

void _DESCallbackFriendNameDidChange(Tox *tox, int32_t from, uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    if (payloadLength == 0)
        return;
    NSString *name = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
    [f willChangeValueForKey:@"name"];
    [f willChangeValueForKey:@"presentableTitle"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"name"];
        [f didChangeValueForKey:@"presentableTitle"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:nameDidChange:onConnection:)])
                [connection.delegate friend:f nameDidChange:name onConnection:connection];
        });
    });
}

void _DESCallbackFriendStatusMessageDidChange(Tox *tox, int32_t from, uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    if (payloadLength == 0)
        return;
    NSString *smg = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
    [f willChangeValueForKey:@"statusMessage"];
    [f willChangeValueForKey:@"presentableSubtitle"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"statusMessage"];
        [f didChangeValueForKey:@"presentableSubtitle"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:statusMessageDidChange:onConnection:)])
                [connection.delegate friend:f statusMessageDidChange:smg onConnection:connection];
        });
    });
}

void _DESCallbackFriendUserStatus(Tox *tox, int32_t from, uint8_t status, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    if (!tox_get_friend_connection_status(tox, from))
        return;
    /* status doesn't get set in core context until the callback returns
     * so we have to do this hacky thing */
    [f willChangeValueForKey:@"status"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"status"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:userStatusDidChange:onConnection:)])
                [connection.delegate friend:f userStatusDidChange:DESToxToFriendStatus(status) onConnection:connection];
        });
    });
}

void _DESCallbackFriendTypingStatus(Tox *tox, int32_t from, uint8_t on_off, void *dtcInstance) {
    DESInfo(@"(%d) typing: %d", from, on_off);
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    if (!tox_get_friend_connection_status(tox, from))
        return;
    /* status doesn't get set in core context until the callback returns
     * so we have to do this hacky thing */
    [f willChangeValueForKey:@"isTyping"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"isTyping"];
    });
}

void _DESCallbackFriendConnectionStatus(Tox *tox, int32_t from, uint8_t on_off, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    /* status doesn't get set in core context until the callback returns
     * so we have to do this hacky thing */
    [f willChangeValueForKey:@"status"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        if (on_off) {
            char *a = NULL;
            uint16_t port = 0;
            int ret = DESCopyNetAddress(tox, from, &a, &port);
            if (!ret)
                return;
            [f updateAddress:[[NSString alloc] initWithCString:a encoding:NSUTF8StringEncoding] port:port];
            DESInfo(@"(%d) Address did change to %s, %hu", from, a, port);
            free(a);
        } else {
            [f updateAddress:@"" port:0];
        }
        [f didChangeValueForKey:@"status"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:connectionStatusDidChange:onConnection:)])
                [connection.delegate friend:f connectionStatusDidChange:on_off? YES : NO onConnection:connection];
        });
    });
}

/* MESSAGES */

void _DESCallbackFriendMessage(Tox *tox, int32_t from, uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    _DESCallbackFMGeneric((__bridge DESToxConnection *)dtcInstance, from, payload, payloadLength, DESMessageTypeAction);
}

void _DESCallbackFriendAction(Tox *tox, int32_t from, uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    _DESCallbackFMGeneric((__bridge DESToxConnection *)dtcInstance, from, payload, payloadLength, DESMessageTypeAction);
}

void _DESCallbackFMGeneric(DESToxConnection *conn, int32_t from, uint8_t *payload, uint16_t payloadLength, DESMessageType mtyp) {
    /* normalize away non-conforming clients who still NUL strings */
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    if (payloadLength == 0)
        return;
    DESConcreteFriend *f = (DESConcreteFriend *)[conn friendWithID:from];
    NSString *messageBody = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
    DESInfo(@"<%@> %@", f.name, messageBody);
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([f.delegate respondsToSelector:@selector(conversation:didReceiveMessage:ofType:fromSender:)])
            [f.delegate conversation:(DESConversation *)f didReceiveMessage:messageBody ofType:mtyp fromSender:f];
    });
}

/* GROUP CHATS */

void _DESCallbackExtendedGroupChatNameListDidChange(Tox *tox, int group, int peernum, uint8_t changeType, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESGroupChat *applyGC = (DESGroupChat *)[connection groupChatWithID:group];
}