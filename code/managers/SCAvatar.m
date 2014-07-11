#include "Copyright.h"

#import "SCAvatar.h"
#include <sodium.h>

@implementation SCAvatar

+ (instancetype)placeholderAvatar {
    static SCAvatar *placeholderAvatar;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        placeholderAvatar = [[self alloc] init];
        placeholderAvatar.url = [[NSBundle mainBundle] URLForResource:@"user-icon-default" withExtension:@"tiff"];
        placeholderAvatar.rep = [NSImage imageNamed:@"user-icon-default"];
        placeholderAvatar.size = 0;
    });
    return placeholderAvatar;
}

- (instancetype)initWithURL:(NSURL *)imageURL {
    NSData *png = [NSData dataWithContentsOfURL:imageURL];
    return [self initWithData:png url:imageURL];
}

- (instancetype)initWithData:(NSData *)png url:(NSURL *)imageURL {
    self = [super init];
    if (self) {
        NSImage *avatar = [[NSImage alloc] initWithData:png];
        if (avatar) {
            NSBitmapImageRep *pixelData = avatar.representations[0];
            if (pixelData.size.width != pixelData.size.height
                || pixelData.size.width < 64) {
                NSLog(@"we expected better of you");
                return nil;
            }
        } else {
            return nil;
        }
        self.rep = avatar;
        self.digest = malloc(crypto_hash_BYTES);
        crypto_hash(self.digest, png.bytes, png.length);
        self.size = ((NSBitmapImageRep *)avatar.representations[0]).size.width;
        self.url = imageURL;
        self.byteSize = (uint32_t)png.length;
    }
    return self;
}

- (void)dealloc {
    free(self.digest);
}

@end
