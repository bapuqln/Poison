#import "DESMacros.h"
#import "ObjectiveTox-Private.h"
#import "tox.h"
#import "toxav.h"
#import "Messenger.h"

NSString *const DESDefaultNickname = @"Toxicle";
NSString *const DESDefaultStatusMessage = @"Toxing on Tox";
const uint32_t DESMaximumNameLength = TOX_MAX_NAME_LENGTH;
const uint32_t DESMaximumStatusMessageLength = TOX_MAX_STATUSMESSAGE_LENGTH;

NSString *const DESFriendAddingErrorDomain = @"DESFriendAddingErrorDomain";

NSString *DESCreateBase64String(NSData *bytes) {
    CFDataRef input = (__bridge CFDataRef)bytes;
    SecTransformRef transform = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
    SecTransformSetAttribute(transform, kSecTransformInputAttributeName,
                             input, NULL);
    CFDataRef encoded = SecTransformExecute(transform, NULL);
    NSString *ret = [[NSString alloc] initWithBytes:CFDataGetBytePtr(encoded)
                                             length:CFDataGetLength(encoded)
                                           encoding:NSASCIIStringEncoding];
    CFRelease(transform);
    CFRelease(encoded);
    return ret;
}

NSData *DESDecodeBase64String(NSString *enc) {
    CFDataRef input = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (uint8_t *)enc.UTF8String, [enc lengthOfBytesUsingEncoding:NSUTF8StringEncoding], kCFAllocatorNull);
    SecTransformRef transform = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
    SecTransformSetAttribute(transform, kSecTransformInputAttributeName,
                             input, NULL);
    CFDataRef encoded = SecTransformExecute(transform, NULL);
    CFRelease(input);
    CFRelease(transform);
    return (__bridge NSData *)encoded;
}

@interface DESToxConnection ()
@property dispatch_queue_t messengerQueue;
@property BOOL isMessengerLoopStopping;

@property Tox *tox;
@property ToxAv *toxav;
@end

@implementation DESToxConnection {
    NSMutableDictionary *_groupMapping;
    NSMutableDictionary *_friendMapping;
    NSMutableSet *_fileSenders;
}
@synthesize tox = _tox;
@synthesize messengerQueue = _messengerQueue;
@synthesize isMessengerLoopStopping = _isMessengerLoopStopping;
@synthesize closeNodesCount = _closeNodesCount;
@synthesize delegate = _delegate;

- (instancetype)init {
    if ((self = [super init])) {
        self.messengerQueue = dispatch_queue_create("ca.kirara.DES2RunLoop", DISPATCH_QUEUE_SERIAL);
        self.tox = tox_new(1);
        _friendMapping = [[NSMutableDictionary alloc] init];
        _groupMapping = [[NSMutableDictionary alloc] init];
        _fileSenders = [[NSMutableSet alloc] init];
        self.name = DESDefaultNickname;
        self.statusMessage = DESDefaultStatusMessage;
        self.isMessengerLoopStopping = YES;
        tox_callback_friend_request(self.tox, _DESCallbackFriendRequest, (__bridge void*)self);
        tox_callback_name_change(self.tox, _DESCallbackFriendNameDidChange, (__bridge void*)self);
        tox_callback_status_message(self.tox, _DESCallbackFriendStatusMessageDidChange, (__bridge void*)self);
        tox_callback_user_status(self.tox, _DESCallbackFriendUserStatus, (__bridge void*)self);
        tox_callback_typing_change(self.tox, _DESCallbackFriendTypingStatus, (__bridge void*)self);
        tox_callback_connection_status(self.tox, _DESCallbackFriendConnectionStatus, (__bridge void*)self);
        tox_callback_friend_message(self.tox, _DESCallbackFriendMessage, (__bridge void*)self);
        tox_callback_friend_action(self.tox, _DESCallbackFriendAction, (__bridge void*)self);
        tox_callback_read_receipt(self.tox, _DESCallbackReadReceipt, (__bridge void*)self);

        tox_callback_file_control(self.tox, _DESCallbackFileControl, (__bridge void*)self);
        tox_callback_file_data(self.tox, _DESCallbackFileData, (__bridge void*)self);
        tox_callback_file_send_request(self.tox, _DESCallbackFileRequest, (__bridge void*)self);

        self.toxav = toxav_new(self.tox, 16);
        toxav_register_callstate_callback(DESOrangeDidRequestCall, av_OnInvite, (__bridge void*)self);
    }
    return self;
}

- (Tox *)_core {
    return self.tox;
}

- (dispatch_queue_t)_messengerQueue {
    return self.messengerQueue;
}

#pragma mark - Run loop

- (void)start {
    if (!self.isMessengerLoopStopping) {
        DESWarn(@"You are calling [DESToxConnection start] multiple times. They will be ignored.");
        return;
    }
    self.isMessengerLoopStopping = NO;
    DESInfo(@"zenshin aru nomi!");
    dispatch_async(self.messengerQueue, ^{
        [self _desRunLoopRun];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(connectionDidBecomeActive:)])
                [self.delegate connectionDidBecomeActive:self];
        });
    });
}

- (void)_desRunLoopRun {
    tox_do(self.tox);
    for (DESFileTransfer *ft in _fileSenders) {
        [ft tryToWritePacks];
    }

    NSInteger previousNodesCount = self.closeNodesCount;
    NSInteger currentNodesCount = DESCountCloseNodes(self.tox);
    if (currentNodesCount != previousNodesCount)
        self.closeNodesCount = DESCountCloseNodes(self.tox);

    if (currentNodesCount > 0 && previousNodesCount == 0
        && [self.delegate respondsToSelector:@selector(connectionDidBecomeEstablished:)])
        [self.delegate connectionDidBecomeEstablished:self];
    else if (currentNodesCount == 0 && previousNodesCount > 0
             && [self.delegate respondsToSelector:@selector(connectionDidDisconnect:)])
        [self.delegate connectionDidDisconnect:self];

    if (!self.isMessengerLoopStopping) {
        uint32_t msec = tox_do_interval(self.tox);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(msec * NSEC_PER_MSEC));
        dispatch_after(popTime, self.messengerQueue, ^(void){
            [self _desRunLoopRun];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(connectionDidBecomeInactive:)])
                [self.delegate connectionDidBecomeInactive:self];
        });
    }
}

- (BOOL)isActive {
    return !self.isMessengerLoopStopping;
}

- (void)stop {
    self.isMessengerLoopStopping = YES;
    DESInfo(@"Stopping messenger loop.");
}

#pragma mark - Bootstrapping

- (void)setCloseNodesCount:(NSUInteger)closeNodesCount {
    if (_closeNodesCount == closeNodesCount)
        return;
    [self willChangeValueForKey:@"closeNodesCount"];
    _closeNodesCount = closeNodesCount;
    DESInfo(@"New node count: %lu", (unsigned long)_closeNodesCount);
    [self didChangeValueForKey:@"closeNodesCount"];
}

- (void)bootstrapWithServerAddress:(NSString *)addr
                              port:(uint16_t)port
                         publicKey:(NSString *)pubKey {
    dispatch_async(self.messengerQueue, ^{
        uint8_t *keyBytes = malloc(DESPublicKeySize);
        DESConvertPublicKeyToData(pubKey, keyBytes);
        tox_bootstrap_from_address(self.tox, [addr UTF8String], YES, port, keyBytes);
        free(keyBytes);
    });
}

#pragma mark - Self

- (DESFriend *)me {
    return (DESFriend*)self;
}

- (NSString *)name {
    uint32_t name_size = tox_get_self_name_size(self.tox);
    uint8_t *buf = malloc(name_size);
    tox_get_self_name(self.tox, buf);
    return [[NSString alloc] initWithBytesNoCopy:buf length:name_size encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

- (void)setName:(NSString *)name {
    if ([name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > TOX_MAX_NAME_LENGTH)
        return;
    dispatch_async(self.messengerQueue, ^{
        [self willChangeValueForKey:@"name"];
        tox_set_name(self.tox, (uint8_t*)[name UTF8String],
                     (uint16_t)[name lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        [self didChangeValueForKey:@"name"];
    });
}

- (NSString *)statusMessage {
    uint32_t smsg_size = tox_get_self_status_message_size(self.tox);
    uint8_t *buf = malloc(smsg_size);
    tox_get_self_status_message(self.tox, buf, smsg_size);
    return [[NSString alloc] initWithBytesNoCopy:buf length:smsg_size encoding:NSUTF8StringEncoding freeWhenDone:YES];
}

- (void)setStatusMessage:(NSString *)statusMessage {
    if ([statusMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > TOX_MAX_STATUSMESSAGE_LENGTH)
        return;
    dispatch_async(self.messengerQueue, ^{
        [self willChangeValueForKey:@"statusMessage"];
        tox_set_status_message(self.tox, (uint8_t*)[statusMessage UTF8String],
                               (uint16_t)[statusMessage lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        [self didChangeValueForKey:@"statusMessage"];
    });
}

- (DESFriendStatus)status {
    return DESToxToFriendStatus(tox_get_self_user_status(self.tox));
}

- (void)setStatus:(DESFriendStatus)status {
    TOX_USERSTATUS bit = DESFriendStatusToTox(status);
    if (bit == TOX_USERSTATUS_INVALID)
        return;
    dispatch_async(self.messengerQueue, ^{
        [self willChangeValueForKey:@"status"];
        tox_set_user_status(self.tox, bit);
        [self didChangeValueForKey:@"status"];
    });
}

- (NSString *)publicKey {
    // uint8_t *buf = malloc(DESPublicKeySize);
    /* TODO: Fix usage of private API */
    //tox_get_self_keys(self.tox, buf, NULL);
    Messenger *private = (Messenger*)self.tox;
    NSString *ret = DESConvertPublicKeyToString(private->net_crypto->self_public_key);
    //free(buf);
    return ret;
}

- (NSString *)privateKey {
    //uint8_t *buf = malloc(DESPrivateKeySize);
    /* TODO: Fix usage of private API */
    //tox_get_self_keys(self.tox, NULL, buf);
    Messenger *private = (Messenger*)self.tox;
    NSString *ret = DESConvertPrivateKeyToString(private->net_crypto->self_secret_key);
    //NSString *ret = DESConvertPrivateKeyToString(buf);
    //free(buf);
    return ret;
}

- (NSString *)friendAddress {
    uint8_t *buf = malloc(DESFriendAddressSize);
    tox_get_address(self.tox, buf);
    NSString *ret = DESConvertFriendAddressToString(buf);
    free(buf);
    return ret;
}

- (void)setPublicKey:(NSString *)publicKey privateKey:(NSString *)privateKey {
    uint8_t *keys = malloc(DESPublicKeySize + DESPrivateKeySize);
    DESConvertPublicKeyToData(publicKey, keys);
    DESConvertPrivateKeyToData(privateKey, keys + DESPublicKeySize);
    if (DESKeyPairIsValid(keys, keys + DESPublicKeySize)) {
        dispatch_async(self.messengerQueue, ^{
            [self willChangeValueForKey:@"publicKey"];
            [self willChangeValueForKey:@"privateKey"];
            [self willChangeValueForKey:@"friendAddress"];
            DESSetKeys(self.tox, keys, keys + DESPublicKeySize);
            free(keys);
            [self didChangeValueForKey:@"friendAddress"];
            [self didChangeValueForKey:@"privateKey"];
            [self didChangeValueForKey:@"publicKey"];
        });
    } else {
        DESWarn(@"You tried to set keys that were not valid. Public: %@ Private %@", publicKey, privateKey);
    }
}

- (DESConversation *)conversation {
    return nil;
}

- (DESToxConnection *)connection {
    return self;
}

- (int32_t)peerNumber {
    return -1;
}

- (BOOL)isTyping {
    return NO;
}

- (NSDate *)lastSeen {
    return [NSDate date];
}

- (NSString *)address {
    return nil;
}

- (uint16_t)port {
    return 0;
}

- (void)sendControlMessage:(NSData *)msg ofType:(uint8_t)packet {
    return;
}

#pragma mark - Nospam

- (NSString *)PIN {
    uint32_t nospam = tox_get_nospam(self.tox);
    NSData *bytes = [[NSData alloc] initWithBytes:&nospam length:4];
    return [DESCreateBase64String(bytes) stringByTrimmingCharactersInSet:
            [NSCharacterSet characterSetWithCharactersInString:@"="]];
}

- (void)setPIN:(NSData *)fourBytes {
    tox_set_nospam(self.tox, *(uint32_t *)fourBytes.bytes);
}

#pragma mark - Friends

- (void)addFriendPublicKey:(NSString *)key message:(NSString *)message {
    dispatch_async(self.messengerQueue, ^{
        uint8_t *keyBytes = malloc(DESFriendAddressSize);
        DESConvertFriendAddressToData(key, keyBytes);
        int32_t friendnum = tox_add_friend(self.tox, keyBytes, (uint8_t*)[message UTF8String],
                                           [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        free(keyBytes);

        if (friendnum >= 0)
            [self addFriendTriggeringKVO:friendnum];
        else
            if ([self.delegate respondsToSelector:@selector(didFailToAddFriendWithError:onConnection:)])
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *e = [NSError errorWithDomain:DESFriendAddingErrorDomain code:friendnum userInfo:nil];
                    [self.delegate didFailToAddFriendWithError:e onConnection:self];
                });
    });
}

- (void)addFriendPublicKeyWithoutRequest:(NSString *)key {
    dispatch_async(self.messengerQueue, ^{
        uint8_t *keyBytes = malloc(DESPublicKeySize);
        DESConvertPublicKeyToData(key, keyBytes);
        int32_t friendnum = tox_add_friend_norequest(self.tox, keyBytes);
        free(keyBytes);

        if (friendnum >= 0)
            [self addFriendTriggeringKVO:friendnum];
        else
            if ([self.delegate respondsToSelector:@selector(didFailToAddFriendWithError:onConnection:)])
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *e = [NSError errorWithDomain:DESFriendAddingErrorDomain code:friendnum userInfo:nil];
                    [self.delegate didFailToAddFriendWithError:e onConnection:self];
                });
    });
}

- (void)addGroup:(id<DESConversation>)conversation {
    NSSet *changeSet = [NSSet setWithObject:conversation];
    [self willChangeValueForKey:@"groups" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
    _groupMapping[@(conversation.peerNumber)] = conversation;
    [self didChangeValueForKey:@"groups" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
    if ([self.delegate respondsToSelector:@selector(didJoinGroupChat:onConnection:)])
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didJoinGroupChat:conversation onConnection:self];
        });
}

- (void)addFriendTriggeringKVO:(int32_t)friendnum {
    DESFriend *friend = [[DESConcreteFriend alloc] initWithNumber:friendnum onConnection:self];
    NSSet *changeSet = [NSSet setWithObject:friend];
    [self willChangeValueForKey:@"friends" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
    _friendMapping[friend.publicKey] = friend;
    [self didChangeValueForKey:@"friends" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changeSet];
    if ([self.delegate respondsToSelector:@selector(didAddFriend:onConnection:)])
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didAddFriend:friend onConnection:self];
        });
}

- (DESConversation *)groupChatWithID:(int32_t)num {
    return _groupMapping[@(num)];
}

- (DESFriend *)friendWithID:(int32_t)num {
    uint8_t *pk = malloc(DESPublicKeySize);
    int ret = tox_get_client_id(self.tox, num, pk);
    if (ret == -1) {
        free(pk);
        return nil;
    } else {
        NSString *key = DESConvertPublicKeyToString(pk);
        free(pk);
        return _friendMapping[key];
    }
}

- (DESFriend *)friendWithKey:(NSString *)pk {
    return _friendMapping[pk];
}

- (void)leaveGroup:(id<DESConversation>)group {
    dispatch_async(self.messengerQueue, ^{
        if (!tox_del_groupchat(self.tox, group.peerNumber)) {
            NSSet *changeSet = [NSSet setWithObject:group];
            [self willChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
            [self->_groupMapping removeObjectForKey:@(group.peerNumber)];
            [self didChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
        } else {
            DESWarn(@"group chat %d is not valid", group.peerNumber);
        }
    });
}

- (void)deleteFriend:(id<DESFriend>)friend {
    dispatch_async(self.messengerQueue, ^{
        NSString *pk = friend.publicKey;
        if (!tox_del_friend(self.tox, friend.peerNumber)) {
            NSSet *changeSet = [NSSet setWithObject:friend];
            [self willChangeValueForKey:@"friends" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
            [self->_friendMapping removeObjectForKey:pk];
            [self didChangeValueForKey:@"friends" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changeSet];
            if ([self.delegate respondsToSelector:@selector(didRemoveFriend:onConnection:)])
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate didRemoveFriend:(DESFriend *)friend onConnection:self];
                });
        } else {
            DESWarn(@"friend %d is not valid", friend.peerNumber);
        }
    });
}

- (void)syncFriendList {
    NSSet *mutationF = [self friends];
    NSSet *mutationG = [self groups];
    [self willChangeValueForKey:@"friends" withSetMutation:NSKeyValueMinusSetMutation usingObjects:mutationF];
    [_friendMapping removeAllObjects];
    [self didChangeValueForKey:@"friends" withSetMutation:NSKeyValueMinusSetMutation usingObjects:mutationF];
    [self willChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:mutationG];
    [_groupMapping removeAllObjects];
    [self didChangeValueForKey:@"groups" withSetMutation:NSKeyValueMinusSetMutation usingObjects:mutationG];

    uint32_t friend_count = tox_count_friendlist(self.tox);
    int32_t *numbers = calloc(friend_count, sizeof(int32_t));
    tox_get_friendlist(self.tox, numbers, friend_count);
    for (uint32_t i = 0; i < friend_count; ++i) {
        [self addFriendTriggeringKVO:numbers[i]];
    }
    free(numbers);
}

- (void)syncPeerNumbers_Friends {
    NSMutableDictionary *work = [_friendMapping mutableCopy];
    NSArray *friendsValid = [_friendMapping allValues];
    for (DESFriend *f in friendsValid) {
        int32_t n = tox_get_friend_number(self.tox, (uint8_t *)f.publicKey.UTF8String);
        if (n >= 0) {
            work[@(n)] = f;
            [(DESConcreteFriend *)f updatePeernum:n];
        }
    }
    _friendMapping = work;
}

- (NSSet *)friends {
    return [NSSet setWithArray:[_friendMapping allValues]];
}

- (NSSet *)groups {
    return [NSSet setWithArray:[_groupMapping allValues]];
}

#pragma mark - Tox Core control messages

- (void)registerForControlMessagesOfType:(uint8_t)pkt fromFriend:(DESFriend *)f {
    custom_lossless_packet_registerhandler((Messenger *)self.tox, f.peerNumber, pkt, _DESCallbackControlMessage, (__bridge void *)f);
}

- (void)unregisterForControlMessagesOfType:(uint8_t)pkt fromFriend:(DESFriend *)f {
    custom_lossless_packet_registerhandler((Messenger *)self.tox, f.peerNumber, pkt, NULL, NULL);
}

#pragma mark - Transfers

- (NSMutableSet *)unsafeTransfers {
    return _fileSenders;
}

- (void)addTransferTriggeringKVO:(DESFileTransfer *)transfer {
    NSSet *u = [NSSet setWithObject:transfer];
    [self willChangeValueForKey:@"fileTransfers" withSetMutation:NSKeyValueUnionSetMutation usingObjects:u];
    [_fileSenders addObject:transfer];
    [self didChangeValueForKey:@"fileTransfers" withSetMutation:NSKeyValueUnionSetMutation usingObjects:u];
}

- (void)removeTransferTriggeringKVO:(DESFileTransfer *)transfer {
    NSSet *u = [NSSet setWithObject:transfer];
    [self willChangeValueForKey:@"fileTransfers" withSetMutation:NSKeyValueMinusSetMutation usingObjects:u];
    [_fileSenders removeObject:transfer];
    [self didChangeValueForKey:@"fileTransfers" withSetMutation:NSKeyValueMinusSetMutation usingObjects:u];
}

- (NSSet *)fileTransfers {
    return [_fileSenders copy];
}

#pragma mark - TXD

- (txd_intermediate_t)createTXDIntermediate {
    txd_intermediate_t txd = txd_intermediate_from_tox(self.tox);
    return txd;
}

- (void)restoreDataFromTXDIntermediate:(txd_intermediate_t)txd {
    if (txd) {
        dispatch_sync(self.messengerQueue, ^{
            [self willChangeValueForKey:@"name"];
            [self willChangeValueForKey:@"statusMessage"];
            [self willChangeValueForKey:@"status"];
            [self willChangeValueForKey:@"publicKey"];
            [self willChangeValueForKey:@"privateKey"];
            [self willChangeValueForKey:@"friendAddress"];
            txd_restore_intermediate(txd, self.tox);
            [self syncFriendList];
            [self didChangeValueForKey:@"friendAddress"];
            [self didChangeValueForKey:@"privateKey"];
            [self didChangeValueForKey:@"publicKey"];
            [self didChangeValueForKey:@"status"];
            [self didChangeValueForKey:@"statusMessage"];
            [self didChangeValueForKey:@"name"];

            if ([self.delegate respondsToSelector:@selector(connectionDidFinishRestoringData:)])
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate connectionDidFinishRestoringData:self];
                });
        });
    }
}

- (void)dealloc {
    if (self.tox)
        tox_kill(self.tox);
    dispatch_release(self.messengerQueue);
    DESInfo(@"deallocated!");
}

@end
