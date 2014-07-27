#import <Foundation/Foundation.h>
#import "code_signing.h"

/**
 * > tfw having to use XPC to break out of sandbox
 * yes, subprocesses inherit the sandbox that's why we can't use them
 * so, DeltaService does both deltas and complete updates, despite
 * the name. we're going to wait for Poison2x to send some data, then
 * when we are positively sure the update is all valid and ready, tell
 * Poison2x to disconnect and exit. we also verify code signatures before
 * and after updating.
 */

static dt_sign_status_t dt_global_sign_status;

static void dt_handle_connection(xpc_connection_t new_connection) {
    int pid = xpc_connection_get_pid(new_connection);
    NSLog(@"hello, %d", pid);

    dt_sign_status_t cs = dt_check_sign_other(pid);
    if (cs == dt_bad_signature) {
        NSLog(@"pid %d is tainted, get the fuck out", pid);
        xpc_connection_cancel(new_connection);
    } else if (cs == dt_no_signature) {
        NSLog(@"i'm ambivalent about pid %d...", pid);
        if (dt_global_sign_status == dt_no_signature) {
            NSLog(@"but hey, i'm not signed either.");
        } else {
            NSLog(@"bye %d", pid);
            xpc_connection_cancel(new_connection);
        }
    } else {
        NSLog(@"all green");
    }

    xpc_connection_set_event_handler(new_connection, ^(xpc_object_t object) {
        NSLog(@"Event: %@", object);
    });
}

int main(int argc, const char *argv[]) {
    NSLog(@"DeltaService is at yours. :^)");
    dt_global_sign_status = dt_check_sign_self();
    NSLog(@"signature status is %d.", dt_global_sign_status);
    xpc_main(dt_handle_connection);
    return 0;
}
