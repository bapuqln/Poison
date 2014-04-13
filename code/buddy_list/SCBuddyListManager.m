#include "Copyright.h"

#import "SCBuddyListManager.h"
#import "SCBuddyListShared.h"
#import "ObjectiveTox.h"
#import "DESConversation+Poison_CustomName.h"

@implementation SCGroupMarker
- (instancetype)initWithName:(NSString *)name other:(NSString *)other {
    self = [super init];
    if (self) {
        _name = name;
        _other = other;
    }
    return self;
}
@end

@implementation SCObjectMarker
- (instancetype)initWithConversation:(DESConversation *)c {
    self = [super init];
    if (self) {
        self.pk = c.publicKey;
        self.sortKey = c.peerNumber;
        self.type = c.type;
    }
    return self;
}
- (NSUInteger)hash {
    return [self.pk hash] ^ (self.type == DESConversationTypeFriend) ?
    0xAFFABFFBCFFCDFFDULL : 0xDFFDCFFCBFFBAFFAULL;
}
- (BOOL)isEqual:(id)object {
    return [self hash] == [object hash];
}
@end

@implementation SCRequestMarker {
    NSDate *_sendTime;
}
- (instancetype)initWithRequest:(DESRequest *)c sendTime:(NSDate *)d {
    self = [super init];
    if (self) {
        _underlyingRequest = c;
        _sendTime = d;
    }
    return self;
}

- (NSString *)sender {
    return _underlyingRequest.senderName;
}

- (DESConversationType)supposedType {
    return DESConversationTypeFriend; /* FIXME: identify which one it is */
}

- (NSString *)invitationMessage {
    return _underlyingRequest.message;
}

- (NSDate *)whence {
    return _sendTime;
}

@end

@implementation SCBuddyListManager {
    DESToxConnection *_watchingConnection;
    NSMutableArray *_orderingList;
}

- (instancetype)initWithConnection:(DESToxConnection *)con {
    self = [super init];
    if (self) {
        [self attachKVOHandlersToConnection:con];
    }
    return self;
}

- (id)conversationAtRowIndex:(NSInteger)r {
    id marker = _orderingList[r];
    if ([marker isKindOfClass:[SCObjectMarker class]]) {
        SCObjectMarker *m2 = marker;
        if (m2.type == DESConversationTypeFriend)
            return [_watchingConnection friendWithKey:m2.pk];
        else
            return [_watchingConnection groupChatWithID:m2.sortKey];
    }
    return nil;
}

#pragma mark - kvo

- (NSArray *)orderingList {
    return _orderingList;
}

- (void)detachHandlersFromConnection {
    [_watchingConnection removeObserver:self forKeyPath:@"friends"];
    [_watchingConnection removeObserver:self forKeyPath:@"groups"];
}

- (void)attachKVOHandlersToConnection:(DESToxConnection *)tox {
    [self detachHandlersFromConnection];
    _watchingConnection = tox;
    [tox addObserver:self forKeyPath:@"friends" options:NSKeyValueObservingOptionNew context:NULL];
    [tox addObserver:self forKeyPath:@"groups" options:NSKeyValueObservingOptionNew context:NULL];
    if (tox.isActive) {
        [self repopulateOrderingList];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"friends"] || [keyPath isEqualToString:@"groups"]) {
        [self repopulateOrderingList];
    }
}

- (void)repopulateOrderingList {
    NSSet *fset = _watchingConnection.friends;
    NSSet *gset = _watchingConnection.groups;

    if (_filterString) {
        NSPredicate *f = nil;
        if ([_filterString isEqualToString:[_filterString lowercaseString]])
            f = [NSPredicate predicateWithBlock:self.caseInsensitiveFilterBlock];
        else
            f = [NSPredicate predicateWithBlock:self.caseSensitiveFilterBlock];

        fset = [fset filteredSetUsingPredicate:f];
        gset = [gset filteredSetUsingPredicate:f];
    }

    [self willChangeValueForKey:@"orderingList"];
    _orderingList = [[NSMutableArray alloc] initWithCapacity:fset.count + gset.count + 2];
    NSMutableArray *scratch = [[NSMutableArray alloc] initWithCapacity:MAX(fset.count, gset.count)];

    if ([fset count]) {
        [_orderingList addObject:[[SCGroupMarker alloc] initWithName:NSLocalizedString(@"Friends", nil)
                                                               other:[NSString stringWithFormat:@"(%lu)", fset.count]]];

        for (DESConversation *f in fset) {
            [scratch addObject:[[SCObjectMarker alloc] initWithConversation:f]];
        }
        [scratch sortUsingComparator:^NSComparisonResult(SCObjectMarker *obj1, SCObjectMarker *obj2) {
            if (obj1.sortKey > obj2.sortKey)
                return NSOrderedDescending;
            else if (obj1.sortKey < obj2.sortKey)
                return NSOrderedAscending;
            return NSOrderedSame;
        }];
        [_orderingList addObjectsFromArray:scratch];
        [scratch removeAllObjects];
    }

    if ([gset count]) {
        [_orderingList addObject:[[SCGroupMarker alloc] initWithName:NSLocalizedString(@"Group Chats", nil)
                                                               other:[NSString stringWithFormat:@"(%lu)", gset.count]]];
        for (DESConversation *g in gset) {
            [scratch addObject:[[SCObjectMarker alloc] initWithConversation:g]];
        }
        [scratch sortUsingComparator:^NSComparisonResult(SCObjectMarker *obj1, SCObjectMarker *obj2) {
            if (obj1.sortKey > obj2.sortKey)
                return NSOrderedDescending;
            else if (obj1.sortKey < obj2.sortKey)
                return NSOrderedAscending;
            return NSOrderedSame;
        }];
        [_orderingList addObjectsFromArray:scratch];
    }
    [self didChangeValueForKey:@"orderingList"];
}

#pragma mark - table source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _orderingList.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    id peer = _orderingList[row];
    if ([peer isKindOfClass:[SCObjectMarker class]])
        return [_watchingConnection friendWithKey:((SCObjectMarker *)peer).pk];
    else
        return ((SCGroupMarker *)peer);
}

#pragma mark - search

- (BOOL(^)(id a, id b))caseSensitiveFilterBlock {
    return ^BOOL(DESConversation *evaluatedObject, NSDictionary *bindings) {
        /* TODO: make smarter, perhaps search chat content */
        if ([evaluatedObject.preferredUIName rangeOfString:_filterString].location != NSNotFound)
            return YES;
        else
            return NO;
    };
}

- (BOOL(^)(id a, id b))caseInsensitiveFilterBlock {
    NSString *cachedLower = [_filterString lowercaseString];
    return ^BOOL(DESConversation *evaluatedObject, NSDictionary *bindings) {
        if ([[evaluatedObject.preferredUIName lowercaseString] rangeOfString:cachedLower].location != NSNotFound)
            return YES;
        else
            return NO;
    };
}

- (void)setFilterString:(NSString *)filterString {
    NSCharacterSet *white = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    filterString = [filterString stringByTrimmingCharactersInSet:white];

    if ([filterString isEqualToString:_filterString])
        return;

    if ([filterString isEqualToString:@""])
        filterString = nil;

    _filterString = filterString;
    [self repopulateOrderingList];
}

- (void)dealloc {
    [self detachHandlersFromConnection];
}

@end
