#import "ObjectiveTox-Private.h"

/*
static inline DESEventType _DESExtendedGroupChatChangeTypeToDESEventType(TOX_CHAT_CHANGE changeType) {
    switch (changeType) {
        case TOX_CHAT_CHANGE_PEER_ADD:
            return DESEventTypeGroupUserJoined;
        case TOX_CHAT_CHANGE_PEER_DEL:
            return DESEventTypeGroupUserLeft;
        case TOX_CHAT_CHANGE_PEER_NAME:
            return DESEventTypeGroupUserNameChanged;
    }
}
 */

void _DESCallbackFriendRequest(Tox *tox, const uint8_t *from, const uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
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

void _DESCallbackFriendNameDidChange(Tox *tox, int32_t from, const uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    if (payloadLength == 0)
        return;
    NSString *name = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
    NSString *old = f.name;
    [f willChangeValueForKey:@"name"];
    [f willChangeValueForKey:@"presentableTitle"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"name"];
        [f didChangeValueForKey:@"presentableTitle"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:nameDidChangeTo:from:onConnection:)])
                [connection.delegate friend:f nameDidChangeTo:name from:old onConnection:connection];
        });
    });
}

void _DESCallbackFriendStatusMessageDidChange(Tox *tox, int32_t from, const uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESConcreteFriend *f = (DESConcreteFriend *)[connection friendWithID:from];
    while (payloadLength > 0 && payload[payloadLength - 1] == 0) {
        --payloadLength;
    }
    if (payloadLength == 0)
        return;
    NSString *smg = [[NSString alloc] initWithBytes:payload length:payloadLength encoding:NSUTF8StringEncoding];
    NSString *old = f.statusMessage;
    [f willChangeValueForKey:@"statusMessage"];
    [f willChangeValueForKey:@"presentableSubtitle"];
    dispatch_async(connection._messengerQueue, ^{
        if (!f)
            return;
        [f didChangeValueForKey:@"statusMessage"];
        [f didChangeValueForKey:@"presentableSubtitle"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([connection.delegate respondsToSelector:@selector(friend:statusMessageDidChangeTo:from:onConnection:)])
                [connection.delegate friend:f statusMessageDidChangeTo:smg from:old onConnection:connection];
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

void _DESCallbackFriendMessage(Tox *tox, int32_t from, const uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    _DESCallbackFMGeneric((__bridge DESToxConnection *)dtcInstance, from, (uint8_t *)payload, payloadLength, DESMessageTypeText);
}

void _DESCallbackFriendAction(Tox *tox, int32_t from, const uint8_t *payload, uint16_t payloadLength, void *dtcInstance) {
    _DESCallbackFMGeneric((__bridge DESToxConnection *)dtcInstance, from, (uint8_t *)payload, payloadLength, DESMessageTypeAction);
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

void _DESCallbackReadReceipt(Tox *tox, int32_t from, uint32_t messageid, void *dtcInstance) {
    DESConversation *f = (DESConversation *)[(__bridge DESToxConnection *)dtcInstance friendWithID:from];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([f.delegate respondsToSelector:@selector(conversation:didReceiveDeliveryNotificationForMessageID:)])
            [f.delegate conversation:f didReceiveDeliveryNotificationForMessageID:messageid];
    });
}

int _DESCallbackControlMessage(void *desfriend, const uint8_t *payload, uint32_t length) {
    DESFriend *f = (__bridge DESFriend *)desfriend;
    DESToxConnection *c = f.connection;
    NSData *payload_ = [NSData dataWithBytes:payload + 1 length:length - 1];
    if ([c.delegate respondsToSelector:@selector(didReceiveControlMessage:ofType:fromFriend:)]) {
        [c.delegate didReceiveControlMessage:payload_ ofType:payload[0] fromFriend:f];
    }
    return 0;
}

/* FILE TRANSFER */

void _DESCallbackFileRequest(Tox *m, int32_t friend, uint8_t file_num,
                             uint64_t size, const uint8_t *name, uint16_t namelen,
                             void *connection) {
    DESConversation<DESFileTransferring> *conv = [(__bridge DESToxConnection *)connection friendWithID:friend];
    NSData *boxedname = [[NSData alloc] initWithBytes:name length:namelen];
    DESFileTransfer *tr = [[DESIncomingFileTransfer alloc] initWithSenderNumber:file_num
                                                                 onConversation:conv
                                                                       filename:boxedname
                                                                           size:size];
    [(__bridge DESToxConnection *)connection addTransferTriggeringKVO:tr];
    dispatch_async(dispatch_get_main_queue(), ^{
        [conv.delegate conversation:conv didReceiveFileTransferRequest:tr];
    });
}

void _DESCallbackFileControl(Tox *m, int32_t friend, uint8_t is_send,
                             uint8_t file_num, uint8_t control_id,
                             const uint8_t *data, uint16_t length, void *connection) {
    DESToxConnection *c = (__bridge DESToxConnection *)connection;
    DESConversation *searchConv = [c friendWithID:friend];
    DESTransferDirection dir = is_send? DESTransferDirectionOut : DESTransferDirectionIn;
    DESFileTransfer *tr = nil;

    for (DESFileTransfer *transfer in c.unsafeTransfers) {
        if (transfer.associatedConversation == searchConv &&
            transfer.direction == dir &&
            transfer.sender == file_num) {
            tr = transfer;
            break;
        }
    }

    switch (control_id) {
        case TOX_FILECONTROL_FINISHED: {
            [(DESIncomingFileTransfer *)tr finish];
            break;
        }
        case TOX_FILECONTROL_ACCEPT: {

        }
            

        default:
            break;
    }
}

void _DESCallbackFileData(Tox *m, int32_t friend, uint8_t file_num,
                          const uint8_t *data, uint16_t length, void *connection) {
    DESToxConnection *c = (__bridge DESToxConnection *)connection;
    DESConversation *searchConv = [c friendWithID:friend];
    for (DESFileTransfer *transfer in c.unsafeTransfers) {
        if (transfer.associatedConversation == searchConv &&
            transfer.direction == DESTransferDirectionIn &&
            transfer.sender == file_num) {
            [(DESIncomingFileTransfer *)transfer didReceiveData:(uint8_t *)data ofLength:length];
            break;
        }
    }
}

/* GROUP CHATS */

/*
void _DESCallbackExtendedGroupChatNameListDidChange(Tox *tox, int group, int peernum, uint8_t changeType, void *dtcInstance) {
    DESToxConnection *connection = (__bridge DESToxConnection*)dtcInstance;
    DESGroupChat *applyGC = (DESGroupChat *)[connection groupChatWithID:group];
}*/