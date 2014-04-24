#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "ObjectiveTox.h"

@interface SCGroupMarker : NSObject
@property (strong) NSString *name;
@property (strong) NSString *other;
@end

@interface SCObjectMarker : NSObject
@property (strong) NSString *pk;
@property DESConversationType type;
@property int32_t sortKey;
@end

@interface SCRequestMarker : NSObject
@property (strong, readonly) NSString *sender;
@property (strong, readonly) NSString *invitationMessage;
@property (readonly) DESConversationType supposedType;
@property (strong, readonly) NSDate *whence;
@property (strong, readonly) DESRequest *underlyingRequest;
@end

@interface SCBuddyListManager : NSObject <NSTableViewDataSource>
@property (nonatomic, readonly) NSArray *orderingList;
@property (nonatomic, copy) NSString *filterString;
- (instancetype)initWithConnection:(DESToxConnection *)con;
- (id)objectAtRowIndex:(NSInteger)r;
@end
