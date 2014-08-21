#include "Copyright.h"

#import <Foundation/Foundation.h>
#import "ObjectiveTox.h"
#import "SCHTMLTranscriptController.h"

@interface SCConversation : NSObject <DESConversationDelegate>
@property (strong, readonly) DESConversation *underlyingConversation;
@property (strong, readonly) NSArray *log;
@property (strong) NSDate *lastAlive;
@property (strong, nonatomic, readonly) NSOrderedSet *completionOrder;

- (void)addContainer:(SCHTMLTranscriptController *)container;
- (void)removeContainer:(SCHTMLTranscriptController *)container;
- (BOOL)containsContainer:(SCHTMLTranscriptController *)container;

- (void)sendMessage:(NSString *)message;
- (void)sendAction:(NSString *)message;
- (void)replayHistoryIntoContainer:(SCHTMLTranscriptController *)container;

- (void)noteNameChanged:(NSString *)newValue;
- (void)noteStatusMessageChanged:(NSString *)newValue;
@end

@interface SCConversationManager : NSObject
- (void)addConversation:(DESConversation *)conv;
- (void)deleteConversation:(DESConversation *)conv;
- (SCConversation *)conversationFor:(DESConversation *)llconv;
@end
