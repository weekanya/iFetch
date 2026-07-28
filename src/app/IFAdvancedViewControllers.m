#import "IFAdvancedViewControllers.h"

#import "../core/IFAdvancedDiagnostics.h"
#import <spawn.h>
#import <sys/stat.h>
#import <sys/wait.h>

extern char **environ;

static NSString *IFAV(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static UITableViewCell *IFAVCell(UITableView *tableView, NSString *identifier,
                                NSString *title, NSString *detail) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.numberOfLines = 3;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = nil;
    return cell;
}

static void IFAVShowMessage(UIViewController *controller, NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

@interface IFProcessConnectionsViewController ()
@property (nonatomic, strong) IFProcessSample *process;
@property (nonatomic, copy) NSArray<IFProcessConnection *> *connections;
@end

@implementation IFProcessConnectionsViewController

- (instancetype)initWithProcess:(IFProcessSample *)process {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _process = process;
        self.title = IFAV(@"Connections", @"Соединения");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reload:) forControlEvents:UIControlEventValueChanged];
    [self reload:nil];
}

- (void)reload:(__unused id)sender {
    self.connections = [IFAdvancedDiagnostics connectionsForProcess:self.process];
    UILabel *empty = [[UILabel alloc] init];
    empty.text = IFAV(@"No visible network connections", @"Видимые сетевые соединения не найдены");
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    empty.numberOfLines = 0;
    self.tableView.backgroundView = self.connections.count == 0 ? empty : nil;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.connections.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    return IFAV(@"Includes the selected app and active processes from its .app bundle, including Network Extensions.",
                @"Показывает выбранное приложение и активные процессы из его .app, включая Network Extension.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFProcessConnection *connection = self.connections[indexPath.row];
    NSString *detail = [NSString stringWithFormat:@"%@ → %@%@",
                        connection.localEndpoint, connection.remoteEndpoint,
                        connection.state.length ? [@" · " stringByAppendingString:connection.state] : @""];
    NSString *title = connection.processName.length
        ? [NSString stringWithFormat:@"%@ · %@", connection.processName, connection.protocolName]
        : connection.protocolName;
    UITableViewCell *cell = IFAVCell(tableView, @"IFConnection", title, detail);
    cell.imageView.image = [UIImage systemImageNamed:@"network"];
    return cell;
}

@end

@interface IFInjectionMapViewController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<IFInjectionGroup *> *groups;
@property (nonatomic, copy) NSArray<IFInjectionGroup *> *visibleGroups;
@end

@implementation IFInjectionMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFAV(@"Injection map", @"Карта инъекций");
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = search;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload:)];
    [self reload:nil];
}

- (void)reload:(__unused id)sender {
    self.groups = [IFAdvancedDiagnostics injectionMap];
    self.visibleGroups = self.groups;
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text.lowercaseString;
    self.visibleGroups = query.length == 0 ? self.groups :
        [self.groups filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(IFInjectionGroup *group,
                                                                                       __unused NSDictionary *bindings) {
        return [group.target.lowercaseString containsString:query] ||
            [[[group.tweaks componentsJoinedByString:@" "] lowercaseString] containsString:query];
    }]];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.visibleGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFInjectionGroup *group = self.visibleGroups[indexPath.row];
    NSString *running = group.runningProcesses.count
        ? [NSString stringWithFormat:IFAV(@"Running: %@", @"Запущено: %@"),
           [group.runningProcesses componentsJoinedByString:@", "]]
        : IFAV(@"No matching running process", @"Совпадающий процесс не запущен");
    UITableViewCell *cell = IFAVCell(tableView, @"IFInjection", group.target,
        [NSString stringWithFormat:@"%@\n%@", [group.tweaks componentsJoinedByString:@", "], running]);
    cell.imageView.image = [UIImage systemImageNamed:group.runningProcesses.count ? @"bolt.fill" : @"bolt"];
    cell.imageView.tintColor = group.runningProcesses.count ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
    return cell;
}

@end

@interface IFLaunchDaemonsViewController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<IFLaunchDaemonRecord *> *records;
@property (nonatomic, copy) NSArray<IFLaunchDaemonRecord *> *visibleRecords;
@end

@implementation IFLaunchDaemonsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"LaunchDaemons";
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = search;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload:)];
    [self reload:nil];
}

- (void)reload:(__unused id)sender {
    self.records = [IFAdvancedDiagnostics launchDaemons];
    self.visibleRecords = self.records;
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text.lowercaseString;
    self.visibleRecords = query.length == 0 ? self.records :
        [self.records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(IFLaunchDaemonRecord *record,
                                                                                        __unused NSDictionary *bindings) {
        return [record.label.lowercaseString containsString:query] ||
            [record.program.lowercaseString containsString:query];
    }]];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.visibleRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFLaunchDaemonRecord *record = self.visibleRecords[indexPath.row];
    NSString *state = record.isLoaded
        ? [NSString stringWithFormat:IFAV(@"Loaded · PID %d", @"Загружен · PID %d"), record.pid]
        : IFAV(@"Not running", @"Не запущен");
    UITableViewCell *cell = IFAVCell(tableView, @"IFDaemon", record.label,
        [NSString stringWithFormat:@"%@\n%@", state, record.program.length ? record.program : record.path]);
    cell.imageView.image = [UIImage systemImageNamed:record.isLoaded ? @"checkmark.circle.fill" : @"circle"];
    cell.imageView.tintColor = record.isLoaded ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
    return cell;
}

@end

@interface IFIntegrityViewController ()
@property (nonatomic, copy) NSArray<IFIntegrityIssue *> *issues;
@end

@implementation IFIntegrityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFAV(@"Jailbreak integrity", @"Целостность jailbreak");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload:)];
    [self reload:nil];
}

- (void)reload:(__unused id)sender {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray *issues = [IFAdvancedDiagnostics integrityIssues];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.issues = issues;
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [self.tableView reloadData];
        });
    });
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.issues.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFIntegrityIssue *issue = self.issues[indexPath.row];
    UITableViewCell *cell = IFAVCell(tableView, @"IFIntegrity", issue.title, issue.detail);
    NSArray *symbols = @[@"checkmark.circle.fill", @"exclamationmark.triangle.fill", @"xmark.octagon.fill"];
    NSArray *colors = @[UIColor.systemGreenColor, UIColor.systemOrangeColor, UIColor.systemRedColor];
    cell.imageView.image = [UIImage systemImageNamed:symbols[issue.severity]];
    cell.imageView.tintColor = colors[issue.severity];
    return cell;
}

@end

@interface IFSnapshotsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *snapshots;
@property (nonatomic, strong) UIBarButtonItem *compareButton;
@end

@implementation IFSnapshotsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFAV(@"System snapshots", @"Снимки системы");
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addSnapshot:)];
    self.compareButton = [[UIBarButtonItem alloc] initWithTitle:IFAV(@"Compare last 2", @"Сравнить 2")
                                                         style:UIBarButtonItemStylePlain
                                                        target:self action:@selector(compare:)];
    self.navigationItem.rightBarButtonItems = @[addButton, self.compareButton];
    [self reload];
}

- (void)reload {
    self.snapshots = [IFAdvancedDiagnostics systemSnapshots];
    self.compareButton.enabled = self.snapshots.count >= 2;
    UILabel *empty = [[UILabel alloc] init];
    empty.text = IFAV(@"Create two snapshots to compare system changes.",
                      @"Создайте два снимка, чтобы сравнить изменения системы.");
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    empty.numberOfLines = 0;
    self.tableView.backgroundView = self.snapshots.count == 0 ? empty : nil;
    [self.tableView reloadData];
}

- (void)addSnapshot:(__unused id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:IFAV(@"New snapshot", @"Новый снимок")
                                                                   message:IFAV(@"A list of processes, packages, tweaks and daemons will be saved.",
                                                                               @"Будут сохранены процессы, пакеты, твики и демоны.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = IFAV(@"Name", @"Название");
    }];
    [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Cancel", @"Отмена")
                                              style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Create", @"Создать")
                                              style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text ?: @"";
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSError *error = nil;
            NSDictionary *snapshot = [IFAdvancedDiagnostics captureSystemSnapshotNamed:name error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (snapshot == nil) {
                    IFAVShowMessage(self, @"iFetch", error.localizedDescription ?: IFAV(@"Could not create snapshot",
                                                                                       @"Не удалось создать снимок"));
                }
                [self reload];
            });
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)compare:(__unused id)sender {
    if (self.snapshots.count < 2) {
        return;
    }
    NSDictionary *newer = self.snapshots[0];
    NSDictionary *older = self.snapshots[1];
    NSDictionary<NSString *, NSArray<NSString *> *> *difference =
        [IFAdvancedDiagnostics compareSnapshot:older with:newer];
    NSArray *sections = @[
        @[@"processes", IFAV(@"Processes", @"Процессы")],
        @[@"packages", IFAV(@"Packages", @"Пакеты")],
        @[@"tweaks", IFAV(@"Tweaks", @"Твики")],
        @[@"daemons", @"LaunchDaemons"]
    ];
    NSMutableString *text = [NSMutableString stringWithFormat:@"%@ → %@\n\n",
                             older[@"name"] ?: older[@"createdAt"], newer[@"name"] ?: newer[@"createdAt"]];
    for (NSArray *section in sections) {
        NSArray *added = difference[[section[0] stringByAppendingString:@"Added"]];
        NSArray *removed = difference[[section[0] stringByAppendingString:@"Removed"]];
        [text appendFormat:@"%@\n+ %@\n− %@\n\n", section[1],
         added.count ? [added componentsJoinedByString:@", "] : @"—",
         removed.count ? [removed componentsJoinedByString:@", "] : @"—"];
    }
    UIViewController *controller = [[UIViewController alloc] init];
    controller.title = IFAV(@"Changes", @"Изменения");
    controller.view.backgroundColor = UIColor.systemBackgroundColor;
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    textView.text = text;
    [controller.view addSubview:textView];
    [NSLayoutConstraint activateConstraints:@[
        [textView.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [textView.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor]
    ]];
    [self.navigationController pushViewController:controller animated:YES];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.snapshots.count;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    return IFAV(@"The newest snapshots are shown first. Compare uses the latest two. Swipe left to delete.",
                @"Сначала показаны новые снимки. Сравнение использует два последних. Смахните влево для удаления.");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.row >= (NSInteger)self.snapshots.count) {
        return;
    }
    NSError *error = nil;
    if (![IFAdvancedDiagnostics deleteSystemSnapshot:self.snapshots[indexPath.row] error:&error]) {
        IFAVShowMessage(self, @"iFetch", error.localizedDescription ?: IFAV(@"Could not delete snapshot",
                                                                            @"Не удалось удалить снимок"));
        return;
    }
    [self reload];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *snapshot = self.snapshots[indexPath.row];
    NSString *detail = [NSString stringWithFormat:@"%@\n%lu %@ · %lu %@ · %lu %@ · %lu %@",
        snapshot[@"createdAt"] ?: @"",
        (unsigned long)[snapshot[@"packages"] count], IFAV(@"packages", @"пакетов"),
        (unsigned long)[snapshot[@"processes"] count], IFAV(@"processes", @"процессов"),
        (unsigned long)[snapshot[@"tweaks"] count], IFAV(@"tweaks", @"твиков"),
        (unsigned long)[snapshot[@"daemons"] count], IFAV(@"daemons", @"демонов")];
    UITableViewCell *cell = IFAVCell(tableView, @"IFSnapshot", snapshot[@"name"] ?: snapshot[@"createdAt"], detail);
    cell.detailTextLabel.numberOfLines = 2;
    cell.imageView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
    cell.imageView.tintColor = UIColor.systemIndigoColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.snapshots.count) {
        return;
    }
    NSDictionary *snapshot = self.snapshots[indexPath.row];
    NSString *message = [NSString stringWithFormat:
        IFAV(@"Created: %@\nDevice: %@\niFetch: %@\n\nProcesses: %lu\nPackages: %lu\nTweaks: %lu\nDaemons: %lu",
             @"Создан: %@\nУстройство: %@\niFetch: %@\n\nПроцессы: %lu\nПакеты: %lu\nТвики: %lu\nДемоны: %lu"),
        snapshot[@"createdAt"] ?: @"—", snapshot[@"device"] ?: @"—", snapshot[@"version"] ?: @"—",
        (unsigned long)[snapshot[@"processes"] count], (unsigned long)[snapshot[@"packages"] count],
        (unsigned long)[snapshot[@"tweaks"] count], (unsigned long)[snapshot[@"daemons"] count]];
    IFAVShowMessage(self, snapshot[@"name"] ?: IFAV(@"Snapshot", @"Снимок"), message);
}

@end

@interface IFDiagnosticModeViewController : UITableViewController
@end

@implementation IFDiagnosticModeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFAV(@"Diagnostic mode", @"Режим диагностики");
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : 1;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 1) {
        return nil;
    }
    return IFAV(@"Third-party tweak dylibs are renamed safely. Critical injectors and iFetch are not changed. The original names are saved for one-tap restore.",
                @"Dylib сторонних твиков безопасно переименовываются. Хук-инжекторы и iFetch не изменяются. Исходные имена сохраняются для восстановления.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL enabled = [IFAdvancedDiagnostics diagnosticModeEnabled];
    if (indexPath.section == 0) {
        return IFAVCell(tableView, @"IFDiagnosticState", IFAV(@"State", @"Состояние"),
            enabled ? [NSString stringWithFormat:IFAV(@"Enabled · %lu tweaks disabled",
                                                      @"Включён · отключено твиков: %lu"),
                       (unsigned long)[IFAdvancedDiagnostics diagnosticModeDisabledCount]]
                    : IFAV(@"Disabled", @"Выключен"));
    }
    UITableViewCell *cell = IFAVCell(tableView, @"IFDiagnosticAction",
        enabled ? IFAV(@"Restore tweaks", @"Вернуть твики")
                : IFAV(@"Disable third-party tweaks", @"Отключить сторонние твики"), @"");
    cell.textLabel.textColor = enabled ? UIColor.systemBlueColor : UIColor.systemOrangeColor;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) {
        return;
    }
    BOOL enabled = [IFAdvancedDiagnostics diagnosticModeEnabled];
    NSString *message = enabled
        ? IFAV(@"Restore every tweak changed by iFetch and Respring?",
               @"Вернуть все изменённые iFetch твики и выполнить Respring?")
        : IFAV(@"Temporarily disable third-party tweaks and Respring? You can restore them from this screen.",
               @"Временно отключить сторонние твики и выполнить Respring? Их можно вернуть на этом экране.");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.title message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Cancel", @"Отмена")
                                              style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Continue", @"Продолжить")
                                              style:enabled ? UIAlertActionStyleDefault : UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        BOOL success = enabled ? [IFAdvancedDiagnostics restoreDiagnosticModeWithError:&error]
                               : [IFAdvancedDiagnostics enableDiagnosticModeWithError:&error];
        if (!success) {
            IFAVShowMessage(self, @"iFetch", error.localizedDescription ?: IFAV(@"Operation failed",
                                                                                @"Операция не выполнена"));
            return;
        }
        [self.tableView reloadData];
        [self respring];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    NSArray<NSString *> *paths = @[@"/var/jb/usr/bin/sbreload", @"/var/jb/usr/bin/killall",
                                   @"/usr/bin/sbreload", @"/usr/bin/killall"];
    NSString *path = nil;
    for (NSString *candidate in paths) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:candidate]) {
            path = candidate;
            break;
        }
    }
    if (path.length == 0) {
        IFAVShowMessage(self, @"iFetch", IFAV(@"Changes saved. Respring manually to apply them.",
                                              @"Изменения сохранены. Выполните Respring вручную."));
        return;
    }
    NSArray<NSString *> *arguments = [path.lastPathComponent isEqualToString:@"killall"]
        ? @[@"killall", @"SpringBoard"] : @[@"sbreload"];
    char *argv[3] = {0};
    for (NSUInteger index = 0; index < arguments.count; index++) {
        argv[index] = (char *)arguments[index].UTF8String;
    }
    pid_t pid = 0;
    int result = posix_spawn(&pid, path.fileSystemRepresentation, NULL, NULL, argv, environ);
    if (result != 0) {
        IFAVShowMessage(self, @"iFetch", [NSString stringWithFormat:IFAV(@"Respring failed: %d",
                                                                        @"Ошибка Respring: %d"), result]);
    }
}

@end

@implementation IFPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFAV(@"Notifications", @"Уведомления");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [IFAdvancedDiagnostics refreshAlertsAuthorizationWithCompletion:^(__unused BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return 1;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(__unused NSInteger)section {
    return IFAV(@"System alerts", @"Системные уведомления");
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    return IFAV(@"Alerts are generated during active iFetch monitoring for high memory, CPU, temperature and new crashes.",
                @"Во время активного мониторинга iFetch сообщает о высокой загрузке ОЗУ, CPU, температуре и новых сбоях.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    UITableViewCell *cell = IFAVCell(tableView, @"IFAlerts", IFAV(@"Health alerts", @"Уведомления о состоянии"), @"");
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = [IFAdvancedDiagnostics alertsEnabled];
    [toggle addTarget:self action:@selector(alertsChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)alertsChanged:(UISwitch *)toggle {
    BOOL requested = toggle.isOn;
    toggle.enabled = NO;
    [IFAdvancedDiagnostics setAlertsEnabled:requested completion:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            toggle.on = granted;
            toggle.enabled = YES;
            if (requested && !granted) {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"iFetch"
                                     message:IFAV(@"Notifications are disabled for iFetch. Enable them in iOS Settings.",
                                                  @"Уведомления для iFetch отключены. Включите их в настройках iOS.")
                              preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Cancel", @"Отмена")
                                                          style:UIAlertActionStyleCancel handler:nil]];
                [alert addAction:[UIAlertAction actionWithTitle:IFAV(@"Open Settings", @"Открыть настройки")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(__unused UIAlertAction *action) {
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    if (url != nil) {
                        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
                    }
                }]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

@end

@implementation IFAdvancedMenuViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"iFetch 4.0";
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *titles = @[
        IFAV(@"Injection map", @"Карта инъекций"),
        @"LaunchDaemons",
        IFAV(@"Diagnostic mode", @"Режим диагностики")
    ];
    NSArray *details = @[
        IFAV(@"Tweak filters grouped by target process", @"Фильтры твиков по целевым процессам"),
        IFAV(@"Bootstrap daemon state and executable paths", @"Состояние демонов и пути запуска"),
        IFAV(@"Temporarily disable and restore third-party tweaks", @"Временное отключение и возврат сторонних твиков")
    ];
    NSArray *symbols = @[@"point.3.connected.trianglepath.dotted", @"gearshape.2", @"stethoscope"];
    UITableViewCell *cell = IFAVCell(tableView, @"IFAdvancedMenu", titles[indexPath.row], details[indexPath.row]);
    cell.imageView.image = [UIImage systemImageNamed:symbols[indexPath.row]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *classes = @[
        [IFInjectionMapViewController class],
        [IFLaunchDaemonsViewController class],
        [IFDiagnosticModeViewController class]
    ];
    UIViewController *controller = [[classes[indexPath.row] alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
