#import "DiagnosticsViewController.h"

#import "../core/IFDiagnostics.h"
#import "../core/IFAdvancedDiagnostics.h"
#import "../core/IFetchCore.h"
#import "IFAdvancedViewControllers.h"
#import <CoreLocation/CoreLocation.h>
#import <errno.h>
#import <objc/runtime.h>
#import <signal.h>
#import <string.h>

static NSString *IFUI(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static const void *IFCrashLogShareKey = &IFCrashLogShareKey;

static UITableViewCell *IFValueCell(UITableView *tableView, NSString *title, NSString *detail) {
    static NSString *identifier = @"IFDiagnosticValue";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.imageView.image = nil;
    return cell;
}

@interface IFLineChartView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@property (nonatomic, strong) UIColor *lineColor;
@property (nonatomic, assign) double fixedMaximum;
@property (nonatomic, copy) NSString *unit;
@property (nonatomic, assign) BOOL rateValues;
@end

@implementation IFLineChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _lineColor = UIColor.systemBlueColor;
        self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 16;
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setValues:(NSArray<NSNumber *> *)values {
    _values = [values copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL) {
        return;
    }
    CGRect plot = CGRectMake(44, 12, MAX(1, CGRectGetWidth(rect) - 56), MAX(1, CGRectGetHeight(rect) - 34));
    double maximum = self.fixedMaximum;
    if (maximum <= 0) {
        for (NSNumber *number in self.values) {
            maximum = MAX(maximum, number.doubleValue);
        }
        maximum = MAX(1.0, maximum * 1.15);
    }
    CGContextSetStrokeColorWithColor(context, [UIColor separatorColor].CGColor);
    CGContextSetLineWidth(context, 0.5);
    NSDictionary *axisAttributes = @{
        NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:8 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: UIColor.tertiaryLabelColor
    };
    for (NSInteger row = 0; row <= 3; row++) {
        CGFloat y = CGRectGetMinY(plot) + CGRectGetHeight(plot) * row / 3.0;
        CGContextMoveToPoint(context, CGRectGetMinX(plot), y);
        CGContextAddLineToPoint(context, CGRectGetMaxX(plot), y);
        double axisValue = maximum * (1.0 - row / 3.0);
        NSString *axisText = self.rateValues ? [IFetchCore formatRate:axisValue]
            : [NSString stringWithFormat:@"%.0f%@", axisValue, self.unit ?: @""];
        [axisText drawInRect:CGRectMake(4, y - 6, 38, 12) withAttributes:axisAttributes];
    }
    CGContextStrokePath(context);
    if (self.values.count < 2) {
        NSString *empty = IFUI(@"Collecting data…", @"Сбор данных…");
        CGSize size = [empty sizeWithAttributes:axisAttributes];
        [empty drawAtPoint:CGPointMake(CGRectGetMidX(plot) - size.width / 2,
                                       CGRectGetMidY(plot) - size.height / 2)
            withAttributes:axisAttributes];
        return;
    }
    UIBezierPath *path = [UIBezierPath bezierPath];
    [self.values enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger index, __unused BOOL *stop) {
        CGFloat x = CGRectGetMinX(plot) + CGRectGetWidth(plot) * index / MAX((NSUInteger)1, self.values.count - 1);
        CGFloat y = CGRectGetMinY(plot) + CGRectGetHeight(plot) *
            (1.0 - MIN(1.0, MAX(0.0, value.doubleValue / maximum)));
        if (index == 0) {
            [path moveToPoint:CGPointMake(x, y)];
        } else {
            [path addLineToPoint:CGPointMake(x, y)];
        }
    }];
    UIBezierPath *fill = [path copy];
    [fill addLineToPoint:CGPointMake(CGRectGetMaxX(plot), CGRectGetMaxY(plot))];
    [fill addLineToPoint:CGPointMake(CGRectGetMinX(plot), CGRectGetMaxY(plot))];
    [fill closePath];
    [[self.lineColor colorWithAlphaComponent:0.14] setFill];
    [fill fill];
    path.lineWidth = 2.0;
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineCapStyle = kCGLineCapRound;
    [self.lineColor setStroke];
    [path stroke];
    NSNumber *last = self.values.lastObject;
    CGFloat lastX = CGRectGetMaxX(plot);
    CGFloat lastY = CGRectGetMinY(plot) + CGRectGetHeight(plot) *
        (1.0 - MIN(1.0, MAX(0.0, last.doubleValue / maximum)));
    CGContextSetFillColorWithColor(context, self.lineColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(lastX - 3.5, lastY - 3.5, 7, 7));
}

@end

@interface IFChartsViewController : UIViewController
@property (nonatomic, strong) IFLiveMetricsMonitor *monitor;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSArray<IFLineChartView *> *charts;
@property (nonatomic, strong) NSArray<UILabel *> *valueLabels;
@end

@implementation IFChartsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Live charts", @"Графики");
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.monitor = [[IFLiveMetricsMonitor alloc] init];
    UIScrollView *scroll = [[UIScrollView alloc] init];
    UIStackView *stack = [[UIStackView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    [self.view addSubview:scroll];
    [scroll addSubview:stack];

    NSArray *titles = @[
        IFUI(@"CPU usage", @"Загрузка CPU"),
        IFUI(@"Memory usage", @"Использование ОЗУ"),
        IFUI(@"Download speed", @"Скорость скачивания"),
        IFUI(@"Upload speed", @"Скорость отдачи"),
        IFUI(@"Battery temperature", @"Температура батареи"),
        IFUI(@"Battery level", @"Уровень заряда")
    ];
    NSArray *colors = @[UIColor.systemOrangeColor, UIColor.systemPurpleColor,
                        UIColor.systemBlueColor, UIColor.systemTealColor,
                        UIColor.systemRedColor, UIColor.systemGreenColor];
    NSMutableArray *charts = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    for (NSUInteger index = 0; index < titles.count; index++) {
        UILabel *title = [[UILabel alloc] init];
        title.text = titles[index];
        title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        UILabel *value = [[UILabel alloc] init];
        value.textColor = UIColor.secondaryLabelColor;
        value.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
        IFLineChartView *chart = [[IFLineChartView alloc] init];
        chart.lineColor = colors[index];
        chart.fixedMaximum = (index < 2 || index == 5) ? 100 : (index == 4 ? 60 : 0);
        chart.unit = (index < 2 || index == 5) ? @"%" : (index == 4 ? @"°" : @"");
        chart.rateValues = index == 2 || index == 3;
        chart.translatesAutoresizingMaskIntoConstraints = NO;
        [chart.heightAnchor constraintEqualToConstant:120].active = YES;
        [stack addArrangedSubview:title];
        [stack addArrangedSubview:value];
        [stack addArrangedSubview:chart];
        [charts addObject:chart];
        [labels addObject:value];
    }
    self.charts = charts;
    self.valueLabels = labels;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)refresh:(__unused NSTimer *)timer {
    [self.monitor refresh];
    NSArray<IFMetricSample *> *history = self.monitor.history;
    self.charts[0].values = [history valueForKey:@"cpuPercent"];
    self.charts[1].values = [history valueForKey:@"memoryPercent"];
    self.charts[2].values = [history valueForKey:@"downloadBytesPerSecond"];
    self.charts[3].values = [history valueForKey:@"uploadBytesPerSecond"];
    self.charts[4].values = [history valueForKey:@"batteryTemperature"];
    self.charts[5].values = [history valueForKey:@"batteryLevel"];
    IFMetricSample *latest = history.lastObject;
    if (latest == nil) {
        return;
    }
    self.valueLabels[0].text = [NSString stringWithFormat:@"%.1f%%", latest.cpuPercent];
    self.valueLabels[1].text = [NSString stringWithFormat:@"%.1f%%", latest.memoryPercent];
    self.valueLabels[2].text = [NSString stringWithFormat:@"↓ %@",
                                [IFetchCore formatRate:latest.downloadBytesPerSecond]];
    self.valueLabels[3].text = [NSString stringWithFormat:@"↑ %@",
                                [IFetchCore formatRate:latest.uploadBytesPerSecond]];
    self.valueLabels[4].text = latest.batteryTemperature > 0
        ? [NSString stringWithFormat:@"%.1f °C", latest.batteryTemperature] : IFUI(@"Unavailable", @"Недоступно");
    self.valueLabels[5].text = latest.batteryLevel > 0
        ? [NSString stringWithFormat:@"%.0f%%", latest.batteryLevel] : IFUI(@"Unavailable", @"Недоступно");
}

@end

@interface IFBatteryViewController : UITableViewController
@property (nonatomic, strong) IFBatteryDetails *battery;
@property (nonatomic, strong) NSDate *lastUpdated;
@end

@implementation IFBatteryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Battery diagnostics", @"Диагностика батареи");
    self.battery = [IFDiagnostics batteryDetails];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                          target:self action:@selector(refresh:)];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh:nil];
}

- (void)refresh:(__unused id)sender {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.battery = [IFDiagnostics batteryDetails];
    self.lastUpdated = NSDate.date;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForFooterInSection:(__unused NSInteger)section {
    if (self.lastUpdated == nil) {
        return nil;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterMediumStyle;
    return [NSString stringWithFormat:IFUI(@"Updated %@", @"Обновлено %@"),
            [formatter stringFromDate:self.lastUpdated]];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return 9;
}

- (NSString *)value:(NSNumber *)number suffix:(NSString *)suffix {
    return number ? [NSString stringWithFormat:@"%.1f%@", number.doubleValue, suffix] : IFUI(@"Unavailable", @"Недоступно");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *rows = @[
        @[IFUI(@"Health", @"Здоровье"), self.battery.healthPercent > 0 ? [NSString stringWithFormat:@"%.0f%%", self.battery.healthPercent] : IFUI(@"Unavailable", @"Недоступно")],
        @[IFUI(@"Current capacity", @"Текущая ёмкость"), [self value:self.battery.currentCapacity suffix:@" mAh"]],
        @[IFUI(@"Maximum capacity", @"Максимальная ёмкость"), [self value:self.battery.maximumCapacity suffix:@" mAh"]],
        @[IFUI(@"Design capacity", @"Проектная ёмкость"), [self value:self.battery.designCapacity suffix:@" mAh"]],
        @[IFUI(@"Cycles", @"Циклы"), self.battery.cycleCount.stringValue ?: IFUI(@"Unavailable", @"Недоступно")],
        @[IFUI(@"Temperature", @"Температура"), [self value:self.battery.temperatureCelsius suffix:@" °C"]],
        @[IFUI(@"Voltage", @"Напряжение"), [self value:self.battery.voltageMillivolts suffix:@" mV"]],
        @[IFUI(@"Current", @"Ток"), [self value:self.battery.amperageMilliamps suffix:@" mA"]],
        @[IFUI(@"Charging power", @"Мощность зарядки"), self.battery.externalConnected ? [NSString stringWithFormat:@"%.1f W%@", self.battery.chargingWatts, self.battery.chargingWatts >= 15 ? @" · Fast" : @""] : IFUI(@"Not connected", @"Не подключена")]
    ];
    return IFValueCell(tableView, rows[indexPath.row][0], rows[indexPath.row][1]);
}

@end

@interface IFProcessesViewController : UITableViewController
@property (nonatomic, strong) IFLiveMetricsMonitor *monitor;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UISegmentedControl *mode;
@property (nonatomic, copy) NSArray<IFProcessSample *> *samples;
@end

@interface IFProcessDetailViewController : UIViewController
@property (nonatomic, assign) pid_t pid;
@property (nonatomic, strong) IFProcessMonitor *processMonitor;
@property (nonatomic, strong) IFLineChartView *chart;
@property (nonatomic, strong) UILabel *detailsLabel;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *cpuHistory;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSArray<NSString *> *relatedTweaks;
@property (nonatomic, copy) NSString *processName;
@property (nonatomic, copy) NSString *executablePath;
@property (nonatomic, strong) UIButton *terminateButton;
- (instancetype)initWithProcess:(IFProcessSample *)process;
@end

@implementation IFProcessDetailViewController

- (instancetype)initWithProcess:(IFProcessSample *)process {
    self = [super init];
    if (self) {
        _pid = process.pid;
        _processName = [process.name copy];
        _executablePath = [process.executablePath copy];
        self.title = process.name;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.processMonitor = [[IFProcessMonitor alloc] init];
    self.cpuHistory = [NSMutableArray array];
    UILabel *heading = [[UILabel alloc] init];
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    heading.text = IFUI(@"CPU history", @"История CPU");
    heading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.chart = [[IFLineChartView alloc] init];
    self.chart.translatesAutoresizingMaskIntoConstraints = NO;
    self.chart.fixedMaximum = 100;
    self.chart.lineColor = UIColor.systemOrangeColor;
    self.detailsLabel = [[UILabel alloc] init];
    self.detailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsLabel.numberOfLines = 0;
    self.detailsLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.terminateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.terminateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.terminateButton.backgroundColor = UIColor.systemRedColor;
    self.terminateButton.tintColor = UIColor.whiteColor;
    self.terminateButton.layer.cornerRadius = 12;
    self.terminateButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.terminateButton setTitle:IFUI(@"Terminate process", @"Завершить процесс") forState:UIControlStateNormal];
    [self.terminateButton addTarget:self action:@selector(confirmTermination:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"network"] style:UIBarButtonItemStylePlain
                target:self action:@selector(showConnections:)];
    [self.view addSubview:heading];
    [self.view addSubview:self.chart];
    [self.view addSubview:self.detailsLabel];
    [self.view addSubview:self.terminateButton];
    [NSLayoutConstraint activateConstraints:@[
        [heading.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor],
        [heading.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor],
        [heading.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18],
        [self.chart.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [self.chart.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor],
        [self.chart.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:10],
        [self.chart.heightAnchor constraintEqualToConstant:150],
        [self.detailsLabel.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [self.detailsLabel.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor],
        [self.detailsLabel.topAnchor constraintEqualToAnchor:self.chart.bottomAnchor constant:18],
        [self.terminateButton.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [self.terminateButton.trailingAnchor constraintEqualToAnchor:heading.trailingAnchor],
        [self.terminateButton.topAnchor constraintEqualToAnchor:self.detailsLabel.bottomAnchor constant:18],
        [self.terminateButton.heightAnchor constraintEqualToConstant:50],
        [self.terminateButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-18]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)refresh:(__unused NSTimer *)timer {
    [self.processMonitor refresh];
    IFProcessSample *current = nil;
    for (IFProcessSample *sample in self.processMonitor.allProcesses) {
        if (sample.pid == self.pid) {
            current = sample;
            break;
        }
    }
    if (current == nil) {
        self.detailsLabel.text = IFUI(@"The process has exited.", @"Процесс завершился.");
        self.terminateButton.enabled = NO;
        self.terminateButton.alpha = 0.45;
        [self.terminateButton setTitle:IFUI(@"Process exited", @"Процесс завершён") forState:UIControlStateNormal];
        [self.timer invalidate];
        self.timer = nil;
        return;
    }
    [self.cpuHistory addObject:@(current.cpuPercent)];
    if (self.cpuHistory.count > 300) {
        [self.cpuHistory removeObjectAtIndex:0];
    }
    self.chart.values = self.cpuHistory;
    if (self.relatedTweaks == nil) {
        NSMutableArray *related = [NSMutableArray array];
        for (IFTweakRecord *tweak in [IFDiagnostics installedTweaks]) {
            if ([tweak.targetExecutables containsObject:current.name]) {
                [related addObject:tweak.name];
            }
        }
        self.relatedTweaks = related;
    }
    NSInteger hours = (NSInteger)(current.runningTime / 3600);
    NSInteger minutes = ((NSInteger)current.runningTime % 3600) / 60;
    self.detailsLabel.text = [NSString stringWithFormat:@"PID: %d\nCPU: %.1f%%\nRAM: %@\n%@: %ld\n%@: %ldh %ldm\n\n%@\n\n%@: %@",
        current.pid, current.cpuPercent, [IFetchCore formatBytes:current.residentBytes],
        IFUI(@"Threads", @"Потоки"), (long)current.threadCount,
        IFUI(@"Running", @"Работает"), (long)hours, (long)minutes,
        current.executablePath.length ? current.executablePath : IFUI(@"Path unavailable", @"Путь недоступен"),
        IFUI(@"Injected tweaks", @"Внедряемые твики"),
        self.relatedTweaks.count ? [self.relatedTweaks componentsJoinedByString:@", "] : IFUI(@"Not detected", @"Не обнаружены")];
}

- (void)showConnections:(__unused id)sender {
    IFProcessSample *process = [self currentProcess];
    if (process == nil) {
        return;
    }
    [self.navigationController pushViewController:
        [[IFProcessConnectionsViewController alloc] initWithProcess:process] animated:YES];
}

- (IFProcessSample *)currentProcess {
    [self.processMonitor refresh];
    for (IFProcessSample *sample in self.processMonitor.allProcesses) {
        if (sample.pid == self.pid) {
            return sample;
        }
    }
    return nil;
}

- (BOOL)isProtectedProcess:(IFProcessSample *)process {
    NSSet *protectedNames = [NSSet setWithArray:@[@"kernel_task", @"launchd"]];
    return process == nil || process.pid <= 1 || process.pid == getpid() ||
        [protectedNames containsObject:process.name.lowercaseString];
}

- (BOOL)isSameProcess:(IFProcessSample *)process {
    if (process == nil || process.pid != self.pid) {
        return NO;
    }
    if (self.executablePath.length > 0 && process.executablePath.length > 0) {
        return [self.executablePath isEqualToString:process.executablePath];
    }
    return self.processName.length > 0 && [self.processName isEqualToString:process.name];
}

- (void)confirmTermination:(__unused id)sender {
    IFProcessSample *process = [self currentProcess];
    if (![self isSameProcess:process]) {
        [self refresh:nil];
        return;
    }
    if ([self isProtectedProcess:process]) {
        UIAlertController *blocked = [UIAlertController alertControllerWithTitle:IFUI(@"Protected process", @"Защищённый процесс")
                                                                         message:IFUI(@"iFetch will not terminate launchd, kernel_task or itself.", @"iFetch не завершает launchd, kernel_task и собственный процесс.")
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [blocked addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:blocked animated:YES completion:nil];
        return;
    }
    NSString *message = [NSString stringWithFormat:IFUI(@"Send SIGTERM to %@ (PID %d)? System daemons may restart the interface.", @"Отправить SIGTERM процессу %@ (PID %d)? Системные демоны могут перезапустить интерфейс."), process.name, process.pid];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:IFUI(@"Terminate process", @"Завершить процесс")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:IFUI(@"Terminate", @"Завершить") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self terminateCurrentProcess];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:IFUI(@"Cancel", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.terminateButton;
    alert.popoverPresentationController.sourceRect = self.terminateButton.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)terminateCurrentProcess {
    IFProcessSample *process = [self currentProcess];
    if (![self isSameProcess:process] || [self isProtectedProcess:process]) {
        [self refresh:nil];
        return;
    }
    errno = 0;
    if (kill(process.pid, SIGTERM) == 0) {
        self.terminateButton.enabled = NO;
        self.terminateButton.alpha = 0.45;
        [self.terminateButton setTitle:IFUI(@"Termination requested", @"Завершение запрошено") forState:UIControlStateNormal];
        [self performSelector:@selector(refresh:) withObject:nil afterDelay:0.5];
        return;
    }
    NSString *reason = [NSString stringWithUTF8String:strerror(errno)] ?: IFUI(@"Unknown error", @"Неизвестная ошибка");
    UIAlertController *error = [UIAlertController alertControllerWithTitle:IFUI(@"Could not terminate process", @"Не удалось завершить процесс")
                                                                   message:reason
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:error animated:YES completion:nil];
}

@end

@implementation IFProcessesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Processes", @"Процессы");
    self.monitor = [[IFLiveMetricsMonitor alloc] init];
    self.mode = [[UISegmentedControl alloc] initWithItems:@[@"CPU", @"RAM"]];
    self.mode.selectedSegmentIndex = 0;
    [self.mode addTarget:self action:@selector(reload:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.mode;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self tick:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)tick:(__unused NSTimer *)timer {
    [self.monitor refresh];
    [self reload:nil];
}

- (void)reload:(__unused id)sender {
    self.samples = self.mode.selectedSegmentIndex == 0
        ? [self.monitor.processes topProcessesByCPU:50]
        : [self.monitor.processes topProcessesByMemory:50];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.samples.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFProcessSample *process = self.samples[indexPath.row];
    UITableViewCell *cell = IFValueCell(tableView, process.name,
        [NSString stringWithFormat:@"PID %d · %.1f%% · %@", process.pid, process.cpuPercent,
         [IFetchCore formatBytes:process.residentBytes]]);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if ([[self.monitor sustainedHighCPUProcesses] containsObject:process]) {
        cell.textLabel.textColor = UIColor.systemOrangeColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IFProcessSample *process = self.samples[indexPath.row];
    [self.navigationController pushViewController:[[IFProcessDetailViewController alloc] initWithProcess:process] animated:YES];
}

@end

@interface IFCrashLogsViewController : UITableViewController
@property (nonatomic, copy) NSArray<IFCrashLog *> *logs;
@end

@implementation IFCrashLogsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Crash Logs", @"Журнал сбоев");
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reloadLogs:) forControlEvents:UIControlEventValueChanged];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadLogs:)
                                                 name:UIApplicationWillEnterForegroundNotification object:nil];
    [self reloadLogs:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadLogs:nil];
}

- (void)reloadLogs:(__unused id)sender {
    self.logs = [IFDiagnostics recentCrashLogsWithLimit:200];
    UILabel *empty = [[UILabel alloc] init];
    empty.text = IFUI(@"No crash reports found", @"Отчёты о сбоях не найдены");
    empty.textAlignment = NSTextAlignmentCenter;
    empty.textColor = UIColor.secondaryLabelColor;
    empty.numberOfLines = 0;
    self.tableView.backgroundView = self.logs.count == 0 ? empty : nil;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.logs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFCrashLog *log = self.logs[indexPath.row];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    UITableViewCell *cell = IFValueCell(tableView, log.name,
        [NSString stringWithFormat:@"%@ · %@", log.kind, [formatter stringFromDate:log.date]]);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IFCrashLog *log = self.logs[indexPath.row];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.title = log.name;
    controller.view.backgroundColor = UIColor.systemBackgroundColor;
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    IFCrashAnalysis *analysis = [IFAdvancedDiagnostics analysisForCrashLog:log];
    textView.text = [NSString stringWithFormat:@"%@\n\n————————————\n\n%@",
                     analysis.summary, log.preview];
    [controller.view addSubview:textView];
    [NSLayoutConstraint activateConstraints:@[
        [textView.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [textView.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor]
    ]];
    controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                                 target:self action:@selector(shareCurrentLog:)];
    objc_setAssociatedObject(controller.navigationItem.rightBarButtonItem, IFCrashLogShareKey, log, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)shareCurrentLog:(UIBarButtonItem *)sender {
    IFCrashLog *log = objc_getAssociatedObject(sender, IFCrashLogShareKey);
    if (log.path.length == 0) {
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:log.path];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    activity.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:activity animated:YES completion:nil];
}

@end

@interface IFTweaksViewController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<IFTweakRecord *> *allTweaks;
@property (nonatomic, copy) NSArray<IFTweakRecord *> *visibleTweaks;
@end

@implementation IFTweaksViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Installed tweaks", @"Установленные твики");
    self.allTweaks = [IFDiagnostics installedTweaks];
    self.visibleTweaks = self.allTweaks;
    UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
    search.searchResultsUpdater = self;
    search.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = search;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text.lowercaseString;
    self.visibleTweaks = query.length == 0 ? self.allTweaks :
        [self.allTweaks filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(IFTweakRecord *record, __unused NSDictionary *bindings) {
            return [record.name.lowercaseString containsString:query] ||
                   [record.packageIdentifier.lowercaseString containsString:query];
        }]];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.visibleTweaks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IFTweakRecord *record = self.visibleTweaks[indexPath.row];
    UITableViewCell *cell = IFValueCell(tableView, record.name,
        [NSString stringWithFormat:@"%@ %@ · %@", record.packageIdentifier, record.packageVersion,
         record.isEnabled ? IFUI(@"Enabled", @"Включён") : IFUI(@"Disabled", @"Отключён")]);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.textColor = record.isEnabled ? UIColor.labelColor : UIColor.secondaryLabelColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IFTweakRecord *record = self.visibleTweaks[indexPath.row];
    NSString *targets = [record.targetBundles arrayByAddingObjectsFromArray:record.targetExecutables].count
        ? [[record.targetBundles arrayByAddingObjectsFromArray:record.targetExecutables] componentsJoinedByString:@"\n"] : IFUI(@"All processes / unspecified", @"Все процессы / не указано");
    NSString *message = [NSString stringWithFormat:@"%@\n%@ %@\n\n%@:\n%@\n\n%@:\n%@",
                         record.dylibPath, record.packageIdentifier, record.packageVersion,
                         IFUI(@"Targets", @"Цели"), targets,
                         IFUI(@"State", @"Состояние"), record.isEnabled ? IFUI(@"Enabled", @"Включён") : IFUI(@"Disabled", @"Отключён")];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:record.name message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:IFUI(@"Copy", @"Копировать") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = message;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@interface IFHealthViewController : UITableViewController
@property (nonatomic, strong) IFLiveMetricsMonitor *monitor;
@property (nonatomic, copy) NSArray<IFHealthItem *> *items;
@property (nonatomic, strong) NSTimer *samplingTimer;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) NSInteger sampleCount;
@end

@implementation IFHealthViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Jailbreak Health";
    self.monitor = [[IFLiveMetricsMonitor alloc] init];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                          target:self action:@selector(refresh:)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh:nil];
    [self.refreshTimer invalidate];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refreshStatus:)
                                                       userInfo:nil repeats:YES];
}

- (void)refresh:(__unused id)sender {
    [self.samplingTimer invalidate];
    self.sampleCount = 0;
    [self sampleHealth:nil];
    self.samplingTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                        selector:@selector(sampleHealth:)
                                                        userInfo:nil repeats:YES];
}

- (void)refreshStatus:(__unused id)sender {
    [self.monitor refresh];
    self.items = [IFDiagnostics healthItemsWithJailbreak:[IFetchCore jailbreakInfo]
                                                battery:[IFDiagnostics batteryDetails]
                                              processes:self.monitor.sustainedHighCPUProcesses];
    [self.tableView reloadData];
}

- (void)sampleHealth:(__unused NSTimer *)timer {
    [self.monitor refresh];
    self.items = [IFDiagnostics healthItemsWithJailbreak:[IFetchCore jailbreakInfo]
                                                battery:[IFDiagnostics batteryDetails]
                                              processes:self.monitor.sustainedHighCPUProcesses];
    [self.tableView reloadData];
    self.sampleCount++;
    if (self.sampleCount >= 5) {
        [self.samplingTimer invalidate];
        self.samplingTimer = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.samplingTimer invalidate];
    self.samplingTimer = nil;
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.items.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == (NSInteger)self.items.count) {
        UITableViewCell *cell = IFValueCell(tableView,
            IFUI(@"Jailbreak integrity", @"Целостность jailbreak"),
            IFUI(@"Bootstrap files, packages, injection filters and symlinks",
                 @"Файлы bootstrap, пакеты, фильтры инъекции и символические ссылки"));
        cell.imageView.image = [UIImage systemImageNamed:@"checkmark.shield"];
        cell.imageView.tintColor = UIColor.systemBlueColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    IFHealthItem *item = self.items[indexPath.row];
    UITableViewCell *cell = IFValueCell(tableView, item.title, item.detail);
    NSArray *symbols = @[@"checkmark.circle.fill", @"exclamationmark.triangle.fill", @"xmark.octagon.fill"];
    NSArray *colors = @[UIColor.systemGreenColor, UIColor.systemOrangeColor, UIColor.systemRedColor];
    cell.imageView.image = [UIImage systemImageNamed:symbols[item.state]];
    cell.imageView.tintColor = colors[item.state];
    if ([item.identifier isEqualToString:@"recent_crashes"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == (NSInteger)self.items.count) {
        [self.navigationController pushViewController:[[IFIntegrityViewController alloc] init] animated:YES];
        return;
    }
    IFHealthItem *item = self.items[indexPath.row];
    if ([item.identifier isEqualToString:@"recent_crashes"]) {
        [self.navigationController pushViewController:[[IFCrashLogsViewController alloc] init] animated:YES];
    }
}

@end

@interface IFNetworkDetailsViewController : UITableViewController <CLLocationManagerDelegate>
@property (nonatomic, copy) NSDictionary *details;
@property (nonatomic, strong) CLLocationManager *locationManager;
@end

@implementation IFNetworkDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Network details", @"Сетевые детали");
    self.details = @{};
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(load:)];
    if (self.locationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        [self load:nil];
    }
}

- (void)load:(__unused id)sender {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *details = [IFDiagnostics extendedNetworkDetails];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.details = details;
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [self.tableView reloadData];
        });
    });
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (manager.authorizationStatus != kCLAuthorizationStatusNotDetermined) {
        [self load:nil];
    }
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 8 : [self.details[@"interfaces"] count];
}

- (NSString *)tableView:(__unused UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? IFUI(@"Connection", @"Подключение") : IFUI(@"Traffic totals by interface", @"Трафик по интерфейсам");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSNumber *latency = self.details[@"dnsLatency"];
        NSNumber *internetLatency = self.details[@"internetLatency"];
        BOOL locationAllowed = self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse ||
                               self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways;
        NSString *wifiUnavailable = locationAllowed ? IFUI(@"Unavailable", @"Недоступно")
                                                    : IFUI(@"Location permission required", @"Требуется доступ к геолокации");
        NSString *internetValue = [self.details[@"internetAvailable"] boolValue]
            ? IFUI(@"Available", @"Доступен")
            : ([self.details[@"internetError"] length] > 0 ? self.details[@"internetError"] : IFUI(@"Unavailable", @"Недоступен"));
        NSArray *rows = @[
            @[@"IPv4", self.details[@"ipv4"] ?: @""],
            @[@"IPv6", self.details[@"ipv6"] ?: @""],
            @[@"Wi-Fi SSID", [self.details[@"ssid"] length] ? self.details[@"ssid"] : wifiUnavailable],
            @[@"BSSID", [self.details[@"bssid"] length] ? self.details[@"bssid"] : wifiUnavailable],
            @[IFUI(@"Cellular", @"Сотовая сеть"), [self.details[@"radio"] length] ? self.details[@"radio"] : IFUI(@"No active cellular service", @"Нет активной сотовой сети")],
            @[IFUI(@"DNS latency", @"Задержка DNS"), latency.doubleValue >= 0 ? [NSString stringWithFormat:@"%.0f ms", latency.doubleValue] : IFUI(@"Unavailable", @"Недоступно")],
            @[IFUI(@"Internet", @"Интернет"), internetValue],
            @[IFUI(@"HTTPS latency", @"Задержка HTTPS"), internetLatency.doubleValue >= 0 ? [NSString stringWithFormat:@"%.0f ms", internetLatency.doubleValue] : IFUI(@"Unavailable", @"Недоступно")]
        ];
        return IFValueCell(tableView, rows[indexPath.row][0], rows[indexPath.row][1]);
    }
    NSArray *names = [[self.details[@"interfaces"] allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSString *name = names[indexPath.row];
    NSDictionary *traffic = self.details[@"interfaces"][name];
    return IFValueCell(tableView, name, [NSString stringWithFormat:@"↓ %@  ↑ %@",
        [IFetchCore formatBytes:[traffic[@"received"] unsignedLongLongValue]],
        [IFetchCore formatBytes:[traffic[@"sent"] unsignedLongLongValue]]]);
}

@end

@implementation IFDiagnosticsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = IFUI(@"Diagnostics", @"Диагностика");
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return 8;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"IFDiagnosticsMenu";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    NSArray *titles = @[
        IFUI(@"Live charts", @"Графики в реальном времени"),
        IFUI(@"Battery diagnostics", @"Диагностика батареи"),
        IFUI(@"Process explorer", @"Диспетчер процессов"),
        @"Crash Logs",
        IFUI(@"Installed tweaks", @"Установленные твики"),
        @"Jailbreak Health",
        IFUI(@"Network details", @"Сетевые детали"),
        IFUI(@"Advanced diagnostics", @"Расширенная диагностика")
    ];
    NSArray *details = @[
        IFUI(@"CPU, RAM, network and temperature history", @"История CPU, ОЗУ, сети и температуры"),
        IFUI(@"Capacity, health, current and charging power", @"Ёмкость, здоровье, ток и мощность зарядки"),
        IFUI(@"Top-50, path, PID and sustained load alerts", @"Top-50, путь, PID и длительная нагрузка"),
        IFUI(@"View, copy and share diagnostic reports", @"Просмотр и отправка диагностических отчётов"),
        IFUI(@"Packages, dylibs and injection filters", @"Пакеты, dylib и фильтры инъекции"),
        IFUI(@"Rootless bootstrap and system status", @"Состояние bootstrap и системы"),
        IFUI(@"IPv4/IPv6, Wi-Fi, cellular and traffic", @"IPv4/IPv6, Wi-Fi, сотовая сеть и трафик"),
        IFUI(@"Snapshots, injection, daemons and diagnostic mode", @"Снимки, инъекции, демоны и режим диагностики")
    ];
    NSArray *symbols = @[@"chart.xyaxis.line", @"battery.100", @"cpu", @"doc.text.magnifyingglass",
                         @"puzzlepiece.extension", @"heart.text.square", @"network", @"waveform.badge.magnifyingglass"];
    cell.textLabel.text = titles[indexPath.row];
    cell.detailTextLabel.text = details[indexPath.row];
    cell.imageView.image = [UIImage systemImageNamed:symbols[indexPath.row]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *controllers = @[
        [IFChartsViewController class], [IFBatteryViewController class], [IFProcessesViewController class],
        [IFCrashLogsViewController class], [IFTweaksViewController class], [IFHealthViewController class],
        [IFNetworkDetailsViewController class], [IFAdvancedMenuViewController class]
    ];
    UIViewController *controller = [[controllers[indexPath.row] alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
