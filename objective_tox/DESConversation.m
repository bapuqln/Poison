#import "ObjectiveTox-Private.h"

@implementation DESConversation

- (NSString *)presentableTitle { DESAbstractWarning; return nil; }
- (NSString *)presentableSubtitle { DESAbstractWarning; return nil; }
- (NSSet *)participants { DESAbstractWarning; return nil; }
- (NSString *)publicKey { DESAbstractWarning; return nil; }
- (int32_t)peerNumber { DESAbstractWarning; return 0; }
- (id<DESConversationDelegate>)delegate { DESAbstractWarning; return nil; }
- (void)setDelegate:(id<DESConversationDelegate>)delegate { DESAbstractWarning; }
- (DESConversationType)type { DESAbstractWarning; return 255; }

- (uint32_t)sendAction:(NSString *)action { DESAbstractWarning; return 0; }
- (uint32_t)sendMessage:(NSString *)message { DESAbstractWarning; return 0; }

@end

@implementation DESGroupChat {
    int32_t _groupNum;
    DESToxConnection *__weak _connection;
    NSMutableSet *_participants;
    NSString *publicKey;
}

- (instancetype)initWithNumber:(int32_t)groupNum onConnection:(DESToxConnection *)connection {
    self = [super init];
    if (self) {
        _groupNum = groupNum;
        _connection = connection;
    }
    return self;
}

- (NSString *)presentableTitle {
    return [NSString stringWithFormat:NSLocalizedString(@"Group chat #%d", @"DESGroupChat: Title template"), _groupNum];
}

- (NSString *)presentableSubtitle {
    uint32_t participantCount = (uint32_t)[self.participants count];
    NSString *template = @"%d";
    if (participantCount == 1)
        template = NSLocalizedString(@"with %d person", @"DESGroupChat: Title template (singular)");
    else
        template = NSLocalizedString(@"with %d people", @"DESGroupChat: Title template (plural)");
    return [NSString stringWithFormat:template, _groupNum];
}

- (NSString *)publicKey {
    return @"";
}

- (NSSet *)participants {
    return _participants;
}

- (int32_t)peerNumber {
    return _groupNum;
}

- (DESConversationType)type {
    return DESConversationTypeGroup;
}

/*- (void)addPeer:(int32_t)peernum {
    tox_callback_group_namelist_change(<#Tox *tox#>, <#void (*function)(Tox *, int, int, uint8_t, void *)#>, <#void *userdata#>)
}*/

@end