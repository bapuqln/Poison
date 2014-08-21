#import <Foundation/Foundation.h>

@interface NSData (ArisaOpening)
+ (instancetype)dataOpeningArisaFile:(NSURL *)pth keys:(NSArray *)keys;
+ (instancetype)dataVerifyingArisaSig:(NSData *)data keys:(NSArray *)keys;
@end
