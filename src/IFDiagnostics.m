#import "IFDiagnostics.h"

#import <SystemConfiguration/CaptiveNetwork.h>
#import <arpa/inet.h>
#import <dlfcn.h>
#import <ifaddrs.h>
#import <mach/mach.h>
#import <netdb.h>
#import <net/if.h>

static NSString *IFD(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

@implementation IFBatteryDetails

- (double)healthPercent {
    double maximum = self.maximumCapacity.doubleValue;
    double design = self.designCapacity.doubleValue;
    return design > 0 ? MIN(100.0, MAX(0.0, maximum / design * 100.0)) : 0;
}

- (double)chargingWatts {
    return fabs(self.voltageMillivolts.doubleValue * self.amperageMilliamps.doubleValue) / 1000000.0;
}

@end

@implementation IFCrashLog
@end

@implementation IFTweakRecord
@end

@implementation IFHealthItem
@end

@implementation IFMetricSample
@end

static NSNumber *IFNumberForKeys(NSDictionary *dictionary, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return value;
        }
    }
    return nil;
}

static NSDictionary *IFBatteryRegistryProperties(void) {
    typedef mach_port_t (*IFMatchingServiceFn)(mach_port_t, CFDictionaryRef);
    typedef CFMutableDictionaryRef (*IFServiceMatchingFn)(const char *);
    typedef kern_return_t (*IFCreatePropertiesFn)(mach_port_t, CFMutableDictionaryRef *, CFAllocatorRef, uint32_t);
    typedef kern_return_t (*IFObjectReleaseFn)(mach_port_t);

    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (handle == NULL) {
        return @{};
    }
    IFMatchingServiceFn matchingService = (IFMatchingServiceFn)dlsym(handle, "IOServiceGetMatchingService");
    IFServiceMatchingFn matching = (IFServiceMatchingFn)dlsym(handle, "IOServiceMatching");
    IFCreatePropertiesFn createProperties = (IFCreatePropertiesFn)dlsym(handle, "IORegistryEntryCreateCFProperties");
    IFObjectReleaseFn objectRelease = (IFObjectReleaseFn)dlsym(handle, "IOObjectRelease");
    if (matchingService == NULL || matching == NULL || createProperties == NULL || objectRelease == NULL) {
        dlclose(handle);
        return @{};
    }

    mach_port_t service = matchingService(0, matching("AppleSmartBattery"));
    if (service == 0) {
        dlclose(handle);
        return @{};
    }
    CFMutableDictionaryRef properties = NULL;
    kern_return_t result = createProperties(service, &properties, kCFAllocatorDefault, 0);
    objectRelease(service);
    NSDictionary *dictionary = result == KERN_SUCCESS && properties != NULL
        ? [(__bridge NSDictionary *)properties copy] : @{};
    if (properties != NULL) {
        CFRelease(properties);
    }
    dlclose(handle);
    return dictionary;
}

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *IFPackageRecords(void) {
    NSString *root = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ? @"/var/jb" : @"";
    NSString *statusPath = [root stringByAppendingString:@"/Library/dpkg/status"];
    NSString *contents = [NSString stringWithContentsOfFile:statusPath encoding:NSUTF8StringEncoding error:nil];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    for (NSString *stanza in [contents componentsSeparatedByString:@"\n\n"]) {
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        for (NSString *line in [stanza componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSRange separator = [line rangeOfString:@": "];
            if (separator.location == NSNotFound) {
                continue;
            }
            NSString *key = [line substringToIndex:separator.location];
            if ([key isEqualToString:@"Package"] || [key isEqualToString:@"Version"] || [key isEqualToString:@"Name"]) {
                record[key] = [line substringFromIndex:NSMaxRange(separator)];
            }
        }
        if ([record[@"Package"] length] > 0) {
            records[record[@"Package"]] = record;
        }
    }
    return records;
}

static NSDictionary<NSString *, NSString *> *IFDylibPackageMap(NSString *root) {
    NSString *infoDirectory = [root stringByAppendingString:@"/Library/dpkg/info"];
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:infoDirectory error:nil];
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSString *file in files) {
        if (![[file pathExtension] isEqualToString:@"list"]) {
            continue;
        }
        NSString *contents = [NSString stringWithContentsOfFile:[infoDirectory stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding error:nil];
        NSString *package = [file stringByDeletingPathExtension];
        for (NSString *path in [contents componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            if ([path.pathExtension.lowercaseString isEqualToString:@"dylib"]) {
                map[path.lastPathComponent.lowercaseString] = package;
            }
        }
    }
    return map;
}

static double IFSystemCPUPercent(void) {
    static host_cpu_load_info_data_t previous = {0};
    host_cpu_load_info_data_t current = {0};
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    mach_port_t host = mach_host_self();
    kern_return_t result = host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&current, &count);
    mach_port_deallocate(mach_task_self(), host);
    if (result != KERN_SUCCESS) {
        return 0;
    }
    uint64_t user = current.cpu_ticks[CPU_STATE_USER] - previous.cpu_ticks[CPU_STATE_USER];
    uint64_t system = current.cpu_ticks[CPU_STATE_SYSTEM] - previous.cpu_ticks[CPU_STATE_SYSTEM];
    uint64_t nice = current.cpu_ticks[CPU_STATE_NICE] - previous.cpu_ticks[CPU_STATE_NICE];
    uint64_t idle = current.cpu_ticks[CPU_STATE_IDLE] - previous.cpu_ticks[CPU_STATE_IDLE];
    previous = current;
    uint64_t total = user + system + nice + idle;
    return total > 0 ? (double)(user + system + nice) / (double)total * 100.0 : 0;
}

@interface IFLiveMetricsMonitor ()
@property (nonatomic, strong) NSMutableArray<IFMetricSample *> *mutableHistory;
@property (nonatomic, strong, readwrite) IFNetworkSnapshot *network;
@property (nonatomic, strong, readwrite) IFProcessMonitor *processes;
@property (nonatomic, strong) IFNetworkMonitor *networkMonitor;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *hotProcessCounts;
@end

@implementation IFLiveMetricsMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableHistory = [NSMutableArray array];
        _networkMonitor = [[IFNetworkMonitor alloc] init];
        _processes = [[IFProcessMonitor alloc] init];
        _network = [_networkMonitor refresh];
        _hotProcessCounts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSArray<IFMetricSample *> *)history {
    return [self.mutableHistory copy];
}

- (void)refresh {
    self.network = [self.networkMonitor refresh];
    [self.processes refresh];

    IFMetricSample *sample = [[IFMetricSample alloc] init];
    sample.date = [NSDate date];
    sample.cpuPercent = IFSystemCPUPercent();
    NSNumber *used = [IFetchCore usedMemoryBytes];
    sample.memoryPercent = used ? (double)used.unsignedLongLongValue / MAX(1.0, (double)[IFetchCore totalMemoryBytes]) * 100.0 : 0;
    sample.downloadBytesPerSecond = self.network.downloadBytesPerSecond;
    sample.uploadBytesPerSecond = self.network.uploadBytesPerSecond;
    IFBatteryDetails *battery = [IFDiagnostics batteryDetails];
    sample.batteryTemperature = battery.temperatureCelsius.doubleValue;
    sample.batteryLevel = battery.maximumCapacity.doubleValue > 0
        ? battery.currentCapacity.doubleValue / battery.maximumCapacity.doubleValue * 100.0 : 0;
    [self.mutableHistory addObject:sample];
    if (self.mutableHistory.count > 300) {
        [self.mutableHistory removeObjectsInRange:NSMakeRange(0, self.mutableHistory.count - 300)];
    }

    NSMutableDictionary *next = [NSMutableDictionary dictionary];
    for (IFProcessSample *process in [self.processes topProcessesByCPU:10]) {
        NSNumber *key = @(process.pid);
        NSInteger count = process.cpuPercent >= 35.0 ? [self.hotProcessCounts[key] integerValue] + 1 : 0;
        if (count > 0) {
            next[key] = @(count);
        }
    }
    self.hotProcessCounts = next;
}

- (NSArray<IFProcessSample *> *)sustainedHighCPUProcesses {
    NSMutableArray *result = [NSMutableArray array];
    for (IFProcessSample *sample in [self.processes topProcessesByCPU:20]) {
        if ([self.hotProcessCounts[@(sample.pid)] integerValue] >= 5) {
            [result addObject:sample];
        }
    }
    return result;
}

@end

@implementation IFDiagnostics

+ (IFBatteryDetails *)batteryDetails {
    NSDictionary *properties = IFBatteryRegistryProperties();
    IFBatteryDetails *details = [[IFBatteryDetails alloc] init];
    details.currentCapacity = IFNumberForKeys(properties, @[@"AppleRawCurrentCapacity", @"CurrentCapacity"]);
    details.maximumCapacity = IFNumberForKeys(properties, @[@"AppleRawMaxCapacity", @"NominalChargeCapacity", @"MaxCapacity"]);
    details.designCapacity = IFNumberForKeys(properties, @[@"DesignCapacity"]);
    details.cycleCount = IFNumberForKeys(properties, @[@"CycleCount", @"BatteryCycleCount"]);
    NSNumber *temperature = IFNumberForKeys(properties, @[@"Temperature"]);
    if (temperature != nil) {
        double raw = temperature.doubleValue;
        details.temperatureCelsius = @(raw > 1000 ? raw / 100.0 : raw > 100 ? raw / 10.0 : raw);
    }
    details.voltageMillivolts = IFNumberForKeys(properties, @[@"Voltage"]);
    details.amperageMilliamps = IFNumberForKeys(properties, @[@"Amperage", @"InstantAmperage"]);
    details.charging = [IFNumberForKeys(properties, @[@"IsCharging"]) boolValue];
    details.externalConnected = [IFNumberForKeys(properties, @[@"ExternalConnected"]) boolValue];
    return details;
}

+ (NSArray<IFCrashLog *> *)recentCrashLogsWithLimit:(NSUInteger)limit {
    NSURL *directory = [NSURL fileURLWithPath:@"/var/mobile/Library/Logs/CrashReporter"];
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory
                                                          includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               error:nil];
    urls = [urls sortedArrayUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
        NSDate *leftDate = nil;
        NSDate *rightDate = nil;
        [left getResourceValue:&leftDate forKey:NSURLContentModificationDateKey error:nil];
        [right getResourceValue:&rightDate forKey:NSURLContentModificationDateKey error:nil];
        return [rightDate ?: NSDate.distantPast compare:leftDate ?: NSDate.distantPast];
    }];

    NSMutableArray *logs = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSString *extension = url.pathExtension.lowercaseString;
        if (![@[@"ips", @"crash", @"panic", @"synced"] containsObject:extension]) {
            continue;
        }
        NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
        NSUInteger length = MIN((NSUInteger)65536, data.length);
        NSString *preview = length > 0 ? [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, length)]
                                                               encoding:NSUTF8StringEncoding] : @"";
        NSDate *date = nil;
        [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        IFCrashLog *log = [[IFCrashLog alloc] init];
        log.name = url.lastPathComponent;
        log.path = url.path;
        log.kind = extension.uppercaseString;
        log.date = date ?: NSDate.distantPast;
        log.preview = preview ?: IFD(@"Binary or unreadable crash report", @"Бинарный или нечитаемый crash-отчёт");
        [logs addObject:log];
        if (limit > 0 && logs.count >= limit) {
            break;
        }
    }
    return logs;
}

+ (NSArray<IFTweakRecord *> *)installedTweaks {
    NSString *root = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ? @"/var/jb" : @"";
    NSDictionary *packages = IFPackageRecords();
    NSDictionary *dylibPackages = IFDylibPackageMap(root);
    NSArray *directories = @[
        [root stringByAppendingString:@"/Library/MobileSubstrate/DynamicLibraries"],
        [root stringByAppendingString:@"/usr/lib/TweakInject"]
    ];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *directory in directories) {
        for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) {
            NSString *extension = file.pathExtension.lowercaseString;
            if (![@[@"dylib", @"disabled"] containsObject:extension]) {
                continue;
            }
            NSString *base = extension.length > 0 ? [file stringByDeletingPathExtension] : file;
            if ([seen containsObject:base.lowercaseString]) {
                continue;
            }
            [seen addObject:base.lowercaseString];
            NSString *path = [directory stringByAppendingPathComponent:file];
            NSString *plistPath = [directory stringByAppendingPathComponent:[base stringByAppendingPathExtension:@"plist"]];
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            NSDictionary *filter = [plist[@"Filter"] isKindOfClass:[NSDictionary class]] ? plist[@"Filter"] : @{};
            NSString *package = dylibPackages[file.lowercaseString] ?: @"";
            NSDictionary *packageRecord = packages[package] ?: @{};

            IFTweakRecord *record = [[IFTweakRecord alloc] init];
            record.name = [packageRecord[@"Name"] length] > 0 ? packageRecord[@"Name"] : base;
            record.dylibPath = path;
            record.packageIdentifier = package;
            record.packageVersion = packageRecord[@"Version"] ?: @"";
            record.targetBundles = [filter[@"Bundles"] isKindOfClass:[NSArray class]] ? filter[@"Bundles"] : @[];
            record.targetExecutables = [filter[@"Executables"] isKindOfClass:[NSArray class]] ? filter[@"Executables"] : @[];
            record.enabled = [extension isEqualToString:@"dylib"];
            [result addObject:record];
        }
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(IFTweakRecord *left, IFTweakRecord *right) {
        return [left.name localizedCaseInsensitiveCompare:right.name];
    }];
}

+ (NSArray<IFHealthItem *> *)healthItemsWithJailbreak:(IFJailbreakInfo *)jailbreak
                                              battery:(IFBatteryDetails *)battery
                                            processes:(NSArray<IFProcessSample *> *)hotProcesses {
    NSMutableArray *items = [NSMutableArray array];
    void (^add)(NSString *, NSString *, IFHealthState) = ^(NSString *title, NSString *detail, IFHealthState state) {
        IFHealthItem *item = [[IFHealthItem alloc] init];
        item.title = title;
        item.detail = detail;
        item.state = state;
        [items addObject:item];
    };

    BOOL rootless = [jailbreak.rootPrefix isEqualToString:@"/var/jb"];
    add(IFD(@"Rootless bootstrap", @"Rootless bootstrap"),
        rootless ? IFD(@"Available at /var/jb", @"Доступен в /var/jb") : IFD(@"Not detected", @"Не обнаружен"),
        rootless ? IFHealthStateGood : IFHealthStateProblem);

    BOOL injector = ![jailbreak.injectorDescription containsString:IFD(@"Not detected", @"Не обнаружен")];
    add(IFD(@"Hook injection", @"Инъекция твиков"), jailbreak.injectorDescription,
        injector ? IFHealthStateGood : IFHealthStateProblem);

    NSNumber *total = [IFetchCore totalStorageBytes];
    NSNumber *used = [IFetchCore usedStorageBytes];
    uint64_t free = total.unsignedLongLongValue > used.unsignedLongLongValue
        ? total.unsignedLongLongValue - used.unsignedLongLongValue : 0;
    IFHealthState storageState = free > 2ULL * 1024 * 1024 * 1024 ? IFHealthStateGood
        : free > 512ULL * 1024 * 1024 ? IFHealthStateWarning : IFHealthStateProblem;
    add(IFD(@"Free storage", @"Свободное место"), [IFetchCore formatBytes:free], storageState);

    IFHealthState batteryState = battery.healthPercent == 0 || battery.healthPercent >= 80
        ? IFHealthStateGood : battery.healthPercent >= 70 ? IFHealthStateWarning : IFHealthStateProblem;
    NSString *batteryText = battery.healthPercent > 0
        ? [NSString stringWithFormat:@"%.0f%%", battery.healthPercent] : IFD(@"Unavailable", @"Недоступно");
    add(IFD(@"Battery health", @"Здоровье аккумулятора"), batteryText, batteryState);

    double temperature = battery.temperatureCelsius.doubleValue;
    IFHealthState thermalState = temperature <= 0 || temperature < 38 ? IFHealthStateGood
        : temperature < 43 ? IFHealthStateWarning : IFHealthStateProblem;
    add(IFD(@"Battery temperature", @"Температура батареи"),
        temperature > 0 ? [NSString stringWithFormat:@"%.1f °C", temperature] : IFD(@"Unavailable", @"Недоступно"),
        thermalState);

    NSInteger crashCount = jailbreak.recentCrashCount;
    add(IFD(@"Recent crashes", @"Недавние сбои"),
        [NSString stringWithFormat:@"%ld / 24h", (long)crashCount],
        crashCount == 0 ? IFHealthStateGood : crashCount < 3 ? IFHealthStateWarning : IFHealthStateProblem);

    add(IFD(@"Sustained CPU load", @"Длительная нагрузка CPU"),
        hotProcesses.count == 0 ? IFD(@"No offenders", @"Проблем не найдено")
        : [hotProcesses valueForKey:@"name"] ? [[hotProcesses valueForKey:@"name"] componentsJoinedByString:@", "] : @"",
        hotProcesses.count == 0 ? IFHealthStateGood : IFHealthStateWarning);
    return items;
}

+ (NSDictionary<NSString *, id> *)extendedNetworkDetails {
    NSString *ipv4 = @"";
    NSString *ipv6 = @"";
    NSMutableDictionary<NSString *, NSDictionary *> *interfaces = [NSMutableDictionary dictionary];
    struct ifaddrs *addresses = NULL;
    if (getifaddrs(&addresses) == 0) {
        for (struct ifaddrs *cursor = addresses; cursor != NULL; cursor = cursor->ifa_next) {
            if (cursor->ifa_addr == NULL || cursor->ifa_name == NULL || (cursor->ifa_flags & IFF_UP) == 0) {
                continue;
            }
            NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
            int family = cursor->ifa_addr->sa_family;
            char buffer[INET6_ADDRSTRLEN] = {0};
            if (family == AF_INET) {
                struct sockaddr_in *address = (struct sockaddr_in *)cursor->ifa_addr;
                inet_ntop(AF_INET, &address->sin_addr, buffer, sizeof(buffer));
                if (([name isEqualToString:@"en0"] || [name hasPrefix:@"pdp_ip"]) && ipv4.length == 0) {
                    ipv4 = [NSString stringWithUTF8String:buffer] ?: @"";
                }
            } else if (family == AF_INET6) {
                struct sockaddr_in6 *address = (struct sockaddr_in6 *)cursor->ifa_addr;
                inet_ntop(AF_INET6, &address->sin6_addr, buffer, sizeof(buffer));
                NSString *candidate = [NSString stringWithUTF8String:buffer] ?: @"";
                if (([name isEqualToString:@"en0"] || [name hasPrefix:@"pdp_ip"]) &&
                    ![candidate hasPrefix:@"fe80"] && ipv6.length == 0) {
                    ipv6 = candidate;
                }
            } else if (family == AF_LINK && cursor->ifa_data != NULL && (cursor->ifa_flags & IFF_LOOPBACK) == 0) {
                const struct if_data *data = cursor->ifa_data;
                interfaces[name] = @{@"received": @(data->ifi_ibytes), @"sent": @(data->ifi_obytes)};
            }
        }
        freeifaddrs(addresses);
    }

    NSString *ssid = @"";
    NSString *bssid = @"";
    for (NSString *interface in (__bridge_transfer NSArray *)CNCopySupportedInterfaces() ?: @[]) {
        NSDictionary *network = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interface);
        if ([network[(NSString *)kCNNetworkInfoKeySSID] length] > 0) {
            ssid = network[(NSString *)kCNNetworkInfoKeySSID];
            bssid = network[(NSString *)kCNNetworkInfoKeyBSSID] ?: @"";
            break;
        }
    }

    NSString *radio = @"";
    @try {
        Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
        id networkInfo = networkInfoClass ? [[networkInfoClass alloc] init] : nil;
        NSDictionary *technologies = [networkInfo valueForKey:@"serviceCurrentRadioAccessTechnology"];
        radio = [[technologies allValues] firstObject] ?: [networkInfo valueForKey:@"currentRadioAccessTechnology"] ?: @"";
        radio = [[radio componentsSeparatedByString:@"."] lastObject];
        radio = [radio stringByReplacingOccurrencesOfString:@"CTRadioAccessTechnology" withString:@""];
    } @catch (__unused NSException *exception) {
        radio = @"";
    }

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    struct addrinfo *answer = NULL;
    int dnsResult = getaddrinfo("api.ipify.org", "443", NULL, &answer);
    if (answer != NULL) {
        freeaddrinfo(answer);
    }
    double dnsMilliseconds = dnsResult == 0 ? (CFAbsoluteTimeGetCurrent() - start) * 1000.0 : -1;

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL internetAvailable = NO;
    __block double internetMilliseconds = -1;
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 4;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.ipify.org"]];
    request.HTTPMethod = @"HEAD";
    CFAbsoluteTime requestStart = CFAbsoluteTimeGetCurrent();
    [[session dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        internetAvailable = error == nil && status >= 200 && status < 500;
        if (internetAvailable) {
            internetMilliseconds = (CFAbsoluteTimeGetCurrent() - requestStart) * 1000.0;
        }
        dispatch_semaphore_signal(semaphore);
    }] resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    [session finishTasksAndInvalidate];
    return @{
        @"ipv4": ipv4,
        @"ipv6": ipv6,
        @"ssid": ssid,
        @"bssid": bssid,
        @"radio": radio,
        @"interfaces": interfaces,
        @"dnsLatency": @(dnsMilliseconds),
        @"internetAvailable": @(internetAvailable),
        @"internetLatency": @(internetMilliseconds)
    };
}

+ (NSString *)redactedAddress:(NSString *)address {
    if ([address containsString:@":"]) {
        NSArray *parts = [address componentsSeparatedByString:@":"];
        return parts.count > 2 ? [NSString stringWithFormat:@"%@:%@:…", parts[0], parts[1]] : @"…";
    }
    NSArray *parts = [address componentsSeparatedByString:@"."];
    return parts.count == 4 ? [NSString stringWithFormat:@"%@.%@.*.*", parts[0], parts[1]] : @"…";
}

@end
