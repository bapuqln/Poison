#include "Copyright.h"

#import <Cocoa/Cocoa.h>

@class SCFriendRequest;
@interface SCRequestDialogController : NSWindowController
@property (strong, nonatomic) SCFriendRequest *request;
@end
