#include "Copyright.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "ObjectiveTox.h"

typedef NS_ENUM(NSInteger, SCMessageType) {
    SCChatMessageType = 1,
    SCAttributeChangeMessageType,
};

@protocol SCMessage <NSObject>

@property (strong) NSString *senderName;
@property (strong) NSString *stringValue;
@property (strong, readonly) NSString *localizedTimestamp;
@property (readonly) SCMessageType type;
@property BOOL isSelf;

@end

@interface SCChatMessage : NSObject <SCMessage>

@property uint32_t messageNumber;

@end

@interface SCAttributeChangeMessage : NSObject <SCMessage>

@property (strong) NSNumber *wrappedColour;

@end
