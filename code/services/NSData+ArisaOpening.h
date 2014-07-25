#import <Foundation/Foundation.h>

@interface NSData (ArisaOpening)
+ (instancetype)dataVerifyingArisaSig:(NSData *)data keys:(NSArray *)keys;
@end
