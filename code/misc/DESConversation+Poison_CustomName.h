#include "Copyright.h"

#import "DESAbstract.h"

@interface DESConversation (Poison_CustomName)
- (NSString *)customName;
- (NSString *)preferredUIName;
- (NSAttributedString *)preferredUIAttributedNameWithColour:(NSColor *)fg
                                           backgroundColour:(NSColor *)bg;

- (NSImage *)userImage;
- (NSString *)conversationIdentifier;
@end
