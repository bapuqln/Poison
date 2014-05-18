#include "Copyright.h"

#import "SCThemeManager.h"

static SCThemeManager *sharedInstance = nil;
NSString *const SCTranscriptThemeDidChangeNotification = @"SCTranscriptThemeDidChangeNotification";

@implementation SCThemeManager {
    NSMutableDictionary *themeDictionary;
    NSString *themeBasePath;
    NSArray *searchPaths;
}

+ (instancetype)sharedManager {
    if (!sharedInstance) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[SCThemeManager alloc] init];
        });
    }
    return sharedInstance;
}

- (instancetype)init {
    self = [self initWithSearchPaths:@[
            [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Themes"],
            [[SCApplicationSupportDirectory() path] stringByAppendingPathComponent:@"Themes"],
            ]];
    return self;
}

- (instancetype)initWithSearchPaths:(NSArray *)anArray {
    self = [super init];
    if (self) {
        searchPaths = anArray;
        for (NSString *searchPath in anArray) {
            [[NSFileManager defaultManager] createDirectoryAtPath:searchPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *savedThemePref = [[NSUserDefaults standardUserDefaults] stringForKey:@"aiThemeDirectory"];
        BOOL themeIsWithinSearchPaths = NO;
        for (NSString *searchPath in anArray) {
            if ([[savedThemePref stringByDeletingLastPathComponent] isEqualToString:searchPath])
                themeIsWithinSearchPaths = YES;
        }
        if (!savedThemePref || ![SCThemeManager isValidThemeAtPath:savedThemePref] || !themeIsWithinSearchPaths) {
            savedThemePref = [[NSBundle mainBundle] pathForResource:@"Default" ofType:@"psnChatStyle" inDirectory:@"Themes"];
            [[NSUserDefaults standardUserDefaults] setObject:savedThemePref forKey:@"aiThemeDirectory"];
        }
        if (![SCThemeManager isValidThemeAtPath:savedThemePref]) {
            [NSException exceptionWithName:@"SCThemeLoadingFailed" reason:@"Not even the default theme is valid. WTF?!" userInfo:nil];
            abort();
        }
        themeBasePath = savedThemePref;
        themeDictionary = [[NSDictionary dictionaryWithContentsOfFile:[savedThemePref stringByAppendingPathComponent:@"Info.plist"]] mutableCopy];
        if (!themeDictionary) {
            [NSException exceptionWithName:@"SCThemeLoadingFailed" reason:@"Theme's still not valid. I'm outta here." userInfo:nil];
            abort();
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SCTranscriptThemeDidChangeNotification object:self userInfo:nil];
    }
    return self;
}

+ (BOOL)isValidThemeAtPath:(NSString *)path {
    NSDictionary *themeDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
    if (!themeDict) {
        return NO;
    }
    NSString *baseTemplate = [path stringByAppendingPathComponent:themeDict[@"aiThemeBaseTemplateName"]];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:baseTemplate isDirectory:&isDir] || isDir) {
        return NO;
    }
    if (!themeDict[@"aiHumanReadableName"]) {
        return NO;
    }
    return YES;
}

- (NSColor *)parseHTMLColor:(NSString *)hex {
    if ([hex length] != 6) {
        return nil;
    }
    NSCharacterSet *valid = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFabcdef0123456789"];
    for (int l = 0; l < [hex length]; l++) {
        if ([valid characterIsMember:[hex characterAtIndex:l]]) {
            continue;
        } else {
            return nil;
        }
    }
    const char *chars = [hex UTF8String];
    uint8_t output[3];
    int i = 0, j = 0;
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte = 0;
    while (i < 6) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        output[j++] = wholeByte;
    }
    return [NSColor colorWithCalibratedRed:((CGFloat)output[0]) / 255.0 green:((CGFloat)output[1]) / 255.0 blue:((CGFloat)output[2]) / 255.0 alpha:1.0];
}

- (NSColor *)colorObjectForKey:(NSString *)key {
    id dictValue = themeDictionary[key];
    if ([dictValue isKindOfClass:[NSColor class]]) {
        return (NSColor*)dictValue;
    } else if (!dictValue) {
        themeDictionary[key] = [NSColor whiteColor];
        return [NSColor whiteColor];
    } else if ([dictValue isKindOfClass:[NSString class]]) {
        NSColor *bgc = [self parseHTMLColor:dictValue];
        if (!bgc) {
            themeDictionary[key] = [NSColor whiteColor];
            return [NSColor whiteColor];
        } else {
            themeDictionary[key] = bgc;
            return bgc;
        }
    }
    return [NSColor whiteColor];
}

- (NSColor *)backgroundColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBackgroundColor"];
}

- (NSColor *)barTopColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBarTopColor"];
}

- (NSColor *)barHighlightColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBarHighlightColor"];
}

- (NSColor *)barBottomColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBarBottomColor"];
}

- (NSColor *)barTextColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBarTextColor"];
}

- (NSColor *)barBorderColorOfCurrentTheme {
    return [self colorObjectForKey:@"aiThemeBarBorderColor"];
}

- (NSURL *)baseTemplateURLOfCurrentTheme {
    return [NSURL fileURLWithPath:[themeBasePath stringByAppendingPathComponent:themeDictionary[@"aiThemeBaseTemplateName"]]];
}

- (NSURL *)baseDirectoryURLOfCurrentTheme {
    return [NSURL fileURLWithPath:themeBasePath];
}

- (NSDictionary *)themeDictionary {
    return (NSDictionary*)themeDictionary;
}

- (void)changeThemePath:(NSString *)themePath {
    if ([SCThemeManager isValidThemeAtPath:themePath]) {
        themeBasePath = themePath;
        themeDictionary = [[NSDictionary dictionaryWithContentsOfFile:[themePath stringByAppendingPathComponent:@"theme.plist"]] mutableCopy];
        [[NSNotificationCenter defaultCenter] postNotificationName:SCTranscriptThemeDidChangeNotification object:self userInfo:nil];
    } else {
        NSLog(@"WARNING: -[SCThemeManager changeThemePath:] called with invalid path argument %@. The theme was not changed.", themePath);
    }
}

- (NSArray *)availableThemes {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    NSMutableArray *discoveredThemes = [[NSMutableArray alloc] init];
    for (NSString *searchPath in searchPaths) {
        NSArray *a = [fm contentsOfDirectoryAtPath:searchPath error:&error];
        if (error) {
            NSLog(@"I fucked up: %@", error.userInfo);
            error = nil;
            continue;
        }
        for (NSString *themePath in a) {
            NSString *s = [searchPath stringByAppendingPathComponent:themePath];
            if ([SCThemeManager isValidThemeAtPath:s]) {
                [discoveredThemes addObject:s];
            }
        }
    }
    return (NSArray*)discoveredThemes;
}

- (NSString *)pathOfCurrentThemeDirectory {
    return themeBasePath;
}

@end
