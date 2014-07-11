#import "ObjectiveTox-Private.h"
#include <time.h>

#define DES_LEFTOVER_BUFFER_SIZE (2097152)

@implementation DESFileTransfer
@dynamic associatedConversation, transferSpeed, direction, inStream, outStream,
         state, progress, proposedFilename, proposedFilenameString;
- (void)acceptFileTransferIntoFile:(NSString *)file append:(BOOL)append { DESAbstractWarning; return; }
- (void)acceptFileTransferIntoStream:(NSOutputStream *)stream { DESAbstractWarning; return; }
- (int)sender { DESAbstractWarning; return 0; }

- (void)pause { DESAbstractWarning; }
- (void)cancel { DESAbstractWarning; }
- (void)finish { DESAbstractWarning; }
- (void)tryToWritePacks { DESAbstractWarning; }
@end

@implementation DESIncomingFileTransfer {
    int _fileSender;
    uint64_t _expectedBytes;
    uint64_t _completeBytes;
    uint64_t _dirtyBytes;

    int64_t _currentTime;
    int64_t _recvLastSecond;

    int64_t _recvLastFiveSeconds[5];
    int _recvRingPosition;
    NSMutableArray *_dirtyChunks;
    NSMutableData *_currentChunk;

    NSRecursiveLock *_streamLock;
}
@synthesize associatedConversation = _associatedConversation;
@synthesize state = _state;

@synthesize proposedFilename = _proposedFilename;
@synthesize proposedFilenameString = _proposedFilenameString;
@synthesize outStream = _output;

- (instancetype)initWithSenderNumber:(int)sender onConversation:(DESConversation<DESFileTransferring> *)conv filename:(NSData *)filename size:(uint64_t)size {
    self = [super init];
    if (self) {
        _associatedConversation = conv;
        _fileSender = sender;
        memset(_recvLastFiveSeconds, 0xFF, sizeof(uint64_t) * 5);
        _dirtyChunks = [[NSMutableArray alloc] init];
        _streamLock = [[NSRecursiveLock alloc] init];
        _expectedBytes = size;
        _state = DESTransferStateWaiting;
        _proposedFilename = filename;

        NSString *tryName = [[NSString alloc] initWithBytesNoCopy:(void *)filename.bytes length:filename.length encoding:NSUTF8StringEncoding freeWhenDone:NO];
        if (tryName)
            _proposedFilenameString = tryName;
    }
    return self;
}

- (void)acceptFileTransferIntoStream:(NSOutputStream *)stream {
    _output = stream;
    [_output open];

    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 1, _fileSender,
                          TOX_FILECONTROL_ACCEPT, NULL, 0);
    self.state = DESTransferStateActive;
}

- (void)acceptFileTransferIntoFile:(NSString *)file append:(BOOL)append {
    NSOutputStream *out = [NSOutputStream outputStreamToFileAtPath:file append:append];
    if (!out) {
        return;
    }
    [self acceptFileTransferIntoStream:out];
}

- (void)didReceiveData:(uint8_t *)buf ofLength:(uint16_t)size {
    if (!_currentChunk)
        _currentChunk = [[NSMutableData alloc] initWithCapacity:size];
    [_currentChunk appendBytes:buf length:size];

    CFAbsoluteTime taimu = (int64_t)CFAbsoluteTimeGetCurrent();
    if (taimu != _currentTime) {
        _currentTime = taimu;
        _recvLastFiveSeconds[_recvRingPosition] = _recvLastSecond;
        _recvRingPosition = (_recvRingPosition + 1) % 5;
        _recvLastSecond = size;

        NSLog(@"avg: %lu", (unsigned long)self.transferSpeed);
    } else {
        _recvLastSecond += size;
    }

    _dirtyBytes += size;
}

- (void)pause {
    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 1, _fileSender,
                          TOX_FILECONTROL_PAUSE, NULL, 0);
    self.state = DESTransferStateUserPaused;
}

- (void)cancel {
    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 1, _fileSender,
                          TOX_FILECONTROL_KILL, NULL, 0);
    [_output close];
    self.state = DESTransferStateInvalid;
}

- (void)finish {
    self.state = DESTransferStateCompleted;
}

- (void)setState:(DESTransferState)state {
    _state = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.associatedConversation.delegate respondsToSelector:@selector(conversation:fileTransfer:didChangeState:)])
            [self.associatedConversation.delegate conversation:self.associatedConversation fileTransfer:self didChangeState:state];
    });
}

- (DESTransferDirection)direction {
    return DESTransferDirectionIn;
}

- (void)writeNextPack {
    NSData *package = [_dirtyChunks firstObject];
    if (!package) {
        NSLog(@"no pack!");
        return;
    }

    NSInteger bytesWritten = [_output write:package.bytes maxLength:package.length];
    if (bytesWritten == -1) {
        DESError(@"stream error: %@", _output.streamError);
    } else if (bytesWritten == 0) {
        DESError(@"stream reached eof but we still have bytes to write. RIP");
        abort();
    } else if (bytesWritten != package.length) {
        _dirtyChunks[0] = [NSData dataWithBytes:package.bytes + bytesWritten
                                         length:package.length - bytesWritten];
        _dirtyBytes -= bytesWritten;
        _completeBytes += bytesWritten;
    } else {
        [_dirtyChunks removeObjectAtIndex:0];
        _dirtyBytes -= bytesWritten;
        _completeBytes += bytesWritten;
    }
}

- (void)commitCurrentChunk {
    [_dirtyChunks addObject:_currentChunk];
    _currentChunk = nil;
}

- (void)tryToWritePacks {
    if (_currentChunk)
        [self commitCurrentChunk];

    while ([_output hasSpaceAvailable] && _dirtyChunks.count != 0) {
        [self writeNextPack];
    }

    if (tox_file_data_remaining(self.associatedConversation.connection._core, self.associatedConversation.peerNumber, self.sender, 1) == 0 && _dirtyChunks.count == 0) {
        [_output close];
        [self.associatedConversation.connection removeTransferTriggeringKVO:self];
    }
}

- (NSUInteger)transferSpeed {
    /* Taken by averaging the last five seconds of receiving. */
    NSUInteger sum = 0;
    int factor = 0;
    for (int i = 0; i < 5; ++i) {
        if (_recvLastFiveSeconds[i] != -1) {
            sum += _recvLastFiveSeconds[i];
            factor += 1;
        }
    }
    return sum / factor;
}

- (double)progress {
    return (double)_completeBytes / _expectedBytes;
}

- (int)sender {
    return _fileSender;
}

@end

@implementation DESOutgoingFileTransfer {
    int _fileSender;
    uint64_t _expectedBytes;
    uint64_t _sentBytes;

    int64_t _currentTime;
    int64_t _sendLastSecond;
    int64_t _sendLastFiveSeconds[5];
    int _sendRingPosition;

    NSData *_keptBuffer;
}
@synthesize associatedConversation = _associatedConversation;
@synthesize state = _state;

@synthesize proposedFilename = _proposedFilename;
@synthesize proposedFilenameString = _proposedFilenameString;
@synthesize inStream = _input;

- (instancetype)initWithSenderNumber:(int)sender onConversation:(DESConversation<DESFileTransferring> *)conv filename:(NSData *)filename size:(uint64_t)size {
    self = [super init];
    if (self) {
        _associatedConversation = conv;
        _fileSender = sender;
        memset(_sendLastFiveSeconds, 0xFF, sizeof(uint64_t) * 5);
        _expectedBytes = size;
        _state = DESTransferStateWaiting;
        _proposedFilename = filename;

        NSString *tryName = [[NSString alloc] initWithBytesNoCopy:(void *)filename.bytes length:filename.length encoding:NSUTF8StringEncoding freeWhenDone:NO];
        if (tryName)
            _proposedFilenameString = tryName;
    }
    return self;
}

- (NSUInteger)transferSpeed {
    /* Taken by averaging the last five seconds of sending. */
    NSUInteger sum = 0;
    int factor = 0;
    for (int i = 0; i < 5; ++i) {
        if (_sendLastFiveSeconds[i] != -1) {
            sum += _sendLastFiveSeconds[i];
            factor += 1;
        }
    }
    return sum / factor;
}

- (BOOL)writePack:(const uint8_t *)pk size:(uint16_t)sz {
    int ret = tox_file_send_data(self.associatedConversation.connection._core,
                                 self.associatedConversation.peerNumber,
                                 self.sender, (uint8_t *)pk, sz);
    if (ret == 0) {
        _sentBytes += sz;
        CFAbsoluteTime taimu = (int64_t)CFAbsoluteTimeGetCurrent();
        if (taimu != _currentTime) {
            _currentTime = taimu;
            _sendLastFiveSeconds[_sendRingPosition] = _sendLastSecond;
            _sendRingPosition = (_sendRingPosition + 1) % 5;
            _sendLastSecond = sz;

            NSLog(@"avg: %lu", (unsigned long)self.transferSpeed);
        } else {
            _sendLastSecond += sz;
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)tryToWritePacks {
    if (_state != DESTransferStateActive)
        return;

    if (_keptBuffer && [self writePack:_keptBuffer.bytes size:_keptBuffer.length]) {
        _keptBuffer = nil;
    } else {
        return;
    }

    int pktsize = tox_file_data_size(self.associatedConversation.connection._core,
                                     self.associatedConversation.peerNumber);
    uint8_t *data = malloc(pktsize);
    while ([_input hasBytesAvailable]) {
        NSInteger read = [_input read:data maxLength:pktsize];
        if (read == 0 && _sentBytes != _expectedBytes) {
            DESError(@"stream reached EOF before we could read all bytes");
            tox_file_send_control(self.associatedConversation.connection._core,
                                  self.associatedConversation.peerNumber, 0,
                                  self.sender, TOX_FILECONTROL_KILL, NULL, 0);
            free(data);
            return;
        } else if (read == -1) {
            DESError(@"stream error: %@", _input.streamError);
            free(data);
            return;
        }

        if ([self writePack:data size:read]) {
            continue;
        } else {
            _keptBuffer = [[NSData alloc] initWithBytesNoCopy:data length:read freeWhenDone:YES];
            return;
        }
    }
    free(data);
}

- (double)progress {
    return (double)_sentBytes / _expectedBytes;
}

- (int)sender {
    return _fileSender;
}

- (void)pause {
    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 0, _fileSender,
                          TOX_FILECONTROL_PAUSE, NULL, 0);
    self.state = DESTransferStateUserPaused;
}

- (void)resume {
    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 0, _fileSender,
                          TOX_FILECONTROL_ACCEPT, NULL, 0);
    self.state = DESTransferStateActive;
}

- (void)cancel {
    tox_file_send_control(_associatedConversation.connection._core,
                          _associatedConversation.peerNumber, 0, _fileSender,
                          TOX_FILECONTROL_KILL, NULL, 0);
    [_input close];
    self.state = DESTransferStateInvalid;
}

- (void)finish {
    self.state = DESTransferStateCompleted;
    [_input close];
    [self.associatedConversation.connection removeTransferTriggeringKVO:self];
}

- (void)setState:(DESTransferState)state {
    _state = state;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.associatedConversation.delegate respondsToSelector:@selector(conversation:fileTransfer:didChangeState:)])
            [self.associatedConversation.delegate conversation:self.associatedConversation fileTransfer:self didChangeState:state];
    });
}

- (DESTransferDirection)direction {
    return DESTransferDirectionOut;
}

@end
