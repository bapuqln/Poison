#include "Copyright.h"

#import <Foundation/Foundation.h>

NSString *const SCTranscriptThemeDidChangeNotification;

@interface SCThemeManager : NSObject

@property (strong, readonly) NSString *pathOfCurrentThemeDirectory;
@property (readonly) NSDictionary *themeDictionary;

+ (instancetype)sharedManager;
+ (BOOL)isValidThemeAtPath:(NSString *)path;
- (NSColor *)backgroundColorOfCurrentTheme;
- (NSColor *)barTopColorOfCurrentTheme;
- (NSColor *)barHighlightColorOfCurrentTheme;
- (NSColor *)barBottomColorOfCurrentTheme;
- (NSColor *)barTextColorOfCurrentTheme;
- (NSColor *)barBorderColorOfCurrentTheme;
- (NSURL *)baseTemplateURLOfCurrentTheme;
- (NSURL *)baseDirectoryURLOfCurrentTheme;
- (NSArray *)availableThemes;
- (void)changeThemePath:(NSString *)themePath;

@end
