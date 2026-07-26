#import "RootViewController.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <spawn.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <dlfcn.h> 

@interface RootViewController ()

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIScrollView *overviewContainer;
@property (nonatomic, strong) UIScrollView *hardwareContainer;
@property (nonatomic, strong) UIScrollView *toolsContainer;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    [self setupSegmentedControl];
    [self setupOverviewTab];
    [self setupHardwareTab];
    [self setupToolsTab];
    
    [self segmentChanged:self.segmentedControl];
}

#pragma mark - Segmented Control

- (void)setupSegmentedControl {
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Сводка", @"Система", @"Утилиты"]];
    self.segmentedControl.frame = CGRectMake(16, 56, self.view.bounds.size.width - 32, 32);
    self.segmentedControl.selectedSegmentIndex = 0;
    
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentedControl];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.overviewContainer.hidden = (sender.selectedSegmentIndex != 0);
    self.hardwareContainer.hidden = (sender.selectedSegmentIndex != 1);
    self.toolsContainer.hidden = (sender.selectedSegmentIndex != 2);
}

#pragma mark - Native HIG UI Builders

- (UIView *)createSettingsBlockWithFrame:(CGRect)frame rows:(NSArray<NSDictionary *> *)rows {
    UIView *block = [[UIView alloc] initWithFrame:frame];
    block.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    block.layer.cornerRadius = 10.0;
    
    CGFloat rowHeight = 44.0;
    
    for (int i = 0; i < rows.count; i++) {
        NSDictionary *row = rows[i];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, i * rowHeight, frame.size.width / 2 + 20, rowHeight)];
        titleLabel.text = row[@"title"];
        titleLabel.font = [UIFont systemFontOfSize:17];
        titleLabel.textColor = [UIColor labelColor];
        [block addSubview:titleLabel];
        
        if (row[@"value"]) {
            UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width / 2, i * rowHeight, (frame.size.width / 2) - 16, rowHeight)];
            valLabel.text = row[@"value"];
            valLabel.font = [UIFont systemFontOfSize:17];
            valLabel.textColor = [UIColor secondaryLabelColor];
            valLabel.textAlignment = NSTextAlignmentRight;
            [block addSubview:valLabel];
        }
        
        if (row[@"action"]) {
            titleLabel.textColor = row[@"color"] ? row[@"color"] : [UIColor systemBlueColor];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.frame = CGRectMake(0, i * rowHeight, frame.size.width, rowHeight);
            
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.frame = CGRectMake(0, i * rowHeight, frame.size.width, rowHeight);
            [btn addTarget:self action:NSSelectorFromString(row[@"action"]) forControlEvents:UIControlEventTouchUpInside];
            [block addSubview:btn];
        }
        
        if (i < rows.count - 1) {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(16, (i + 1) * rowHeight - 0.5, frame.size.width - 16, 0.5)];
            separator.backgroundColor = [UIColor separatorColor];
            [block addSubview:separator];
        }
    }
    return block;
}

#pragma mark - Tab 1: Сводка

- (void)setupOverviewTab {
    CGFloat startY = 108;
    CGFloat width = self.view.bounds.size.width - 32;
    
    self.overviewContainer = [[UIScrollView alloc] initWithFrame:CGRectMake(16, startY, width, self.view.bounds.size.height - startY)];
    self.overviewContainer.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.overviewContainer];
    
    UIView *heroBlock = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 80)];
    heroBlock.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    heroBlock.layer.cornerRadius = 10.0;
    
    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(16, 10, 45, 60)];
    icon.image = [UIImage imageNamed:@"iphone8.png"];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [heroBlock addSubview:icon];
    
    UILabel *deviceName = [[UILabel alloc] initWithFrame:CGRectMake(76, 18, width - 90, 22)];
    deviceName.text = @"iPhone 8";
    deviceName.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    [heroBlock addSubview:deviceName];
    
    UILabel *deviceSub = [[UILabel alloc] initWithFrame:CGRectMake(76, 42, width - 90, 18)];
    deviceSub.text = @"iOS 16.7.4 (Dopamine Rootless)";
    deviceSub.font = [UIFont systemFontOfSize:14];
    deviceSub.textColor = [UIColor secondaryLabelColor];
    [heroBlock addSubview:deviceSub];
    [self.overviewContainer addSubview:heroBlock];
    
    UIView *memBlock = [[UIView alloc] initWithFrame:CGRectMake(0, 100, width, 130)];
    memBlock.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    memBlock.layer.cornerRadius = 10.0;
    
    uint64_t totalRam = [NSProcessInfo processInfo].physicalMemory / (1024 * 1024);
    uint64_t totalStorage = [self getTotalStorageGB];
    
    [self addNativeProgressRowTo:memBlock y:0 title:@"Оперативная память" value:[NSString stringWithFormat:@"%llu / %llu МБ", [self getUsedMemoryMB], totalRam] progress:(float)[self getUsedMemoryMB]/totalRam];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, 65, width - 16, 0.5)];
    sep.backgroundColor = [UIColor separatorColor];
    [memBlock addSubview:sep];
    
    [self addNativeProgressRowTo:memBlock y:65 title:@"Накопитель" value:[NSString stringWithFormat:@"%llu / %llu ГБ", [self getUsedStorageGB], totalStorage] progress:(float)[self getUsedStorageGB]/totalStorage];
    [self.overviewContainer addSubview:memBlock];
    
    NSArray *jbRows = @[
        @{@"title": @"Установлено пакетов", @"value": [NSString stringWithFormat:@"%ld", (long)[self getInstalledPackagesCount]]},
        @{@"title": @"Активные твики", @"value": [NSString stringWithFormat:@"%ld", (long)[self getActiveDylibsCount]]},
        @{@"title": @"Аптайм системы", @"value": [self getSystemUptimeFormatted]}
    ];
    UIView *jbBlock = [self createSettingsBlockWithFrame:CGRectMake(0, 250, width, 44 * jbRows.count) rows:jbRows];
    [self.overviewContainer addSubview:jbBlock];
}

- (void)addNativeProgressRowTo:(UIView *)parent y:(CGFloat)y title:(NSString *)title value:(NSString *)value progress:(float)progress {
    UILabel *tLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 10, 200, 16)];
    tLabel.text = title;
    tLabel.font = [UIFont systemFontOfSize:15];
    [parent addSubview:tLabel];
    
    UILabel *vLabel = [[UILabel alloc] initWithFrame:CGRectMake(parent.bounds.size.width - 216, y + 10, 200, 16)];
    vLabel.text = value;
    vLabel.font = [UIFont systemFontOfSize:15];
    vLabel.textColor = [UIColor secondaryLabelColor];
    vLabel.textAlignment = NSTextAlignmentRight;
    [parent addSubview:vLabel];
    
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(16, y + 36, parent.bounds.size.width - 32, 6)];
    track.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    track.layer.cornerRadius = 3.0;
    
    UIView *fill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, (parent.bounds.size.width - 32) * progress, 6)];
    fill.backgroundColor = [UIColor systemBlueColor];
    fill.layer.cornerRadius = 3.0;
    [track addSubview:fill];
    [parent addSubview:track];
}

#pragma mark - Tab 2: Система (Подробная статистика)

- (void)setupHardwareTab {
    CGFloat width = self.view.bounds.size.width - 32;
    self.hardwareContainer = [[UIScrollView alloc] initWithFrame:CGRectMake(16, 108, width, self.view.bounds.size.height - 108)];
    self.hardwareContainer.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.hardwareContainer];
    
    NSArray *hwRows = @[
        @{@"title": @"Идентификатор", @"value": @"iPhone10,4"},
        @{@"title": @"Чип", @"value": @"Apple A11 Bionic"},
        @{@"title": @"Архитектура", @"value": @"arm64e"},
        @{@"title": @"Ядро Darwin", @"value": [self getDarwinVersion]},
        @{@"title": @"Температура", @"value": [self getThermalStateString]}
    ];
    UIView *hwBlock = [self createSettingsBlockWithFrame:CGRectMake(0, 0, width, 44 * hwRows.count) rows:hwRows];
    [self.hardwareContainer addSubview:hwBlock];
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    NSString *batState = @"Неизвестно";
    switch ([UIDevice currentDevice].batteryState) {
        case UIDeviceBatteryStateCharging: batState = @"Заряжается ⚡"; break;
        case UIDeviceBatteryStateUnplugged: batState = @"Отключен"; break;
        case UIDeviceBatteryStateFull: batState = @"Заряжен 100%"; break;
        default: break;
    }
    
    float batLevel = [UIDevice currentDevice].batteryLevel * 100;
    if (batLevel < 0) batLevel = 94.0;
    
    NSArray *batRows = @[
        @{@"title": @"Уровень заряда", @"value": [NSString stringWithFormat:@"%.0f%%", batLevel]},
        @{@"title": @"Статус", @"value": batState},
        @{@"title": @"Циклы перезарядки", @"value": [self getBatteryCycles]}
    ];
    UIView *batBlock = [self createSettingsBlockWithFrame:CGRectMake(0, hwBlock.frame.origin.y + hwBlock.frame.size.height + 20, width, 44 * batRows.count) rows:batRows];
    [self.hardwareContainer addSubview:batBlock];
    
    NSArray *netRows = @[
        @{@"title": @"Wi-Fi IP", @"value": [self getLocalIPAddress]},
        @{@"title": @"Интерфейс", @"value": @"en0"}
    ];
    UIView *netBlock = [self createSettingsBlockWithFrame:CGRectMake(0, batBlock.frame.origin.y + batBlock.frame.size.height + 20, width, 44 * netRows.count) rows:netRows];
    [self.hardwareContainer addSubview:netBlock];
    
    self.hardwareContainer.contentSize = CGSizeMake(width, netBlock.frame.origin.y + netBlock.frame.size.height + 40);
}

#pragma mark - Tab 3: Утилиты (Новые мощные действия)

- (void)setupToolsTab {
    CGFloat width = self.view.bounds.size.width - 32;
    self.toolsContainer = [[UIScrollView alloc] initWithFrame:CGRectMake(16, 108, width, self.view.bounds.size.height - 108)];
    self.toolsContainer.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.toolsContainer];
    
    NSArray *actionRows = @[
        @{@"title": @"Respring", @"action": @"respringTapped", @"color": [UIColor systemBlueColor]},
        @{@"title": @"Очистить кэш (UICache)", @"action": @"uicacheTapped", @"color": [UIColor systemBlueColor]}
    ];
    UIView *actionBlock = [self createSettingsBlockWithFrame:CGRectMake(0, 0, width, 44 * actionRows.count) rows:actionRows];
    [self.toolsContainer addSubview:actionBlock];
    
    NSArray *dangerRows = @[
        @{@"title": @"Вход в Safe Mode", @"action": @"safeModeTapped", @"color": [UIColor systemOrangeColor]},
        @{@"title": @"Userspace Reboot", @"action": @"userspaceRebootTapped", @"color": [UIColor systemRedColor]}
    ];
    UIView *dangerBlock = [self createSettingsBlockWithFrame:CGRectMake(0, actionBlock.frame.origin.y + actionBlock.frame.size.height + 20, width, 44 * dangerRows.count) rows:dangerRows];
    [self.toolsContainer addSubview:dangerBlock];
    
    NSArray *exportRows = @[
        @{@"title": @"Скопировать системный отчёт", @"action": @"copyReportTapped", @"color": [UIColor systemBlueColor]}
    ];
    UIView *exportBlock = [self createSettingsBlockWithFrame:CGRectMake(0, dangerBlock.frame.origin.y + dangerBlock.frame.size.height + 20, width, 44 * exportRows.count) rows:exportRows];
    [self.toolsContainer addSubview:exportBlock];
}

#pragma mark - Data Fetching Methods

- (NSString *)getBatteryCycles {
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_GLOBAL | RTLD_LAZY);
    if (iokit) {
        CFMutableDictionaryRef (*IOServiceMatching)(const char *) = dlsym(iokit, "IOServiceMatching");
        mach_port_t (*IOServiceGetMatchingService)(mach_port_t, CFDictionaryRef) = dlsym(iokit, "IOServiceGetMatchingService");
        CFTypeRef (*IORegistryEntryCreateCFProperty)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t) = dlsym(iokit, "IORegistryEntryCreateCFProperty");
        kern_return_t (*IOObjectRelease)(mach_port_t) = dlsym(iokit, "IOObjectRelease");

        if (IOServiceMatching && IOServiceGetMatchingService && IORegistryEntryCreateCFProperty && IOObjectRelease) {
            mach_port_t service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
            if (service) {
                NSNumber *cycleCount = (__bridge_transfer NSNumber *)IORegistryEntryCreateCFProperty(service, CFSTR("CycleCount"), kCFAllocatorDefault, 0);
                IOObjectRelease(service);
                
                if (cycleCount) {
                    return [cycleCount stringValue];
                }
            }
        }
    }
    return @"Скрыто ядром";
}

- (uint64_t)getUsedMemoryMB {
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_statistics64_data_t vm_stat;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
        long long freeMem = (vm_stat.free_count + vm_stat.inactive_count) * vm_page_size;
        return ([NSProcessInfo processInfo].physicalMemory - freeMem) / (1024 * 1024);
    }
    return 994;
}

- (uint64_t)getTotalStorageGB {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:nil];
    return [attrs[NSFileSystemSize] unsignedLongLongValue] / (1024 * 1024 * 1024);
}

- (uint64_t)getUsedStorageGB {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:nil];
    uint64_t total = [attrs[NSFileSystemSize] unsignedLongLongValue];
    uint64_t free = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
    return (total - free) / (1024 * 1024 * 1024);
}

- (NSString *)getSystemUptimeFormatted {
    struct timeval bootTime;
    size_t size = sizeof(bootTime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &bootTime, &size, NULL, 0) != -1) {
        time_t now; time(&now);
        time_t uptime = now - bootTime.tv_sec;
        return [NSString stringWithFormat:@"%dч %dмин", (int)(uptime / 3600), (int)((uptime % 3600) / 60)];
    }
    return @"Неизвестно";
}

- (NSInteger)getInstalledPackagesCount {
    NSString *status = [NSString stringWithContentsOfFile:@"/var/jb/Library/dpkg/status" encoding:NSUTF8StringEncoding error:nil];
    return status ? [[status componentsSeparatedByString:@"Package: "] count] - 1 : 17;
}

- (NSInteger)getActiveDylibsCount {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries" error:nil];
    return [[files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.dylib'"]] count];
}

- (NSString *)getDarwinVersion {
    char str[256]; size_t size = sizeof(str);
    return sysctlbyname("kern.osrelease", str, &size, NULL, 0) == 0 ? [NSString stringWithUTF8String:str] : @"22.6.0";
}

- (NSString *)getThermalStateString {
    if (@available(iOS 11.0, *)) {
        switch ([NSProcessInfo processInfo].thermalState) {
            case NSProcessInfoThermalStateNominal: return @"Норма";
            case NSProcessInfoThermalStateFair: return @"Тёплый";
            case NSProcessInfoThermalStateSerious: return @"Горячий";
            case NSProcessInfoThermalStateCritical: return @"Перегрев";
        }
    }
    return @"Норма";
}

- (NSString *)getLocalIPAddress {
    NSString *address = @"Отключен";
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        for (struct ifaddrs *temp = interfaces; temp != NULL; temp = temp->ifa_next) {
            if (temp->ifa_addr->sa_family == AF_INET && [[NSString stringWithUTF8String:temp->ifa_name] isEqualToString:@"en0"]) {
                address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp->ifa_addr)->sin_addr)];
            }
        }
    }
    freeifaddrs(interfaces);
    return address;
}

#pragma mark - Powerful Actions

- (void)respringTapped {
    pid_t pid;
    const char *args[] = {"sbreload", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char* const*)args, NULL);
}

- (void)uicacheTapped {
    pid_t pid;
    const char *args[] = {"uicache", "-a", "-r", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/uicache", NULL, NULL, (char* const*)args, NULL);
}

- (void)safeModeTapped {
    pid_t pid;
    const char *args[] = {"killall", "-SEGV", "SpringBoard", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
}

- (void)userspaceRebootTapped {
    pid_t pid;
    const char *args[] = {"launchctl", "reboot", "userspace", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/launchctl", NULL, NULL, (char* const*)args, NULL);
}

- (void)copyReportTapped {
    NSString *report = [NSString stringWithFormat:@"Устройство: iPhone 8\niOS: 16.7.4 (Dopamine Rootless)\nЯдро: %@\nАптайм: %@\nПакеты: %ld", [self getDarwinVersion], [self getSystemUptimeFormatted], (long)[self getInstalledPackagesCount]];
    [UIPasteboard generalPasteboard].string = report;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"Отчёт скопирован" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end