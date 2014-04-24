#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "tox.h"
#import "data.h"

@interface SCToxProfile : NSObject

@end

@interface SCProfileManager : NSObject
+ (BOOL)profileNameExists:(NSString *)aProfile;
+ (NSURL *)profileDirectory;
+ (BOOL)deleteProfileName:(NSString *)aProfile;
+ (BOOL)saveProfile:(txd_intermediate_t)aProfile name:(NSString *)name password:(NSString *)password;
+ (txd_intermediate_t)attemptDecryptionOfProfileName:(NSString *)aProfile password:(NSString *)password error:(NSError **)err;

+ (NSString *)currentProfileIdentifier;
+ (NSDictionary *)privateSettings;
+ (id)privateSettingForKey:(id<NSCopying>)k;
+ (void)setPrivateSetting:(id)val forKey:(id<NSCopying>)k;
+ (void)commitPrivateSettings;
+ (void)purgePrivateSettingsFromMemory;
@end
