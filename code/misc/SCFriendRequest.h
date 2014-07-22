#import "Copyright.h"

#import "DESAbstract.h"

@interface SCFriendRequest : DESRequest <NSSecureCoding>
@property (strong, readonly) NSDate *dateReceived;
- (instancetype)initWithDESRequest:(DESRequest *)req;
@end
