#ifndef CODE_SIGNING_H
#define CODE_SIGNING_H

#include <CoreFoundation/CoreFoundation.h>
#include <Security/CodeSigning.h>

typedef NS_ENUM(int, dt_sign_status_t) {
    dt_no_signature,
    dt_bad_signature,
    dt_good_signature,
};

static inline dt_sign_status_t dt_check_sign_other(pid_t pid) {
    NSDictionary *attrs = @{ (__bridge id)kSecGuestAttributePid: @(pid) };

    SecCodeRef other;
    int ret = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)(attrs), kSecCSDefaultFlags, &other);

    if (ret != errSecSuccess) {
        NSLog(@"%d", ret);
        return dt_no_signature;
    }

    OSStatus rv = SecCodeCheckValidity(other, kSecCSEnforceRevocationChecks, NULL);
    CFRelease(other);

    switch (rv) {
        case errSecSuccess:
            return dt_good_signature;
        case errSecCSUnsigned:
            return dt_no_signature;
        default:
            return dt_bad_signature;
    }
}

static inline dt_sign_status_t dt_check_sign_self(void) {
    SecCodeRef sig = NULL;
    SecCodeCopySelf(kSecCSDefaultFlags, &sig);

    OSStatus rv = SecCodeCheckValidity(sig, kSecCSEnforceRevocationChecks, NULL);
    CFRelease(sig);

    switch (rv) {
        case errSecSuccess:
            return dt_good_signature;
        case errSecCSUnsigned:
            return dt_no_signature;
        default:
            return dt_bad_signature;
    }
}

#endif
