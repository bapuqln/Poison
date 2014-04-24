#import "Copyright.h"

#import "SCFriendRequest.h"
#import "SCAppDelegate.h"

@interface SCAppDelegate (SCFriendRequest_Private)
- (DESToxConnection *)toxConnection;
@end

@interface SCFriendRequest ()
@property (readwrite, copy) NSString *senderName;
@property (readwrite, copy) NSString *message;
@property (readwrite) NSDate *dateReceived;
@end

@implementation SCFriendRequest
@synthesize senderName = _senderName;
@synthesize message = _message;

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithDESRequest:(DESRequest *)req {
    self = [super init];
    if (self) {
        if (req.senderName.length != DESPublicKeySize * 2) {
            NSLog(@"warning: tried to initialize SCFriendRequest with a not-friend request");
            return nil;
        }
        self.senderName = req.senderName;
        self.message = req.message;
        self.dateReceived = [NSDate date];
    }
    return self;
}

/* Because lion doesn't have decodeObjectOfClass: */
- (id)proxyDecodeObjectOfClass:(Class)class forKey:(NSString *)k usingDecoder:(NSCoder *)c {
    if (SCIsMountainLionOrHigher())
        return [c decodeObjectOfClass:class forKey:k];

    id objectOrNil = [c decodeObjectForKey:k];
    if (![objectOrNil isKindOfClass:class]) {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                reason:@"Object decoded was not of specified class"
                              userInfo:@{@"decodedObject": (objectOrNil ?: [NSNull null])}] raise];
    }
    return objectOrNil;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        @try {
            self.senderName = [self proxyDecodeObjectOfClass:[NSString class]
                                                      forKey:@"senderName"
                                                usingDecoder:aDecoder];
            self.message = [self proxyDecodeObjectOfClass:[NSString class]
                                                   forKey:@"message"
                                             usingDecoder:aDecoder];
            self.dateReceived = [self proxyDecodeObjectOfClass:[NSDate class]
                                                        forKey:@"dateReceived"
                                                  usingDecoder:aDecoder];
        }
        @catch (NSException *exception) {
            NSLog(@"warning: tried to decode an invalid SCFriendRequest");
            return nil;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.senderName forKey:@"senderName"];
    [aCoder encodeObject:self.message forKey:@"message"];
    [aCoder encodeObject:self.dateReceived forKey:@"dateReceived"];
}

- (void)accept {
    SCAppDelegate *d = [NSApp delegate];
    [d.toxConnection addFriendPublicKeyWithoutRequest:self.senderName];
}

- (void)decline {
    return;
}

@end
