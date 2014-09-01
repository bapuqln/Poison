#import "SCDHTList.h"
#import "ObjectiveTox.h"
#import "NSData+ArisaOpening.h"
#import "SCKeybag.h"
#import <SystemConfiguration/SystemConfiguration.h>

NS_INLINE NSDictionary *_SCDHTListLoad() {
    NSURL *dynamicList = [SCApplicationSupportDirectory() URLByAppendingPathComponent:@"Nodefile.json.risa"];
    NSURL *embeddedList = [[NSBundle mainBundle] URLForResource:@"Nodefile.json"
                                                  withExtension:@"risa"];
    NSArray *keys = [[SCKeybag keybag] keysForRole:@"arisa" containingDomain:@"dht-list."];
    NSData *file = [NSData dataOpeningArisaFile:dynamicList keys:keys];
    if (!file) {
        NSLog(@"file is nil... which means it's either missing or not arisa-signed properly");
        file = [NSData dataOpeningArisaFile:embeddedList keys:keys];
    } else {
        NSLog(@"arisa signature good, nodefile is OK.");
    }

    NSError *error;
    NSDictionary *ret = [NSJSONSerialization JSONObjectWithData:file options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        NSLog(@"can't parse json -> %@", error);
        return nil;
    } else {
        return ret;
    }
}

/* FIXME: ipv6 */

void SCDHTListApplyToConnection(DESToxConnection *conn) {
    NSMutableArray *list = _SCDHTListLoad()[@"servers"];
    NSUInteger cnt = 0;
    for (NSDictionary *serv in list) {
        if (cnt > 5)
            break;
//        for (NSString *key in serv) {
//            NSLog(@"%@ -> %@", key, NSStringFromClass([serv[key] class]));
//        }
        NSLog(@"try: %@", serv);
        [conn bootstrapWithServerAddress:serv[@"ipv4"]
                                    port:[serv[@"port"] unsignedShortValue]
                               publicKey:serv[@"pubkey"]];
        ++cnt;
    }
}