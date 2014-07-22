#include "Copyright.h"

#import <Cocoa/Cocoa.h>
#import "ObjectiveTox.h"
#import "SCSelectiveMenuTableView.h"

@interface SCBuddyListController : NSViewController <NSTextFieldDelegate,
                                                     SCSelectiveMenuTableViewing,
                                                     NSMenuDelegate>
@property (strong) IBOutlet NSTableView *friendListView;
- (void)attachKVOHandlersToConnection:(DESToxConnection *)tox;
- (IBAction)changeName:(id)sender;
- (IBAction)changeStatus:(id)sender;

- (NSString *)formatDate:(NSDate *)date;
- (DESConversation *)conversationSelectedInView;

- (NSRect)positionOfSelectedRow;
@end
