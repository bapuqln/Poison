#ifndef DESProtocols_h
#define DESProtocols_h
#import "DESConstants.h"

@class DESToxConnection, DESConversation, DESFriend, DESFileTransfer, DESRequest;

@protocol DESToxConnectionDelegate <NSObject>
@optional
/* Fired when calling -start or -stop on DESToxConnection. */
- (void)connectionDidBecomeActive:(DESToxConnection *)connection;
- (void)connectionDidBecomeInactive:(DESToxConnection *)connection;

- (void)connectionDidBecomeEstablished:(DESToxConnection *)connection;
- (void)connectionDidDisconnect:(DESToxConnection *)connection;

- (void)connectionDidFinishRestoringData:(DESToxConnection *)connection;

- (void)didAddFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didRemoveFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didFailToAddFriendWithError:(NSError *)error onConnection:(DESToxConnection *)connection;
- (void)didReceiveFriendRequest:(DESRequest *)request onConnection:(DESToxConnection *)connection;
- (void)didReceiveGroupChatInvite:(DESRequest *)request fromFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didJoinGroupChat:(DESConversation *)chat onConnection:(DESToxConnection *)connection;

- (void)friend:(DESFriend *)friend connectionStatusDidChange:(BOOL)newStatus onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend userStatusDidChange:(DESFriendStatus)newStatus onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend statusMessageDidChangeTo:(NSString *)newStatusMessage from:(NSString *)oldStatusMessage onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend nameDidChangeTo:(NSString *)newName from:(NSString *)oldName onConnection:(DESToxConnection *)connection;

- (void)didReceiveControlMessage:(NSData *)payload ofType:(uint8_t)pkt fromFriend:(DESFriend *)friend;
@end

@protocol DESConversationDelegate <NSObject>
@optional
- (void)conversation:(DESConversation *)con
   didReceiveMessage:(NSString *)message
              ofType:(DESMessageType)type_
          fromSender:(DESFriend *)sender;

- (void)conversation:(DESConversation *)con
        didFailToSendMessageWithID:(uint32_t)messageID
              ofType:(DESMessageType)type_;

/* Called after -[DESConversation sendMessage:]. */

- (void)conversation:(DESConversation *)con
didSendMessageWithID:(uint32_t)messageID
              ofType:(DESMessageType)type_;

/* Called when a delivery notification is received. */

- (void)conversation:(DESConversation *)con
        didReceiveDeliveryNotificationForMessageID:(uint32_t)messageID;

- (void)conversation:(DESConversation *)con
        typingStatusDidChange:(BOOL)isTyping
      forParticipant:(DESFriend *)f;

/* FT */

- (void)conversation:(DESConversation *)con
        didReceiveFileTransferRequest:(DESFileTransfer *)transferIn;

- (void)conversation:(DESConversation *)con
        fileTransfer:(DESFileTransfer *)transfer didChangeState:(DESTransferState)newState;

@end

@protocol DESConversation <NSObject>
@property (readonly) NSString *presentableTitle;
@property (readonly) NSString *presentableSubtitle;
@property (readonly) NSSet *participants;
@property (readonly) NSString *publicKey;
@property (readonly) int32_t peerNumber;
@property (readonly) DESConversationType type;
@property (weak) id<DESConversationDelegate> delegate;
@property (readonly, weak) DESToxConnection *connection;

- (uint32_t)sendMessage:(NSString *)message;
- (uint32_t)sendAction:(NSString *)action;
@end

@protocol DESFriend <NSObject>
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *statusMessage;
@property (readonly) DESFriendStatus status;
/* Not Key-Value-Observable. */
@property (readonly) NSString *publicKey;
@property (readonly) DESConversation *conversation;
@property (readonly, weak) DESToxConnection *connection;
/* Not Key-Value-Observable. */
@property (readonly) int32_t peerNumber;
@property (readonly) BOOL isTyping;
/* Not Key-Value-Observable. */
@property (readonly) NSDate *lastSeen;

/* fragile? */
@property (readonly) NSString *address;
@property (readonly) uint16_t port;

/* Send a custom packet. */
- (void)sendControlMessage:(NSData *)msg ofType:(uint8_t)packet;
@end

@protocol DESFileTransferring <NSObject>
@property (strong, readonly) NSSet *transfers;
- (DESFileTransfer *)requestFileTransferWithInput:(NSInputStream *)stream filename:(NSData *)filename size:(uint64_t)length;
@end

#endif
