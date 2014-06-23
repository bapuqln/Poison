#include "Copyright.h"

#import "SCFeedbackController.h"
#import "DESKeyFunctions.h"
#import <sodium.h>

static NSString *const SCFeedbackProjectName = @"poison2x";

@interface SCFeedbackController ()
@property (strong) IBOutlet NSButton *sendSystemVersionCheckbox;
@property (strong) IBOutlet NSTextView *comments;
@end

@implementation SCFeedbackController

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)awakeFromNib {
    self.sendSystemVersionCheckbox.title = NSLocalizedString(@"Include OS X version", nil);
}

- (IBAction)cancel:(id)sender {
    [[NSApplication sharedApplication] stopModal];
}

- (IBAction)send:(id)sender {
    /* create and serialize the base data */
    NSDictionary *data = @{
        @"comment": self.comments.string,
        @"system_vers": (self.sendSystemVersionCheckbox.state == NSOnState) ?
                        [NSProcessInfo processInfo].operatingSystemVersionString : @"(redacted)"
    };
    /* reasonably sure this will not fail */
    NSData *cleart = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    cleart = 0;

    uint8_t *tempkeys = malloc(crypto_box_PUBLICKEYBYTES + crypto_box_SECRETKEYBYTES);
    crypto_box_keypair(tempkeys, tempkeys + crypto_box_PUBLICKEYBYTES);
    /*


    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:SCApplicationInfoDictKey(@"SCFeedbackURL")];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        <#code#>
    }];*/
}


@end
