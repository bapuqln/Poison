#include "Copyright.h"

#import <AppKit/AppKit.h>

@interface SCAvatar : NSObject

/* the placeholderAvatar displays as the head silhouette, but has
 * a size hardcoded to 0 so spec-conforming friends will refuse to
 * download it */
+ (instancetype)placeholderAvatar;
- (instancetype)initWithURL:(NSURL *)imageURL;
- (instancetype)initWithData:(NSData *)png url:(NSURL *)imageURL;

@property (strong) NSImage *rep;
@property (strong) NSURL *url;
@property uint8_t *digest;
@property uint16_t size;
@property uint32_t byteSize;

@end
