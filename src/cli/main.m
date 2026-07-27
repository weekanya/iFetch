#import <Foundation/Foundation.h>
#import <unistd.h>

#import "IFetchCore.h"

static NSString *IFColor(NSString *code, NSString *text, BOOL enabled) {
    return enabled ? [NSString stringWithFormat:@"\033[%@m%@\033[0m", code, text] : text;
}

static void IFPrintLine(NSString *label, NSString *value, BOOL color) {
    NSString *coloredLabel = IFColor(@"1;36", label, color);
    printf("  %s: %s\n", coloredLabel.UTF8String, value.UTF8String);
}

static NSString *IFSynchronousPublicIP(void) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *address = @"Недоступно";
    [IFNetworkMonitor fetchPublicIPAddressWithCompletion:^(NSString *result) {
        address = result;
        dispatch_semaphore_signal(semaphore);
    }];

    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:5.5];
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 && [timeout timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return address;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        (void)argc;
        (void)argv;
        BOOL color = isatty(STDOUT_FILENO);
        IFDeviceInfo *device = [IFDeviceInfo currentDevice];
        IFJailbreakInfo *jailbreak = [IFetchCore jailbreakInfo];
        IFNetworkMonitor *networkMonitor = [[IFNetworkMonitor alloc] init];
        IFProcessMonitor *processMonitor = [[IFProcessMonitor alloc] init];

        usleep(300000);
        IFNetworkSnapshot *network = [networkMonitor refresh];
        [processMonitor refresh];

        NSString *logo = IFColor(@"1;35",
            @"        .:'\n"
             "    __ :'__\n"
             " .'`_ `-'_``.\n"
             ":________.-'\n"
             ":_______:\n"
             " :_______`-;\n"
             "  `._.-._.'\n", color);
        printf("%s\n", logo.UTF8String);
        printf("%s\n\n", IFColor(@"1;37", @"iFetch 2.0.0 — iOS system fetch", color).UTF8String);

        IFPrintLine(@"Устройство", [NSString stringWithFormat:@"%@ (%@)", device.modelName, device.identifier], color);
        IFPrintLine(@"Система", [NSString stringWithFormat:@"iOS %@", [NSProcessInfo processInfo].operatingSystemVersionString], color);
        IFPrintLine(@"Чип", device.chipName, color);
        IFPrintLine(@"Архитектура", device.architectureName, color);
        IFPrintLine(@"Ядро", [IFetchCore darwinVersion], color);
        IFPrintLine(@"Аптайм", [IFetchCore systemUptime], color);

        NSNumber *usedMemory = [IFetchCore usedMemoryBytes];
        NSString *memory = usedMemory
            ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedMemory.unsignedLongLongValue],
               [IFetchCore formatBytes:[IFetchCore totalMemoryBytes]]]
            : @"Недоступно";
        IFPrintLine(@"ОЗУ", memory, color);

        NSNumber *usedStorage = [IFetchCore usedStorageBytes];
        NSNumber *totalStorage = [IFetchCore totalStorageBytes];
        NSString *storage = usedStorage && totalStorage
            ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedStorage.unsignedLongLongValue],
               [IFetchCore formatBytes:totalStorage.unsignedLongLongValue]]
            : @"Недоступно";
        IFPrintLine(@"Накопитель", storage, color);

        IFPrintLine(@"Jailbreak", jailbreak.environmentName, color);
        IFPrintLine(@"Хук-инжектор", jailbreak.injectorDescription, color);
        IFPrintLine(@"Пакеты / твики",
                    [NSString stringWithFormat:@"%ld / %ld", (long)jailbreak.installedPackageCount,
                     (long)jailbreak.activeTweakCount], color);
        IFPrintLine(@"Crash-логи 24ч", [NSString stringWithFormat:@"%ld", (long)jailbreak.recentCrashCount], color);

        IFPrintLine(@"Локальный IP", network.localIPAddress, color);
        IFPrintLine(@"Публичный IP", IFSynchronousPublicIP(), color);
        IFPrintLine(@"Интерфейс", network.activeInterface, color);
        IFPrintLine(@"VPN", network.vpnInterface, color);
        IFPrintLine(@"DNS", network.dnsServers.count > 0 ? [network.dnsServers componentsJoinedByString:@", "] : @"Недоступно", color);
        IFPrintLine(@"Сеть ↓ / ↑",
                    [NSString stringWithFormat:@"%@ / %@",
                     [IFetchCore formatRate:network.downloadBytesPerSecond],
                     [IFetchCore formatRate:network.uploadBytesPerSecond]], color);

        printf("\n%s\n", IFColor(@"1;33", @"Top-3 процессов по ОЗУ", color).UTF8String);
        NSArray<IFProcessSample *> *topMemory = [processMonitor topProcessesByMemory:3];
        if (topMemory.count == 0) {
            printf("  Недоступно (proc_pidinfo)\n");
        }
        for (IFProcessSample *sample in topMemory) {
            printf("  %-22s %9s  %5.1f%% CPU\n", sample.name.UTF8String,
                   [IFetchCore formatBytes:sample.residentBytes].UTF8String, sample.cpuPercent);
        }

        printf("\n%s\n", IFColor(@"1;33", @"Top-3 процессов по CPU", color).UTF8String);
        NSArray<IFProcessSample *> *topCPU = [processMonitor topProcessesByCPU:3];
        if (topCPU.count == 0) {
            printf("  Недоступно (proc_pidinfo)\n");
        }
        for (IFProcessSample *sample in topCPU) {
            printf("  %-22s %5.1f%% CPU  %s\n", sample.name.UTF8String, sample.cpuPercent,
                   [IFetchCore formatBytes:sample.residentBytes].UTF8String);
        }
        printf("\n");
    }
    return 0;
}
