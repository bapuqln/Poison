#import "Copyright.h"

#import "SCNotificationManager.h"

@implementation SCNotificationManager

+ (BOOL)systemSupportsNotifications {
    return (NSFoundationVersionNumber > NSFoundationVersionNumber10_7_4)? YES : NO;
}

- (void)playSoundForEvent:(SCNotificationType)event {
    return;
}

- (void)postNotification:(NSUserNotification *)note forEventType:(SCNotificationType)event {
    NSUserNotificationCenter *centre = [NSUserNotificationCenter defaultUserNotificationCenter];
    note.deliveryDate = [NSDate date];
    [centre deliverNotification:note];
}


@end
