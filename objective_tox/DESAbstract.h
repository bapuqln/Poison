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
@interface DESFriend : DESConversation <DESFriend, DESFileTransferring>
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

@interface DESFileTransfer : NSObject
@property (weak, readonly) DESConversation<DESFileTransferring> *associatedConversation;

/* Bytes/sec. calculated internally. */
@property (readonly) NSUInteger transferSpeed;

/* Progress (0..1) */
@property (readonly) double progress;

/* Up or down */
@property (readonly) DESTransferDirection direction;

/* Input or output stream. One of these will be nil depending on direction */
@property (strong, readonly) NSInputStream *inStream;
@property (strong, readonly) NSOutputStream *outStream;

@property (strong, readonly) NSData *proposedFilename;
@property (strong, readonly) NSString *proposedFilenameString;

/* Incoming only */
- (void)acceptFileTransferIntoStream:(NSOutputStream *)stream;
- (void)acceptFileTransferIntoFile:(NSString *)file append:(BOOL)append;

- (void)pause;
- (void)cancel;

@property (readonly) DESTransferState state;
@end

#endif
