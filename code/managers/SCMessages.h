#include "Copyright.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "ObjectiveTox.h"

typedef NS_ENUM(NSInteger, SCMessageType) {
    SCChatMessageType = 1,
    SCInformationalMessageType = 2,
    SCAttributeMessageType = 3,
};

typedef NS_ENUM(NSInteger, SCAttributeChange) {
    SCAttributeName = 1,
    SCAttributeStatusMessage = 2,
};

@protocol SCMessage <NSObject>
@property (strong) NSString *senderUID;
@property (strong) NSString *senderName;
@property (strong) NSString *stringValue;
@property (strong) NSDate *datePosted;
@property (strong, readonly) NSString *localizedTimestamp;
@property (readonly) SCMessageType type;
@property BOOL isSelf;
@end

@interface SCPendingMessage : NSObject
@property uint32_t messageID;
@property (strong) NSString *messageString;
@property (strong) NSDate *date;

- (instancetype)initWithString:(NSString *)messageString id:(uint32_t)mid;
@end

@interface SCChatMessage : NSObject <SCMessage>
@property uint32_t messageID;
@property BOOL isAction;
@property BOOL successfullyDelivered;

- (instancetype)initWithString:(NSString *)s type:(DESMessageType)type sender:(DESFriend *)sender;
- (instancetype)initWithString:(NSString *)s type:(DESMessageType)type sender:(DESFriend *)sender id:(uint32_t)id_;
@end

@interface SCAttributeMessage : NSObject <SCMessage>
- (instancetype)initWithOldValue:(NSString *)s sender:(DESFriend *)sender attribute:(SCAttributeChange)attr;
- (SCAttributeChange)attribute;
- (NSString *)valueAfter;
@end
