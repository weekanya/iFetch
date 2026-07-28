#import "IFWidgetMetrics.h"

#import "../core/IFWidgetPreferences.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <sys/sysctl.h>

#define IF_WIDGET_PROC_ALL_PIDS 1
#define IF_WIDGET_PROC_PIDTASKINFO 4

struct if_widget_proc_taskinfo {
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

static double IFWidgetMemoryPercent(void) {
    vm_statistics64_data_t statistics = {0};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    mach_port_t host = mach_host_self();
    kern_return_t result = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&statistics, &count);
    vm_size_t pageSize = 0;
    kern_return_t pageResult = host_page_size(host, &pageSize);
    mach_port_deallocate(mach_task_self(), host);
    uint64_t total = NSProcessInfo.processInfo.physicalMemory;
    if (result != KERN_SUCCESS || pageResult != KERN_SUCCESS || total == 0) {
        return 0;
    }
    uint64_t usedPages = statistics.active_count + statistics.wire_count + statistics.compressor_page_count;
    return MIN(100.0, (double)(usedPages * pageSize) / (double)total * 100.0);
}

static double IFWidgetStoragePercent(void) {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/var/mobile" error:nil];
    NSNumber *total = attributes[NSFileSystemSize];
    NSNumber *free = attributes[NSFileSystemFreeSize];
    if (total.unsignedLongLongValue == 0 || free.unsignedLongLongValue > total.unsignedLongLongValue) {
        return 0;
    }
    return (double)(total.unsignedLongLongValue - free.unsignedLongLongValue) /
        (double)total.unsignedLongLongValue * 100.0;
}

static NSString *IFWidgetUptime(BOOL russian) {
    struct timeval bootTime = {0};
    size_t size = sizeof(bootTime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &bootTime, &size, NULL, 0) != 0) {
        return russian ? @"Недоступно" : @"Unavailable";
    }
    NSTimeInterval uptime = MAX(0, NSDate.date.timeIntervalSince1970 - bootTime.tv_sec);
    NSInteger days = (NSInteger)(uptime / 86400);
    NSInteger hours = ((NSInteger)uptime % 86400) / 3600;
    if (russian) {
        return days > 0 ? [NSString stringWithFormat:@"%ldд %ldч", (long)days, (long)hours]
            : [NSString stringWithFormat:@"%ldч", (long)hours];
    }
    return days > 0 ? [NSString stringWithFormat:@"%ldd %ldh", (long)days, (long)hours]
        : [NSString stringWithFormat:@"%ldh", (long)hours];
}

static NSInteger IFWidgetCrashCount(void) {
    NSURL *directory = [NSURL fileURLWithPath:@"/var/mobile/Library/Logs/CrashReporter"];
    NSArray *keys = @[NSURLContentModificationDateKey, NSURLIsRegularFileKey];
    NSDirectoryEnumerator<NSURL *> *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directory
                                                                     includingPropertiesForKeys:keys
                                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   errorHandler:nil];
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-24 * 60 * 60];
    NSInteger count = 0;
    for (NSURL *url in enumerator) {
        NSNumber *regular = nil;
        NSDate *date = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        if (regular.boolValue && date != nil && [date compare:cutoff] != NSOrderedAscending &&
            [@[@"ips", @"crash", @"panic", @"synced"] containsObject:url.pathExtension.lowercaseString]) {
            count++;
        }
    }
    return count;
}

static NSDictionary<NSString *, id> *IFWidgetTopProcess(void) {
    typedef int (*IFProcListPidsFn)(uint32_t, uint32_t, void *, int);
    typedef int (*IFProcPidInfoFn)(int, int, uint64_t, void *, int);
    typedef int (*IFProcNameFn)(int, void *, uint32_t);
    IFProcListPidsFn listPids = (IFProcListPidsFn)dlsym(RTLD_DEFAULT, "proc_listpids");
    IFProcPidInfoFn pidInfo = (IFProcPidInfoFn)dlsym(RTLD_DEFAULT, "proc_pidinfo");
    IFProcNameFn processName = (IFProcNameFn)dlsym(RTLD_DEFAULT, "proc_name");
    if (listPids == NULL || pidInfo == NULL || processName == NULL) {
        return @{};
    }
    const int capacity = 4096;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (pids == NULL) {
        return @{};
    }
    int bytes = listPids(IF_WIDGET_PROC_ALL_PIDS, 0, pids, capacity * (int)sizeof(pid_t));
    int count = MAX(0, bytes / (int)sizeof(pid_t));
    uint64_t highestMemory = 0;
    NSString *highestName = @"";
    for (int index = 0; index < count; index++) {
        pid_t pid = pids[index];
        if (pid <= 0) {
            continue;
        }
        struct if_widget_proc_taskinfo taskInfo = {0};
        if (pidInfo(pid, IF_WIDGET_PROC_PIDTASKINFO, 0, &taskInfo, sizeof(taskInfo)) != sizeof(taskInfo) ||
            taskInfo.resident_size <= highestMemory) {
            continue;
        }
        char buffer[1024] = {0};
        if (processName(pid, buffer, sizeof(buffer)) <= 0) {
            continue;
        }
        highestMemory = taskInfo.resident_size;
        highestName = [NSString stringWithUTF8String:buffer] ?: @"";
    }
    free(pids);
    return highestName.length > 0 ? @{@"name": highestName, @"memory": @(highestMemory)} : @{};
}

static NSString *IFWidgetFormatBytes(uint64_t bytes) {
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleMemory;
    formatter.allowedUnits = NSByteCountFormatterUseMB | NSByteCountFormatterUseGB;
    formatter.includesUnit = YES;
    return [formatter stringFromByteCount:(long long)bytes];
}

@implementation IFWidgetMetrics

+ (NSDictionary<NSString *, id> *)snapshot {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.wee1ka.ifetch.plist"];
    NSDictionary *widgetPreferences = IFWidgetPreferencesRead();
    BOOL russian = [preferences[@"IFetchLanguage"] isEqualToString:@"ru"];
    NSString *accent = [widgetPreferences[@"accent"] isKindOfClass:[NSString class]]
        ? widgetPreferences[@"accent"] : @"cyan";
    NSString *primaryMetric = [widgetPreferences[@"primaryMetric"] isKindOfClass:[NSString class]]
        ? widgetPreferences[@"primaryMetric"] : @"battery";
    NSInteger refreshMinutes = [widgetPreferences[@"refreshMinutes"] integerValue];
    if (refreshMinutes != 5 && refreshMinutes != 15 && refreshMinutes != 30) {
        refreshMinutes = 15;
    }
    NSString *destination = [widgetPreferences[@"deepLink"] isKindOfClass:[NSString class]]
        ? widgetPreferences[@"deepLink"] : @"diagnostics";
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    float battery = device.batteryLevel;
    NSDictionary *topProcess = IFWidgetTopProcess();
    return @{
        @"battery": @(battery >= 0 ? battery * 100.0 : -1),
        @"memory": @(IFWidgetMemoryPercent()),
        @"storage": @(IFWidgetStoragePercent()),
        @"uptime": IFWidgetUptime(russian),
        @"device": device.model ?: @"iPhone",
        @"system": [NSString stringWithFormat:@"iOS %@", device.systemVersion ?: @""],
        @"crashes": @(IFWidgetCrashCount()),
        @"topProcess": topProcess[@"name"] ?: @"",
        @"topMemory": IFWidgetFormatBytes([topProcess[@"memory"] unsignedLongLongValue]),
        @"russian": @(russian),
        @"accent": accent,
        @"primaryMetric": primaryMetric,
        @"refreshMinutes": @(refreshMinutes),
        @"deepLink": [NSString stringWithFormat:@"ifetch://%@", destination]
    };
}

@end
