#include "Copyright.h"

#import "SCKeybag.h"
#import "NSData+ArisaOpening.h"

@implementation SCKey

- (NSUInteger)hash {
    return self.hex.hash;
}

- (BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    return [self.hex isEqualToString:((SCKey *)object).hex];
}

- (BOOL)matchesDomain:(NSString *)domain {
    return [self.domains containsObject:domain];
}

@end

@implementation SCKeybag {
    NSMutableSet *_keys;
}

+ (instancetype)keybag {
    static SCKeybag *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSData *master = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"master" withExtension:@"keybag"]];
    NSError *error;
    NSMutableDictionary *contents = [NSJSONSerialization JSONObjectWithData:master options:0 error:&error];
    if (!contents) {
        NSLog(@"SCKeybag error reading master kb: %@", error);
        return nil;
    }

    _keys = [NSMutableSet set];
    for (NSDictionary *kv in contents[@"keys"]) {
        SCKey *k = [[SCKey alloc] init];
        k.role = kv[@"role"];
        k.hex = kv[@"key"];
        k.domains = kv[@"domain"];
        [_keys addObject:k];
    }

    if (contents[@"nodefile_address"]) {
        NSURL *url = [NSURL URLWithString:contents[@"nodefile_address"]];
        if (url) _DHTListURL = url;
    }
    if (contents[@"dynamickb_address"]) {
        NSURL *url = [NSURL URLWithString:contents[@"dynamickb_address"]];
        if (url) _dynamicKeybagURL = url;
    }
    if (contents[@"update_catalog"]) {
        NSURL *url = [NSURL URLWithString:contents[@"update_catalog"]];
        if (url) _softwareUpdateCatalogURL = url;
    }

    [self applyDynamicKeybag];
    return self;
}

- (NSArray *)keysForRole:(NSString *)role {
    return [[_keys filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"role == %@", role]] allObjects];
}

- (NSArray *)keysForRole:(NSString *)role containingDomain:(NSString *)domain {
    NSMutableArray *arr = [NSMutableArray array];
    for (SCKey *k in [_keys filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"role == %@", role]]) {
        if ([k matchesDomain:domain])
            [arr addObject:k];
    }
    return arr;
}

- (void)applyDynamicKeybag {
    NSURL *dynamicURL = [SCApplicationSupportDirectory() URLByAppendingPathComponent:@"dynamic.keybag"];
    NSData *dynamic = [NSData dataVerifyingArisaSig:[NSData dataWithContentsOfURL:dynamicURL] keys:[self keysForRole:@"arisa" containingDomain:@"dynamic-keybag."]];
    if (!dynamic) {
        NSLog(@"SCKeybag cannot arisa verify dynamic kb, probably missing");
        return;
    }

    NSError *error;
    NSMutableDictionary *contents = [NSJSONSerialization JSONObjectWithData:dynamic options:0 error:&error];
    if (!contents) {
        NSLog(@"SCKeybag error reading dynamic kb: %@", error);
        return;
    }

    for (NSDictionary *kv in contents[@"keys"]) {
        SCKey *k = [[SCKey alloc] init];
        k.role = kv[@"role"];
        k.hex = kv[@"key"];
        k.domains = kv[@"domain"];
        [_keys removeObject:k];
        if (![k.role isEqualToString:@"revoked"])
            [_keys addObject:k];
    }

    if (contents[@"nodefile_address"]) {
        NSURL *url = [NSURL URLWithString:contents[@"nodefile_address"]];
        if (url) _DHTListURL = url;
    }
    if (contents[@"dynamickb_address"]) {
        NSURL *url = [NSURL URLWithString:contents[@"dynamickb_address"]];
        if (url) _dynamicKeybagURL = url;
    }
    if (contents[@"update_catalog"]) {
        NSURL *url = [NSURL URLWithString:contents[@"update_catalog"]];
        if (url) _softwareUpdateCatalogURL = url;
    }
}

- (void)synchronizeRemote {

}

@end
