#import "IFAdvancedDiagnostics.h"
#import "IFJailbreakPaths.h"

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <arpa/inet.h>
#import <dlfcn.h>
#import <netinet/in.h>
#import <objc/message.h>
#import <spawn.h>
#import <string.h>
#import <sys/socket.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString *IFA(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static BOOL IFAAuthorizedNotificationStatus(UNAuthorizationStatus status) {
    return status == UNAuthorizationStatusAuthorized ||
        status == UNAuthorizationStatusProvisional ||
        status == UNAuthorizationStatusEphemeral;
}

static void IFAStoreAlertsState(BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"IFetchAlertsEnabled"];
    if (enabled) {
        [NSUserDefaults.standardUserDefaults setInteger:[IFetchCore jailbreakInfo].recentCrashCount
                                                 forKey:@"IFetchObservedCrashCount"];
    }
    [NSUserDefaults.standardUserDefaults synchronize];
}

static void IFARegisterLegacyNotificationSettings(void) {
    void (^registrationBlock)(void) = ^{
        Class settingsClass = NSClassFromString(@"UIUserNotificationSettings");
        SEL factory = NSSelectorFromString(@"settingsForTypes:categories:");
        SEL registration = NSSelectorFromString(@"registerUserNotificationSettings:");
        UIApplication *application = UIApplication.sharedApplication;
        if (settingsClass == Nil || ![settingsClass respondsToSelector:factory] ||
            ![application respondsToSelector:registration]) {
            return;
        }
        id settings = ((id (*)(id, SEL, NSUInteger, id))objc_msgSend)
            (settingsClass, factory, 7, nil);
        if (settings != nil) {
            ((void (*)(id, SEL, id))objc_msgSend)(application, registration, settings);
        }
    };
    if (NSThread.isMainThread) {
        registrationBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), registrationBlock);
    }
}

static void IFAScheduleAlertsEnabledConfirmation(void) {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"iFetch";
    content.body = IFA(@"Health alerts are enabled.", @"Уведомления о состоянии включены.");
    content.sound = UNNotificationSound.defaultSound;
    content.userInfo = @{@"destination": @"advanced"};
    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:@"ifetch.alerts.enabled"
                                             content:content trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter]
        addNotificationRequest:request withCompletionHandler:nil];
}

@implementation IFProcessConnection
@end

@implementation IFCrashAnalysis
@end

@implementation IFInjectionGroup
@end

@implementation IFLaunchDaemonRecord
@end

@implementation IFIntegrityIssue
@end

struct if_adv_proc_fdinfo {
    int32_t proc_fd;
    uint32_t proc_fdtype;
};

struct if_adv_proc_fileinfo {
    uint32_t fi_openflags;
    uint32_t fi_status;
    int64_t fi_offset;
    int32_t fi_type;
    uint32_t fi_guardflags;
};

struct if_adv_vinfo_stat {
    uint32_t vst_dev;
    uint16_t vst_mode;
    uint16_t vst_nlink;
    uint64_t vst_ino;
    uid_t vst_uid;
    gid_t vst_gid;
    int64_t vst_atime;
    int64_t vst_atimensec;
    int64_t vst_mtime;
    int64_t vst_mtimensec;
    int64_t vst_ctime;
    int64_t vst_ctimensec;
    int64_t vst_birthtime;
    int64_t vst_birthtimensec;
    int64_t vst_size;
    int64_t vst_blocks;
    int32_t vst_blksize;
    uint32_t vst_flags;
    uint32_t vst_gen;
    uint32_t vst_rdev;
    int64_t vst_qspare[2];
};

struct if_adv_in4in6_addr {
    uint32_t pad[3];
    struct in_addr address;
};

struct if_adv_in_sockinfo {
    int foreignPort;
    int localPort;
    uint64_t generation;
    uint32_t flags;
    uint32_t flow;
    uint8_t versionFlags;
    uint8_t ttl;
    uint32_t reserved;
    union {
        struct if_adv_in4in6_addr ipv4;
        struct in6_addr ipv6;
    } foreignAddress;
    union {
        struct if_adv_in4in6_addr ipv4;
        struct in6_addr ipv6;
    } localAddress;
    struct {
        uint8_t tos;
    } ipv4;
    struct {
        uint8_t hopLimit;
        int checksum;
        uint16_t interfaceIndex;
        int16_t hops;
    } ipv6;
};

struct if_adv_tcp_sockinfo {
    struct if_adv_in_sockinfo internet;
    int state;
    int timers[4];
    int maximumSegmentSize;
    uint32_t flags;
    uint32_t reserved;
    uint64_t controlBlock;
};

struct if_adv_sockbuf_info {
    uint32_t byteCount;
    uint32_t highWater;
    uint32_t mbufCount;
    uint32_t maximumMbufCount;
    uint32_t lowWater;
    int16_t flags;
    int16_t timeout;
};

struct if_adv_socket_info {
    struct if_adv_vinfo_stat stat;
    uint64_t socketHandle;
    uint64_t controlBlock;
    int type;
    int protocol;
    int family;
    int16_t options;
    int16_t linger;
    int16_t state;
    int16_t queueLength;
    int16_t incompleteQueueLength;
    int16_t queueLimit;
    int16_t timeout;
    uint16_t error;
    uint32_t outOfBandMark;
    struct if_adv_sockbuf_info receive;
    struct if_adv_sockbuf_info send;
    int kind;
    uint32_t reserved;
    union {
        struct if_adv_in_sockinfo internet;
        struct if_adv_tcp_sockinfo tcp;
        uint8_t raw[768];
    } protocolInfo;
};

struct if_adv_socket_fdinfo {
    struct if_adv_proc_fileinfo file;
    struct if_adv_socket_info socket;
};

typedef int (*IFAProcPidInfoFn)(int, int, uint64_t, void *, int);
typedef int (*IFAProcPidFDInfoFn)(int, int, int, void *, int);

static NSString *IFAAddress(const struct if_adv_in_sockinfo *info, BOOL local) {
    if (info == NULL) {
        return @"";
    }
    char buffer[INET6_ADDRSTRLEN] = {0};
    const void *address = NULL;
    int family = AF_UNSPEC;
    if ((info->versionFlags & 0x1) != 0) {
        family = AF_INET;
        address = local ? (const void *)&info->localAddress.ipv4.address
                        : (const void *)&info->foreignAddress.ipv4.address;
    } else if ((info->versionFlags & 0x2) != 0) {
        family = AF_INET6;
        address = local ? (const void *)&info->localAddress.ipv6
                        : (const void *)&info->foreignAddress.ipv6;
    }
    if (address == NULL || inet_ntop(family, address, buffer, sizeof(buffer)) == NULL) {
        return @"";
    }
    return [NSString stringWithUTF8String:buffer] ?: @"";
}

static NSString *IFAEndpoint(const struct if_adv_in_sockinfo *info, BOOL local) {
    NSString *address = IFAAddress(info, local);
    uint16_t port = ntohs((uint16_t)(local ? info->localPort : info->foreignPort));
    if ([address isEqualToString:@"0.0.0.0"] || [address isEqualToString:@"::"] || address.length == 0) {
        address = local ? @"*" : @"—";
    }
    if (!local && port == 0) {
        return @"—";
    }
    if ([address containsString:@":"]) {
        return [NSString stringWithFormat:@"[%@]:%u", address, port];
    }
    return [NSString stringWithFormat:@"%@:%u", address, port];
}

static NSString *IFATCPState(int state) {
    NSArray<NSString *> *states = @[
        @"CLOSED", @"LISTEN", @"SYN-SENT", @"SYN-RECEIVED", @"ESTABLISHED",
        @"CLOSE-WAIT", @"FIN-WAIT-1", @"CLOSING", @"LAST-ACK", @"FIN-WAIT-2",
        @"TIME-WAIT", @"RESERVED"
    ];
    return state >= 0 && state < (int)states.count ? states[(NSUInteger)state] : @"";
}

static NSString *IFAFirstMatch(NSString *text, NSArray<NSString *> *patterns) {
    if (text.length == 0) {
        return @"";
    }
    for (NSString *pattern in patterns) {
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:nil];
        NSTextCheckingResult *match = [expression firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (match.numberOfRanges > 1) {
            NSString *value = [text substringWithRange:[match rangeAtIndex:1]];
            value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (value.length > 0) {
                return value;
            }
        }
    }
    return @"";
}

static NSArray<NSString *> *IFAInstalledPackageIdentifiers(void) {
    NSString *contents = [NSString stringWithContentsOfFile:IFBootstrapPath(@"/Library/dpkg/status")
                                                   encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *packages = [NSMutableArray array];
    for (NSString *stanza in [contents componentsSeparatedByString:@"\n\n"]) {
        if (![stanza containsString:@"Status: install ok installed"]) {
            continue;
        }
        NSString *identifier = IFAFirstMatch(stanza, @[@"(?:^|\\n)Package:\\s*([^\\n]+)"]);
        if (identifier.length > 0) {
            [packages addObject:identifier];
        }
    }
    return [packages sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSArray<NSString *> *IFASnapshotValues(NSDictionary *snapshot, NSString *key) {
    NSArray *values = [snapshot[key] isKindOfClass:[NSArray class]] ? snapshot[key] : @[];
    return [values sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSString *IFASnapshotDirectory(void) {
    return @"/var/mobile/Library/Application Support/iFetch/Snapshots";
}

static NSString *IFADiagnosticStatePath(void) {
    return IFBootstrapPath(@"/var/lib/ifetch/diagnostic-mode.plist");
}

static NSArray<NSString *> *IFATweakDirectories(void) {
    return @[
        IFBootstrapPath(@"/Library/MobileSubstrate/DynamicLibraries"),
        IFBootstrapPath(@"/usr/lib/TweakInject")
    ];
}

static void IFAAddIssue(NSMutableArray<IFIntegrityIssue *> *issues,
                        NSString *title,
                        NSString *detail,
                        IFIntegritySeverity severity) {
    IFIntegrityIssue *issue = [[IFIntegrityIssue alloc] init];
    issue.title = title;
    issue.detail = detail;
    issue.severity = severity;
    [issues addObject:issue];
}

static NSDictionary *IFARunHelper(NSArray<NSString *> *arguments, NSError **error) {
    NSString *path = IFBootstrapPath(@"/usr/libexec/ifetchhelper");
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"com.wee1ka.ifetch.helper" code:2
                                    userInfo:@{NSLocalizedDescriptionKey:
                                        IFA(@"The privileged helper is missing. Reinstall the package through a package manager.",
                                            @"Привилегированный helper отсутствует. Переустановите пакет через пакетный менеджер.")}];
        }
        return nil;
    }
    int outputPipe[2] = {-1, -1};
    if (pipe(outputPipe) != 0) {
        return nil;
    }
    NSMutableArray<NSString *> *allArguments = [NSMutableArray arrayWithObject:path.lastPathComponent];
    [allArguments addObjectsFromArray:arguments];
    char **argv = calloc(allArguments.count + 1, sizeof(char *));
    if (argv == NULL) {
        close(outputPipe[0]);
        close(outputPipe[1]);
        return nil;
    }
    for (NSUInteger index = 0; index < allArguments.count; index++) {
        argv[index] = (char *)allArguments[index].UTF8String;
    }
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, outputPipe[0]);
    pid_t pid = 0;
    int spawnResult = posix_spawn(&pid, path.fileSystemRepresentation, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    free(argv);
    close(outputPipe[1]);
    if (spawnResult != 0) {
        close(outputPipe[0]);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"com.wee1ka.ifetch.helper" code:spawnResult
                                    userInfo:@{NSLocalizedDescriptionKey:
                                        [NSString stringWithFormat:IFA(@"Could not start helper: %s",
                                                                       @"Не удалось запустить helper: %s"),
                                         strerror(spawnResult)]}];
        }
        return nil;
    }
    NSMutableData *output = [NSMutableData data];
    uint8_t buffer[4096];
    ssize_t count = 0;
    while ((count = read(outputPipe[0], buffer, sizeof(buffer))) > 0) {
        [output appendBytes:buffer length:(NSUInteger)count];
    }
    close(outputPipe[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    NSDictionary *result = output.length > 0
        ? [NSJSONSerialization JSONObjectWithData:output options:0 error:nil] : nil;
    if (![result isKindOfClass:[NSDictionary class]]) {
        result = nil;
    }
    if ((result == nil || ![result[@"success"] boolValue]) && error != NULL) {
        NSString *message = [result[@"error"] isKindOfClass:[NSString class]] ? result[@"error"]
            : [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
        *error = [NSError errorWithDomain:@"com.wee1ka.ifetch.helper"
                                     code:WIFEXITED(status) ? WEXITSTATUS(status) : 1
                                 userInfo:@{NSLocalizedDescriptionKey:
                                     message.length ? message : IFA(@"Helper operation failed", @"Ошибка helper")}];
    }
    return result;
}

static void IFAScheduleAlert(NSString *identifier, NSString *title, NSString *body) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *key = [@"IFetchAlertDate." stringByAppendingString:identifier];
    NSDate *lastDate = [defaults objectForKey:key];
    if ([lastDate isKindOfClass:[NSDate class]] && -lastDate.timeIntervalSinceNow < 900) {
        return;
    }
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = UNNotificationSound.defaultSound;
    content.userInfo = @{@"destination": @"diagnostics"};
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];
    NSString *requestIdentifier = [NSString stringWithFormat:@"ifetch.%@.%lld", identifier,
                                   (long long)(NSDate.date.timeIntervalSince1970 * 1000)];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:requestIdentifier
                                                                          content:content trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
    [defaults setObject:NSDate.date forKey:key];
}

@implementation IFAdvancedDiagnostics

+ (NSArray<IFProcessConnection *> *)connectionsForProcess:(IFProcessSample *)process {
    if (process == nil || process.pid <= 0) {
        return @[];
    }
    NSMutableOrderedSet<NSNumber *> *pids = [NSMutableOrderedSet orderedSetWithObject:@(process.pid)];
    NSString *applicationPrefix = @"";
    NSRange appRange = [process.executablePath rangeOfString:@".app/" options:NSCaseInsensitiveSearch];
    if (appRange.location != NSNotFound) {
        applicationPrefix = [process.executablePath substringToIndex:appRange.location + 4];
        IFProcessMonitor *monitor = [[IFProcessMonitor alloc] init];
        for (IFProcessSample *candidate in monitor.allProcesses) {
            if (candidate.pid > 0 && [candidate.executablePath hasPrefix:applicationPrefix]) {
                [pids addObject:@(candidate.pid)];
            }
        }
    }
    NSMutableArray<NSString *> *helperArguments = [NSMutableArray arrayWithObject:@"connections"];
    for (NSNumber *pid in pids) {
        [helperArguments addObject:pid.stringValue];
    }
    NSDictionary *helperResult = IFARunHelper(helperArguments, nil);
    NSArray<NSDictionary *> *helperConnections =
        [helperResult[@"connections"] isKindOfClass:[NSArray class]] ? helperResult[@"connections"] : nil;
    if (helperConnections != nil) {
        NSMutableArray *converted = [NSMutableArray array];
        for (NSDictionary *entry in helperConnections) {
            IFProcessConnection *connection = [[IFProcessConnection alloc] init];
            connection.pid = [entry[@"pid"] intValue];
            connection.processName = entry[@"process"] ?: @"";
            connection.protocolName = entry[@"protocol"] ?: @"";
            connection.localEndpoint = entry[@"local"] ?: @"";
            connection.remoteEndpoint = entry[@"remote"] ?: @"";
            connection.state = entry[@"state"] ?: @"";
            [converted addObject:connection];
        }
        return converted;
    }
    IFAProcPidInfoFn procPidInfo = (IFAProcPidInfoFn)dlsym(RTLD_DEFAULT, "proc_pidinfo");
    IFAProcPidFDInfoFn procPidFDInfo = (IFAProcPidFDInfoFn)dlsym(RTLD_DEFAULT, "proc_pidfdinfo");
    if (procPidInfo == NULL || procPidFDInfo == NULL) {
        return @[];
    }
    const int capacity = 4096;
    struct if_adv_proc_fdinfo *descriptors = calloc((size_t)capacity, sizeof(struct if_adv_proc_fdinfo));
    if (descriptors == NULL) {
        return @[];
    }
    int bytes = procPidInfo(process.pid, 1, 0, descriptors,
                            capacity * (int)sizeof(struct if_adv_proc_fdinfo));
    int count = MAX(0, bytes / (int)sizeof(struct if_adv_proc_fdinfo));
    NSMutableArray *connections = [NSMutableArray array];
    for (int index = 0; index < count; index++) {
        if (descriptors[index].proc_fdtype != 2) {
            continue;
        }
        struct if_adv_socket_fdinfo info = {0};
        int result = procPidFDInfo(process.pid, descriptors[index].proc_fd, 3, &info, sizeof(info));
        if (result <= 0 || (info.socket.family != AF_INET && info.socket.family != AF_INET6)) {
            continue;
        }
        const struct if_adv_in_sockinfo *internet = info.socket.protocol == IPPROTO_TCP
            ? &info.socket.protocolInfo.tcp.internet : &info.socket.protocolInfo.internet;
        IFProcessConnection *connection = [[IFProcessConnection alloc] init];
        connection.pid = process.pid;
        connection.processName = process.name ?: @"";
        connection.protocolName = info.socket.protocol == IPPROTO_TCP ? @"TCP"
            : info.socket.protocol == IPPROTO_UDP ? @"UDP" : [NSString stringWithFormat:@"%d", info.socket.protocol];
        connection.localEndpoint = IFAEndpoint(internet, YES);
        connection.remoteEndpoint = IFAEndpoint(internet, NO);
        connection.state = info.socket.protocol == IPPROTO_TCP ? IFATCPState(info.socket.protocolInfo.tcp.state) : @"";
        [connections addObject:connection];
    }
    free(descriptors);
    return [connections sortedArrayUsingComparator:^NSComparisonResult(IFProcessConnection *left,
                                                                        IFProcessConnection *right) {
        NSComparisonResult result = [left.protocolName compare:right.protocolName];
        return result == NSOrderedSame ? [left.remoteEndpoint compare:right.remoteEndpoint] : result;
    }];
}

+ (IFCrashAnalysis *)analysisForCrashLog:(IFCrashLog *)log {
    NSString *text = log.preview ?: @"";
    IFCrashAnalysis *analysis = [[IFCrashAnalysis alloc] init];
    analysis.processName = IFAFirstMatch(text, @[
        @"\"procName\"\\s*:\\s*\"([^\"]+)\"",
        @"(?:^|\\n)Process:\\s*([^\\n\\[]+)",
        @"(?:^|\\n)Command:\\s*([^\\n]+)"
    ]);
    analysis.exceptionType = IFAFirstMatch(text, @[
        @"\"type\"\\s*:\\s*\"(EXC_[^\"]+)\"",
        @"(?:^|\\n)Exception Type:\\s*([^\\n]+)",
        @"(?:^|\\n)Exception Codes?:\\s*([^\\n]+)"
    ]);
    analysis.terminationReason = IFAFirstMatch(text, @[
        @"\"termination\"\\s*:\\s*\\{[^}]*\"indicator\"\\s*:\\s*\"([^\"]+)\"",
        @"(?:^|\\n)Termination Reason:\\s*([^\\n]+)",
        @"(?:^|\\n)Termination Description:\\s*([^\\n]+)"
    ]);
    analysis.faultingThread = IFAFirstMatch(text, @[
        @"\"faultingThread\"\\s*:\\s*(\\d+)",
        @"(?:^|\\n)Crashed Thread:\\s*([^\\n]+)",
        @"(?:^|\\n)Triggered by Thread:\\s*([^\\n]+)"
    ]);
    NSMutableOrderedSet<NSString *> *suspects = [NSMutableOrderedSet orderedSet];
    NSRegularExpression *paths = [NSRegularExpression regularExpressionWithPattern:
        @"(?:/var/jb)?/(?:Library/MobileSubstrate/DynamicLibraries|usr/lib/TweakInject)/([^/\\s\"\\\\]+\\.dylib)"
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:nil];
    for (NSTextCheckingResult *match in [paths matchesInString:text options:0 range:NSMakeRange(0, text.length)]) {
        if (match.numberOfRanges > 1) {
            [suspects addObject:[[text substringWithRange:[match rangeAtIndex:1]] stringByDeletingPathExtension]];
        }
    }
    analysis.suspectedTweaks = suspects.array;
    NSString *unavailable = IFA(@"Not found", @"Не найдено");
    analysis.summary = [NSString stringWithFormat:
        @"%@: %@\n%@: %@\n%@: %@\n%@: %@\n%@: %@",
        IFA(@"Process", @"Процесс"), analysis.processName.length ? analysis.processName : unavailable,
        IFA(@"Exception", @"Исключение"), analysis.exceptionType.length ? analysis.exceptionType : unavailable,
        IFA(@"Termination", @"Завершение"), analysis.terminationReason.length ? analysis.terminationReason : unavailable,
        IFA(@"Faulting thread", @"Сбойный поток"), analysis.faultingThread.length ? analysis.faultingThread : unavailable,
        IFA(@"Possible injected tweaks", @"Возможные внедрённые твики"),
        analysis.suspectedTweaks.count ? [analysis.suspectedTweaks componentsJoinedByString:@", "] : unavailable];
    return analysis;
}

+ (NSArray<IFInjectionGroup *> *)injectionMap {
    NSArray<IFTweakRecord *> *tweaks = [IFDiagnostics installedTweaks];
    IFProcessMonitor *monitor = [[IFProcessMonitor alloc] init];
    NSArray<IFProcessSample *> *processes = monitor.allProcesses;
    NSMutableDictionary<NSString *, NSMutableOrderedSet<NSString *> *> *map = [NSMutableDictionary dictionary];
    for (IFTweakRecord *tweak in tweaks) {
        if (!tweak.isEnabled) {
            continue;
        }
        NSArray<NSString *> *targets = [tweak.targetExecutables arrayByAddingObjectsFromArray:tweak.targetBundles];
        if (targets.count == 0) {
            targets = @[IFA(@"All processes / unspecified", @"Все процессы / не указано")];
        }
        for (NSString *target in targets) {
            if (target.length == 0) {
                continue;
            }
            if (map[target] == nil) {
                map[target] = [NSMutableOrderedSet orderedSet];
            }
            [map[target] addObject:tweak.name ?: tweak.dylibPath.lastPathComponent];
        }
    }
    NSMutableArray *groups = [NSMutableArray array];
    for (NSString *target in map) {
        IFInjectionGroup *group = [[IFInjectionGroup alloc] init];
        group.target = target;
        group.tweaks = map[target].array;
        NSMutableArray *running = [NSMutableArray array];
        for (IFProcessSample *process in processes) {
            if ([process.name caseInsensitiveCompare:target] == NSOrderedSame ||
                [process.executablePath.lastPathComponent caseInsensitiveCompare:target] == NSOrderedSame ||
                [process.executablePath containsString:target]) {
                [running addObject:[NSString stringWithFormat:@"%@ (%d)", process.name, process.pid]];
            }
        }
        group.runningProcesses = running;
        [groups addObject:group];
    }
    return [groups sortedArrayUsingComparator:^NSComparisonResult(IFInjectionGroup *left, IFInjectionGroup *right) {
        return [left.target localizedCaseInsensitiveCompare:right.target];
    }];
}

+ (NSArray<IFLaunchDaemonRecord *> *)launchDaemons {
    NSArray<NSString *> *directories = @[
        IFBootstrapPath(@"/Library/LaunchDaemons"),
        @"/Library/LaunchDaemons"
    ];
    IFProcessMonitor *monitor = [[IFProcessMonitor alloc] init];
    NSArray<IFProcessSample *> *processes = monitor.allProcesses;
    NSMutableArray *records = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *directory in directories) {
        for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) {
            if (![file.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                continue;
            }
            NSString *path = [directory stringByAppendingPathComponent:file];
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
            NSString *label = [plist[@"Label"] isKindOfClass:[NSString class]] ? plist[@"Label"] : file.stringByDeletingPathExtension;
            if (label.length == 0 || [seen containsObject:label]) {
                continue;
            }
            [seen addObject:label];
            NSString *program = [plist[@"Program"] isKindOfClass:[NSString class]] ? plist[@"Program"] : @"";
            if (program.length == 0 && [plist[@"ProgramArguments"] isKindOfClass:[NSArray class]]) {
                program = [plist[@"ProgramArguments"] firstObject] ?: @"";
            }
            IFLaunchDaemonRecord *record = [[IFLaunchDaemonRecord alloc] init];
            record.label = label;
            record.path = path;
            record.program = program;
            for (IFProcessSample *process in processes) {
                if ((program.length > 0 && [process.executablePath isEqualToString:program]) ||
                    (program.lastPathComponent.length > 0 &&
                     [process.name caseInsensitiveCompare:program.lastPathComponent] == NSOrderedSame)) {
                    record.loaded = YES;
                    record.pid = process.pid;
                    break;
                }
            }
            [records addObject:record];
        }
    }
    return [records sortedArrayUsingComparator:^NSComparisonResult(IFLaunchDaemonRecord *left,
                                                                    IFLaunchDaemonRecord *right) {
        if (left.isLoaded != right.isLoaded) {
            return left.isLoaded ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left.label localizedCaseInsensitiveCompare:right.label];
    }];
}

+ (NSArray<IFIntegrityIssue *> *)integrityIssues {
    NSMutableArray<IFIntegrityIssue *> *issues = [NSMutableArray array];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSString *bootstrapRoot = IFBootstrapRootPath();
    if (bootstrapRoot.length == 0 || ![manager fileExistsAtPath:bootstrapRoot]) {
        NSString *title = IFRootHideRuntime() ? @"RootHide bootstrap" : @"Rootless bootstrap";
        IFAAddIssue(issues, title,
                    IFA(@"Jailbreak bootstrap was not found", @"Bootstrap джейлбрейка не найден"),
                    IFIntegritySeverityProblem);
        return issues;
    }
    NSArray<NSArray<NSString *> *> *required = @[
        @[IFBootstrapPath(@"/Library/dpkg/status"), IFA(@"Package database", @"База пакетов")],
        @[IFBootstrapPath(@"/Library/LaunchDaemons"), @"LaunchDaemons"],
        @[IFBootstrapPath(@"/usr/bin/dpkg"), @"dpkg"]
    ];
    for (NSArray<NSString *> *entry in required) {
        if (![manager fileExistsAtPath:entry[0]]) {
            IFAAddIssue(issues, entry[1], [NSString stringWithFormat:IFA(@"Missing: %@", @"Отсутствует: %@"), entry[0]],
                        IFIntegritySeverityProblem);
        }
    }
    NSArray<NSString *> *packages = IFAInstalledPackageIdentifiers();
    if (packages.count == 0) {
        IFAAddIssue(issues, IFA(@"Installed packages", @"Установленные пакеты"),
                    IFA(@"No valid installed package records found", @"Не найдены корректные записи установленных пакетов"),
                    IFIntegritySeverityProblem);
    }
    for (NSString *directory in IFATweakDirectories()) {
        NSArray<NSString *> *files = [manager contentsOfDirectoryAtPath:directory error:nil];
        NSMutableSet *dylibs = [NSMutableSet set];
        NSMutableSet *plists = [NSMutableSet set];
        for (NSString *file in files) {
            if ([file.pathExtension.lowercaseString isEqualToString:@"dylib"] ||
                [file.pathExtension.lowercaseString isEqualToString:@"disabled"]) {
                [dylibs addObject:file.stringByDeletingPathExtension.lowercaseString];
            } else if ([file.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                [plists addObject:file.stringByDeletingPathExtension.lowercaseString];
            }
        }
        for (NSString *name in plists) {
            if (![dylibs containsObject:name]) {
                IFAAddIssue(issues, IFA(@"Orphan injection filter", @"Фильтр без dylib"),
                            [directory stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"plist"]],
                            IFIntegritySeverityWarning);
            }
        }
    }
    NSArray<NSString *> *scanRoots = @[
        IFBootstrapPath(@"/usr/lib"),
        IFBootstrapPath(@"/Library")
    ];
    NSUInteger brokenLinks = 0;
    for (NSString *root in scanRoots) {
        NSDirectoryEnumerator<NSString *> *enumerator = [manager enumeratorAtPath:root];
        for (NSString *relative in enumerator) {
            NSString *path = [root stringByAppendingPathComponent:relative];
            NSDictionary *attributes = [manager attributesOfItemAtPath:path error:nil];
            if ([attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
                NSString *destination = [manager destinationOfSymbolicLinkAtPath:path error:nil];
                NSString *resolved = [destination hasPrefix:@"/"] ? destination
                    : [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:destination ?: @""];
                if (destination.length > 0 && ![manager fileExistsAtPath:resolved]) {
                    brokenLinks++;
                    if (brokenLinks <= 20) {
                        IFAAddIssue(issues, IFA(@"Broken symbolic link", @"Битая символическая ссылка"),
                                    path, IFIntegritySeverityWarning);
                    }
                }
            }
            if (brokenLinks >= 20) {
                [enumerator skipDescendants];
                break;
            }
        }
    }
    if (issues.count == 0) {
        IFAAddIssue(issues, IFA(@"Integrity check passed", @"Проверка пройдена"),
                    [NSString stringWithFormat:IFA(@"%lu packages checked", @"Проверено пакетов: %lu"),
                     (unsigned long)packages.count], IFIntegritySeverityInfo);
    }
    return issues;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)systemSnapshots {
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:IFASnapshotDirectory()
                                                                                   error:nil];
    NSMutableArray *snapshots = [NSMutableArray array];
    for (NSString *file in files) {
        if (![file.pathExtension.lowercaseString isEqualToString:@"json"]) {
            continue;
        }
        NSData *data = [NSData dataWithContentsOfFile:[IFASnapshotDirectory() stringByAppendingPathComponent:file]];
        NSDictionary *snapshot = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([snapshot isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *record = [snapshot mutableCopy];
            record[@"_path"] = [IFASnapshotDirectory() stringByAppendingPathComponent:file];
            [snapshots addObject:record];
        }
    }
    return [snapshots sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [right[@"createdAt"] compare:left[@"createdAt"]];
    }];
}

+ (NSDictionary<NSString *, id> *)captureSystemSnapshotNamed:(NSString *)name error:(NSError **)error {
    IFProcessMonitor *monitor = [[IFProcessMonitor alloc] init];
    NSMutableOrderedSet *processNames = [NSMutableOrderedSet orderedSet];
    for (IFProcessSample *process in monitor.allProcesses) {
        if (process.name.length > 0) {
            [processNames addObject:process.name];
        }
    }
    NSMutableArray *tweaks = [NSMutableArray array];
    for (IFTweakRecord *tweak in [IFDiagnostics installedTweaks]) {
        [tweaks addObject:[NSString stringWithFormat:@"%@|%@|%@", tweak.packageIdentifier ?: @"",
                           tweak.name ?: @"", tweak.isEnabled ? @"enabled" : @"disabled"]];
    }
    NSMutableArray *daemons = [NSMutableArray array];
    for (IFLaunchDaemonRecord *daemon in [self launchDaemons]) {
        [daemons addObject:[NSString stringWithFormat:@"%@|%@", daemon.label, daemon.isLoaded ? @"loaded" : @"stopped"]];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSString *createdAt = [formatter stringFromDate:NSDate.date];
    NSDictionary *snapshot = @{
        @"schema": @1,
        @"name": name.length ? name : createdAt,
        @"createdAt": createdAt,
        @"version": [IFetchCore versionString],
        @"device": IFDeviceInfo.currentDevice.identifier ?: @"",
        @"processes": [processNames.array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
        @"packages": IFAInstalledPackageIdentifiers(),
        @"tweaks": [tweaks sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
        @"daemons": [daemons sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
    };
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager createDirectoryAtPath:IFASnapshotDirectory() withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:error];
    if (data == nil) {
        return nil;
    }
    NSString *filename = [[createdAt stringByReplacingOccurrencesOfString:@":" withString:@"-"] stringByAppendingPathExtension:@"json"];
    return [data writeToFile:[IFASnapshotDirectory() stringByAppendingPathComponent:filename]
                     options:NSDataWritingAtomic error:error] ? snapshot : nil;
}

+ (BOOL)deleteSystemSnapshot:(NSDictionary<NSString *, id> *)snapshot error:(NSError **)error {
    NSString *path = [snapshot[@"_path"] isKindOfClass:[NSString class]] ? snapshot[@"_path"] : @"";
    NSString *directory = [IFASnapshotDirectory() stringByAppendingString:@"/"];
    if (![path hasPrefix:directory] || ![path.pathExtension.lowercaseString isEqualToString:@"json"]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"com.wee1ka.ifetch" code:3
                                    userInfo:@{NSLocalizedDescriptionKey: IFA(@"Invalid snapshot path",
                                                                            @"Некорректный путь снимка")}];
        }
        return NO;
    }
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

+ (NSDictionary<NSString *, NSArray<NSString *> *> *)compareSnapshot:(NSDictionary<NSString *, id> *)older
                                                                  with:(NSDictionary<NSString *, id> *)newer {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"processes", @"packages", @"tweaks", @"daemons"]) {
        NSSet *oldValues = [NSSet setWithArray:IFASnapshotValues(older, key)];
        NSSet *newValues = [NSSet setWithArray:IFASnapshotValues(newer, key)];
        NSMutableSet *added = [newValues mutableCopy];
        [added minusSet:oldValues];
        NSMutableSet *removed = [oldValues mutableCopy];
        [removed minusSet:newValues];
        result[[key stringByAppendingString:@"Added"]] = [added.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        result[[key stringByAppendingString:@"Removed"]] = [removed.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return result;
}

+ (BOOL)diagnosticModeEnabled {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:IFADiagnosticStatePath()];
    return [state[@"files"] isKindOfClass:[NSArray class]] && [state[@"files"] count] > 0;
}

+ (NSUInteger)diagnosticModeDisabledCount {
    return [[NSDictionary dictionaryWithContentsOfFile:IFADiagnosticStatePath()][@"files"] count];
}

+ (BOOL)enableDiagnosticModeWithError:(NSError **)error {
    NSDictionary *result = IFARunHelper(@[@"diagnostic-enable"], error);
    return [result[@"success"] boolValue];
}

+ (BOOL)restoreDiagnosticModeWithError:(NSError **)error {
    NSDictionary *result = IFARunHelper(@[@"diagnostic-restore"], error);
    return [result[@"success"] boolValue];
}

+ (BOOL)refreshWidgetsWithError:(NSError **)error {
    NSDictionary *result = IFARunHelper(@[@"widget-refresh"], error);
    return [result[@"success"] boolValue];
}

+ (BOOL)alertsEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:@"IFetchAlertsEnabled"];
}

+ (void)refreshAlertsAuthorizationWithCompletion:(void (^)(BOOL))completion {
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        BOOL authorized = IFAAuthorizedNotificationStatus(settings.authorizationStatus);
        IFAStoreAlertsState(authorized);
        if (completion != nil) {
            completion(authorized);
        }
    }];
}

+ (void)setAlertsEnabled:(BOOL)enabled completion:(void (^)(BOOL))completion {
    if (!enabled) {
        IFAStoreAlertsState(NO);
        if (completion != nil) {
            completion(NO);
        }
        return;
    }
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *current) {
        if (IFAAuthorizedNotificationStatus(current.authorizationStatus)) {
            IFAStoreAlertsState(YES);
            IFAScheduleAlertsEnabledConfirmation();
            if (completion != nil) {
                completion(YES);
            }
            return;
        }
        IFARegisterLegacyNotificationSettings();
        [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert |
                                                UNAuthorizationOptionSound |
                                                UNAuthorizationOptionBadge
                              completionHandler:^(BOOL granted, __unused NSError *requestError) {
            if (granted) {
                IFAStoreAlertsState(YES);
                IFAScheduleAlertsEnabledConfirmation();
                if (completion != nil) {
                    completion(YES);
                }
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)),
                           dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                    BOOL authorized = IFAAuthorizedNotificationStatus(settings.authorizationStatus);
                    IFAStoreAlertsState(authorized);
                    if (authorized) {
                        IFAScheduleAlertsEnabledConfirmation();
                    }
                    if (completion != nil) {
                        completion(authorized);
                    }
                }];
            });
        }];
    }];
}

+ (void)evaluateAlertsWithMonitor:(IFLiveMetricsMonitor *)monitor {
    if (![self alertsEnabled] || monitor == nil) {
        return;
    }
    IFMetricSample *sample = monitor.history.lastObject;
    if (sample.memoryPercent >= 90) {
        IFAScheduleAlert(@"memory", IFA(@"High memory usage", @"Высокая загрузка ОЗУ"),
                         [NSString stringWithFormat:@"%.0f%%", sample.memoryPercent]);
    }
    if (sample.batteryTemperature >= 43) {
        IFAScheduleAlert(@"temperature", IFA(@"Battery is overheating", @"Перегрев батареи"),
                         [NSString stringWithFormat:@"%.1f °C", sample.batteryTemperature]);
    }
    IFProcessSample *hot = [monitor.processes topProcessesByCPU:1].firstObject;
    if (hot.cpuPercent >= 80) {
        IFAScheduleAlert(@"cpu", IFA(@"High process CPU usage", @"Высокая нагрузка процесса"),
                         [NSString stringWithFormat:@"%@ · %.0f%%", hot.name, hot.cpuPercent]);
    }
    NSInteger crashes = [IFetchCore jailbreakInfo].recentCrashCount;
    NSInteger previous = [NSUserDefaults.standardUserDefaults integerForKey:@"IFetchObservedCrashCount"];
    if (crashes > previous && previous >= 0) {
        IFAScheduleAlert(@"crash", IFA(@"New crash report", @"Новый crash-отчёт"),
                         [NSString stringWithFormat:IFA(@"Crashes in 24 hours: %ld", @"Сбоев за 24 часа: %ld"),
                          (long)crashes]);
    }
    [NSUserDefaults.standardUserDefaults setInteger:crashes forKey:@"IFetchObservedCrashCount"];
}

@end
