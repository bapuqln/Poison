#include "Copyright.h"

#import "DESConversation+Poison_CustomName.h"
#import "SCProfileManager.h"

@implementation DESConversation (Poison_CustomName)
- (NSParagraphStyle *)_paragraphStyle {
    //return [NSParagraphStyle defaultParagraphStyle];
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    return ps;
}

- (NSString *)_lookupCustomNameForID:(NSString *)id_ {
    NSDictionary *map = [[SCProfileManager currentProfile] privateSettingForKey:@"nicknames"];
    return map[id_];
}

- (NSString *)customName {
    return [self _lookupCustomNameForID:self.publicKey] ?: @"";
}

- (NSString *)preferredUIName {
    if (![self conformsToProtocol:@protocol(DESFriend)]) {
        return self.presentableTitle;
    }

    NSString *custom = [self _lookupCustomNameForID:self.publicKey];
    NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *def = [self.presentableTitle stringByTrimmingCharactersInSet:cs];

    /* note: actually left and right part, respectively */
    NSString *topPart = nil;
    NSString *bottomPart = nil;

    if (custom && ![custom isEqualToString:@""]) {
        topPart = custom;
        bottomPart = [def isEqualToString:@""]? nil : def;
    } else {
        BOOL hasBottom = [def isEqualToString:@""];
        topPart = hasBottom? NSLocalizedString(@"Unknown", nil) : def;
        if (hasBottom)
            bottomPart = [self.publicKey substringToIndex:8];
    }

    if (!bottomPart)
        return topPart;
    else
        return [NSString stringWithFormat:@"%@ (%@)", topPart, bottomPart];
}

- (NSAttributedString *)preferredUIAttributedNameWithColour:(NSColor *)fg
                                           backgroundColour:(NSColor *)bg {
    if (![self conformsToProtocol:@protocol(DESFriend)]) {
        return [[NSAttributedString alloc] initWithString:self.presentableTitle];
    }

    NSString *custom = [self _lookupCustomNameForID:self.publicKey];
    NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *def = [self.presentableTitle stringByTrimmingCharactersInSet:cs];

    /* note: actually left and right part, respectively */
    NSString *topPart = nil;
    NSString *bottomPart = nil;

    if (custom && ![custom isEqualToString:@""]) {
        topPart = custom;
        bottomPart = [def isEqualToString:@""]? nil : def;
    } else {
        BOOL hasBottom = [def isEqualToString:@""];
        topPart = hasBottom? NSLocalizedString(@"Unknown", nil) : def;
        if (hasBottom)
            bottomPart = [self.publicKey substringToIndex:8];
    }

    NSMutableAttributedString *p;
    p = [[NSMutableAttributedString alloc] initWithString:topPart
                                               attributes:@{NSForegroundColorAttributeName: fg,
                                                            NSParagraphStyleAttributeName: self._paragraphStyle}];
    if (bottomPart) {
        NSString *appendage = [NSString stringWithFormat:@" (%@)", bottomPart];
        [p appendAttributedString:[[NSAttributedString alloc] initWithString:appendage
                                                                  attributes:@{NSForegroundColorAttributeName: bg,
                                                                               NSParagraphStyleAttributeName: self._paragraphStyle}]];
    }
    return p;
}

#pragma mark - Avatars

- (NSImage *)userImage {
    if (self.type == DESConversationTypeFriend) {
        return [SCAvatar placeholderAvatar].rep;
    } else {
        return [NSImage imageNamed:@"group-icon-default"];
    }
}

#pragma mark - IDs

- (NSString *)conversationIdentifier {
    NSString *base = (self.type == DESConversationTypeFriend? @"F:"
                      : @"G:");
    return [base stringByAppendingString:self.publicKey];
}

@end
