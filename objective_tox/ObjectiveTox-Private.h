#import "ObjectiveTox.h"
#import "DESMacros.h"

#pragma mark - DESToxConnection internal API

@interface DESToxConnection ()
- (Tox *)_core;
- (dispatch_queue_t)_messengerQueue;
- (void)addGroup:(id<DESConversation>)conversation;
@end

#pragma mark - Base64

NSString *DESCreateBase64String(NSData *bytes);
NSData *DESDecodeBase64String(NSString *enc);

#pragma mark - Callbacks

void _DESCallbackFriendRequest(Tox *tox, const uint8_t *from, const uint8_t *payload,
                               uint16_t payloadLength, void *dtcInstance);
void _DESCallbackFriendNameDidChange(Tox *tox, int32_t from, uint8_t *payload,
                                     uint16_t payloadLength, void *dtcInstance);
void _DESCallbackFriendStatusMessageDidChange(Tox *tox, int32_t from,
                                              uint8_t *payload,
                                              uint16_t payloadLength,
                                              void *dtcInstance);
void _DESCallbackFriendUserStatus(Tox *tox, int32_t from, uint8_t on_off,
                                  void *dtcInstance);
void _DESCallbackFriendTypingStatus(Tox *tox, int32_t from, uint8_t on_off,
                                    void *dtcInstance);
void _DESCallbackFriendConnectionStatus(Tox *tox, int32_t from, uint8_t on_off,
                                        void *dtcInstance);
void _DESCallbackFriendMessage(Tox *tox, int32_t from, uint8_t *payload,
                               uint16_t payloadLength, void *dtcInstance);
void _DESCallbackFriendAction(Tox *tox, int32_t from, uint8_t *payload,
                              uint16_t payloadLength, void *dtcInstance);
void _DESCallbackFMGeneric(DESToxConnection *conn, int32_t from,
                           uint8_t *payload, uint16_t payloadLength,
                           DESMessageType mtyp);
void _DESCallbackReadReceipt(Tox *tox, int32_t from, uint32_t messageid,
                             void *dtcInstance);
int _DESCallbackControlMessage(void *desfriend, uint8_t *payload, uint32_t length);

#pragma mark - DESRequest concrete subclasses

@interface DESFriendRequest : DESRequest
@property uint8_t *senderPublicKey;

- (instancetype)initWithSenderKey:(const uint8_t *)sender
                          message:(const uint8_t *)message
                           length:(uint32_t)length
                       connection:(DESToxConnection *)connection;

@end

@interface DESGroupRequest : DESRequest
@property int32_t senderNo;
@property uint8_t *groupKey;

- (instancetype)initWithSenderNo:(int32_t)sender
                            name:(NSString *)name
                        groupKey:(const uint8_t *)key
                      connection:(DESToxConnection *)connection;

@end

#pragma mark - DESFriend concrete subclasses

NS_INLINE DESFriendStatus DESToxToFriendStatus(TOX_USERSTATUS status) {
    switch (status) {
        case TOX_USERSTATUS_NONE:
            return DESFriendStatusAvailable;
        case TOX_USERSTATUS_AWAY:
            return DESFriendStatusAway;
        case TOX_USERSTATUS_BUSY:
            return DESFriendStatusBusy;
        case TOX_USERSTATUS_INVALID:
            return DESFriendStatusOffline;
    }
}

NS_INLINE TOX_USERSTATUS DESFriendStatusToTox(DESFriendStatus status) {
    switch (status) {
        case DESFriendStatusAvailable:
            return TOX_USERSTATUS_NONE;
        case DESFriendStatusAway:
            return TOX_USERSTATUS_AWAY;
        case DESFriendStatusBusy:
            return TOX_USERSTATUS_BUSY;
        case DESFriendStatusOffline:
            return TOX_USERSTATUS_INVALID;
    }
}

@interface DESConcreteFriend : DESFriend

- (instancetype)initWithNumber:(int32_t)friendNum
                  onConnection:(DESToxConnection *)connection;
- (void)updatePeernum:(int32_t)newpeernum;
- (void)updateAddress:(NSString *)newAddr port:(uint16_t)newPort;

@end

@interface DESGroupChat : DESConversation

- (instancetype)initWithNumber:(int32_t)groupNum
                  onConnection:(DESToxConnection *)connection;

@end

#pragma mark - Extensions to Core

void DESSetKeys(Tox *tox, uint8_t *pk, uint8_t *sk);
/* Counts the connected DHT nodes. Maximum 32 due to core limit */
int DESCountCloseNodes(Tox *tox);
/* Gets a friend's IP address and port into ip_out and port_out.
 * (you can enable the UI by
 *  $ defaults write ca.kirara.poison.next airiUIEnabled <key>
 *  in Poison.app.) */
int DESCopyNetAddress(Tox *tox, int32_t peernum, char **ip_out, uint16_t *port_out);
