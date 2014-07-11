#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "ObjectiveTox.h"
#import "SCMainWindowing.h"
#include <sodium.h>

/* Avatar information packet sent to friends on connection */
#define DESControlMessageAvatarAnnounce (160)
/* Packet to request an avatar transfer. */
#define DESControlMessageAvatarRequest  (161)
/* Do we allow coloured messages to be sent? (reserved) */
#define DESControlMessageMessageColourEnabled   (162)
#define DESAvatarAnnounceSize (2 + 4 + crypto_hash_BYTES)

@class SCStandaloneWindowController, SCFriendRequest, SCConversationManager,
       SCMediaCall, SCAudioVideoRecorder;
@interface SCAppDelegate : NSObject <NSApplicationDelegate, DESToxConnectionDelegate>
@property (strong, nonatomic) NSWindowController *mainWindowController;
@property (strong) SCConversationManager *conversationManager;

@property (strong) SCMediaCall *avCall;
@property (strong) SCAudioVideoRecorder *avSource;

- (void)makeApplicationReadyForToxing:(txd_intermediate_t)userProfile
                                 name:(NSString *)profileName
                             password:(NSString *)pass;
- (IBAction)copyPublicID:(id)sender;
- (IBAction)showQRCode:(id)sender;
- (IBAction)addFriend:(id)sender;
- (void)removeFriend:(DESFriend *)f;
- (void)sendAvatarPacket:(DESFriend *)friend;

- (void)reopenMainWindow;

/* by popular demand */
- (NSString *)profileName;
- (NSSet *)requests;

- (void)focusWindowForConversation:(DESConversation *)conv;
- (void)removeAuxWindowFromService:(SCStandaloneWindowController *)w;

- (void)destroyFriendRequest:(SCFriendRequest *)request;

- (void)deleteFriend:(DESFriend *)friend confirmingInWindow:(NSWindow *)window;
@end
