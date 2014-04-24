#import "Copyright.h"

#import "DESAbstract.h"

@interface SCFriendRequest : DESRequest <NSSecureCoding>
- (instancetype)initWithDESRequest:(DESRequest *)req;
@end
