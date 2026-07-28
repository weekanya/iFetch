#import <UIKit/UIKit.h>

#import "../core/IFetchCore.h"

@interface IFAdvancedMenuViewController : UITableViewController
@end

@interface IFIntegrityViewController : UITableViewController
@end

@interface IFProcessConnectionsViewController : UITableViewController
- (instancetype)initWithProcess:(IFProcessSample *)process;
@end
