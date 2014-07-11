#include "Copyright.h"

#import "SCMessages.h"
#import "SCProfileManager.h"

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
        if (self.isSelf)
            self.senderUID = SCSelfSenderUID;
        else
            self.senderUID = sender.publicKey;
        /* DES: group senders will probably get their own "public keys".
         * which are UUIDs in disguise. */
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

@implementation SCAttributeMessage {
    SCAttributeChange _attribute;
    NSString *_attrStringValue;
}
@dynamic stringValue;
@synthesize senderUID = _senderUID;
@synthesize senderName = _senderName;
@synthesize isSelf = _isSelf;
@synthesize datePosted = _datePosted;

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
    return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return NO;
}

- (instancetype)initWithOldValue:(NSString *)s sender:(DESFriend *)sender attribute:(SCAttributeChange)attr {
    self = [super init];
    if (self) {
        _attribute = attr;
        self.isSelf = (sender.peerNumber == -1);
        if (attr == SCAttributeName) {
            self.senderName = s;
            _attrStringValue = sender.name;
        } else {
            self.senderName = sender.name;
            _attrStringValue = sender.statusMessage;
        }
        self.senderUID = sender.publicKey;
        self.datePosted = [NSDate date];
    }
    return self;
}

- (NSString *)stringValue {
    if (self.attribute == SCAttributeName) {
        return [NSString stringWithFormat:NSLocalizedString(@"%@ changed their name to %@.", nil),
                self.senderName, _attrStringValue];
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"%@ is now %@.", nil),
                self.senderName, _attrStringValue];
    }
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

- (SCAttributeChange)attribute {
    return _attribute;
}

- (NSString *)valueAfter {
    return _attrStringValue;
}

- (int64_t)unixTimestamp {
    return (int64_t)[_datePosted timeIntervalSince1970];
}

- (SCMessageType)type {
    return SCAttributeMessageType;
}

@end

