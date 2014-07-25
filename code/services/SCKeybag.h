#include "Copyright.h"

#import <Foundation/Foundation.h>

@interface SCKey : NSObject
@property (strong) NSString *hex;
@property (strong) NSString *role;
@property (strong) NSArray *domains;

- (BOOL)matchesDomain:(NSString *)domain;

@end

@interface SCKeybag : NSObject
@property (strong, readonly) NSURL *DHTListURL;
@property (strong, readonly) NSURL *dynamicKeybagURL;
@property (strong, readonly) NSURL *softwareUpdateCatalogURL;

+ (instancetype)keybag;

- (NSArray *)keysForRole:(NSString *)role;
- (NSArray *)keysForRole:(NSString *)role containingDomain:(NSString *)domain;

- (void)synchronizeRemote;

@end
