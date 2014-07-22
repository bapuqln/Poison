#import <Foundation/Foundation.h>
#import "DESUserDiscovery.h"
#import "DESConstants.h"
#import "DESKeyFunctions.h"
#include "toxdns.h"
#include <dns.h>

NSString *const DESUserDiscoveryCallbackDomain = @"DESUserDiscoveryErrorDomain";

NSString *const DESUserDiscoveryIDKey = @"id";
NSString *const DESUserDiscoveryPublicKey = @"pub";
NSString *const DESUserDiscoveryChecksumKey = @"check";
NSString *const DESUserDiscoveryVersionKey = @"v";

NSString *const DESUserDiscoveryRecVersion1 = @"tox1";
NSString *const DESUserDiscoveryRecVersion2 = @"tox2";

NSDictionary *_DESGetKeybag(void) {
    static NSDictionary *keybag;
    static uint64_t modtime = 0;
    /* TODO: add custom keybag location */
    NSURL *keybagURL = [[NSBundle mainBundle] URLForResource:@"DESSignKeybag" withExtension:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attrs = [fileManager attributesOfItemAtPath:keybagURL.path error:nil];
    if (!attrs || (uint64_t)attrs.fileModificationDate.timeIntervalSince1970 != modtime) {
        keybag = [NSDictionary dictionaryWithContentsOfURL:keybagURL];
        modtime = [attrs.fileModificationDate timeIntervalSince1970];
        NSLog(@"note: had to re-read the manifest due to first access; or the modification time changed");
    }
    if (!keybag)
        keybag = @{};
    return keybag;
}

void _DESDecodeKeyValuePair(NSString *kv, NSString **kout, id *vout) {
    NSRange equals = [kv rangeOfString:@"="];
    if (equals.location == NSNotFound || equals.location + 1 == [kv length]) {
        *kout = kv;
        *vout = @"";
        return;
    } else {
        *kout = [kv substringToIndex:equals.location];
        *vout = [kv substringFromIndex:equals.location + 1];
    }
}

NSDictionary *_DESParametersForTXT(NSString *rec) {
    NSScanner *scanner = [[NSScanner alloc] initWithString:rec];
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
    NSString *pair = nil;
    while (!scanner.isAtEnd) {
        pair = nil;
        [scanner scanUpToString:@";" intoString:&pair];
        if (pair) {
            NSString *key, *value;
            _DESDecodeKeyValuePair(pair, &key, &value);
            if (key && value)
                ret[key] = value;
        }
        if (scanner.scanLocation >= rec.length)
            break;
        ++scanner.scanLocation;
    }
    return ret;
}

void _DESDiscoverUser_ErrorOut(NSString *domain, NSInteger code,
                               DESUserDiscoveryCallback callback) {
    NSError *e = [NSError errorWithDomain:domain
                                     code:code
                                 userInfo:nil];
    dispatch_sync(dispatch_get_main_queue(), ^{
        callback(nil, e);
    });
}

BOOL _DESLookup3(NSString *mail, DESUserDiscoveryCallback callback) {
    NSRange position = [mail rangeOfString:@"@"];
    NSString *normalDomain = [mail substringFromIndex:position.location + 1].lowercaseString;
    NSString *name = [mail substringToIndex:position.location];

    NSString *key = _DESGetKeybag()[normalDomain];
    if (!key)
        return NO;

    uint8_t *k = malloc(DESPublicKeySize);
    DESConvertPublicKeyToData(key, k);
    void *lookup_object = tox_dns3_new(k);

    stralloc fqdn = {0};
    fqdn.s = calloc(512, 1);
    fqdn.s[0] = '_';
    uint32_t requestid;
    tox_generate_dns3_string(lookup_object, (uint8_t *)fqdn.s + 1, 512, &requestid, (uint8_t *)name.UTF8String, [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    NSLog(@"fqdn.s: %s", fqdn.s);
    uint32_t enclen = strlen(fqdn.s);
    uint32_t left = 511 - enclen;
    NSString *domainPart = [NSString stringWithFormat:@"._tox.%@.", normalDomain];

    if ([domainPart lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > left) {
        free(fqdn.s);
        return NO;
    }

    memcpy(fqdn.s + enclen, domainPart.UTF8String, [domainPart lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    fqdn.len = strlen(fqdn.s);

    stralloc finis = {0};
    errno = 0;
    int result = dns_txt(&finis, &fqdn);
    free(fqdn.s);

    if (result == -1) {
        perror("lookup fail");
        return NO;
    } else {
        NSString *rec = [[NSString alloc] initWithBytes:finis.s
                                                 length:finis.len
                                               encoding:NSUTF8StringEncoding];
        NSDictionary *params = _DESParametersForTXT(rec);
        if (![params[@"v"] isEqualToString:@"tox3"]) {
            return NO;
        }

        if (!params[@"id"]) {
            _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                      DESUserDiscoveryErrorBadReply, callback);
            return YES;
        }

        uint8_t *toxid = malloc(DESFriendAddressSize);
        result = tox_decrypt_dns3_TXT(lookup_object, toxid,
                                      (uint8_t *)[params[@"id"] UTF8String],
                                      [params[@"id"] lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                      requestid);

        if (result == -1) {
            _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                      DESUserDiscoveryErrorBadReply, callback);
            return YES;
        }

        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:2];
        d[@"v"] = DESUserDiscoveryRecVersion1;
        d[@"id"] = DESConvertFriendAddressToString(toxid);
        callback(d, nil);
        return YES;
    }
}

BOOL _DESLookup2_1(NSString *mail, DESUserDiscoveryCallback callback) {
    NSRange position = [mail rangeOfString:@"@"];
    /* alloc memory for transforming @ to ._tox. */
    NSMutableString *DNSName = [NSMutableString stringWithCapacity:mail.length + 5];
    //NSString *normalDomain = [mail substringFromIndex:position.location + 1].lowercaseString;
    [DNSName appendFormat:@"%@._tox.%@",
     [mail substringToIndex:position.location],
     [mail substringFromIndex:position.location + 1]];

    stralloc fqdn = {0};
    uint32_t dl = (uint32_t)[DNSName lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    fqdn.s = calloc(dl + 1, 1);
    fqdn.len = dl;
    memcpy(fqdn.s, DNSName.UTF8String, dl);

    stralloc finis = {0};
    errno = 0;
    int result = dns_txt(&finis, &fqdn);
    free(fqdn.s);
    if (result == -1) {
        perror("lookup fail");
        _DESDiscoverUser_ErrorOut(NSPOSIXErrorDomain, errno,
                                  callback);
        return NO;
    } else {
        //__builtin_trap();
        if (finis.len == 0) {
            _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                      DESUserDiscoveryErrorNoAddress,
                                      callback);
            return NO;
        }
        NSString *rec = [[NSString alloc] initWithBytes:finis.s
                                                 length:finis.len
                                               encoding:NSUTF8StringEncoding];
        NSDictionary *params = _DESParametersForTXT(rec);
        if (!params[@"v"]) {
            _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                      DESUserDiscoveryErrorBadReply,
                                      callback);
            return NO;
        }

        if ([params[@"v"] isEqualToString:DESUserDiscoveryRecVersion1]) {
            if (((NSString *)params[@"id"]).length != DESFriendAddressSize * 2) {
                _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                          DESUserDiscoveryErrorBadReply,
                                          callback);
                return NO;
            }
        } else {
            _DESDiscoverUser_ErrorOut(DESUserDiscoveryCallbackDomain,
                                      DESUserDiscoveryErrorBadReply,
                                      callback);
            return NO;
        }

        dispatch_sync(dispatch_get_main_queue(), ^{
            callback(params, nil);
        });
        return YES;
    }
}

void DESDiscoverUser(NSString *shouldBeAnEmailAddress,
                     DESUserDiscoveryCallback callback) {
    const char *buf = shouldBeAnEmailAddress.UTF8String;
    NSUInteger len = [shouldBeAnEmailAddress lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    int at_count = 0;
    for (unsigned int i = 0; i < len && at_count < 2; ++i) {
        if (buf[i] == '@')
            ++at_count;
    }
    /*  */
    if (at_count != 1 || *buf == '@' || buf[len - 1] == '@' || len > UINT32_MAX) {
        NSError *e = [NSError errorWithDomain:DESUserDiscoveryCallbackDomain
                                         code:DESUserDiscoveryErrorBadInput
                                     userInfo:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(nil, e);
        });
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (_DESLookup3(shouldBeAnEmailAddress, callback)) {
            return;
        } else {
            _DESLookup2_1(shouldBeAnEmailAddress, callback);
        }
    });

}
