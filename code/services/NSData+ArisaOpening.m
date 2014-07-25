#import "NSData+ArisaOpening.h"
#import "DESKeyFunctions.h"
#import "SCKeybag.h"
#include "libarisa.h"

@implementation NSData (ArisaOpening)

+ (instancetype)dataVerifyingArisaSig:(NSData *)data keys:(NSArray *)keys {
    if (data.length <= ARISA_SIGSTRUCTLEN)
        return nil;

    uint8_t *sigptr = arisa_get_signature((uint8_t *)data.bytes, data.length);
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
        return nil;
    }

    uint8_t real_hash[crypto_hash_sha512_BYTES];
    crypto_hash_sha512(real_hash, data.bytes, data.length - ARISA_SIGSTRUCTLEN);
    int match = crypto_verify_32(real_hash, hash) | crypto_verify_32(real_hash + 32, hash + 32);
    free(hash);
    if (match != 0)
        return nil;
    else
        return [NSData dataWithBytes:data.bytes length:data.length - ARISA_SIGSTRUCTLEN];
}

@end
