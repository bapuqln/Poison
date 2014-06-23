#import "ObjectiveTox.h"
#import "tox.h"
#import <sodium.h>

const uint32_t DESPublicKeySize = crypto_box_PUBLICKEYBYTES;
const uint32_t DESPrivateKeySize = crypto_box_SECRETKEYBYTES;
const uint32_t DESFriendAddressSize = TOX_FRIEND_ADDRESS_SIZE;

BOOL DESHexStringIsValid(NSString *hex) {
    NSCharacterSet *validSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF1234567890"];
    unsigned int i = 0;
    while(i < [hex length]) {
        if (![validSet characterIsMember:[hex characterAtIndex:i]]) {
            return NO;
        }
        i++;
    }
    return YES;
}

BOOL DESPublicKeyIsValid(NSString *theKey) {
    if ([theKey length] != DESPublicKeySize * 2) {
        return NO;
    } else {
        return DESHexStringIsValid(theKey);
    }
    return YES;
}

BOOL DESPrivateKeyIsValid(NSString *theKey) {
    if ([theKey length] != DESPrivateKeySize * 2) {
        return NO;
    } else {
        return DESHexStringIsValid(theKey);
    }
    return YES;
}

BOOL DESFriendAddressIsValid(NSString *theAddr) {
    if ([theAddr length] != DESFriendAddressSize * 2) {
        return NO;
    } else if (!DESHexStringIsValid(theAddr)) {
        return NO;
    }
    return YES;
}

void DESConvertHexToBytes(NSString *theString, uint8_t *theOutput) {
    const char *chars = [theString UTF8String];
    unsigned int i = 0, j = 0;
    NSUInteger len = [theString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte = 0;
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        theOutput[j++] = wholeByte;
    }
}

BOOL DESConvertPublicKeyToData(NSString *theString, uint8_t *theOutput) {
    if (!DESPublicKeyIsValid(theString))
        return NO;
    DESConvertHexToBytes(theString, theOutput);
    return YES;
}

BOOL DESConvertPrivateKeyToData(NSString *theString, uint8_t *theOutput) {
    if (!DESPrivateKeyIsValid(theString))
        return NO;
    DESConvertHexToBytes(theString, theOutput);
    return YES;
}

BOOL DESConvertFriendAddressToData(NSString *theString, uint8_t *theOutput) {
    if (!DESHexStringIsValid(theString) || [theString length] != DESFriendAddressSize * 2)
        return NO;
    DESConvertHexToBytes(theString, theOutput);
    return YES;
}

NSString *DESConvertBytesToHex(const uint8_t *theData, uint32_t len) {
    NSMutableString *theString = [NSMutableString stringWithCapacity:len * 2];
    for (NSInteger idx = 0; idx < len; ++idx) {
        [theString appendFormat:@"%02X", theData[idx]];
    }
    return (NSString*)theString;
}

NSString *DESConvertPublicKeyToString(const uint8_t *theData) {
    return DESConvertBytesToHex(theData, DESPublicKeySize);
}

NSString *DESConvertPrivateKeyToString(const uint8_t *theData) {
    return DESConvertBytesToHex(theData, DESPrivateKeySize);
}

NSString *DESConvertFriendAddressToString(const uint8_t *theData) {
    return DESConvertBytesToHex(theData, DESFriendAddressSize);
}

BOOL DESKeyPairIsValid(const uint8_t *privateKey, const uint8_t *publicKey) {
    /* This function is a bit... expensive. */
    uint8_t *temp_pub = malloc(DESPublicKeySize);
    uint8_t *temp_priv = malloc(DESPrivateKeySize);
    int success = crypto_box_keypair(temp_pub, temp_priv);
    if (success != 0) {
        free(temp_priv);
        free(temp_pub);
        return NO;
    }
    uint8_t *nonce = malloc(crypto_box_NONCEBYTES);
    randombytes_buf(nonce, crypto_box_NONCEBYTES);
    NSString *challenge = @"THIS IS A VALID SODIUM KEYPAIR"; /* Maybe generate a random string instead. */
    size_t mlen = crypto_box_ZEROBYTES + [challenge lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    uint8_t *encrypted = calloc(mlen, 1);
    uint8_t *message = calloc(mlen, 1);
    memcpy(message + crypto_box_ZEROBYTES, [challenge UTF8String], [challenge lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    crypto_box(encrypted, message, mlen, nonce, publicKey, temp_priv);
    memset(message, 0, mlen);
    crypto_box_open(message, encrypted, mlen, nonce, temp_pub, privateKey);
    NSString *verify = [[NSString alloc] initWithBytes:message + crypto_box_ZEROBYTES length:mlen - crypto_box_ZEROBYTES encoding:NSUTF8StringEncoding];
    free(temp_priv);
    free(temp_pub);
    free(message);
    free(encrypted);
    free(nonce);
    if ([verify isEqualToString:challenge])
        return YES;
    else
        return NO;
}
