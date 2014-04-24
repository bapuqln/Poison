#include "Copyright.h"

#import "ObjectiveTox.h"
#import "SCAddFriendSheetController.h"
#import "NSURL+Parameters.h"
#import "DESUserDiscovery.h"
#import "SCBase64.h"
#import "SCValidationHelpers.h"
#import "NSWindow+Shake.h"

#define SCFailureUIColour ([NSColor colorWithCalibratedRed:0.6 green:0.0 blue:0.0 alpha:1.0])
#define SCSuccessUIColour ([NSColor colorWithCalibratedRed:0.0 green:0.8 blue:0.0 alpha:1.0])

@interface SCAddFriendSheetController ()
#pragma mark - plain id
@property (strong) IBOutlet NSView *plainIDMethodView;
@property (strong) IBOutlet NSTextField *idField;
#pragma mark - dns discovery
@property (strong) IBOutlet NSView *DNSDiscoveryMethodView;
@property (strong) IBOutlet NSTextField *mailAddressField;
@property (strong) IBOutlet NSButton *findButton;
@property (strong) IBOutlet NSTextField *keyPreview;
@property (strong) IBOutlet NSTextField *pinField;
@property (strong) IBOutlet NSTextField *pinValidationStatusField;

@property (strong) IBOutlet NSSegmentedControl *methodChooser;
@property (strong) IBOutlet NSView *methodPlaceholder;
@property (strong) IBOutlet NSTextField *messageField;
@property (strong) IBOutlet NSTextField *idValidationStatusField;
@property (strong) IBOutlet NSButton *continueButton;
@end

@implementation SCAddFriendSheetController {
    NSString *_proposedName;
    NSString *_proposedPIN;
    NSInteger _dnsDiscoveryVersion;
    NSDictionary *_rec;

    NSColor *_cachedSuccessColour;
    NSColor *_cachedFailureColour;
    NSColor *_cachedNeutralColour;
}

- (id)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        _cachedSuccessColour = SCSuccessUIColour;
        _cachedFailureColour = SCFailureUIColour;
        _cachedNeutralColour = [NSColor disabledControlTextColor];
    }
    return self;
}

- (void)awakeFromNib {
    self.idField.delegate = self;
    self.messageField.delegate = self;
    self.mailAddressField.delegate = self;
    self.pinField.delegate = self;

    self.keyPreview.font = [NSFont fontWithName:@"Menlo-Regular" size:12];
    self.idField.font = [NSFont fontWithName:@"Menlo-Regular" size:12];
    self.method = SCFriendFindMethodDNSDiscovery;
    [self resetFields:YES];
}

- (NSString *)proposedName {
    return _proposedName;
}

- (void)setProposedName:(NSString *)proposedName {
    _proposedName = proposedName;
}

- (NSString *)toxID {
    if (self.method == SCFriendFindMethodPlain) {
        return self.idField.stringValue;
    } else if (self.method == SCFriendFindMethodDNSDiscovery) {
        if (_dnsDiscoveryVersion == 1) {
            return _rec[DESUserDiscoveryIDKey];
        } else {
            NSData *bytes = [[self.pinField.stringValue stringByAppendingString:@"=="] substringToIndex:8].dataByDecodingBase64;
            return [NSString stringWithFormat:@"%@%@%@",
                    _rec[DESUserDiscoveryPublicKey],
                    DESConvertBytesToHex(bytes.bytes, (uint32_t)bytes.length),
                    _rec[DESUserDiscoveryChecksumKey]];
        }
    }
    return nil;
}

- (void)setToxID:(NSString *)theID {
    self.method = SCFriendFindMethodPlain;
    self.idField.stringValue = [theID uppercaseString];
    [self validateFields];
}

- (NSString *)message {
    return self.messageField.stringValue;
}

- (void)setMessage:(NSString *)theMessage {
    self.messageField.stringValue = theMessage;
    [self validateFields];
}

- (IBAction)methodDidChange:(NSSegmentedControl *)sender {
    NSView *op = nil;
    switch (sender.selectedSegment) {
        case SCFriendFindMethodPlain:
            op = self.plainIDMethodView;
            break;
        case SCFriendFindMethodDNSDiscovery:
            op = self.DNSDiscoveryMethodView;
            break;
        default:
            break;
    }
    self.methodPlaceholder.hidden = YES;
    CGFloat currentHeight = self.window.frame.size.height - self.methodPlaceholder.frame.size.height;
    [self.window setFrame:(CGRect){
        self.window.frame.origin,
        {self.window.frame.size.width, currentHeight + op.frame.size.height}
    } display:self.window.isVisible animate:self.window.isVisible];
    NSView *temp = self.methodPlaceholder;
    self.methodPlaceholder = op;

    op.frameOrigin = temp.frame.origin;

    [self resetFields:NO];
    [self.window.contentView replaceSubview:temp with:op];
    temp.hidden = NO;
    op.hidden = NO;
}

- (SCFriendFindMethod)method {
    return self.methodChooser.selectedSegment;
}

- (void)setMethod:(SCFriendFindMethod)method {
    self.methodChooser.selectedSegment = (NSInteger)method;
    [self methodDidChange:self.methodChooser];
}

- (NSString *)defaultFlavourText {
    switch (self.methodChooser.selectedSegment) {
        case SCFriendFindMethodPlain:
            return NSLocalizedString(@"Tox IDs are usually 76 characters long.", nil);
        case SCFriendFindMethodDNSDiscovery:
            return NSLocalizedString(@"Addresses look like name@doma.in.", nil);
        default:
            return NSLocalizedString(@"Huh?", @"Do not localize this string.");
    }
}

- (void)resetFields:(BOOL)clearMessage {
    _proposedName = nil;
    _proposedPIN = nil;
    _rec = nil;
    _dnsDiscoveryVersion = 0;
    self.idField.stringValue = @"";

    self.findButton.enabled = NO;
    self.mailAddressField.stringValue = @"";
    ((NSTextFieldCell *)self.mailAddressField.cell).placeholderString = [NSString stringWithFormat:@"%@@%@",
        NSLocalizedString(@"james", @"sample name for lookup sheet; lowercase"),
        [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultRegistrationDomain"]];
    self.keyPreview.stringValue = @"";
    self.pinField.stringValue = @"";
    [self.pinField.cell setPlaceholderString:NSLocalizedString(@"PIN", nil)];
    self.pinField.enabled = NO;
    self.pinValidationStatusField.stringValue = @"-";
    self.pinValidationStatusField.textColor = _cachedNeutralColour;

    [self validateFields];
    self.idValidationStatusField.stringValue = self.defaultFlavourText;

    if (clearMessage)
        self.messageField.stringValue = NSLocalizedString(@"Please Tox me on Tox.", nil);
    self.continueButton.enabled = NO;
}

- (void)fillWithURL:(NSURL *)toxURL {
    /* DD urls are over-parsed by apple, so apply the fix */
    NSString *id_ = toxURL.host;
    if (toxURL.user)
        id_ = [toxURL.user stringByAppendingString:[NSString stringWithFormat:@"@%@", id_]];

    if (SCQuickValidateID(id_)) {
        self.method = SCFriendFindMethodPlain;
        self.toxID = id_;
    } else if (SCQuickValidateDNSDiscoveryID(id_)) {
        self.method = SCFriendFindMethodDNSDiscovery;
        self.mailAddressField.stringValue = id_;
        [self startLookup:self];
    }

    if (toxURL.query) {
        NSDictionary *params = toxURL.parameters;
        if ([params[@"message"] isKindOfClass:[NSString class]]) {
            self.message = params[@"message"];
        }
        if ([params[@"x-name"] isKindOfClass:[NSString class]]) {
            self.proposedName = params[@"x-name"];
        }
        if ([params[@"pin"] isKindOfClass:[NSString class]]) {
            _proposedPIN = params[@"pin"];
        }
    }
}

- (void)validateFields {
    if (![self validateFields_Message])
        return;
    switch (self.methodChooser.selectedSegment) {
        case SCFriendFindMethodPlain:
            [self validateFields_PlainID];
            return;
        case SCFriendFindMethodDNSDiscovery:
            [self validateFieldsID_DNSDiscovery];
            if (_dnsDiscoveryVersion != 1)
                [self validateFieldsPIN_DNSDiscovery];
            return;
        default:
            return;
    }
}

- (BOOL)validateFields_Message {
    if (self.messageField.stringValue.length > UINT16_MAX) {
        self.messageField.textColor = _cachedFailureColour;
        [self failedValidation:NSLocalizedString(@"The message was too long.", nil)];
        return NO;
    }
    return YES;
}

- (void)failedValidation:(NSString *)message {
    self.idValidationStatusField.stringValue = message;
    self.continueButton.enabled = NO;
}

- (void)passedValidation {
    self.idValidationStatusField.stringValue = NSLocalizedString(@"Looks good.", nil);
    self.continueButton.enabled = YES;
}

#pragma mark - validation: dns discover mode
- (void)clearDNSDiscoveryInfo {
    self.keyPreview.stringValue = @"";
    self.pinField.stringValue = @"";
    self.pinField.enabled = NO;
    [self.pinField.cell setPlaceholderString:NSLocalizedString(@"PIN", nil)];
    self.pinValidationStatusField.stringValue = @"-";
    self.pinValidationStatusField.textColor = _cachedNeutralColour;
    _dnsDiscoveryVersion = 0;
    _rec = nil;
    _proposedPIN = nil;
    _proposedName = nil;
    self.continueButton.enabled = NO;
}

- (void)validateFieldsID_DNSDiscovery {
    if (!SCQuickValidateDNSDiscoveryID(self.mailAddressField.stringValue)) {
        self.mailAddressField.textColor = _cachedFailureColour;
        self.findButton.enabled = NO;
        [self failedValidation:NSLocalizedString(@"That doesn't look like a valid Tox ID.", nil)];
    } else if ([self.mailAddressField.stringValue isEqualToString:@""]) {
        [self failedValidation:self.defaultFlavourText];
    } else {
        self.mailAddressField.textColor = [NSColor controlTextColor];
        self.findButton.enabled = YES;
        self.idValidationStatusField.stringValue = NSLocalizedString(@"Click Find to search for a Tox user at that address.", nil);
    }
}

- (BOOL)isPINValid_toxv2:(NSString *)pin64 {
    if ([pin64 length] != 6)
        return NO;
    NSData *bytes = [[[pin64 stringByAppendingString:@"=="] substringToIndex:8] dataByDecodingBase64];
    if (SCChecksumAddress([_rec[@"__Poison_check_IV"] unsignedShortValue],
                          (uint8_t *)bytes.bytes, bytes.length)
        == [_rec[@"__Poison_check_match"] unsignedShortValue])
        return YES;
    else
        return NO;
}

- (void)validateFieldsPIN_DNSDiscovery {
    switch (_dnsDiscoveryVersion) {
        case 1:
            self.pinValidationStatusField.stringValue = @"\u2713";
            self.pinValidationStatusField.textColor = _cachedSuccessColour;
            self.idValidationStatusField.stringValue = NSLocalizedString(@"A PIN isn't required.", nil);
            [self passedValidation];
            break;
        case 2:
            self.idValidationStatusField.stringValue = NSLocalizedString(@"This type of PIN is 6 characters long.", nil);
            if ([self isPINValid_toxv2:self.pinField.stringValue]) {
                self.pinValidationStatusField.stringValue = @"\u2713";
                self.pinValidationStatusField.textColor = _cachedSuccessColour;
                [self passedValidation];
            } else {
                self.pinValidationStatusField.stringValue = @"\u2715";
                self.pinValidationStatusField.textColor = _cachedFailureColour;
                [self failedValidation:NSLocalizedString(@"Did you type the PIN correctly?", nil)];
            }
            break;
        default:
            break;
    }
}

#pragma mark - validation: plain ID mode
- (void)validateFields_PlainID {
    if (self.idField.stringValue.length != DESFriendAddressSize * 2
        || !SCQuickValidateID(self.idField.stringValue)) {
        self.idField.textColor = _cachedFailureColour;
        if (self.idField.stringValue.length == 0)
            [self failedValidation:self.defaultFlavourText];
        else
            [self failedValidation:NSLocalizedString(@"That doesn't look like a valid Tox ID.", nil)];
        return;
    }
    self.idField.textColor = [NSColor controlTextColor];
    self.messageField.textColor = [NSColor controlTextColor];
    [self passedValidation];
}

#pragma mark - ui binding

- (IBAction)startLookup:(id)sender {
    NSString *addr = self.mailAddressField.stringValue;
    if ([addr rangeOfString:@"@"].location == NSNotFound)
        addr = [addr stringByAppendingString:[NSString stringWithFormat:@"@%@",
                                              [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultRegistrationDomain"]]];
    self.mailAddressField.stringValue = addr;
    self.mailAddressField.enabled = NO;
    self.findButton.enabled = NO;
    DESDiscoverUser(addr, ^(NSDictionary *result, NSError *error) {
        self.mailAddressField.enabled = YES;
        self.findButton.enabled = YES;

        if (!result) {
            [self clearDNSDiscoveryInfo];
            if (error.domain == DESUserDiscoveryCallbackDomain
                && error.code == DESUserDiscoveryErrorNoAddress)
                [self failedValidation:NSLocalizedString(@"The user couldn't be found.", nil)];
            else if (error.domain == DESUserDiscoveryCallbackDomain
                     && error.code == DESUserDiscoveryErrorBadReply)
                [self failedValidation:NSLocalizedString(@"The server didn't respond correctly.", nil)];
            else
                [self failedValidation:NSLocalizedString(@"The lookup failed due to an unknown error.", nil)];
            [self.mailAddressField becomeFirstResponder];
            [self.mailAddressField selectText:self];
        }

        NSMutableDictionary *d = [result mutableCopy];
        _rec = d;

        if ([result[DESUserDiscoveryVersionKey] isEqual:DESUserDiscoveryRecVersion1]) {
            self.keyPreview.stringValue = result[DESUserDiscoveryIDKey];
            self.pinField.enabled = NO;
            [self.pinField.cell setPlaceholderString:NSLocalizedString(@"None", nil)];
            _dnsDiscoveryVersion = 1;
        } else if ([result[DESUserDiscoveryVersionKey] isEqual:DESUserDiscoveryRecVersion2]) {
            uint16_t check = 0;
            DESConvertHexToBytes(d[DESUserDiscoveryChecksumKey], (uint8_t *)&check);
            d[@"__Poison_check_match"] = @(check);

            uint8_t *pk = malloc(DESPublicKeySize);
            DESConvertPublicKeyToData(d[DESUserDiscoveryPublicKey], pk);
            d[@"__Poison_check_IV"] = @(SCChecksumAddress(0, pk, DESPublicKeySize));
            free(pk);

            self.keyPreview.stringValue = result[DESUserDiscoveryPublicKey];
            self.pinField.enabled = YES;
            [self.pinField.cell setPlaceholderString:NSLocalizedString(@"PIN", nil)];
            if (_proposedPIN && [self isPINValid_toxv2:_proposedPIN])
                self.pinField.stringValue = _proposedPIN;

            _dnsDiscoveryVersion = 2;
            [self.pinField becomeFirstResponder];
        }

        [self validateFieldsPIN_DNSDiscovery];
        NSLog(@"%@ %@", result, error);
    });
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == self.idField) {
        [self validateFields_PlainID];
    } else if (obj.object == self.messageField) {
        [self validateFields_Message];
    } else if (obj.object == self.mailAddressField) {
        [self clearDNSDiscoveryInfo];
        [self validateFieldsID_DNSDiscovery];
    } else if (obj.object == self.pinField) {
        [self validateFieldsPIN_DNSDiscovery];
    }
}

- (IBAction)exitSheet:(NSButton *)sender {
    [NSApp endSheet:self.window returnCode:sender.tag];
}
@end
