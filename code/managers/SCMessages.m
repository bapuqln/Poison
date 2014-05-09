#include "Copyright.h"

#import "SCMessages.h"

static NSDateFormatter *SCMessagesDateFormatter;

@implementation SCChatMessage {
    NSDate *_date;
}
@synthesize senderName = _senderName;
@synthesize stringValue = _stringValue;
@synthesize isSelf = _isSelf;

- (NSString *)localizedTimestamp {
    if (!SCMessagesDateFormatter) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            SCMessagesDateFormatter = [[NSDateFormatter alloc] init];
            SCMessagesDateFormatter.dateStyle = NSDateFormatterShortStyle;
            SCMessagesDateFormatter.timeStyle = NSDateFormatterMediumStyle;
        });
    }
    return [SCMessagesDateFormatter stringFromDate:_date];
}

- (SCMessageType)type {
    return SCChatMessageType;
}

@end

@implementation SCAttributeChangeMessage {
    NSDate *_date;
}
@synthesize senderName = _senderName;
@synthesize stringValue = _stringValue;
@synthesize isSelf = _isSelf;

- (NSString *)localizedTimestamp {
    if (!SCMessagesDateFormatter) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            SCMessagesDateFormatter = [[NSDateFormatter alloc] init];
            SCMessagesDateFormatter.dateStyle = NSDateFormatterShortStyle;
            SCMessagesDateFormatter.timeStyle = NSDateFormatterMediumStyle;
        });
    }
    return [SCMessagesDateFormatter stringFromDate:_date];
}

- (SCMessageType)type {
    return SCAttributeChangeMessageType;
}

@end

