#import "IFetchCore.h"

#import <arpa/inet.h>
#import <dlfcn.h>
#import <ifaddrs.h>
#import <mach/mach.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSString *IFHardwareIdentifier(void) {
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0) {
        return @"iPhone";
    }

    char *machine = calloc(size, sizeof(char));
    if (machine == NULL) {
        return @"iPhone";
    }

    NSString *identifier = @"iPhone";
    if (sysctlbyname("hw.machine", machine, &size, NULL, 0) == 0) {
        identifier = [NSString stringWithUTF8String:machine] ?: @"iPhone";
    }
    free(machine);
    return identifier;
}

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *IFDeviceCatalog(void) {
    static NSDictionary *catalog;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        catalog = @{
            @"iPhone8,1":  @{@"name": @"iPhone 6s",       @"chip": @"Apple A9",  @"image": @"iphone-6s.png"},
            @"iPhone8,2":  @{@"name": @"iPhone 6s Plus",  @"chip": @"Apple A9",  @"image": @"iphone-6s-plus.png"},
            @"iPhone8,4":  @{@"name": @"iPhone SE",       @"chip": @"Apple A9",  @"image": @"iphone-se-1.png"},
            @"iPhone9,1":  @{@"name": @"iPhone 7",        @"chip": @"Apple A10 Fusion", @"image": @"iphone-7.png"},
            @"iPhone9,3":  @{@"name": @"iPhone 7",        @"chip": @"Apple A10 Fusion", @"image": @"iphone-7.png"},
            @"iPhone9,2":  @{@"name": @"iPhone 7 Plus",   @"chip": @"Apple A10 Fusion", @"image": @"iphone-7-plus.png"},
            @"iPhone9,4":  @{@"name": @"iPhone 7 Plus",   @"chip": @"Apple A10 Fusion", @"image": @"iphone-7-plus.png"},
            @"iPhone10,1": @{@"name": @"iPhone 8",        @"chip": @"Apple A11 Bionic", @"image": @"iphone-8.png"},
            @"iPhone10,4": @{@"name": @"iPhone 8",        @"chip": @"Apple A11 Bionic", @"image": @"iphone-8.png"},
            @"iPhone10,2": @{@"name": @"iPhone 8 Plus",   @"chip": @"Apple A11 Bionic", @"image": @"iphone-8-plus.png"},
            @"iPhone10,5": @{@"name": @"iPhone 8 Plus",   @"chip": @"Apple A11 Bionic", @"image": @"iphone-8-plus.png"},
            @"iPhone10,3": @{@"name": @"iPhone X",        @"chip": @"Apple A11 Bionic", @"image": @"iphone-x.png"},
            @"iPhone10,6": @{@"name": @"iPhone X",        @"chip": @"Apple A11 Bionic", @"image": @"iphone-x.png"},
            @"iPhone11,2": @{@"name": @"iPhone XS",       @"chip": @"Apple A12 Bionic", @"image": @"iphone-xs.png", @"arch": @"arm64e"},
            @"iPhone11,4": @{@"name": @"iPhone XS Max",   @"chip": @"Apple A12 Bionic", @"image": @"iphone-xs-max.png", @"arch": @"arm64e"},
            @"iPhone11,6": @{@"name": @"iPhone XS Max",   @"chip": @"Apple A12 Bionic", @"image": @"iphone-xs-max.png", @"arch": @"arm64e"},
            @"iPhone11,8": @{@"name": @"iPhone XR",       @"chip": @"Apple A12 Bionic", @"image": @"iphone-xr.png", @"arch": @"arm64e"},
            @"iPhone12,1": @{@"name": @"iPhone 11",       @"chip": @"Apple A13 Bionic", @"image": @"iphone-11.png"},
            @"iPhone12,3": @{@"name": @"iPhone 11 Pro",   @"chip": @"Apple A13 Bionic", @"image": @"iphone-11-pro.png"},
            @"iPhone12,5": @{@"name": @"iPhone 11 Pro Max", @"chip": @"Apple A13 Bionic", @"image": @"iphone-11-pro-max.png"},
            @"iPhone12,8": @{@"name": @"iPhone SE (2-го поколения)", @"chip": @"Apple A13 Bionic", @"image": @"iphone-se-2.png"},
            @"iPhone13,1": @{@"name": @"iPhone 12 mini",  @"chip": @"Apple A14 Bionic", @"image": @"iphone-12-mini.png"},
            @"iPhone13,2": @{@"name": @"iPhone 12",       @"chip": @"Apple A14 Bionic", @"image": @"iphone-12.png"},
            @"iPhone13,3": @{@"name": @"iPhone 12 Pro",   @"chip": @"Apple A14 Bionic", @"image": @"iphone-12-pro.png"},
            @"iPhone13,4": @{@"name": @"iPhone 12 Pro Max", @"chip": @"Apple A14 Bionic", @"image": @"iphone-12-pro-max.png"},
            @"iPhone14,4": @{@"name": @"iPhone 13 mini",  @"chip": @"Apple A15 Bionic", @"image": @"iphone-13-mini.png"},
            @"iPhone14,5": @{@"name": @"iPhone 13",       @"chip": @"Apple A15 Bionic", @"image": @"iphone-13.png"},
            @"iPhone14,2": @{@"name": @"iPhone 13 Pro",   @"chip": @"Apple A15 Bionic", @"image": @"iphone-13-pro.png"},
            @"iPhone14,3": @{@"name": @"iPhone 13 Pro Max", @"chip": @"Apple A15 Bionic", @"image": @"iphone-13-pro-max.png"},
            @"iPhone14,6": @{@"name": @"iPhone SE (3-го поколения)", @"chip": @"Apple A15 Bionic", @"image": @"iphone-se-3.png"},
            @"iPhone14,7": @{@"name": @"iPhone 14",       @"chip": @"Apple A15 Bionic", @"image": @"iphone-14.png"},
            @"iPhone14,8": @{@"name": @"iPhone 14 Plus",  @"chip": @"Apple A15 Bionic", @"image": @"iphone-14-plus.png"},
            @"iPhone15,2": @{@"name": @"iPhone 14 Pro",   @"chip": @"Apple A16 Bionic", @"image": @"iphone-14-pro.png"},
            @"iPhone15,3": @{@"name": @"iPhone 14 Pro Max", @"chip": @"Apple A16 Bionic", @"image": @"iphone-14-pro-max.png"},
            @"iPhone15,4": @{@"name": @"iPhone 15",       @"chip": @"Apple A16 Bionic", @"image": @"iphone-15.png"},
            @"iPhone15,5": @{@"name": @"iPhone 15 Plus",  @"chip": @"Apple A16 Bionic", @"image": @"iphone-15-plus.png"},
            @"iPhone16,1": @{@"name": @"iPhone 15 Pro",   @"chip": @"Apple A17 Pro", @"image": @"iphone-15-pro.png"},
            @"iPhone16,2": @{@"name": @"iPhone 15 Pro Max", @"chip": @"Apple A17 Pro", @"image": @"iphone-15-pro-max.png"}
        };
    });
    return catalog;
}

@interface IFDeviceInfo ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *modelName;
@property (nonatomic, copy, readwrite) NSString *chipName;
@property (nonatomic, copy, readwrite) NSString *architectureName;
@property (nonatomic, copy, readwrite) NSString *imageName;
@property (nonatomic, copy, readwrite) NSString *systemVersion;
@end

@implementation IFDeviceInfo

+ (instancetype)currentDevice {
    IFDeviceInfo *device = [[self alloc] init];
    device.identifier = IFHardwareIdentifier();
    NSDictionary *entry = IFDeviceCatalog()[device.identifier];
    device.modelName = entry[@"name"] ?: device.identifier;
    device.chipName = entry[@"chip"] ?: @"Неизвестно";
    NSString *imageFile = entry[@"image"] ?: @"iphone-generic.png";
    device.imageName = [@"DevicePhotos" stringByAppendingPathComponent:imageFile];
    device.systemVersion = [NSProcessInfo processInfo].operatingSystemVersionString;
    NSInteger generation = 0;
    if ([device.identifier hasPrefix:@"iPhone"]) {
        generation = [[[device.identifier substringFromIndex:6] componentsSeparatedByString:@","] firstObject].integerValue;
    }
    device.architectureName = entry[@"arch"] ?: (generation >= 11 ? @"arm64e" : @"arm64");
    return device;
}

@end

@implementation IFProcessSample
@end

#define IF_PROC_ALL_PIDS 1
#define IF_PROC_PIDTASKINFO 4
#define IF_PROC_NAME_MAX 1024

struct if_proc_taskinfo {
    uint64_t virtual_size;
    uint64_t resident_size;
    uint64_t total_user;
    uint64_t total_system;
    uint64_t threads_user;
    uint64_t threads_system;
    int32_t policy;
    int32_t faults;
    int32_t pageins;
    int32_t cow_faults;
    int32_t messages_sent;
    int32_t messages_received;
    int32_t syscalls_mach;
    int32_t syscalls_unix;
    int32_t context_switches;
    int32_t thread_count;
    int32_t running_threads;
    int32_t priority;
};

typedef int (*IFProcListPidsFn)(uint32_t, uint32_t, void *, int);
typedef int (*IFProcPidInfoFn)(int, int, uint64_t, void *, int);
typedef int (*IFProcNameFn)(int, void *, uint32_t);

@interface IFProcessMonitor ()
@property (nonatomic, copy) NSArray<IFProcessSample *> *samples;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *previousCPUTimes;
@property (nonatomic, assign) CFAbsoluteTime previousTimestamp;
@end

@implementation IFProcessMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        _samples = @[];
        _previousCPUTimes = [NSMutableDictionary dictionary];
        _previousTimestamp = CFAbsoluteTimeGetCurrent();
        [self refresh];
    }
    return self;
}

- (void)refresh {
    IFProcListPidsFn procListPids = (IFProcListPidsFn)dlsym(RTLD_DEFAULT, "proc_listpids");
    IFProcPidInfoFn procPidInfo = (IFProcPidInfoFn)dlsym(RTLD_DEFAULT, "proc_pidinfo");
    IFProcNameFn procName = (IFProcNameFn)dlsym(RTLD_DEFAULT, "proc_name");
    if (procListPids == NULL || procPidInfo == NULL || procName == NULL) {
        self.samples = @[];
        return;
    }

    const int capacity = 4096;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (pids == NULL) {
        self.samples = @[];
        return;
    }

    int bytes = procListPids(IF_PROC_ALL_PIDS, 0, pids, capacity * (int)sizeof(pid_t));
    int count = MAX(0, bytes / (int)sizeof(pid_t));
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    double elapsed = MAX(0.001, now - self.previousTimestamp);
    NSMutableDictionary<NSNumber *, NSNumber *> *currentTimes = [NSMutableDictionary dictionary];
    NSMutableArray<IFProcessSample *> *newSamples = [NSMutableArray array];

    for (int index = 0; index < count; index++) {
        pid_t pid = pids[index];
        if (pid <= 0) {
            continue;
        }

        struct if_proc_taskinfo taskInfo = {0};
        int result = procPidInfo(pid, IF_PROC_PIDTASKINFO, 0, &taskInfo, sizeof(taskInfo));
        if (result != sizeof(taskInfo)) {
            continue;
        }

        char nameBuffer[IF_PROC_NAME_MAX] = {0};
        if (procName(pid, nameBuffer, sizeof(nameBuffer)) <= 0) {
            snprintf(nameBuffer, sizeof(nameBuffer), "pid %d", pid);
        }

        uint64_t cpuTime = taskInfo.total_user + taskInfo.total_system;
        NSNumber *pidKey = @(pid);
        NSNumber *previous = self.previousCPUTimes[pidKey];
        double cpuPercent = 0;
        if (previous != nil && cpuTime >= previous.unsignedLongLongValue) {
            cpuPercent = ((double)(cpuTime - previous.unsignedLongLongValue) / 1000000000.0) / elapsed * 100.0;
        }

        IFProcessSample *sample = [[IFProcessSample alloc] init];
        sample.pid = pid;
        sample.name = [NSString stringWithUTF8String:nameBuffer] ?: [NSString stringWithFormat:@"pid %d", pid];
        sample.residentBytes = taskInfo.resident_size;
        sample.cpuPercent = MIN(MAX(cpuPercent, 0), 999.9);
        [newSamples addObject:sample];
        currentTimes[pidKey] = @(cpuTime);
    }

    free(pids);
    self.samples = newSamples;
    self.previousCPUTimes = currentTimes;
    self.previousTimestamp = now;
}

- (NSArray<IFProcessSample *> *)topProcessesByMemory:(NSUInteger)limit {
    NSArray *sorted = [self.samples sortedArrayUsingComparator:^NSComparisonResult(IFProcessSample *left, IFProcessSample *right) {
        if (left.residentBytes == right.residentBytes) {
            return [left.name compare:right.name options:NSCaseInsensitiveSearch];
        }
        return left.residentBytes > right.residentBytes ? NSOrderedAscending : NSOrderedDescending;
    }];
    return [sorted subarrayWithRange:NSMakeRange(0, MIN(limit, sorted.count))];
}

- (NSArray<IFProcessSample *> *)topProcessesByCPU:(NSUInteger)limit {
    NSArray *sorted = [self.samples sortedArrayUsingComparator:^NSComparisonResult(IFProcessSample *left, IFProcessSample *right) {
        if (left.cpuPercent == right.cpuPercent) {
            return left.residentBytes > right.residentBytes ? NSOrderedAscending : NSOrderedDescending;
        }
        return left.cpuPercent > right.cpuPercent ? NSOrderedAscending : NSOrderedDescending;
    }];
    return [sorted subarrayWithRange:NSMakeRange(0, MIN(limit, sorted.count))];
}

@end

@implementation IFNetworkSnapshot
@end

static NSDictionary<NSString *, NSNumber *> *IFNetworkByteTotals(void) {
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) {
        return @{@"in": @0, @"out": @0};
    }

    uint64_t inputBytes = 0;
    uint64_t outputBytes = 0;
    NSMutableSet<NSString *> *counted = [NSMutableSet set];
    for (struct ifaddrs *cursor = interfaces; cursor != NULL; cursor = cursor->ifa_next) {
        if (cursor->ifa_addr == NULL || cursor->ifa_data == NULL ||
            cursor->ifa_addr->sa_family != AF_LINK ||
            (cursor->ifa_flags & IFF_UP) == 0 ||
            (cursor->ifa_flags & IFF_LOOPBACK) != 0) {
            continue;
        }

        NSString *name = cursor->ifa_name ? [NSString stringWithUTF8String:cursor->ifa_name] : nil;
        if (name.length == 0 || [counted containsObject:name]) {
            continue;
        }
        [counted addObject:name];

        const struct if_data *data = cursor->ifa_data;
        inputBytes += data->ifi_ibytes;
        outputBytes += data->ifi_obytes;
    }
    freeifaddrs(interfaces);
    return @{@"in": @(inputBytes), @"out": @(outputBytes)};
}

static NSDictionary<NSString *, NSString *> *IFActiveNetworkDetails(void) {
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) {
        return @{@"ip": @"Недоступно", @"interface": @"Нет", @"vpn": @"Нет"};
    }

    NSString *preferredIP = nil;
    NSString *preferredInterface = nil;
    NSString *fallbackIP = nil;
    NSString *fallbackInterface = nil;
    NSString *vpnInterface = nil;

    for (struct ifaddrs *cursor = interfaces; cursor != NULL; cursor = cursor->ifa_next) {
        if (cursor->ifa_addr == NULL || cursor->ifa_name == NULL ||
            cursor->ifa_addr->sa_family != AF_INET ||
            (cursor->ifa_flags & IFF_UP) == 0 ||
            (cursor->ifa_flags & IFF_LOOPBACK) != 0) {
            continue;
        }

        NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
        struct sockaddr_in *address = (struct sockaddr_in *)cursor->ifa_addr;
        char buffer[INET_ADDRSTRLEN] = {0};
        if (inet_ntop(AF_INET, &address->sin_addr, buffer, sizeof(buffer)) == NULL) {
            continue;
        }
        NSString *ip = [NSString stringWithUTF8String:buffer];

        BOOL isVPN = [name hasPrefix:@"utun"] || [name hasPrefix:@"tun"] ||
                     [name hasPrefix:@"tap"] || [name hasPrefix:@"ipsec"] ||
                     [name hasPrefix:@"ppp"] || [name hasPrefix:@"wg"];
        if (isVPN) {
            vpnInterface = name;
        }

        if ([name isEqualToString:@"en0"] || [name isEqualToString:@"pdp_ip0"]) {
            preferredIP = ip;
            preferredInterface = name;
        } else if (fallbackIP == nil) {
            fallbackIP = ip;
            fallbackInterface = name;
        }
    }
    freeifaddrs(interfaces);

    return @{
        @"ip": preferredIP ?: fallbackIP ?: @"Недоступно",
        @"interface": preferredInterface ?: fallbackInterface ?: @"Нет",
        @"vpn": vpnInterface ?: @"Нет"
    };
}

static NSArray<NSString *> *IFDNSServers(void) {
    typedef CFTypeRef (*IFDynamicStoreCreateFn)(CFAllocatorRef, CFStringRef, const void *, const void *);
    typedef CFPropertyListRef (*IFDynamicStoreCopyValueFn)(CFTypeRef, CFStringRef);
    IFDynamicStoreCreateFn createStore = (IFDynamicStoreCreateFn)dlsym(RTLD_DEFAULT, "SCDynamicStoreCreate");
    IFDynamicStoreCopyValueFn copyValue = (IFDynamicStoreCopyValueFn)dlsym(RTLD_DEFAULT, "SCDynamicStoreCopyValue");
    if (createStore == NULL || copyValue == NULL) {
        return @[];
    }

    CFTypeRef store = createStore(kCFAllocatorDefault, CFSTR("iFetch"), NULL, NULL);
    if (store == NULL) {
        return @[];
    }

    CFPropertyListRef dns = copyValue(store, CFSTR("State:/Network/Global/DNS"));
    CFRelease(store);
    if (dns == NULL || CFGetTypeID(dns) != CFDictionaryGetTypeID()) {
        if (dns != NULL) {
            CFRelease(dns);
        }
        return @[];
    }

    NSArray *servers = [(__bridge NSDictionary *)dns objectForKey:@"ServerAddresses"];
    NSArray *result = [servers isKindOfClass:[NSArray class]] ? [servers copy] : @[];
    CFRelease(dns);
    return result;
}

@interface IFNetworkMonitor ()
@property (nonatomic, assign) uint64_t previousInputBytes;
@property (nonatomic, assign) uint64_t previousOutputBytes;
@property (nonatomic, assign) CFAbsoluteTime previousTimestamp;
@end

@implementation IFNetworkMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        NSDictionary *totals = IFNetworkByteTotals();
        _previousInputBytes = [totals[@"in"] unsignedLongLongValue];
        _previousOutputBytes = [totals[@"out"] unsignedLongLongValue];
        _previousTimestamp = CFAbsoluteTimeGetCurrent();
    }
    return self;
}

- (IFNetworkSnapshot *)refresh {
    NSDictionary *totals = IFNetworkByteTotals();
    uint64_t inputBytes = [totals[@"in"] unsignedLongLongValue];
    uint64_t outputBytes = [totals[@"out"] unsignedLongLongValue];
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    double elapsed = MAX(0.001, now - self.previousTimestamp);

    IFNetworkSnapshot *snapshot = [[IFNetworkSnapshot alloc] init];
    if (inputBytes >= self.previousInputBytes) {
        snapshot.downloadBytesPerSecond = (inputBytes - self.previousInputBytes) / elapsed;
    }
    if (outputBytes >= self.previousOutputBytes) {
        snapshot.uploadBytesPerSecond = (outputBytes - self.previousOutputBytes) / elapsed;
    }

    NSDictionary *details = IFActiveNetworkDetails();
    snapshot.localIPAddress = details[@"ip"];
    snapshot.activeInterface = details[@"interface"];
    snapshot.vpnInterface = details[@"vpn"];
    snapshot.dnsServers = IFDNSServers();

    self.previousInputBytes = inputBytes;
    self.previousOutputBytes = outputBytes;
    self.previousTimestamp = now;
    return snapshot;
}

+ (void)fetchPublicIPAddressWithCompletion:(void (^)(NSString *))completion {
    NSURL *url = [NSURL URLWithString:@"https://api.ipify.org?format=json"];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 5;
    configuration.timeoutIntervalForResource = 5;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *address = @"Недоступно";
        if (data != nil && error == nil) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *candidate = [json isKindOfClass:[NSDictionary class]] ? json[@"ip"] : nil;
            if ([candidate isKindOfClass:[NSString class]] && candidate.length > 0) {
                address = candidate;
            }
        }
        completion(address);
        [session finishTasksAndInvalidate];
    }] resume];
}

@end

@implementation IFJailbreakInfo
@end

static NSString *IFRootPrefix(void) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        return @"/var/jb";
    }
    return @"";
}

static NSArray<NSDictionary<NSString *, NSString *> *> *IFInstalledPackageRecords(NSString *rootPrefix) {
    NSString *statusPath = [rootPrefix stringByAppendingString:@"/Library/dpkg/status"];
    NSString *contents = [NSString stringWithContentsOfFile:statusPath encoding:NSUTF8StringEncoding error:nil];
    if (contents.length == 0) {
        return @[];
    }

    NSMutableArray *records = [NSMutableArray array];
    for (NSString *stanza in [contents componentsSeparatedByString:@"\n\n"]) {
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        for (NSString *line in [stanza componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSRange delimiter = [line rangeOfString:@": "];
            if (delimiter.location == NSNotFound) {
                continue;
            }
            NSString *key = [line substringToIndex:delimiter.location];
            if ([key isEqualToString:@"Package"] || [key isEqualToString:@"Version"] || [key isEqualToString:@"Status"]) {
                record[key] = [line substringFromIndex:NSMaxRange(delimiter)];
            }
        }
        if ([record[@"Status"] isEqualToString:@"install ok installed"] && record[@"Package"] != nil) {
            [records addObject:record];
        }
    }
    return records;
}

static NSInteger IFActiveTweakCount(NSString *rootPrefix) {
    NSArray *directories = @[
        [rootPrefix stringByAppendingString:@"/Library/MobileSubstrate/DynamicLibraries"],
        [rootPrefix stringByAppendingString:@"/usr/lib/TweakInject"]
    ];
    NSMutableSet<NSString *> *dylibs = [NSMutableSet set];
    for (NSString *directory in directories) {
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
        for (NSString *file in files) {
            if ([[file pathExtension].lowercaseString isEqualToString:@"dylib"]) {
                [dylibs addObject:file.lowercaseString];
            }
        }
    }
    return dylibs.count;
}

static NSInteger IFRecentCrashCount(void) {
    NSString *directory = @"/var/mobile/Library/Logs/CrashReporter";
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directory]
                                                           includingPropertiesForKeys:@[NSURLContentModificationDateKey, NSURLIsRegularFileKey]
                                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                error:nil];
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-24 * 60 * 60];
    NSInteger count = 0;
    for (NSURL *url in files) {
        NSString *extension = url.pathExtension.lowercaseString;
        if (![@[@"ips", @"crash", @"panic", @"synced"] containsObject:extension]) {
            continue;
        }
        NSNumber *regular = nil;
        NSDate *date = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        if (regular.boolValue && date != nil && [date compare:cutoff] != NSOrderedAscending) {
            count++;
        }
    }
    return count;
}

@implementation IFetchCore

+ (uint64_t)totalMemoryBytes {
    return [NSProcessInfo processInfo].physicalMemory;
}

+ (NSNumber *)usedMemoryBytes {
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_statistics64_data_t statistics = {0};
    mach_port_t host = mach_host_self();
    kern_return_t result = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&statistics, &count);
    if (result != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), host);
        return nil;
    }

    vm_size_t pageSize = 0;
    if (host_page_size(host, &pageSize) != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), host);
        return nil;
    }
    mach_port_deallocate(mach_task_self(), host);
    uint64_t active = statistics.active_count;
    uint64_t wired = statistics.wire_count;
    uint64_t compressed = statistics.compressor_page_count;
    return @((active + wired + compressed) * pageSize);
}

+ (NSDictionary *)storageAttributes {
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:&error];
    return error == nil ? attributes : nil;
}

+ (NSNumber *)totalStorageBytes {
    return [self storageAttributes][NSFileSystemSize];
}

+ (NSNumber *)usedStorageBytes {
    NSDictionary *attributes = [self storageAttributes];
    NSNumber *total = attributes[NSFileSystemSize];
    NSNumber *free = attributes[NSFileSystemFreeSize];
    if (total == nil || free == nil || total.unsignedLongLongValue < free.unsignedLongLongValue) {
        return nil;
    }
    return @(total.unsignedLongLongValue - free.unsignedLongLongValue);
}

+ (NSString *)systemUptime {
    struct timeval bootTime = {0};
    size_t size = sizeof(bootTime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &bootTime, &size, NULL, 0) != 0) {
        return @"Недоступно";
    }

    NSTimeInterval uptime = MAX(0, [[NSDate date] timeIntervalSince1970] - bootTime.tv_sec);
    NSInteger days = (NSInteger)(uptime / 86400);
    NSInteger hours = ((NSInteger)uptime % 86400) / 3600;
    NSInteger minutes = ((NSInteger)uptime % 3600) / 60;
    return days > 0
        ? [NSString stringWithFormat:@"%ldд %ldч %ldмин", (long)days, (long)hours, (long)minutes]
        : [NSString stringWithFormat:@"%ldч %ldмин", (long)hours, (long)minutes];
}

+ (NSString *)darwinVersion {
    size_t size = 0;
    if (sysctlbyname("kern.osrelease", NULL, &size, NULL, 0) != 0 || size == 0) {
        return @"Недоступно";
    }
    char *buffer = calloc(size, sizeof(char));
    if (buffer == NULL) {
        return @"Недоступно";
    }
    NSString *result = @"Недоступно";
    if (sysctlbyname("kern.osrelease", buffer, &size, NULL, 0) == 0) {
        result = [NSString stringWithUTF8String:buffer] ?: @"Недоступно";
    }
    free(buffer);
    return result;
}

+ (NSString *)batteryCycleCount {
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LOCAL | RTLD_LAZY);
    if (iokit == NULL) {
        return nil;
    }

    CFMutableDictionaryRef (*matching)(const char *) = dlsym(iokit, "IOServiceMatching");
    mach_port_t (*matchingService)(mach_port_t, CFDictionaryRef) = dlsym(iokit, "IOServiceGetMatchingService");
    CFTypeRef (*property)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t) = dlsym(iokit, "IORegistryEntryCreateCFProperty");
    kern_return_t (*releaseObject)(mach_port_t) = dlsym(iokit, "IOObjectRelease");
    NSString *result = nil;

    if (matching != NULL && matchingService != NULL && property != NULL && releaseObject != NULL) {
        mach_port_t service = matchingService(0, matching("AppleSmartBattery"));
        if (service != 0) {
            CFTypeRef value = property(service, CFSTR("CycleCount"), kCFAllocatorDefault, 0);
            if (value != NULL) {
                if (CFGetTypeID(value) == CFNumberGetTypeID()) {
                    result = [(__bridge NSNumber *)value stringValue];
                }
                CFRelease(value);
            }
            releaseObject(service);
        }
    }
    dlclose(iokit);
    return result;
}

+ (IFJailbreakInfo *)jailbreakInfo {
    IFJailbreakInfo *info = [[IFJailbreakInfo alloc] init];
    info.rootPrefix = IFRootPrefix();
    NSArray<NSDictionary *> *packages = IFInstalledPackageRecords(info.rootPrefix);
    info.installedPackageCount = packages.count;
    info.activeTweakCount = IFActiveTweakCount(info.rootPrefix);
    info.recentCrashCount = IFRecentCrashCount();

    if (info.rootPrefix.length > 0) {
        info.environmentName = @"Rootless";
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]) {
        info.environmentName = @"Procursus / Rootful";
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate"]) {
        info.environmentName = @"Rootful";
    } else {
        info.environmentName = @"Не обнаружен";
    }

    NSDictionary *injectors = @{
        @"ellekit": @"ElleKit",
        @"com.opa334.ellekit": @"ElleKit",
        @"mobilesubstrate": @"Cydia Substrate",
        @"org.coolstar.libhooker": @"libhooker",
        @"libhooker": @"libhooker",
        @"science.xnu.substitute": @"Substitute",
        @"com.ex.substitute": @"Substitute"
    };
    for (NSDictionary *package in packages) {
        NSString *displayName = injectors[package[@"Package"]];
        if (displayName != nil) {
            NSString *version = package[@"Version"];
            info.injectorDescription = version.length > 0
                ? [NSString stringWithFormat:@"%@ %@", displayName, version]
                : displayName;
            break;
        }
    }
    if (info.injectorDescription.length == 0) {
        info.injectorDescription = @"Не обнаружен";
    }
    return info;
}

+ (NSString *)executablePathForCandidates:(NSArray<NSString *> *)candidates {
    for (NSString *candidate in candidates) {
        if (access(candidate.fileSystemRepresentation, X_OK) == 0) {
            return candidate;
        }
    }
    return nil;
}

+ (NSString *)formatBytes:(uint64_t)bytes {
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleBinary;
    formatter.allowedUnits = NSByteCountFormatterUseMB | NSByteCountFormatterUseGB | NSByteCountFormatterUseTB;
    return [formatter stringFromByteCount:(long long)bytes];
}

+ (NSString *)formatRate:(double)bytesPerSecond {
    if (bytesPerSecond < 1024) {
        return [NSString stringWithFormat:@"%.0f Б/с", bytesPerSecond];
    }
    if (bytesPerSecond < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f КБ/с", bytesPerSecond / 1024.0];
    }
    return [NSString stringWithFormat:@"%.1f МБ/с", bytesPerSecond / (1024.0 * 1024.0)];
}

@end
