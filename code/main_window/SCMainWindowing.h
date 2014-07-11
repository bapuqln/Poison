#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "SCQRCodeSheetController.h"
#import "SCAddFriendSheetController.h"
#import "SCBuddyListController.h"

@class DESToxConnection;
@protocol SCMainWindowing <NSObject>
- (instancetype)initWithDESConnection:(DESToxConnection *)tox;
- (void)displayQRCode;
- (void)displayAddFriend;
- (void)displayAddFriendWithToxSchemeURL:(NSURL *)url;

- (SCBuddyListController *)buddyListController;
- (void)updateKeyViewAndRepostTypingEvent:(NSEvent *)event;

@optional
- (void)conversationDidBecomeFocused:(DESConversation *)conversation;
@end
