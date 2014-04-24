#include "Copyright.h"

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, SCFriendFindMethod) {
    SCFriendFindMethodDNSDiscovery = 0,
    SCFriendFindMethodPlain = 1,
    // SCFriendFindMethodBonjour,
};

@interface SCAddFriendSheetController : NSWindowController <NSTextFieldDelegate>
- (void)resetFields:(BOOL)clearMessage;

- (NSString *)toxID;
- (NSString *)message;
- (void)setToxID:(NSString *)theID;
- (void)setMessage:(NSString *)theMessage;

- (NSString *)proposedName;

- (void)setMethod:(SCFriendFindMethod)method;
- (void)fillWithURL:(NSURL *)toxURL;

@end
