#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "tox.h"
#import "data.h"
#import "txdplus.h"
#import "SCAvatar.h"

FOUNDATION_EXPORT NSString *const SCSelfSenderUID;

@interface SCProfileManager : NSObject
+ (instancetype)currentProfile;

+ (BOOL)profileNameExists:(NSString *)aProfile;
+ (NSURL *)profileDirectory;
+ (BOOL)deleteProfileName:(NSString *)aProfile;
+ (BOOL)saveProfile:(txd_intermediate_t)aProfile name:(NSString *)name password:(NSString *)password;
+ (BOOL)saveProfile:(txd_intermediate_t)aProfile name:(NSString *)name fast:(txd_fast_t)password;
+ (txd_intermediate_t)attemptDecryptionOfProfileName:(NSString *)aProfile password:(NSString *)password error:(NSError **)err;
+ (void)purgeCurrentProfile;

- (SCAvatar *)avatar;
- (SCAvatar *)avatarForUID:(NSString *)uid;
- (void)setAvatar:(NSImage *)image;
- (NSURL *)profileDirectory;

- (NSString *)identifier;
- (NSDictionary *)privateSettings;
- (id)privateSettingForKey:(id<NSCopying>)k;
- (void)setPrivateSetting:(id)val forKey:(id<NSCopying>)k;
- (void)commitPrivateSettings;
@end
