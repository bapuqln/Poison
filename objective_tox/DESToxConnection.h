#import <Foundation/Foundation.h>
#import "DESConstants.h"
#import "DESProtocols.h"
#import "tox.h"
#import "data.h"

@class DESRequest, DESFriend, DESToxConnection;

@protocol DESToxConnectionDelegate <NSObject>
@optional
/* Fired when calling -start or -stop on DESToxConnection. */
- (void)connectionDidBecomeActive:(DESToxConnection *)connection;
- (void)connectionDidBecomeInactive:(DESToxConnection *)connection;

- (void)connectionDidBecomeEstablished:(DESToxConnection *)connection;
- (void)connectionDidDisconnect:(DESToxConnection *)connection;

- (void)didAddFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didRemoveFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didFailToAddFriendWithError:(NSError *)error onConnection:(DESToxConnection *)connection;
- (void)didReceiveFriendRequest:(DESRequest *)request onConnection:(DESToxConnection *)connection;
- (void)didReceiveGroupChatInvite:(DESRequest *)request fromFriend:(DESFriend *)friend onConnection:(DESToxConnection *)connection;
- (void)didJoinGroupChat:(DESConversation *)chat onConnection:(DESToxConnection *)connection;

- (void)friend:(DESFriend *)friend connectionStatusDidChange:(BOOL)newStatus onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend userStatusDidChange:(DESFriendStatus)newStatus onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend statusMessageDidChange:(NSString *)newStatusMessage onConnection:(DESToxConnection *)connection;
- (void)friend:(DESFriend *)friend nameDidChange:(NSString *)newName onConnection:(DESToxConnection *)connection;
@end

@interface DESToxConnection : NSObject <DESFriend>
@property (readonly, getter = isActive) BOOL active;
@property (readwrite, strong) NSString *name;
@property (readwrite, strong) NSString *statusMessage;
@property DESFriendStatus status;
/**
 * Actually, settable using -setPublicKey:privateKey:
 */
@property (readonly) NSString *privateKey;
@property (readonly) NSString *friendAddress;
@property (nonatomic, readonly) NSUInteger closeNodesCount;
@property (weak) id<DESToxConnectionDelegate> delegate;

/**
 * Set of friends. All objects conform to <DESFriend>.
 */
@property (readonly) NSSet *friends;
/**
 * Set of groups. All objects conform to <DESConversation>.
 */
@property (readonly) NSSet *groups;
/**
 * An object conforming to DESFriend representing the current user.
 * Attempts to send messages will fail.
 */
@property (readonly) DESFriend *me;
/**
 * Starts the connection run loop.
 */
- (void)start;
/**
 * Notifies the connection that it should stop after the current run loop
 * iteration. -connectionDidDisconnect: will be called on the connection's
 * delegate.
 */
- (void)stop;

- (void)setPublicKey:(NSString *)publicKey privateKey:(NSString *)privateKey;

- (void)addFriendPublicKey:(NSString *)key message:(NSString *)message;
- (void)addFriendPublicKeyWithoutRequest:(NSString *)key;
- (void)deleteFriend:(DESFriend *)friend;
- (DESConversation *)groupChatWithID:(int32_t)num;
- (DESFriend *)friendWithID:(int32_t)num;
- (DESFriend *)friendWithKey:(NSString *)pk;
- (void)leaveGroup:(DESConversation *)group;

- (txd_intermediate_t)createTXDIntermediate;
- (void)restoreDataFromTXDIntermediate:(txd_intermediate_t)txd;
@end
