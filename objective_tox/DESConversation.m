#import "ObjectiveTox-Private.h"

@implementation DESConversation
@dynamic presentableTitle, presentableSubtitle, participants, delegate, type,
         connection, peerNumber, publicKey;

- (uint32_t)sendAction:(NSString *)action { DESAbstractWarning; return 0; }
- (uint32_t)sendMessage:(NSString *)message { DESAbstractWarning; return 0; }

@end

@implementation DESGroupChat {
    int32_t _groupNum;
    NSMutableSet *_participants;
    NSString *publicKey;
}
@synthesize connection = _connection;
@synthesize peerNumber = _groupNum;
@synthesize participants = _participants;

- (instancetype)initWithNumber:(int32_t)groupNum onConnection:(DESToxConnection *)connection {
    self = [super init];
    if (self) {
        _groupNum = groupNum;
        _connection = connection;
    }
    return self;
}

- (NSString *)presentableTitle {
    return [NSString stringWithFormat:NSLocalizedString(@"Group chat #%d", @"DESGroupChat: Title template"), self.peerNumber];
}

- (NSString *)presentableSubtitle {
    uint32_t participantCount = (uint32_t)[self.participants count];
    if (participantCount == 1) {
        return [NSString stringWithFormat:NSLocalizedString(@"with %d person", @"DESGroupChat: Title template (singular)"), self.peerNumber];
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"with %d people", @"DESGroupChat: Title template (plural)"), self.peerNumber];
    }
}

- (NSString *)publicKey {
    return @"";
}

- (DESConversationType)type {
    return DESConversationTypeGroup;
}

/*- (void)addPeer:(int32_t)peernum {
    tox_callback_group_namelist_change(<#Tox *tox#>, <#void (*function)(Tox *, int, int, uint8_t, void *)#>, <#void *userdata#>)
}*/

@end