#import "ObjectiveTox-Private.h"

@implementation DESRequest
@dynamic connection, message, senderName;
- (void)accept { DESAbstractWarning; }
- (void)decline { DESAbstractWarning; }
@end

@implementation DESFriendRequest {
    NSString *_senderName;
    NSString *_message;
    DESToxConnection *__weak _connection;
}
@synthesize senderName = _senderName;
@synthesize message = _message;
@synthesize connection = _connection;
@synthesize senderPublicKey = _senderPublicKey;

- (instancetype)initWithSenderKey:(const uint8_t *)sender
                          message:(const uint8_t *)message
                           length:(uint32_t)length
                       connection:(DESToxConnection *)connection {
    self = [super init];
    if (self) {
        _senderName = DESConvertPublicKeyToString(sender);
        self.senderPublicKey = malloc(TOX_CLIENT_ID_SIZE);
        memcpy(self.senderPublicKey, sender, TOX_CLIENT_ID_SIZE);
        _message = [[NSString alloc] initWithBytes:message length:length encoding:NSUTF8StringEncoding];
        _connection = connection;
    }
    return self;
}

- (void)accept {
    [self.connection addFriendPublicKeyWithoutRequest:DESConvertPublicKeyToString(self.senderPublicKey)];
}

- (void)decline {
    return;
}

- (void)dealloc {
    free(self.senderPublicKey);
}

@end

@implementation DESGroupRequest {
    NSString *_senderName;
    NSString *_message;
    DESToxConnection *__weak _connection;
}
@synthesize senderName = _senderName;
@synthesize message = _message;
@synthesize connection = _connection;
@synthesize senderNo = _senderNo;
@synthesize groupKey = _groupKey;

- (instancetype)initWithSenderNo:(int32_t)sender
                            name:(NSString *)name
                        groupKey:(const uint8_t *)key
                      connection:(DESToxConnection *)connection {
    self = [super init];
    if (self) {
        _senderName = name;
        self.groupKey = malloc(TOX_CLIENT_ID_SIZE);
        memcpy(self.groupKey, key, TOX_CLIENT_ID_SIZE);
        _message = nil;
        _connection = connection;
    }
    return self;
}

- (void)accept {
    int32_t groupnum = tox_join_groupchat(self.connection._core,
                                          self.senderNo, self.groupKey);
    DESConversation *gc = [[DESGroupChat alloc] initWithNumber:groupnum onConnection:self.connection];
    [self.connection addGroup:gc];
}

- (void)decline {
    return;
}

@end

