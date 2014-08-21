#import "SCAdvancedPaneController.h"

@interface SCAdvancedPaneController ()
@property xpc_connection_t updateConnection;
@property (weak) IBOutlet NSTextField *selectorField;
@end

@implementation SCAdvancedPaneController

- (IBAction)testXPC:(id)sender {
    self.updateConnection = xpc_connection_create("org.zodiaclabs.updategremlin", dispatch_get_main_queue());
    xpc_connection_set_event_handler(self.updateConnection, ^(xpc_object_t object) {
        NSLog(@"object:  %s", xpc_copy_description(object));
    });
    xpc_connection_resume(self.updateConnection);
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_bool(msg, "hi", YES);
    xpc_connection_send_message(self.updateConnection, msg);
    xpc_release(msg);
}

- (IBAction)runCustomUISelector:(id)sender {
    SEL selector = NSSelectorFromString(self.selectorField.stringValue);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
    inv.selector = selector;
    [inv setArgument:&selector atIndex:2];
    [inv invokeWithTarget:self];
}

- (void)testSel:(SEL)aSelector {
    NSLog(@"%@", NSStringFromSelector(aSelector));
}

@end
