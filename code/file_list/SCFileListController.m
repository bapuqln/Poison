#import "SCFileListController.h"

@interface SCFileListController ()
@property (strong) IBOutlet NSSegmentedControl *filterControl;
@property (strong) IBOutlet NSTableView *list;
@end

@implementation SCFileListController

- (void)awakeFromNib {
    if ([NSAppearance class]) {
        NSString *appearanceName = NSAppearanceNameLightContent;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 10100
        if (SCIsYosemiteOrHigher())
            appearanceName = NSAppearanceNameVibrantLight;
#endif
        self.view.appearance = [NSAppearance appearanceNamed:appearanceName];
    }
    self.list.dataSource = self;
}

- (IBAction)clearCompletedTransfers:(id)sender {

}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 1000;
}

@end
