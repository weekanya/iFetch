#import <Foundation/Foundation.h>

#import "../core/IFJailbreakPaths.h"

#import <arpa/inet.h>
#import <dlfcn.h>
#import <netinet/in.h>
#import <signal.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <unistd.h>

struct ifh_proc_fdinfo {
    int32_t proc_fd;
    uint32_t proc_fdtype;
};

struct ifh_proc_fileinfo {
    uint32_t fi_openflags;
    uint32_t fi_status;
    int64_t fi_offset;
    int32_t fi_type;
    uint32_t fi_guardflags;
};

struct ifh_vinfo_stat {
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

struct ifh_in4in6_addr {
    uint32_t pad[3];
    struct in_addr address;
};

struct ifh_in_sockinfo {
    int foreignPort;
    int localPort;
    uint64_t generation;
    uint32_t flags;
    uint32_t flow;
    uint8_t versionFlags;
    uint8_t ttl;
    uint32_t reserved;
    union {
        struct ifh_in4in6_addr ipv4;
        struct in6_addr ipv6;
    } foreignAddress;
    union {
        struct ifh_in4in6_addr ipv4;
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

struct ifh_tcp_sockinfo {
    struct ifh_in_sockinfo internet;
    int state;
    int timers[4];
    int maximumSegmentSize;
    uint32_t flags;
    uint32_t reserved;
    uint64_t controlBlock;
};

struct ifh_sockbuf_info {
    uint32_t byteCount;
    uint32_t highWater;
    uint32_t mbufCount;
    uint32_t maximumMbufCount;
    uint32_t lowWater;
    int16_t flags;
    int16_t timeout;
};

struct ifh_socket_info {
    struct ifh_vinfo_stat stat;
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
    struct ifh_sockbuf_info receive;
    struct ifh_sockbuf_info send;
    int kind;
    uint32_t reserved;
    union {
        struct ifh_in_sockinfo internet;
        struct ifh_tcp_sockinfo tcp;
        uint8_t raw[768];
    } protocolInfo;
};

struct ifh_socket_fdinfo {
    struct ifh_proc_fileinfo file;
    struct ifh_socket_info socket;
};

typedef int (*IFHProcPidInfoFn)(int, int, uint64_t, void *, int);
typedef int (*IFHProcPidFDInfoFn)(int, int, int, void *, int);
typedef int (*IFHProcNameFn)(int, void *, uint32_t);
typedef int (*IFHProcListPidsFn)(uint32_t, uint32_t, void *, int);

static NSString *IFHStateDirectory(void) {
    return IFBootstrapPath(@"/var/lib/ifetch");
}

static NSString *IFHStatePath(void) {
    return [IFHStateDirectory() stringByAppendingPathComponent:@"diagnostic-mode.plist"];
}

static NSString *IFHTweakDirectory(void) {
    return IFBootstrapPath(@"/usr/lib/TweakInject");
}

static void IFHPrintJSON(id object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (data.length > 0) {
        fwrite(data.bytes, 1, data.length, stdout);
        fwrite("\n", 1, 1, stdout);
    }
}

static BOOL IFHIsSafeFilename(NSString *filename) {
    return filename.length > 0 &&
        [filename.lastPathComponent isEqualToString:filename] &&
        [filename.pathExtension.lowercaseString isEqualToString:@"dylib"];
}

static BOOL IFHIsCriticalTweak(NSString *filename) {
    NSString *lower = filename.lowercaseString;
    for (NSString *name in @[@"ellekit", @"substrate", @"libhooker", @"substitute", @"safe", @"ifetch"]) {
        if ([lower containsString:name]) {
            return YES;
        }
    }
    return NO;
}

static BOOL IFHRegularRootFile(NSString *path) {
    struct stat info = {0};
    return lstat(path.fileSystemRepresentation, &info) == 0 &&
        S_ISREG(info.st_mode) && info.st_uid == 0;
}

static NSDictionary *IFHEnableDiagnosticMode(void) {
    NSFileManager *manager = NSFileManager.defaultManager;
    NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:IFHStatePath()];
    NSArray *currentFiles = [current[@"files"] isKindOfClass:[NSArray class]] ? current[@"files"] : @[];
    if (currentFiles.count > 0) {
        return @{@"success": @YES, @"count": @(currentFiles.count)};
    }
    NSError *directoryError = nil;
    if (![manager createDirectoryAtPath:IFHStateDirectory() withIntermediateDirectories:YES
                              attributes:@{NSFilePosixPermissions: @0755} error:&directoryError]) {
        return @{@"success": @NO, @"error": directoryError.localizedDescription ?: @"state directory failed"};
    }
    NSMutableArray<NSString *> *moved = [NSMutableArray array];
    for (NSString *filename in [manager contentsOfDirectoryAtPath:IFHTweakDirectory() error:nil]) {
        if (!IFHIsSafeFilename(filename) || IFHIsCriticalTweak(filename)) {
            continue;
        }
        NSString *source = [IFHTweakDirectory() stringByAppendingPathComponent:filename];
        NSString *destination = [[source stringByDeletingPathExtension] stringByAppendingPathExtension:@"disabled"];
        if (!IFHRegularRootFile(source) || [manager fileExistsAtPath:destination]) {
            continue;
        }
        if (rename(source.fileSystemRepresentation, destination.fileSystemRepresentation) != 0) {
            for (NSString *changed in moved.reverseObjectEnumerator) {
                NSString *disabled = [[[IFHTweakDirectory() stringByAppendingPathComponent:changed]
                    stringByDeletingPathExtension] stringByAppendingPathExtension:@"disabled"];
                NSString *original = [IFHTweakDirectory() stringByAppendingPathComponent:changed];
                rename(disabled.fileSystemRepresentation, original.fileSystemRepresentation);
            }
            return @{@"success": @NO, @"error": [NSString stringWithUTF8String:strerror(errno)] ?: @"rename failed"};
        }
        [moved addObject:filename];
    }
    if (moved.count == 0) {
        return @{@"success": @NO, @"error": @"No active third-party tweaks found"};
    }
    NSDictionary *state = @{@"createdAt": NSDate.date, @"files": moved};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:state
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0 error:nil];
    if (data == nil || ![data writeToFile:IFHStatePath() options:NSDataWritingAtomic error:nil]) {
        for (NSString *changed in moved.reverseObjectEnumerator) {
            NSString *disabled = [[[IFHTweakDirectory() stringByAppendingPathComponent:changed]
                stringByDeletingPathExtension] stringByAppendingPathExtension:@"disabled"];
            NSString *original = [IFHTweakDirectory() stringByAppendingPathComponent:changed];
            rename(disabled.fileSystemRepresentation, original.fileSystemRepresentation);
        }
        return @{@"success": @NO, @"error": @"Could not save restore state"};
    }
    chmod(IFHStatePath().fileSystemRepresentation, 0644);
    chown(IFHStatePath().fileSystemRepresentation, 0, 0);
    return @{@"success": @YES, @"count": @(moved.count)};
}

static NSDictionary *IFHRestoreDiagnosticMode(void) {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:IFHStatePath()];
    NSArray<NSString *> *files = [state[@"files"] isKindOfClass:[NSArray class]] ? state[@"files"] : @[];
    if (files.count == 0) {
        return @{@"success": @NO, @"error": @"No diagnostic-mode state found"};
    }
    NSUInteger restored = 0;
    for (NSString *filename in files) {
        if (!IFHIsSafeFilename(filename)) {
            return @{@"success": @NO, @"error": @"Invalid restore entry"};
        }
        NSString *original = [IFHTweakDirectory() stringByAppendingPathComponent:filename];
        NSString *disabled = [[original stringByDeletingPathExtension] stringByAppendingPathExtension:@"disabled"];
        if (!IFHRegularRootFile(disabled)) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:original]) {
                continue;
            }
            return @{@"success": @NO, @"error": [NSString stringWithFormat:@"Missing %@", disabled.lastPathComponent]};
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:original] ||
            rename(disabled.fileSystemRepresentation, original.fileSystemRepresentation) != 0) {
            return @{@"success": @NO, @"error": [NSString stringWithUTF8String:strerror(errno)] ?: @"restore failed"};
        }
        restored++;
    }
    unlink(IFHStatePath().fileSystemRepresentation);
    return @{@"success": @YES, @"count": @(restored)};
}

static NSString *IFHAddress(const struct ifh_in_sockinfo *info, BOOL local) {
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
    return address != NULL && inet_ntop(family, address, buffer, sizeof(buffer)) != NULL
        ? [NSString stringWithUTF8String:buffer] ?: @"" : @"";
}

static NSString *IFHEndpoint(const struct ifh_in_sockinfo *info, BOOL local) {
    NSString *address = IFHAddress(info, local);
    uint16_t port = ntohs((uint16_t)(local ? info->localPort : info->foreignPort));
    if ([address isEqualToString:@"0.0.0.0"] || [address isEqualToString:@"::"] || address.length == 0) {
        address = local ? @"*" : @"—";
    }
    if (!local && port == 0) {
        return @"—";
    }
    return [address containsString:@":"]
        ? [NSString stringWithFormat:@"[%@]:%u", address, port]
        : [NSString stringWithFormat:@"%@:%u", address, port];
}

static NSString *IFHTCPState(int state) {
    NSArray *states = @[
        @"CLOSED", @"LISTEN", @"SYN-SENT", @"SYN-RECEIVED", @"ESTABLISHED",
        @"CLOSE-WAIT", @"FIN-WAIT-1", @"CLOSING", @"LAST-ACK", @"FIN-WAIT-2",
        @"TIME-WAIT", @"RESERVED"
    ];
    return state >= 0 && state < (int)states.count ? states[(NSUInteger)state] : @"";
}

static NSArray *IFHConnections(NSArray<NSNumber *> *pids) {
    IFHProcPidInfoFn procPidInfo = (IFHProcPidInfoFn)dlsym(RTLD_DEFAULT, "proc_pidinfo");
    IFHProcPidFDInfoFn procPidFDInfo = (IFHProcPidFDInfoFn)dlsym(RTLD_DEFAULT, "proc_pidfdinfo");
    IFHProcNameFn procName = (IFHProcNameFn)dlsym(RTLD_DEFAULT, "proc_name");
    if (procPidInfo == NULL || procPidFDInfo == NULL) {
        return @[];
    }
    NSMutableArray *connections = [NSMutableArray array];
    const int capacity = 4096;
    for (NSNumber *pidValue in pids) {
        pid_t pid = pidValue.intValue;
        if (pid <= 0) {
            continue;
        }
        char processBuffer[1024] = {0};
        NSString *processName = procName != NULL && procName(pid, processBuffer, sizeof(processBuffer)) > 0
            ? [NSString stringWithUTF8String:processBuffer] ?: [NSString stringWithFormat:@"PID %d", pid]
            : [NSString stringWithFormat:@"PID %d", pid];
        struct ifh_proc_fdinfo *descriptors = calloc((size_t)capacity, sizeof(struct ifh_proc_fdinfo));
        if (descriptors == NULL) {
            continue;
        }
        int bytes = procPidInfo(pid, 1, 0, descriptors,
                                capacity * (int)sizeof(struct ifh_proc_fdinfo));
        int count = MAX(0, bytes / (int)sizeof(struct ifh_proc_fdinfo));
        for (int index = 0; index < count; index++) {
            if (descriptors[index].proc_fdtype != 2) {
                continue;
            }
            struct ifh_socket_fdinfo info = {0};
            int result = procPidFDInfo(pid, descriptors[index].proc_fd, 3, &info, sizeof(info));
            if (result <= 0 || (info.socket.family != AF_INET && info.socket.family != AF_INET6)) {
                continue;
            }
            const struct ifh_in_sockinfo *internet = info.socket.protocol == IPPROTO_TCP
                ? &info.socket.protocolInfo.tcp.internet : &info.socket.protocolInfo.internet;
            NSString *protocol = info.socket.protocol == IPPROTO_TCP ? @"TCP"
                : info.socket.protocol == IPPROTO_UDP ? @"UDP"
                : [NSString stringWithFormat:@"%d", info.socket.protocol];
            [connections addObject:@{
                @"pid": @(pid),
                @"process": processName,
                @"protocol": protocol,
                @"local": IFHEndpoint(internet, YES),
                @"remote": IFHEndpoint(internet, NO),
                @"state": info.socket.protocol == IPPROTO_TCP ? IFHTCPState(info.socket.protocolInfo.tcp.state) : @""
            }];
        }
        free(descriptors);
    }
    return connections;
}

static NSDictionary *IFHRefreshWidgets(void) {
    IFHProcListPidsFn listPids = (IFHProcListPidsFn)dlsym(RTLD_DEFAULT, "proc_listpids");
    IFHProcNameFn processName = (IFHProcNameFn)dlsym(RTLD_DEFAULT, "proc_name");
    if (listPids == NULL || processName == NULL) {
        return @{@"success": @NO, @"error": @"Process API is unavailable"};
    }
    const int capacity = 4096;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (pids == NULL) {
        return @{@"success": @NO, @"error": @"Could not allocate process list"};
    }
    NSSet<NSString *> *targets = [NSSet setWithObjects:@"IFetchWidgets", @"chronod", nil];
    int bytes = listPids(1, 0, pids, capacity * (int)sizeof(pid_t));
    int count = MAX(0, bytes / (int)sizeof(pid_t));
    NSUInteger stopped = 0;
    for (int index = 0; index < count; index++) {
        pid_t pid = pids[index];
        if (pid <= 1) {
            continue;
        }
        char buffer[1024] = {0};
        if (processName(pid, buffer, sizeof(buffer)) <= 0) {
            continue;
        }
        NSString *name = [NSString stringWithUTF8String:buffer] ?: @"";
        if ([targets containsObject:name] && (kill(pid, SIGTERM) == 0 || errno == ESRCH)) {
            stopped++;
        }
    }
    free(pids);
    return @{@"success": @YES, @"stopped": @(stopped)};
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (setuid(0) != 0 || geteuid() != 0) {
            IFHPrintJSON(@{@"success": @NO, @"error": @"Root helper is not installed with setuid permissions"});
            return 77;
        }
        if (argc < 2) {
            IFHPrintJSON(@{@"success": @NO, @"error": @"Missing command"});
            return 64;
        }
        NSString *command = [NSString stringWithUTF8String:argv[1]] ?: @"";
        if ([command isEqualToString:@"diagnostic-enable"]) {
            NSDictionary *result = IFHEnableDiagnosticMode();
            IFHPrintJSON(result);
            return [result[@"success"] boolValue] ? 0 : 1;
        }
        if ([command isEqualToString:@"diagnostic-restore"]) {
            NSDictionary *result = IFHRestoreDiagnosticMode();
            IFHPrintJSON(result);
            return [result[@"success"] boolValue] ? 0 : 1;
        }
        if ([command isEqualToString:@"diagnostic-status"]) {
            NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:IFHStatePath()];
            NSArray *files = [state[@"files"] isKindOfClass:[NSArray class]] ? state[@"files"] : @[];
            IFHPrintJSON(@{@"success": @YES, @"enabled": @(files.count > 0), @"count": @(files.count)});
            return 0;
        }
        if ([command isEqualToString:@"connections"]) {
            NSMutableArray<NSNumber *> *pids = [NSMutableArray array];
            for (int index = 2; index < argc && pids.count < 32; index++) {
                int value = atoi(argv[index]);
                if (value > 0) {
                    [pids addObject:@(value)];
                }
            }
            IFHPrintJSON(@{@"success": @YES, @"connections": IFHConnections(pids)});
            return 0;
        }
        if ([command isEqualToString:@"widget-refresh"]) {
            IFHPrintJSON(IFHRefreshWidgets());
            return 0;
        }
        IFHPrintJSON(@{@"success": @NO, @"error": @"Unsupported command"});
        return 64;
    }
}
