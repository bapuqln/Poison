#import "NSData+ArisaOpening.h"
#import "DESKeyFunctions.h"
#import "SCKeybag.h"
#include "libarisa.h"

BOOL _ArisaSigOpen(const uint8_t *bytes, uint64_t length, NSArray *keys) {
    if (length <= ARISA_SIGSTRUCTLEN)
        return NO;

    uint8_t *sigptr = arisa_get_signature((uint8_t *)bytes, length);
    uint8_t *hash = NULL;
    uint8_t ckey[ARISA_OPEN_KEYSIZE];
    for (SCKey *k in keys) {
        DESConvertHexToBytes(k.hex, ckey);
        int ret = arisa_copy_hash(sigptr, ckey, &hash);
        if (ret == 0)
            break;
    }
    if (!hash) {
        NSLog(@"no keys matched data, returning nil");
        return NO;
    }

    uint8_t real_hash[crypto_hash_sha512_BYTES];
    crypto_hash_sha512(real_hash, bytes, length - ARISA_SIGSTRUCTLEN);
    int match = crypto_verify_32(real_hash, hash) | crypto_verify_32(real_hash + 32, hash + 32);
    free(hash);
    if (match != 0)
        return NO;
    else
        return YES;
}

@implementation NSData (ArisaOpening)

+ (instancetype)dataOpeningArisaFile:(NSURL *)pth keys:(NSArray *)keys {
    int fd = open(pth.path.UTF8String, O_RDONLY);

    if (fd == -1)
        return nil;

    off_t fl = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);
    uint8_t *buf = malloc(fl);

    size_t nread = 0;
    while (nread < fl) {
        nread += read(fd, buf + nread, fl - nread);
    }
    close(fd);

    if (_ArisaSigOpen(buf, fl, keys)) {
        return [[NSData alloc] initWithBytesNoCopy:buf length:fl - ARISA_SIGSTRUCTLEN freeWhenDone:YES];
    } else {
        free(buf);
        return nil;
    }
}

+ (instancetype)dataVerifyingArisaSig:(NSData *)data keys:(NSArray *)keys {
    if (_ArisaSigOpen(data.bytes, data.length, keys)) {
        return [NSData dataWithBytes:data.bytes length:data.length - ARISA_SIGSTRUCTLEN];
    } else {
        return nil;
    }
}

@end
