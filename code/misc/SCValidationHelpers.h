#ifndef Poison2x_SCValidationHelpers_h
#define Poison2x_SCValidationHelpers_h

#include "Copyright.h"

#import <Foundation/Foundation.h>

NS_INLINE int SCQuickValidateID(NSString *string) {
    const char *check = string.UTF8String;
    int i = 0;
    char a = 0;
    /* clear bit 3 - same thing as the XOR 32 trick to make
     * lowercase -> uppercase */
    for (a = *check & (~(1 << 5)); a != 0; a = check[++i] & (~(1 << 5))) {
        if ((a <= 70 && a >= 65) || (a <= 25 && a >= 16)) {
            continue; /* A-F, 0-9 */
        } else {
            // NSLog(@"fail: %d %c (%d -> %d) not valid tox char", i, check[i], check[i], a);
            return 0;
        }
    }
    return 1;
}

NS_INLINE int SCQuickValidateDNSDiscoveryID(NSString *string) {
    const char *buf = string.UTF8String;
    NSUInteger len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    int at_count = 0;
    for (int i = 0; i < len && at_count < 2; ++i) {
        if (buf[i] == '@')
            ++at_count;
    }

    if ((at_count != 1)
        || *buf == '@' /* can't start with @ */
        || buf[len - 1] == '@' /* can't end with it either */
        || len > UINT32_MAX) /* breaks djbdns */
        return 0;
    return 1;
}

NS_INLINE uint16_t SCChecksumAddress(uint16_t iv, uint8_t *address, uint16_t len) {
    uint8_t *checksum = (uint8_t *)&iv;
    uint16_t check;
    uint32_t i;

    for (i = 0; i < len; ++i)
        checksum[i % 2] ^= address[i];

    memcpy(&check, checksum, sizeof(check));
    return check;
}

#endif
