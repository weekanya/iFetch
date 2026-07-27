#import <Foundation/Foundation.h>
#import <unistd.h>

#import "IFetchCore.h"

static NSString *IFT(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static NSString *IFColor(NSString *code, NSString *text, BOOL enabled) {
    return enabled ? [NSString stringWithFormat:@"\033[%@m%@\033[0m", code, text] : text;
}

static void IFPrintLine(NSString *label, NSString *value, BOOL color) {
    NSString *coloredLabel = IFColor(@"1;36", label, color);
    printf("  %s: %s\n", coloredLabel.UTF8String, value.UTF8String);
}

static NSString *IFSynchronousPublicIP(void) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *address = IFT(@"Unavailable", @"Недоступно");
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
        NSString *title = [NSString stringWithFormat:@"iFetch %@ — iOS system fetch", [IFetchCore versionString]];
        printf("%s\n\n", IFColor(@"1;37", title, color).UTF8String);

        IFPrintLine(IFT(@"Device", @"Устройство"), [NSString stringWithFormat:@"%@ (%@)", device.modelName, device.identifier], color);
        IFPrintLine(IFT(@"System", @"Система"), [NSString stringWithFormat:@"iOS %@", [NSProcessInfo processInfo].operatingSystemVersionString], color);
        IFPrintLine(IFT(@"Chip", @"Чип"), device.chipName, color);
        IFPrintLine(IFT(@"Architecture", @"Архитектура"), device.architectureName, color);
        IFPrintLine(IFT(@"Kernel", @"Ядро"), [IFetchCore darwinVersion], color);
        IFPrintLine(IFT(@"Uptime", @"Аптайм"), [IFetchCore systemUptime], color);

        NSNumber *usedMemory = [IFetchCore usedMemoryBytes];
        NSString *memory = usedMemory
            ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedMemory.unsignedLongLongValue],
               [IFetchCore formatBytes:[IFetchCore totalMemoryBytes]]]
            : IFT(@"Unavailable", @"Недоступно");
        IFPrintLine(IFT(@"Memory", @"ОЗУ"), memory, color);

        NSNumber *usedStorage = [IFetchCore usedStorageBytes];
        NSNumber *totalStorage = [IFetchCore totalStorageBytes];
        NSString *storage = usedStorage && totalStorage
            ? [NSString stringWithFormat:@"%@ / %@", [IFetchCore formatBytes:usedStorage.unsignedLongLongValue],
               [IFetchCore formatBytes:totalStorage.unsignedLongLongValue]]
            : IFT(@"Unavailable", @"Недоступно");
        IFPrintLine(IFT(@"Storage", @"Накопитель"), storage, color);

        IFPrintLine(@"Jailbreak", jailbreak.environmentName, color);
        IFPrintLine(IFT(@"Hook injector", @"Хук-инжектор"), jailbreak.injectorDescription, color);
        IFPrintLine(IFT(@"Packages / tweaks", @"Пакеты / твики"),
                    [NSString stringWithFormat:@"%ld / %ld", (long)jailbreak.installedPackageCount,
                     (long)jailbreak.activeTweakCount], color);
        IFPrintLine(IFT(@"Crash logs 24h", @"Crash-логи 24ч"), [NSString stringWithFormat:@"%ld", (long)jailbreak.recentCrashCount], color);

        IFPrintLine(IFT(@"Local IP", @"Локальный IP"), network.localIPAddress, color);
        IFPrintLine(IFT(@"Public IP", @"Публичный IP"), IFSynchronousPublicIP(), color);
        IFPrintLine(IFT(@"Interface", @"Интерфейс"), network.activeInterface, color);
        IFPrintLine(@"VPN", network.vpnInterface, color);
        IFPrintLine(@"DNS", network.dnsServers.count > 0 ? [network.dnsServers componentsJoinedByString:@", "] : IFT(@"Unavailable", @"Недоступно"), color);
        IFPrintLine(IFT(@"Network ↓ / ↑", @"Сеть ↓ / ↑"),
                    [NSString stringWithFormat:@"%@ / %@",
                     [IFetchCore formatRate:network.downloadBytesPerSecond],
                     [IFetchCore formatRate:network.uploadBytesPerSecond]], color);

        printf("\n%s\n", IFColor(@"1;33", IFT(@"Top-3 processes by memory", @"Top-3 процессов по ОЗУ"), color).UTF8String);
        NSArray<IFProcessSample *> *topMemory = [processMonitor topProcessesByMemory:3];
        if (topMemory.count == 0) {
            printf("  %s (proc_pidinfo)\n", IFT(@"Unavailable", @"Недоступно").UTF8String);
        }
        for (IFProcessSample *sample in topMemory) {
            printf("  %-22s %9s  %5.1f%% CPU\n", sample.name.UTF8String,
                   [IFetchCore formatBytes:sample.residentBytes].UTF8String, sample.cpuPercent);
        }

        printf("\n%s\n", IFColor(@"1;33", IFT(@"Top-3 processes by CPU", @"Top-3 процессов по CPU"), color).UTF8String);
        NSArray<IFProcessSample *> *topCPU = [processMonitor topProcessesByCPU:3];
        if (topCPU.count == 0) {
            printf("  %s (proc_pidinfo)\n", IFT(@"Unavailable", @"Недоступно").UTF8String);
        }
        for (IFProcessSample *sample in topCPU) {
            printf("  %-22s %5.1f%% CPU  %s\n", sample.name.UTF8String, sample.cpuPercent,
                   [IFetchCore formatBytes:sample.residentBytes].UTF8String);
        }
        printf("\n");
    }
    return 0;
}
