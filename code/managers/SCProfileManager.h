#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "tox.h"
#import "data.h"

@interface SCProfileManager : NSObject
+ (instancetype)currentProfile;

+ (BOOL)profileNameExists:(NSString *)aProfile;
+ (NSURL *)profileDirectory;
+ (BOOL)deleteProfileName:(NSString *)aProfile;
+ (BOOL)saveProfile:(txd_intermediate_t)aProfile name:(NSString *)name password:(NSString *)password;
+ (txd_intermediate_t)attemptDecryptionOfProfileName:(NSString *)aProfile password:(NSString *)password error:(NSError **)err;
+ (void)purgeCurrentProfile;

- (NSString *)identifier;
- (NSDictionary *)privateSettings;
- (id)privateSettingForKey:(id<NSCopying>)k;
- (void)setPrivateSetting:(id)val forKey:(id<NSCopying>)k;
- (void)commitPrivateSettings;
@end
