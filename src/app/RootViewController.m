#import "RootViewController.h"
#import "../core/IFetchCore.h"
#import "../core/IFDiagnostics.h"
#import "../core/IFAdvancedDiagnostics.h"
#import "DiagnosticsViewController.h"
#import "IFAdvancedViewControllers.h"

#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

typedef NS_ENUM(NSInteger, IFTab) {
    IFTabOverview = 0,
    IFTabSystem = 1,
    IFTabTools = 2
};

static NSString *IFT(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static NSString *IFTSnapshotDate(NSString *value) {
    if (value.length == 0) {
        return @"—";
    }
    NSDateFormatter *source = [[NSDateFormatter alloc] init];
    source.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    source.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    source.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSDate *date = [source dateFromString:value];
    if (date == nil) {
        return value;
    }
    NSDateFormatter *display = [[NSDateFormatter alloc] init];
    display.locale = [NSLocale localeWithLocaleIdentifier:[IFLanguageManager isRussian] ? @"ru_RU" : @"en_US"];
    display.dateStyle = NSDateFormatterMediumStyle;
    display.timeStyle = NSDateFormatterShortStyle;
    return [display stringFromDate:date];
}

@interface RootViewController ()

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, assign) IFTab selectedTab;
@property (nonatomic, strong) IFDeviceInfo *device;
@property (nonatomic, strong) IFJailbreakInfo *jailbreak;
@property (nonatomic, strong) IFProcessMonitor *processMonitor;
@property (nonatomic, strong) IFNetworkMonitor *networkMonitor;
@property (nonatomic, strong) IFNetworkSnapshot *networkSnapshot;
@property (nonatomic, strong) IFLiveMetricsMonitor *alertMonitor;
@property (nonatomic, copy) NSString *publicIPAddress;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) NSUInteger refreshTick;

@end

@implementation RootViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"iFetch";
    self.device = [IFDeviceInfo currentDevice];
    self.jailbreak = [IFetchCore jailbreakInfo];
    self.processMonitor = [[IFProcessMonitor alloc] init];
    self.networkMonitor = [[IFNetworkMonitor alloc] init];
    self.alertMonitor = [[IFLiveMetricsMonitor alloc] init];
    self.networkSnapshot = [self.networkMonitor refresh];
    self.publicIPAddress = IFT(@"Loading…", @"Загрузка…");

    self.tableView.rowHeight = 52;
    self.tableView.estimatedRowHeight = 52;
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
    [self setupHeader];
    [self fetchPublicIPAddress];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"waveform.path.ecg"]
                                                                             style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(showDiagnostics:)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = IFT(@"Diagnostics", @"Диагностика");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopLiveUpdates:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startLiveUpdates:)
                                                 name:UIApplicationWillEnterForegroundNotification object:nil];
    [self startLiveUpdates:nil];
}

- (void)dealloc {
    [self.refreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.device = [IFDeviceInfo currentDevice];
    self.jailbreak = [IFetchCore jailbreakInfo];
    [self.tableView reloadData];
}

- (void)startLiveUpdates:(__unused id)sender {
    if (self.refreshTimer != nil) {
        return;
    }
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(refreshLiveData:)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopLiveUpdates:(__unused id)sender {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)showDiagnostics:(__unused id)sender {
    [self.navigationController pushViewController:[[IFDiagnosticsViewController alloc] init] animated:YES];
}

- (void)openDeepLink:(NSURL *)url {
    NSString *destination = url.host.lowercaseString;
    [self.navigationController popToRootViewControllerAnimated:NO];
    if ([destination isEqualToString:@"overview"]) {
        self.selectedTab = IFTabOverview;
        self.segmentedControl.selectedSegmentIndex = IFTabOverview;
        [self.tableView reloadData];
    } else if ([destination isEqualToString:@"advanced"]) {
        [self.navigationController pushViewController:[[IFAdvancedMenuViewController alloc] init] animated:YES];
    } else {
        [self showDiagnostics:nil];
    }
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 56)];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[
        IFT(@"Overview", @"Сводка"),
        IFT(@"System", @"Система"),
        IFT(@"Tools", @"Утилиты")
    ]];
    self.segmentedControl.selectedSegmentIndex = self.selectedTab;
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [header addSubview:self.segmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
        [self.segmentedControl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:32]
    ]];
    self.tableView.tableHeaderView = header;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.selectedTab = (IFTab)sender.selectedSegmentIndex;
    [self.tableView reloadData];
    [self.tableView setContentOffset:CGPointMake(0, -self.tableView.adjustedContentInset.top) animated:NO];
}

- (void)refreshLiveData:(NSTimer *)timer {
    (void)timer;
    self.networkSnapshot = [self.networkMonitor refresh];
    self.refreshTick++;
    if (self.refreshTick % 2 == 0) {
        [self.processMonitor refresh];
    }
    if (self.refreshTick % 15 == 0 && [IFAdvancedDiagnostics alertsEnabled]) {
        [self.alertMonitor refresh];
        [IFAdvancedDiagnostics evaluateAlertsWithMonitor:self.alertMonitor];
    }
    if (self.selectedTab == IFTabSystem) {
        [self.tableView reloadData];
    }
}

- (void)fetchPublicIPAddress {
    __weak typeof(self) weakSelf = self;
    [IFNetworkMonitor fetchPublicIPAddressWithCompletion:^(NSString *address) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.publicIPAddress = address;
            if (weakSelf.selectedTab == IFTabSystem) {
                [weakSelf.tableView reloadData];
            }
        });
    }];
}

#pragma mark - Table structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    switch (self.selectedTab) {
        case IFTabOverview: return 4;
        case IFTabSystem: return 6;
        case IFTabTools: return 4;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (self.selectedTab == IFTabOverview) {
        return section == 0 || section == 3 ? 1 : 3;
    }
    if (self.selectedTab == IFTabSystem) {
        switch (section) {
            case 0: return 6;
            case 1: return 3;
            case 2: return 7;
            case 3: return MAX(1, [self.processMonitor topProcessesByMemory:3].count);
            case 4: return MAX(1, [self.processMonitor topProcessesByCPU:3].count);
            case 5: return 4;
            default: return 0;
        }
    }
    switch (section) {
        case 0: return 2;
        case 1: return 2;
        case 2: return 2;
        case 3: return 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (self.selectedTab == IFTabOverview) {
        return @[
            IFT(@"Device", @"Устройство"),
            IFT(@"System resources", @"Ресурсы системы"),
            IFT(@"Jailbreak status", @"Состояние jailbreak"),
            IFT(@"System snapshots", @"Снимки системы")
        ][(NSUInteger)section];
    }
    if (self.selectedTab == IFTabSystem) {
        return @[
            IFT(@"Hardware", @"Аппаратная часть"),
            IFT(@"Battery", @"Батарея"),
            IFT(@"Live network", @"Сеть в реальном времени"),
            IFT(@"Top-3 by memory", @"Top-3 по оперативной памяти"),
            IFT(@"Top-3 by CPU", @"Top-3 по CPU"),
            IFT(@"Jailbreak environment", @"Среда jailbreak")
        ][(NSUInteger)section];
    }
    return @[
        IFT(@"Settings", @"Настройки"),
        IFT(@"System actions", @"Системные действия"),
        IFT(@"Confirmation required", @"Требуют подтверждения"),
        IFT(@"Export", @"Экспорт")
    ][(NSUInteger)section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (self.selectedTab == IFTabSystem && section == 2) {
        return IFT(@"The public IP is requested from api.ipify.org. Transfer speed is calculated across active network interfaces.",
                   @"Публичный IP запрашивается у api.ipify.org. Скорость считается по активным сетевым интерфейсам.");
    }
    if (self.selectedTab == IFTabSystem && section == 5 && self.jailbreak.recentCrashCount > 0) {
        return IFT(@"Crash logs modified within the last 24 hours were found.",
                   @"Найдены crash-логи, изменённые за последние 24 часа.");
    }
    if (self.selectedTab == IFTabTools && section == 2) {
        return IFT(@"Safe Mode terminates SpringBoard; Userspace Reboot restarts the user environment.",
                   @"Safe Mode аварийно завершает SpringBoard; Userspace Reboot перезапускает пользовательское окружение.");
    }
    return nil;
}

- (UITableViewCell *)standardCellWithTitle:(NSString *)title value:(NSString *)value {
    static NSString *identifier = @"ValueCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        cell.detailTextLabel.minimumScaleFactor = 0.7;
    }
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.textAlignment = NSTextAlignmentNatural;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = nil;
    return cell;
}

- (UITableViewCell *)deviceCell {
    static NSString *identifier = @"DeviceCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.clipsToBounds = YES;
    }
    cell.textLabel.text = self.device.modelName;
    cell.textLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@ · %@", [UIDevice currentDevice].systemVersion, self.jailbreak.environmentName];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = [UIImage imageNamed:self.device.imageName] ?: [UIImage imageNamed:@"DevicePhotos/iphone-generic.png"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)processCellForSample:(IFProcessSample *)sample metric:(NSString *)metric {
    UITableViewCell *cell = [self standardCellWithTitle:sample.name value:@""];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    if ([metric isEqualToString:@"cpu"]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%% · %@", sample.cpuPercent,
                                     [IFetchCore formatBytes:sample.residentBytes]];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %.1f%%",
                                     [IFetchCore formatBytes:sample.residentBytes], sample.cpuPercent];
    }
    return cell;
}

- (UITableViewCell *)actionCellWithTitle:(NSString *)title color:(UIColor *)color {
    UITableViewCell *cell = [self standardCellWithTitle:title value:@""];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = color;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (self.selectedTab == IFTabOverview) {
        return [self overviewCellAtIndexPath:indexPath];
    }
    if (self.selectedTab == IFTabSystem) {
        return [self systemCellAtIndexPath:indexPath];
    }
    return [self toolsCellAtIndexPath:indexPath];
}

- (UITableViewCell *)overviewCellAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return [self deviceCell];
    }

    if (indexPath.section == 1) {
        NSNumber *usedMemory = [IFetchCore usedMemoryBytes];
        NSNumber *totalStorage = [IFetchCore totalStorageBytes];
        NSNumber *usedStorage = [IFetchCore usedStorageBytes];
        NSArray *rows = @[
            @[IFT(@"Memory", @"Оперативная память"), usedMemory ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedMemory.unsignedLongLongValue], [IFetchCore formatBytes:[IFetchCore totalMemoryBytes]]] : IFT(@"Unavailable", @"Недоступно")],
            @[IFT(@"Storage", @"Накопитель"), (usedStorage && totalStorage) ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedStorage.unsignedLongLongValue], [IFetchCore formatBytes:totalStorage.unsignedLongLongValue]] : IFT(@"Unavailable", @"Недоступно")],
            @[IFT(@"Uptime", @"Аптайм"), [IFetchCore systemUptime]]
        ];
        UITableViewCell *cell = [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                                     value:rows[(NSUInteger)indexPath.row][1]];
        NSArray *symbols = @[@"memorychip", @"internaldrive", @"clock"];
        NSArray *colors = @[UIColor.systemPurpleColor, UIColor.systemBlueColor, UIColor.systemGreenColor];
        cell.imageView.image = [UIImage systemImageNamed:symbols[(NSUInteger)indexPath.row]];
        cell.imageView.tintColor = colors[(NSUInteger)indexPath.row];
        return cell;
    }

    if (indexPath.section == 3) {
        NSArray<NSDictionary<NSString *, id> *> *snapshots = [IFAdvancedDiagnostics systemSnapshots];
        NSDictionary *latest = snapshots.firstObject;
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"IFSnapshotSummary"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:@"IFSnapshotSummary"];
        }
        cell.textLabel.text = snapshots.count > 0
            ? [NSString stringWithFormat:IFT(@"%lu snapshots", @"Снимков: %lu"), (unsigned long)snapshots.count]
            : IFT(@"No snapshots yet", @"Снимков пока нет");
        cell.detailTextLabel.text = latest != nil
            ? [NSString stringWithFormat:IFT(@"Latest: %@ · Tap to view or compare",
                                             @"Последний: %@ · Нажмите для просмотра или сравнения"),
               IFTSnapshotDate(latest[@"createdAt"])]
            : IFT(@"Create snapshots and compare system changes",
                  @"Создавайте снимки и сравнивайте изменения системы");
        cell.detailTextLabel.numberOfLines = 2;
        cell.imageView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
        cell.imageView.tintColor = UIColor.systemIndigoColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    NSArray *rows = @[
        @[IFT(@"Installed packages", @"Установлено пакетов"), [NSString stringWithFormat:@"%ld", (long)self.jailbreak.installedPackageCount]],
        @[IFT(@"Active tweaks", @"Активные твики"), [NSString stringWithFormat:@"%ld", (long)self.jailbreak.activeTweakCount]],
        @[IFT(@"Hook injector", @"Хук-инжектор"), self.jailbreak.injectorDescription]
    ];
    UITableViewCell *cell = [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                                 value:rows[(NSUInteger)indexPath.row][1]];
    NSArray *symbols = @[@"shippingbox.fill", @"puzzlepiece.extension.fill",
                         @"point.3.connected.trianglepath.dotted"];
    NSArray *colors = @[UIColor.systemTealColor, UIColor.systemOrangeColor, UIColor.systemPinkColor];
    cell.imageView.image = [UIImage systemImageNamed:symbols[(NSUInteger)indexPath.row]];
    cell.imageView.tintColor = colors[(NSUInteger)indexPath.row];
    return cell;
}

- (UITableViewCell *)systemCellAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSArray *rows = @[
            @[IFT(@"Model", @"Модель"), self.device.modelName],
            @[IFT(@"Identifier", @"Идентификатор"), self.device.identifier],
            @[IFT(@"Chip", @"Чип"), self.device.chipName],
            @[IFT(@"Architecture", @"Архитектура"), self.device.architectureName],
            @[IFT(@"Darwin kernel", @"Ядро Darwin"), [IFetchCore darwinVersion]],
            @[IFT(@"Thermal state", @"Температура"), [self thermalStateDescription]]
        ];
        return [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                    value:rows[(NSUInteger)indexPath.row][1]];
    }

    if (indexPath.section == 1) {
        UIDevice *device = [UIDevice currentDevice];
        device.batteryMonitoringEnabled = YES;
        NSString *level = device.batteryLevel >= 0
            ? [NSString stringWithFormat:@"%.0f%%", device.batteryLevel * 100]
            : IFT(@"Unavailable", @"Недоступно");
        NSDictionary *states = @{
            @(UIDeviceBatteryStateUnknown): IFT(@"Unknown", @"Неизвестно"),
            @(UIDeviceBatteryStateUnplugged): IFT(@"Unplugged", @"Отключена"),
            @(UIDeviceBatteryStateCharging): IFT(@"Charging", @"Заряжается"),
            @(UIDeviceBatteryStateFull): IFT(@"Full", @"Заряжена")
        };
        NSArray *rows = @[
            @[IFT(@"Charge level", @"Уровень заряда"), level],
            @[IFT(@"Status", @"Статус"), states[@(device.batteryState)] ?: IFT(@"Unknown", @"Неизвестно")],
            @[IFT(@"Cycles", @"Циклы"), [IFetchCore batteryCycleCount] ?: IFT(@"Unavailable", @"Недоступно")]
        ];
        return [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                    value:rows[(NSUInteger)indexPath.row][1]];
    }

    if (indexPath.section == 2) {
        NSString *dns = self.networkSnapshot.dnsServers.count > 0
            ? [self.networkSnapshot.dnsServers componentsJoinedByString:@", "]
            : IFT(@"Unavailable", @"Недоступно");
        NSArray *rows = @[
            @[IFT(@"Download", @"Скачивание"), [IFetchCore formatRate:self.networkSnapshot.downloadBytesPerSecond]],
            @[IFT(@"Upload", @"Отдача"), [IFetchCore formatRate:self.networkSnapshot.uploadBytesPerSecond]],
            @[IFT(@"Local IP", @"Локальный IP"), self.networkSnapshot.localIPAddress],
            @[IFT(@"Public IP", @"Публичный IP"), self.publicIPAddress],
            @[IFT(@"Interface", @"Интерфейс"), self.networkSnapshot.activeInterface],
            @[@"VPN", self.networkSnapshot.vpnInterface],
            @[@"DNS", dns]
        ];
        return [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                    value:rows[(NSUInteger)indexPath.row][1]];
    }

    if (indexPath.section == 3 || indexPath.section == 4) {
        BOOL cpu = indexPath.section == 4;
        NSArray<IFProcessSample *> *samples = cpu
            ? [self.processMonitor topProcessesByCPU:3]
            : [self.processMonitor topProcessesByMemory:3];
        if (samples.count == 0) {
            return [self standardCellWithTitle:IFT(@"Unavailable", @"Недоступно") value:@"proc_pidinfo"];
        }
        return [self processCellForSample:samples[(NSUInteger)indexPath.row] metric:cpu ? @"cpu" : @"memory"];
    }

    NSString *crashes = self.jailbreak.recentCrashCount > 0
        ? [NSString stringWithFormat:IFT(@"%ld new", @"%ld новых"), (long)self.jailbreak.recentCrashCount]
        : IFT(@"No new logs", @"Нет новых");
    NSArray *rows = @[
        @[IFT(@"Environment", @"Окружение"), self.jailbreak.environmentName],
        @[IFT(@"Root", @"Корень"), self.jailbreak.rootPrefix.length > 0 ? self.jailbreak.rootPrefix : @"/"],
        @[IFT(@"Hook injector", @"Хук-инжектор"), self.jailbreak.injectorDescription],
        @[IFT(@"Crash logs (24h)", @"Crash-логи (24ч)"), crashes]
    ];
    UITableViewCell *cell = [self standardCellWithTitle:rows[(NSUInteger)indexPath.row][0]
                                                 value:rows[(NSUInteger)indexPath.row][1]];
    if (indexPath.row == 3 && self.jailbreak.recentCrashCount > 0) {
        cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
    }
    return cell;
}

- (UITableViewCell *)toolsCellAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSArray *titles = @[
            IFT(@"Language", @"Язык"),
            IFT(@"Notifications", @"Уведомления")
        ];
        NSArray *values = @[
            [IFLanguageManager isRussian] ? @"Русский" : @"English",
            IFT(@"Configure", @"Настроить")
        ];
        UITableViewCell *cell = [self standardCellWithTitle:titles[(NSUInteger)indexPath.row]
                                                     value:values[(NSUInteger)indexPath.row]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.imageView.image = [UIImage systemImageNamed:indexPath.row == 0
            ? @"globe" : @"bell.badge"];
        return cell;
    }
    if (indexPath.section == 1) {
        return [self actionCellWithTitle:indexPath.row == 0 ? @"Respring" : IFT(@"Refresh icon cache", @"Обновить кэш иконок")
                                  color:[UIColor systemBlueColor]];
    }
    if (indexPath.section == 2) {
        return [self actionCellWithTitle:indexPath.row == 0 ? IFT(@"Enter Safe Mode", @"Войти в Safe Mode") : @"Userspace Reboot"
                                  color:indexPath.row == 0 ? [UIColor systemOrangeColor] : [UIColor systemRedColor]];
    }
    return [self actionCellWithTitle:IFT(@"Copy system report", @"Скопировать системный отчёт")
                              color:[UIColor systemBlueColor]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (self.selectedTab == IFTabOverview && indexPath.section == 0) {
        return 88;
    }
    return self.selectedTab == IFTabOverview && indexPath.section == 3 ? 68 : 52;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.selectedTab == IFTabOverview && indexPath.section == 3) {
        [self.navigationController pushViewController:[[IFSnapshotsViewController alloc] init]
                                             animated:YES];
        return;
    }
    if (self.selectedTab != IFTabTools) {
        return;
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self showLanguagePicker];
        } else {
            [self.navigationController pushViewController:[[IFPreferencesViewController alloc] init]
                                                 animated:YES];
        }
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        [self confirmActionWithTitle:IFT(@"Perform Respring?", @"Выполнить Respring?")
                             message:IFT(@"SpringBoard will be restarted.", @"SpringBoard будет перезапущен.")
                             command:@"sbreload"
                           arguments:@[]];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [self runCommand:@"uicache"
               arguments:@[@"-a", @"-r"]
          successMessage:IFT(@"The icon cache has been refreshed", @"Кэш иконок обновлён")];
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        [self confirmActionWithTitle:IFT(@"Enter Safe Mode?", @"Войти в Safe Mode?")
                             message:IFT(@"SpringBoard will be terminated with a SEGV signal.",
                                         @"SpringBoard будет аварийно завершён сигналом SEGV.")
                             command:@"killall"
                           arguments:@[@"-SEGV", @"SpringBoard"]];
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        [self confirmActionWithTitle:IFT(@"Perform Userspace Reboot?", @"Выполнить Userspace Reboot?")
                             message:IFT(@"All apps will close and the user environment will restart.",
                                         @"Все приложения закроются, пользовательское окружение будет перезапущено.")
                             command:@"launchctl"
                           arguments:@[@"reboot", @"userspace"]];
    } else if (indexPath.section == 3) {
        [self showExportOptions];
    }
}

#pragma mark - Actions

- (void)showLanguagePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:IFT(@"Language", @"Язык")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"English" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [IFLanguageManager setCurrentLanguage:IFLanguageEnglish];
        [weakSelf applySelectedLanguage];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Русский" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [IFLanguageManager setCurrentLanguage:IFLanguageRussian];
        [weakSelf applySelectedLanguage];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:IFT(@"Cancel", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 1, 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applySelectedLanguage {
    [self.segmentedControl setTitle:IFT(@"Overview", @"Сводка") forSegmentAtIndex:0];
    [self.segmentedControl setTitle:IFT(@"System", @"Система") forSegmentAtIndex:1];
    [self.segmentedControl setTitle:IFT(@"Tools", @"Утилиты") forSegmentAtIndex:2];
    self.device = [IFDeviceInfo currentDevice];
    self.jailbreak = [IFetchCore jailbreakInfo];
    self.networkSnapshot = [self.networkMonitor refresh];
    self.publicIPAddress = IFT(@"Loading…", @"Загрузка…");
    [self.tableView reloadData];
    [self fetchPublicIPAddress];
}

- (NSString *)thermalStateDescription {
    switch ([NSProcessInfo processInfo].thermalState) {
        case NSProcessInfoThermalStateNominal: return IFT(@"Nominal", @"Норма");
        case NSProcessInfoThermalStateFair: return IFT(@"Fair", @"Повышена");
        case NSProcessInfoThermalStateSerious: return IFT(@"Serious", @"Высокая");
        case NSProcessInfoThermalStateCritical: return IFT(@"Critical", @"Критическая");
    }
    return IFT(@"Unavailable", @"Недоступно");
}

- (NSArray<NSString *> *)pathsForCommand:(NSString *)command {
    return @[
        [@"/var/jb/usr/bin" stringByAppendingPathComponent:command],
        [@"/var/jb/usr/sbin" stringByAppendingPathComponent:command],
        [@"/usr/bin" stringByAppendingPathComponent:command],
        [@"/usr/sbin" stringByAppendingPathComponent:command],
        [@"/bin" stringByAppendingPathComponent:command],
        [@"/sbin" stringByAppendingPathComponent:command]
    ];
}

- (void)confirmActionWithTitle:(NSString *)title
                       message:(NSString *)message
                       command:(NSString *)command
                     arguments:(NSArray<NSString *> *)arguments {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:IFT(@"Cancel", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:IFT(@"Continue", @"Продолжить") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf runCommand:command arguments:arguments successMessage:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)runCommand:(NSString *)command
         arguments:(NSArray<NSString *> *)arguments
     successMessage:(NSString *)successMessage {
    NSString *path = [IFetchCore executablePathForCandidates:[self pathsForCommand:command]];
    if (path == nil) {
        [self showMessage:[NSString stringWithFormat:IFT(@"Command %@ was not found", @"Команда %@ не найдена"), command]];
        return;
    }

    NSMutableArray<NSString *> *allArguments = [NSMutableArray arrayWithObject:command];
    [allArguments addObjectsFromArray:arguments];
    char **argv = calloc(allArguments.count + 1, sizeof(char *));
    if (argv == NULL) {
        [self showMessage:IFT(@"Unable to allocate memory for the command", @"Не удалось выделить память для запуска команды")];
        return;
    }
    for (NSUInteger index = 0; index < allArguments.count; index++) {
        argv[index] = (char *)[allArguments[index] UTF8String];
    }

    pid_t pid = 0;
    int result = posix_spawn(&pid, path.fileSystemRepresentation, NULL, NULL, argv, environ);
    free(argv);
    if (result != 0) {
        [self showMessage:[NSString stringWithFormat:IFT(@"Unable to start %@: %s", @"Ошибка запуска %@: %s"), command, strerror(result)]];
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int status = 0;
        pid_t waited = waitpid(pid, &status, 0);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (waited < 0) {
                [weakSelf showMessage:[NSString stringWithFormat:IFT(@"Unable to read the result of %@", @"Не удалось получить результат команды %@"), command]];
            } else if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
                [weakSelf showMessage:[NSString stringWithFormat:IFT(@"%@ exited with code %d", @"%@ завершилась с кодом %d"), command, WEXITSTATUS(status)]];
            } else if (WIFSIGNALED(status)) {
                [weakSelf showMessage:[NSString stringWithFormat:IFT(@"%@ was terminated by signal %d", @"%@ завершилась по сигналу %d"), command, WTERMSIG(status)]];
            } else if (successMessage.length > 0) {
                [weakSelf showMessage:successMessage];
            }
        });
    });
}

- (void)showExportOptions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:IFT(@"System report", @"Системный отчёт")
                                                                   message:IFT(@"Choose whether network addresses should be hidden.",
                                                                               @"Выберите, нужно ли скрыть сетевые адреса.")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:IFT(@"Copy private report", @"Копировать приватный отчёт")
                                             style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf copyReportRedacted:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:IFT(@"Copy full report", @"Копировать полный отчёт")
                                             style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf copyReportRedacted:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:IFT(@"Cancel", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)copyReportRedacted:(BOOL)redacted {
    NSNumber *usedMemory = [IFetchCore usedMemoryBytes];
    NSNumber *usedStorage = [IFetchCore usedStorageBytes];
    NSString *reportFormat = IFT(
        @"iFetch %@\n"
         "Device: %@ (%@)\n"
         "iOS: %@\n"
         "Architecture: %@\n"
         "Kernel: %@\n"
         "Uptime: %@\n"
         "Memory used: %@\n"
         "Storage used: %@\n"
         "Jailbreak: %@\n"
         "Hook injector: %@\n"
         "Packages: %ld\n"
         "Active tweaks: %ld\n"
         "New crash logs: %ld\n"
         "Local IP: %@\n"
         "Public IP: %@",
        @"iFetch %@\n"
         "Устройство: %@ (%@)\n"
         "iOS: %@\n"
         "Архитектура: %@\n"
         "Ядро: %@\n"
         "Аптайм: %@\n"
         "ОЗУ занято: %@\n"
         "Диск занято: %@\n"
         "Jailbreak: %@\n"
         "Хук-инжектор: %@\n"
         "Пакеты: %ld\n"
         "Активные твики: %ld\n"
         "Новые crash-логи: %ld\n"
         "Локальный IP: %@\n"
         "Публичный IP: %@");
    NSString *report = [NSString stringWithFormat:reportFormat,
         [IFetchCore versionString],
         self.device.modelName, self.device.identifier,
         [UIDevice currentDevice].systemVersion,
         self.device.architectureName,
         [IFetchCore darwinVersion],
         [IFetchCore systemUptime],
         usedMemory ? [IFetchCore formatBytes:usedMemory.unsignedLongLongValue] : IFT(@"Unavailable", @"Недоступно"),
         usedStorage ? [IFetchCore formatBytes:usedStorage.unsignedLongLongValue] : IFT(@"Unavailable", @"Недоступно"),
         self.jailbreak.environmentName,
         self.jailbreak.injectorDescription,
         (long)self.jailbreak.installedPackageCount,
         (long)self.jailbreak.activeTweakCount,
         (long)self.jailbreak.recentCrashCount,
         redacted ? [IFDiagnostics redactedAddress:self.networkSnapshot.localIPAddress] : self.networkSnapshot.localIPAddress,
         redacted ? [IFDiagnostics redactedAddress:self.publicIPAddress] : self.publicIPAddress];
    [UIPasteboard generalPasteboard].string = report;
    [self showMessage:IFT(@"System report copied", @"Системный отчёт скопирован")];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"iFetch"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
