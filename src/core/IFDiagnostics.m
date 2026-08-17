#import "IFDiagnostics.h"
#import "IFJailbreakPaths.h"

#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
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

static NSString *IFStringFromWiFiValue(CFTypeRef value) {
    if (value == NULL) {
        return @"";
    }
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return [(__bridge NSString *)value copy];
    }
    if (CFGetTypeID(value) == CFDataGetTypeID()) {
        NSData *data = (__bridge NSData *)value;
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (string.length > 0) {
            return string;
        }
        if (data.length == 6) {
            const uint8_t *bytes = data.bytes;
            return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                    bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
        }
    }
    return @"";
}

static NSDictionary<NSString *, NSString *> *IFMobileWiFiInfo(void) {
    typedef CFTypeRef (*IFWiFiManagerCreateFn)(CFAllocatorRef, CFTypeRef);
    typedef CFArrayRef (*IFWiFiManagerCopyDevicesFn)(CFTypeRef);
    typedef CFTypeRef (*IFWiFiDeviceCopyCurrentNetworkFn)(CFTypeRef);
    typedef CFTypeRef (*IFWiFiNetworkGetValueFn)(CFTypeRef);
    typedef CFTypeRef (*IFWiFiNetworkGetPropertyFn)(CFTypeRef, CFStringRef);

    NSString *ssid = @"";
    NSString *bssid = @"";
    void *handle = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",
                          RTLD_LAZY | RTLD_LOCAL);
    if (handle == NULL) {
        return @{@"ssid": ssid, @"bssid": bssid};
    }

    IFWiFiManagerCreateFn createManager = (IFWiFiManagerCreateFn)dlsym(handle, "WiFiManagerClientCreate");
    IFWiFiManagerCopyDevicesFn copyDevices = (IFWiFiManagerCopyDevicesFn)dlsym(handle, "WiFiManagerClientCopyDevices");
    IFWiFiDeviceCopyCurrentNetworkFn copyCurrentNetwork =
        (IFWiFiDeviceCopyCurrentNetworkFn)dlsym(handle, "WiFiDeviceClientCopyCurrentNetwork");
    IFWiFiNetworkGetValueFn getSSID = (IFWiFiNetworkGetValueFn)dlsym(handle, "WiFiNetworkGetSSID");
    IFWiFiNetworkGetValueFn getLastBSSID = (IFWiFiNetworkGetValueFn)dlsym(handle, "WiFiNetworkGetLastBSSID");
    IFWiFiNetworkGetValueFn copyBSSIDData = (IFWiFiNetworkGetValueFn)dlsym(handle, "WiFiNetworkCopyBSSIDData");
    IFWiFiNetworkGetPropertyFn getProperty =
        (IFWiFiNetworkGetPropertyFn)dlsym(handle, "WiFiNetworkGetProperty");

    if (createManager == NULL || copyCurrentNetwork == NULL) {
        dlclose(handle);
        return @{@"ssid": ssid, @"bssid": bssid};
    }

    CFTypeRef manager = createManager(kCFAllocatorDefault, NULL);
    CFArrayRef devices = manager != NULL && copyDevices != NULL ? copyDevices(manager) : NULL;
    CFTypeRef device = NULL;
    if (devices != NULL && CFArrayGetCount(devices) > 0) {
        device = CFArrayGetValueAtIndex(devices, 0);
    }

    CFTypeRef network = device != NULL ? copyCurrentNetwork(device) : NULL;
    if (network != NULL) {
        if (getSSID != NULL) {
            ssid = IFStringFromWiFiValue(getSSID(network));
        }
        if (ssid.length == 0 && getProperty != NULL) {
            ssid = IFStringFromWiFiValue(getProperty(network, CFSTR("SSID")));
        }

        if (getProperty != NULL) {
            bssid = IFStringFromWiFiValue(getProperty(network, CFSTR("BSSID")));
        }
        if (bssid.length == 0 && getLastBSSID != NULL) {
            bssid = IFStringFromWiFiValue(getLastBSSID(network));
        }
        if (bssid.length == 0 && copyBSSIDData != NULL) {
            CFTypeRef data = copyBSSIDData(network);
            bssid = IFStringFromWiFiValue(data);
            if (data != NULL) {
                CFRelease(data);
            }
        }
        CFRelease(network);
    }
    if (devices != NULL) {
        CFRelease(devices);
    }
    if (manager != NULL) {
        CFRelease(manager);
    }
    dlclose(handle);
    return @{@"ssid": ssid ?: @"", @"bssid": bssid ?: @""};
}

static NSDictionary<NSString *, NSString *> *IFCurrentWiFiInfo(void) {
    __block NSString *ssid = @"";
    __block NSString *bssid = @"";

    if (@available(iOS 14.0, *)) {
        if ([NEHotspotNetwork respondsToSelector:@selector(fetchCurrentWithCompletionHandler:)]) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork *network) {
                ssid = network.SSID ?: @"";
                bssid = network.BSSID ?: @"";
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        }
    }

    if (ssid.length == 0) {
        CFArrayRef supported = CNCopySupportedInterfaces();
        NSArray *interfaces = CFBridgingRelease(supported) ?: @[];
        for (NSString *interface in interfaces) {
            CFDictionaryRef current = CNCopyCurrentNetworkInfo((__bridge CFStringRef)interface);
            NSDictionary *network = CFBridgingRelease(current);
            NSString *candidateSSID = network[(NSString *)kCNNetworkInfoKeySSID];
            if (candidateSSID.length > 0) {
                ssid = candidateSSID;
                bssid = network[(NSString *)kCNNetworkInfoKeyBSSID] ?: @"";
                break;
            }
        }
    }
    if (ssid.length == 0 || bssid.length == 0) {
        NSDictionary<NSString *, NSString *> *privateInfo = IFMobileWiFiInfo();
        if (ssid.length == 0) {
            ssid = privateInfo[@"ssid"] ?: @"";
        }
        if (bssid.length == 0) {
            bssid = privateInfo[@"bssid"] ?: @"";
        }
    }
    return @{@"ssid": ssid, @"bssid": bssid};
}

static NSDictionary<NSString *, id> *IFHTTPSProbe(void) {
    NSArray<NSString *> *endpoints = @[
        @"https://api.ipify.org/",
        @"https://captive.apple.com/hotspot-detect.html"
    ];
    __block NSString *lastError = @"";
    for (NSString *endpoint in endpoints) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block BOOL available = NO;
        __block double milliseconds = -1;
        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.timeoutIntervalForRequest = 5;
        configuration.timeoutIntervalForResource = 6;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
        request.HTTPMethod = @"GET";
        request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        [request setValue:[NSString stringWithFormat:@"iFetch/%@", [IFetchCore versionString]]
       forHTTPHeaderField:@"User-Agent"];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [[session dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
            available = error == nil && status >= 200 && status < 500;
            if (available) {
                milliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000.0;
            } else {
                lastError = error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld", (long)status];
            }
            dispatch_semaphore_signal(semaphore);
        }] resume];
        long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 7 * NSEC_PER_SEC));
        if (waitResult != 0) {
            lastError = IFD(@"Request timed out", @"Превышено время ожидания");
        }
        [session finishTasksAndInvalidate];
        if (available) {
            return @{@"available": @YES, @"latency": @(milliseconds), @"endpoint": endpoint, @"error": @""};
        }
    }
    return @{@"available": @NO, @"latency": @(-1), @"endpoint": @"", @"error": lastError};
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
    NSString *root = IFBootstrapRootPath();
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
    NSArray *keys = @[NSURLContentModificationDateKey, NSURLIsRegularFileKey];
    NSDirectoryEnumerator<NSURL *> *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directory
                                                                     includingPropertiesForKeys:keys
                                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   errorHandler:nil];
    NSMutableArray<NSURL *> *found = [NSMutableArray array];
    for (NSURL *url in enumerator) {
        NSNumber *regular = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        NSString *extension = url.pathExtension.lowercaseString;
        if (regular.boolValue && [@[@"ips", @"crash", @"panic", @"synced"] containsObject:extension]) {
            [found addObject:url];
        }
    }
    NSArray<NSURL *> *urls = [found sortedArrayUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
        NSDate *leftDate = nil;
        NSDate *rightDate = nil;
        [left getResourceValue:&leftDate forKey:NSURLContentModificationDateKey error:nil];
        [right getResourceValue:&rightDate forKey:NSURLContentModificationDateKey error:nil];
        return [rightDate ?: NSDate.distantPast compare:leftDate ?: NSDate.distantPast];
    }];

    NSMutableArray *logs = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSString *extension = url.pathExtension.lowercaseString;
        NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
        NSUInteger length = MIN((NSUInteger)(2 * 1024 * 1024), data.length);
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
    NSString *root = IFBootstrapRootPath();
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
    void (^add)(NSString *, NSString *, NSString *, IFHealthState) =
        ^(NSString *identifier, NSString *title, NSString *detail, IFHealthState state) {
        IFHealthItem *item = [[IFHealthItem alloc] init];
        item.identifier = identifier;
        item.title = title;
        item.detail = detail;
        item.state = state;
        [items addObject:item];
    };

    BOOL bootstrap = jailbreak.rootPrefix.length > 0;
    NSString *bootstrapName = IFRootHideRuntime() ? @"RootHide bootstrap" : @"Rootless bootstrap";
    NSString *bootstrapDetail = IFRootHideRuntime()
        ? IFD(@"Available through randomized jbroot", @"Доступен через случайный jbroot")
        : bootstrap ? IFD(@"Available at /var/jb", @"Доступен в /var/jb")
                    : IFD(@"Not detected", @"Не обнаружен");
    add(@"bootstrap", bootstrapName, bootstrapDetail,
        bootstrap ? IFHealthStateGood : IFHealthStateProblem);

    BOOL injector = ![jailbreak.injectorDescription containsString:IFD(@"Not detected", @"Не обнаружен")];
    add(@"injector", IFD(@"Hook injection", @"Инъекция твиков"), jailbreak.injectorDescription,
        injector ? IFHealthStateGood : IFHealthStateProblem);

    NSNumber *total = [IFetchCore totalStorageBytes];
    NSNumber *used = [IFetchCore usedStorageBytes];
    uint64_t free = total.unsignedLongLongValue > used.unsignedLongLongValue
        ? total.unsignedLongLongValue - used.unsignedLongLongValue : 0;
    IFHealthState storageState = free > 2ULL * 1024 * 1024 * 1024 ? IFHealthStateGood
        : free > 512ULL * 1024 * 1024 ? IFHealthStateWarning : IFHealthStateProblem;
    add(@"storage", IFD(@"Free storage", @"Свободное место"), [IFetchCore formatBytes:free], storageState);

    IFHealthState batteryState = battery.healthPercent == 0 || battery.healthPercent >= 80
        ? IFHealthStateGood : battery.healthPercent >= 70 ? IFHealthStateWarning : IFHealthStateProblem;
    NSString *batteryText = battery.healthPercent > 0
        ? [NSString stringWithFormat:@"%.0f%%", battery.healthPercent] : IFD(@"Unavailable", @"Недоступно");
    add(@"battery_health", IFD(@"Battery health", @"Здоровье аккумулятора"), batteryText, batteryState);

    double temperature = battery.temperatureCelsius.doubleValue;
    IFHealthState thermalState = temperature <= 0 || temperature < 38 ? IFHealthStateGood
        : temperature < 43 ? IFHealthStateWarning : IFHealthStateProblem;
    add(@"battery_temperature", IFD(@"Battery temperature", @"Температура батареи"),
        temperature > 0 ? [NSString stringWithFormat:@"%.1f °C", temperature] : IFD(@"Unavailable", @"Недоступно"),
        thermalState);

    NSInteger thermalRaw = [IFetchCore thermalStateRaw];
    NSString *thermalDesc = [IFetchCore thermalStateDescription];
    IFHealthState thermalSysState = thermalRaw <= 0 ? IFHealthStateGood
        : (thermalRaw == 1 ? IFHealthStateGood : (thermalRaw == 2 ? IFHealthStateWarning : IFHealthStateProblem));
    add(@"thermal_state", IFD(@"Thermal status", @"Термальное состояние"),
        thermalDesc, thermalSysState);

    for (IFProcessSample *proc in hotProcesses) {
        if (proc.jetsamLimitBytes > 0 && proc.jetsamUsagePercent >= 80.0) {
            add(@"jetsam_warning", IFD(@"Jetsam memory pressure", @"Нагрузка на лимит Jetsam"),
                [NSString stringWithFormat:@"%@ (PID %d): %.1f%% (%@)",
                 proc.name, proc.pid, proc.jetsamUsagePercent, [IFetchCore formatBytes:proc.jetsamLimitBytes]],
                proc.jetsamUsagePercent >= 95.0 ? IFHealthStateProblem : IFHealthStateWarning);
            break;
        }
    }

    NSInteger crashCount = jailbreak.recentCrashCount;
    add(@"recent_crashes", IFD(@"Recent crashes", @"Недавние сбои"),
        [NSString stringWithFormat:@"%ld / 24h", (long)crashCount],
        crashCount == 0 ? IFHealthStateGood : crashCount < 3 ? IFHealthStateWarning : IFHealthStateProblem);

    add(@"cpu_load", IFD(@"Sustained CPU load", @"Длительная нагрузка CPU"),
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

    NSDictionary *wifi = IFCurrentWiFiInfo();
    NSString *ssid = wifi[@"ssid"];
    NSString *bssid = wifi[@"bssid"];

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

    NSDictionary *httpsProbe = IFHTTPSProbe();
    return @{
        @"ipv4": ipv4,
        @"ipv6": ipv6,
        @"ssid": ssid,
        @"bssid": bssid,
        @"radio": radio,
        @"interfaces": interfaces,
        @"dnsLatency": @(dnsMilliseconds),
        @"internetAvailable": httpsProbe[@"available"],
        @"internetLatency": httpsProbe[@"latency"],
        @"internetEndpoint": httpsProbe[@"endpoint"],
        @"internetError": httpsProbe[@"error"]
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

+ (NSDictionary<NSString *, id> *)generateDiagnosticReportDictionary {
    IFDeviceInfo *device = [IFDeviceInfo currentDevice];
    IFJailbreakInfo *jailbreak = [IFetchCore jailbreakInfo];
    IFBatteryDetails *battery = [self batteryDetails];
    IFProcessMonitor *monitor = [[IFProcessMonitor alloc] init];
    [monitor refresh];

    NSNumber *usedMemory = [IFetchCore usedMemoryBytes] ?: @0;
    NSNumber *totalStorage = [IFetchCore totalStorageBytes] ?: @0;
    NSNumber *usedStorage = [IFetchCore usedStorageBytes] ?: @0;

    NSMutableArray *activeTweaks = [NSMutableArray array];
    for (IFTweakRecord *tweak in [self installedTweaks]) {
        [activeTweaks addObject:@{
            @"name": tweak.name ?: @"",
            @"path": tweak.dylibPath ?: @"",
            @"package": tweak.packageIdentifier ?: @"",
            @"version": tweak.packageVersion ?: @"",
            @"enabled": @(tweak.isEnabled)
        }];
    }

    NSMutableArray *crashes = [NSMutableArray array];
    for (IFCrashLog *log in [self recentCrashLogsWithLimit:5]) {
        [crashes addObject:@{
            @"name": log.name ?: @"",
            @"date": log.date ? [log.date description] : @"",
            @"kind": log.kind ?: @"",
            @"path": log.path ?: @""
        }];
    }

    NSMutableArray *cpuProcs = [NSMutableArray array];
    for (IFProcessSample *sample in [monitor topProcessesByCPU:5]) {
        [cpuProcs addObject:@{
            @"pid": @(sample.pid),
            @"name": sample.name ?: @"",
            @"cpu_percent": @(sample.cpuPercent),
            @"resident_bytes": @(sample.residentBytes),
            @"jetsam_band": sample.jetsamBandName ?: @"",
            @"jetsam_priority": @(sample.jetsamPriority),
            @"jetsam_limit_bytes": @(sample.jetsamLimitBytes),
            @"jetsam_usage_percent": @(sample.jetsamUsagePercent)
        }];
    }

    NSMutableArray *memProcs = [NSMutableArray array];
    for (IFProcessSample *sample in [monitor topProcessesByMemory:5]) {
        [memProcs addObject:@{
            @"pid": @(sample.pid),
            @"name": sample.name ?: @"",
            @"cpu_percent": @(sample.cpuPercent),
            @"resident_bytes": @(sample.residentBytes),
            @"jetsam_band": sample.jetsamBandName ?: @"",
            @"jetsam_priority": @(sample.jetsamPriority),
            @"jetsam_limit_bytes": @(sample.jetsamLimitBytes),
            @"jetsam_usage_percent": @(sample.jetsamUsagePercent)
        }];
    }

    NSMutableArray *jetsamProcs = [NSMutableArray array];
    for (IFProcessSample *sample in [monitor topProcessesByJetsamPressure:5]) {
        [jetsamProcs addObject:@{
            @"pid": @(sample.pid),
            @"name": sample.name ?: @"",
            @"resident_bytes": @(sample.residentBytes),
            @"jetsam_band": sample.jetsamBandName ?: @"",
            @"jetsam_priority": @(sample.jetsamPriority),
            @"jetsam_limit_bytes": @(sample.jetsamLimitBytes),
            @"jetsam_usage_percent": @(sample.jetsamUsagePercent)
        }];
    }

    NSMutableArray *healthList = [NSMutableArray array];
    for (IFHealthItem *item in [self healthItemsWithJailbreak:jailbreak battery:battery processes:[monitor topProcessesByCPU:3]]) {
        NSString *stateName = item.state == IFHealthStateGood ? @"Good" : (item.state == IFHealthStateWarning ? @"Warning" : @"Problem");
        [healthList addObject:@{
            @"id": item.identifier ?: @"",
            @"title": item.title ?: @"",
            @"detail": item.detail ?: @"",
            @"state": stateName
        }];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    return @{
        @"report_version": [IFetchCore versionString],
        @"timestamp": timestamp,
        @"device": @{
            @"model": device.modelName ?: @"",
            @"identifier": device.identifier ?: @"",
            @"chip": device.chipName ?: @"",
            @"architecture": device.architectureName ?: @"",
            @"os_version": NSProcessInfo.processInfo.operatingSystemVersionString,
            @"darwin_version": [IFetchCore darwinVersion],
            @"uptime": [IFetchCore systemUptime]
        },
        @"thermal": @{
            @"state": [IFetchCore thermalStateDescription],
            @"state_raw": @([IFetchCore thermalStateRaw]),
            @"throttling": @([IFetchCore isThermalThrottling]),
            @"summary": [IFetchCore thermalThrottlingSummary]
        },
        @"battery": @{
            @"health_percent": @(battery.healthPercent),
            @"current_capacity_mah": battery.currentCapacity ?: @0,
            @"maximum_capacity_mah": battery.maximumCapacity ?: @0,
            @"design_capacity_mah": battery.designCapacity ?: @0,
            @"cycle_count": battery.cycleCount ?: @0,
            @"temperature_celsius": battery.temperatureCelsius ?: @0,
            @"voltage_mv": battery.voltageMillivolts ?: @0,
            @"amperage_ma": battery.amperageMilliamps ?: @0,
            @"charging_watts": @(battery.chargingWatts),
            @"charging": @(battery.charging)
        },
        @"memory_storage": @{
            @"memory_total_bytes": @([IFetchCore totalMemoryBytes]),
            @"memory_used_bytes": usedMemory,
            @"storage_total_bytes": totalStorage,
            @"storage_used_bytes": usedStorage
        },
        @"jailbreak": @{
            @"environment": jailbreak.environmentName ?: @"",
            @"root_prefix": jailbreak.rootPrefix ?: @"",
            @"injector": jailbreak.injectorDescription ?: @"",
            @"packages_count": @(jailbreak.installedPackageCount),
            @"active_tweaks_count": @(jailbreak.activeTweakCount),
            @"crash_logs_24h": @(jailbreak.recentCrashCount)
        },
        @"tweaks": activeTweaks,
        @"recent_crashes": crashes,
        @"top_cpu_processes": cpuProcs,
        @"top_memory_processes": memProcs,
        @"top_jetsam_processes": jetsamProcs,
        @"health": healthList,
        @"network": [self extendedNetworkDetails]
    };
}

+ (NSString *)generateDiagnosticReportMarkdown {
    NSDictionary<NSString *, id> *dict = [self generateDiagnosticReportDictionary];
    NSDictionary *device = dict[@"device"];
    NSDictionary *thermal = dict[@"thermal"];
    NSDictionary *battery = dict[@"battery"];
    NSDictionary *memStorage = dict[@"memory_storage"];
    NSDictionary *jailbreak = dict[@"jailbreak"];
    NSArray *tweaks = dict[@"tweaks"];
    NSArray *crashes = dict[@"recent_crashes"];
    NSArray *cpuProcs = dict[@"top_cpu_processes"];
    NSArray *memProcs = dict[@"top_memory_processes"];
    NSArray *jetsamProcs = dict[@"top_jetsam_processes"];
    NSArray *health = dict[@"health"];
    NSDictionary *network = dict[@"network"];

    NSMutableString *md = [NSMutableString string];
    [md appendFormat:@"# iFetch System Diagnostics Report\n"];
    [md appendFormat:@"*Generated: %@ (iFetch v%@)*\n\n", dict[@"timestamp"], dict[@"report_version"]];

    [md appendString:@"## 📱 Device & Operating System\n"];
    [md appendFormat:@"- **Model:** %@ (`%@`)\n", device[@"model"], device[@"identifier"]];
    [md appendFormat:@"- **Chip / Architecture:** %@ (`%@`)\n", device[@"chip"], device[@"architecture"]];
    [md appendFormat:@"- **OS Version:** %@\n", device[@"os_version"]];
    [md appendFormat:@"- **Darwin Kernel:** %@\n", device[@"darwin_version"]];
    [md appendFormat:@"- **System Uptime:** %@\n\n", device[@"uptime"]];

    [md appendString:@"## 🌡️ Thermal State & Throttling\n"];
    [md appendFormat:@"- **Thermal Status:** %@\n", thermal[@"state"]];
    [md appendFormat:@"- **Throttling Active:** %@\n", [thermal[@"throttling"] boolValue] ? @"YES" : @"NO"];
    [md appendFormat:@"- **Impact:** %@\n\n", thermal[@"summary"]];

    [md appendString:@"## 🔋 Battery Health & Power\n"];
    double batteryHealth = [battery[@"health_percent"] doubleValue];
    if (batteryHealth > 0) {
        [md appendFormat:@"- **Battery Health:** %.1f%% (Max: %@ mAh / Design: %@ mAh)\n",
         batteryHealth, battery[@"maximum_capacity_mah"], battery[@"design_capacity_mah"]];
    } else {
        [md appendString:@"- **Battery Health:** Unavailable\n"];
    }
    [md appendFormat:@"- **Cycle Count:** %@\n", battery[@"cycle_count"]];
    [md appendFormat:@"- **Temperature:** %.1f °C\n", [battery[@"temperature_celsius"] doubleValue]];
    [md appendFormat:@"- **Power Draw / Charge:** %.2f W (%@)\n\n",
     [battery[@"charging_watts"] doubleValue], [battery[@"charging"] boolValue] ? @"Charging" : @"Discharging"];

    [md appendString:@"## 💾 Memory & Storage\n"];
    uint64_t memUsed = [memStorage[@"memory_used_bytes"] unsignedLongLongValue];
    uint64_t memTotal = [memStorage[@"memory_total_bytes"] unsignedLongLongValue];
    double memPercent = memTotal > 0 ? ((double)memUsed / (double)memTotal) * 100.0 : 0;
    [md appendFormat:@"- **RAM Usage:** %@ / %@ (%.1f%%)\n",
     [IFetchCore formatBytes:memUsed], [IFetchCore formatBytes:memTotal], memPercent];

    uint64_t storUsed = [memStorage[@"storage_used_bytes"] unsignedLongLongValue];
    uint64_t storTotal = [memStorage[@"storage_total_bytes"] unsignedLongLongValue];
    double storPercent = storTotal > 0 ? ((double)storUsed / (double)storTotal) * 100.0 : 0;
    [md appendFormat:@"- **Storage:** %@ / %@ (%.1f%%)\n\n",
     [IFetchCore formatBytes:storUsed], [IFetchCore formatBytes:storTotal], storPercent];

    [md appendString:@"## 🔓 Jailbreak Environment\n"];
    [md appendFormat:@"- **Environment:** %@\n", jailbreak[@"environment"]];
    [md appendFormat:@"- **Root Prefix:** `%@`\n", jailbreak[@"root_prefix"]];
    [md appendFormat:@"- **Tweak Injector:** %@\n", jailbreak[@"injector"]];
    [md appendFormat:@"- **Installed Packages:** %@\n", jailbreak[@"packages_count"]];
    [md appendFormat:@"- **Active Tweaks:** %@\n", jailbreak[@"active_tweaks_count"]];
    [md appendFormat:@"- **Crashes in Last 24h:** %@\n\n", jailbreak[@"crash_logs_24h"]];

    [md appendFormat:@"## 🧩 Active Tweaks (%lu)\n", (unsigned long)tweaks.count];
    if (tweaks.count == 0) {
        [md appendString:@"*No tweaks detected.*\n\n"];
    } else {
        for (NSDictionary *tweak in tweaks) {
            NSString *ver = [tweak[@"version"] length] > 0 ? [NSString stringWithFormat:@" v%@", tweak[@"version"]] : @"";
            NSString *pkg = [tweak[@"package"] length] > 0 ? [NSString stringWithFormat:@" (`%@`)", tweak[@"package"]] : @"";
            [md appendFormat:@"- **%@**%@%@ — `%@`\n", tweak[@"name"], ver, pkg, tweak[@"path"]];
        }
        [md appendString:@"\n"];
    }

    [md appendString:@"## 🛡️ System Health Checks\n"];
    for (NSDictionary *item in health) {
        NSString *icon = [item[@"state"] isEqualToString:@"Good"] ? @"✅" : ([item[@"state"] isEqualToString:@"Warning"] ? @"⚠️" : @"❌");
        [md appendFormat:@"- %ux200b%@ **%@:** %@\n", 0, icon, item[@"title"], item[@"detail"]];
    }
    [md appendString:@"\n"];

    [md appendString:@"## 💥 Recent Crash Logs\n"];
    if (crashes.count == 0) {
        [md appendString:@"*No recent crash logs found.*\n\n"];
    } else {
        for (NSDictionary *crash in crashes) {
            [md appendFormat:@"- **%@** | Kind: `%@` | Date: %@\n", crash[@"name"], crash[@"kind"], crash[@"date"]];
        }
        [md appendString:@"\n"];
    }

    [md appendString:@"## ⚙️ Top Processes (RAM / CPU / Jetsam)\n"];
    [md appendString:@"### Top CPU Consumers\n"];
    for (NSDictionary *p in cpuProcs) {
        [md appendFormat:@"- **%@** (PID %@): %.1f%% CPU, %@ RAM, Jetsam Band: %@\n",
         p[@"name"], p[@"pid"], [p[@"cpu_percent"] doubleValue], [IFetchCore formatBytes:[p[@"resident_bytes"] unsignedLongLongValue]], p[@"jetsam_band"]];
    }

    [md appendString:@"\n### Top Memory Consumers & Jetsam Limits\n"];
    for (NSDictionary *p in memProcs) {
        uint64_t limit = [p[@"jetsam_limit_bytes"] unsignedLongLongValue];
        NSString *limitStr = limit > 0
            ? [NSString stringWithFormat:@"Limit: %@ (%.1f%% used)", [IFetchCore formatBytes:limit], [p[@"jetsam_usage_percent"] doubleValue]]
            : @"Limit: Default/Unlimited";
        [md appendFormat:@"- **%@** (PID %@): %@ RAM | Band: %@ | %@\n",
         p[@"name"], p[@"pid"], [IFetchCore formatBytes:[p[@"resident_bytes"] unsignedLongLongValue]], p[@"jetsam_band"], limitStr];
    }

    [md appendString:@"\n## 🌐 Network Status\n"];
    [md appendFormat:@"- **Local IP:** %@\n", network[@"ipv4"] ?: @"—"];
    if ([network[@"ssid"] length] > 0) {
        [md appendFormat:@"- **Wi-Fi SSID:** %@\n", network[@"ssid"]];
    }
    if ([network[@"radio"] length] > 0) {
        [md appendFormat:@"- **Cellular Radio:** %@\n", network[@"radio"]];
    }
    if ([network[@"dnsLatency"] doubleValue] >= 0) {
        [md appendFormat:@"- **DNS Query Latency:** %.1f ms\n", [network[@"dnsLatency"] doubleValue]];
    }
    [md appendFormat:@"- **Internet Probe:** %@ (Latency: %@)\n\n",
     [network[@"internetAvailable"] boolValue] ? @"Online" : @"Offline", network[@"internetLatency"] ?: @"—"];

    [md appendString:@"---\n*Report generated by iFetch.*\n"];
    return md;
}

@end
