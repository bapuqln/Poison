#include "Copyright.h"

#import "SCMessages.h"

static NSDateFormatter *SCMessagesDateFormatter;

@implementation SCPendingMessage

- (instancetype)initWithString:(NSString *)messageString id:(uint32_t)mid {
    self.messageID = mid;
    self.messageString = messageString;
    self.date = [NSDate date];
    return self;
}

@end

@implementation SCChatMessage {
    DESMessageType _chatMessageType;
}
@synthesize senderUID = _senderUID;
@synthesize senderName = _senderName;
@synthesize stringValue = _stringValue;
@synthesize isSelf = _isSelf;
@synthesize datePosted = _datePosted;

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
    return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return NO;
}

- (instancetype)initWithString:(NSString *)s type:(DESMessageType)type sender:(DESFriend *)sender {
    return [self initWithString:s type:type sender:sender id:0];
}

- (instancetype)initWithString:(NSString *)s type:(DESMessageType)type sender:(DESFriend *)sender id:(uint32_t)id_ {
    self = [super init];
    if (self) {
        self.stringValue = s;
        self.isSelf = (sender.peerNumber == -1);
        /* DESToxConnection has peerNumber hardcoded to -1 */
        self.senderName = sender.name;
        self.senderUID = sender.publicKey;
        self.messageID = id_;
        self.datePosted = [NSDate date];
        _chatMessageType = type;
    }
    return self;
}

- (NSString *)localizedTimestamp {
    if (!SCMessagesDateFormatter) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            SCMessagesDateFormatter = [[NSDateFormatter alloc] init];
            SCMessagesDateFormatter.dateStyle = NSDateFormatterShortStyle;
            SCMessagesDateFormatter.timeStyle = NSDateFormatterMediumStyle;
        });
    }
    return [SCMessagesDateFormatter stringFromDate:self.datePosted];
}

- (int64_t)unixTimestamp {
    return (int64_t)[_datePosted timeIntervalSince1970];
}

- (DESMessageType)chatMessageType {
    return _chatMessageType;
}

- (SCMessageType)type {
    return SCChatMessageType;
}

@end

/*@implementation SCAttributeChangeMessage {
    NSDate *_date;
}
@synthesize senderUID = _senderUID;
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

@end*/

