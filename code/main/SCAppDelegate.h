#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "ObjectiveTox.h"
#import "SCMainWindowing.h"
#include "tox.h"

@class SCStandaloneWindowController, SCFriendRequest, SCConversationManager;
@interface SCAppDelegate : NSObject <NSApplicationDelegate, DESToxConnectionDelegate>
@property (strong, nonatomic) NSWindowController *mainWindowController;
@property (strong) SCConversationManager *conversationManager;

- (void)makeApplicationReadyForToxing:(txd_intermediate_t)userProfile
                                 name:(NSString *)profileName
                             password:(NSString *)pass;
- (IBAction)copyPublicID:(id)sender;
- (IBAction)showQRCode:(id)sender;
- (IBAction)addFriend:(id)sender;
- (void)removeFriend:(DESFriend *)f;

/* by popular demand */
- (NSString *)profileName;
- (NSSet *)requests;

- (void)focusWindowForConversation:(DESConversation *)conv;
- (void)removeAuxWindowFromService:(SCStandaloneWindowController *)w;

- (void)destroyFriendRequest:(SCFriendRequest *)request;

- (void)deleteFriend:(DESFriend *)friend confirmingInWindow:(NSWindow *)window;
@end
