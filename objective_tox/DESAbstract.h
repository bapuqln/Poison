#ifndef DESAbstract_h
#define DESAbstract_h
#import "DESProtocols.h"

/**
 * DESConversation is the abstract class that implements the
 * DESConversation protocol.
 */
@interface DESConversation : NSObject <DESConversation>
@end

/**
 * DESFriend is an abstract class that implements the
 * DESFriend and DESConversation protocols.
 */
@interface DESFriend : DESConversation <DESFriend>
@end

/**
 * DESRequest is an abstract class that represents friend requests
 * and group invitations.
 * All requests can be accepted using -accept, and all requests can
 * be declined using -decline.
 */
@interface DESRequest : NSObject
/**
 * The name of the sender of this request. For friends,
 * it is a public key. For groups, it is a name.
 */
@property (readonly) NSString *senderName;
/**
 * The message sent with this request. For group invites,
 * it will be nil. 
 */
@property (readonly) NSString *message;
/**
 * Connection that the request originated from.
 */
@property (weak, readonly) DESToxConnection *connection;
/**
 * Accept this request and join the group chat/add the friend.
 */
- (void)accept;
/**
 * Declines this request. Currently, it just gets ignored.
 */
- (void)decline;
@end

#endif
