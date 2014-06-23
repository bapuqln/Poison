#ifndef DESUserDiscovery_h
#define DESUserDiscovery_h
#import <Foundation/Foundation.h>

extern NSString *const DESUserDiscoveryCallbackDomain;
#define DESUserDiscoveryErrorBadInput  (-1)
#define DESUserDiscoveryErrorBadReply  (-2)
#define DESUserDiscoveryErrorNoAddress (-3)

extern NSString *const DESUserDiscoveryIDKey;
extern NSString *const DESUserDiscoveryPublicKey;
extern NSString *const DESUserDiscoveryChecksumKey;
extern NSString *const DESUserDiscoveryVersionKey;

extern NSString *const DESUserDiscoveryRecVersion1;
extern NSString *const DESUserDiscoveryRecVersion2;

typedef NS_ENUM(NSInteger, DESUserDiscoveryTrustLevel) {
    DESUserDiscoveryUntrusted,
    DESUserDiscoveryUndecided,
    DESUserDiscoveryTrusted,
};

typedef void(^DESUserDiscoveryCallback)(NSDictionary *result, NSError *error);

/**
 * Find a user's Tox ID using DNS service discovery.
 * This function returns immediately, callback will be
 * called when the resolution is complete.
 * @param shouldBeAnEmailAddress the user's address.
 *                               Example: "stqism\@unglinux.org"
 * @param callback func(NSString *result, NSError *error).
 *                 One of the parameters will be valid depending on how
 *                 the resolution turned out.
 */
void DESDiscoverUser(NSString *shouldBeAnEmailAddress,
                     DESUserDiscoveryCallback callback);
#endif
