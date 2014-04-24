#import "Copyright.h"

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCNotificationType) {
    SCNotificationTypeFriendMessage,
    SCNotificationTypeGroupMessage,
    SCNotificationTypeFriendConnected,
    SCNotificationTypeFriendDisconnected,

    SCNotificationTypeRequestReceived,
    SCNotificationTypeTransferDone,
    SCNotificationTypeTransferProposed,
};

@interface SCNotificationManager : NSObject
+ (BOOL)systemSupportsNotifications;
- (void)playSoundForEvent:(SCNotificationType)event;
- (void)postNotification:(NSUserNotification *)note
            forEventType:(SCNotificationType)event;

@end
