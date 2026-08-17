#import <Foundation/Foundation.h>
#import <unistd.h>

#import "../core/IFDiagnostics.h"
#import "../core/IFetchCore.h"

static NSString *IFT(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

static NSString *IFColor(NSString *code, NSString *text, BOOL enabled) {
    return enabled ? [NSString stringWithFormat:@"\033[%@m%@\033[0m", code, text] : text;
}

static void IFPrintLine(NSString *label, NSString *value, BOOL color) {
    printf("  %s: %s\n", IFColor(@"1;36", label, color).UTF8String, (value ?: @"").UTF8String);
}

static NSString *IFSynchronousPublicIP(void) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *address = IFT(@"Unavailable", @"Недоступно");
    [IFNetworkMonitor fetchPublicIPAddressWithCompletion:^(NSString *result) {
        address = result;
        dispatch_semaphore_signal(semaphore);
    }];
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:5.5];
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0 && timeout.timeIntervalSinceNow > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return address;
}

static NSString *IFStringNumber(NSNumber *number, NSString *suffix) {
    return number ? [NSString stringWithFormat:@"%.1f%@", number.doubleValue, suffix]
                  : IFT(@"Unavailable", @"Недоступно");
}

static NSDictionary *IFBuildSnapshot(IFNetworkMonitor *networkMonitor,
                                     IFProcessMonitor *processMonitor,
                                     NSUInteger processLimit,
                                     NSString *publicIP) {
    IFDeviceInfo *device = [IFDeviceInfo currentDevice];
    IFJailbreakInfo *jailbreak = [IFetchCore jailbreakInfo];
    IFNetworkSnapshot *network = [networkMonitor refresh];
    [processMonitor refresh];
    IFBatteryDetails *battery = [IFDiagnostics batteryDetails];
    NSDictionary *extendedNetwork = [IFDiagnostics extendedNetworkDetails];
    NSNumber *usedMemory = [IFetchCore usedMemoryBytes] ?: @0;
    NSNumber *totalStorage = [IFetchCore totalStorageBytes] ?: @0;
    NSNumber *usedStorage = [IFetchCore usedStorageBytes] ?: @0;

    NSMutableArray *topCPU = [NSMutableArray array];
    for (IFProcessSample *sample in [processMonitor topProcessesByCPU:processLimit]) {
        [topCPU addObject:@{
            @"pid": @(sample.pid),
            @"name": sample.name ?: @"",
            @"path": sample.executablePath ?: @"",
            @"cpu_percent": @(sample.cpuPercent),
            @"resident_bytes": @(sample.residentBytes),
            @"threads": @(sample.threadCount),
            @"jetsam_band": sample.jetsamBandName ?: @"",
            @"jetsam_priority": @(sample.jetsamPriority),
            @"jetsam_limit_bytes": @(sample.jetsamLimitBytes),
            @"jetsam_usage_percent": @(sample.jetsamUsagePercent)
        }];
    }
    NSMutableArray *topMemory = [NSMutableArray array];
    for (IFProcessSample *sample in [processMonitor topProcessesByMemory:processLimit]) {
        [topMemory addObject:@{
            @"pid": @(sample.pid),
            @"name": sample.name ?: @"",
            @"path": sample.executablePath ?: @"",
            @"cpu_percent": @(sample.cpuPercent),
            @"resident_bytes": @(sample.residentBytes),
            @"threads": @(sample.threadCount),
            @"jetsam_band": sample.jetsamBandName ?: @"",
            @"jetsam_priority": @(sample.jetsamPriority),
            @"jetsam_limit_bytes": @(sample.jetsamLimitBytes),
            @"jetsam_usage_percent": @(sample.jetsamUsagePercent)
        }];
    }

    return @{
        @"version": [IFetchCore versionString],
        @"device": @{@"name": device.modelName, @"identifier": device.identifier,
                      @"chip": device.chipName, @"architecture": device.architectureName},
        @"thermal": @{@"state": [IFetchCore thermalStateDescription],
                      @"state_raw": @([IFetchCore thermalStateRaw]),
                      @"throttling": @([IFetchCore isThermalThrottling]),
                      @"summary": [IFetchCore thermalThrottlingSummary]},
        @"system": @{@"ios": NSProcessInfo.processInfo.operatingSystemVersionString,
                      @"kernel": [IFetchCore darwinVersion], @"uptime": [IFetchCore systemUptime],
                      @"memory_used_bytes": usedMemory, @"memory_total_bytes": @([IFetchCore totalMemoryBytes]),
                      @"storage_used_bytes": usedStorage, @"storage_total_bytes": totalStorage},
        @"battery": @{@"health_percent": @(battery.healthPercent),
                       @"current_capacity_mah": battery.currentCapacity ?: @0,
                       @"maximum_capacity_mah": battery.maximumCapacity ?: @0,
                       @"design_capacity_mah": battery.designCapacity ?: @0,
                       @"cycles": battery.cycleCount ?: @0,
                       @"temperature_celsius": battery.temperatureCelsius ?: @0,
                       @"voltage_mv": battery.voltageMillivolts ?: @0,
                       @"amperage_ma": battery.amperageMilliamps ?: @0,
                       @"charging_watts": @(battery.chargingWatts)},
        @"jailbreak": @{@"environment": jailbreak.environmentName, @"root": jailbreak.rootPrefix,
                         @"injector": jailbreak.injectorDescription,
                         @"packages": @(jailbreak.installedPackageCount),
                         @"tweaks": @(jailbreak.activeTweakCount),
                         @"crash_logs_24h": @(jailbreak.recentCrashCount)},
        @"network": @{@"download_bytes_per_second": @(network.downloadBytesPerSecond),
                       @"upload_bytes_per_second": @(network.uploadBytesPerSecond),
                       @"local_ip": network.localIPAddress, @"public_ip": publicIP,
                       @"interface": network.activeInterface,
                       @"dns": network.dnsServers ?: @[], @"details": extendedNetwork},
        @"processes": @{@"top_cpu": topCPU, @"top_memory": topMemory}
    };
}

static void IFPrintLogo(BOOL color) {
    NSString *logo = IFColor(@"1;35",
        @"        .:'\n"
         "    __ :'__\n"
         " .'`_ `-'_``.\n"
         ":________.-'\n"
         ":_______:\n"
         " :_______`-;\n"
         "  `._.-._.'\n", color);
    printf("%s\n", logo.UTF8String);
}

static void IFPrintSnapshot(NSDictionary *snapshot, BOOL color, NSUInteger processLimit,
                            BOOL networkOnly, BOOL batteryOnly) {
    NSDictionary *device = snapshot[@"device"];
    NSDictionary *system = snapshot[@"system"];
    NSDictionary *thermal = snapshot[@"thermal"];
    NSDictionary *battery = snapshot[@"battery"];
    NSDictionary *jailbreak = snapshot[@"jailbreak"];
    NSDictionary *network = snapshot[@"network"];

    if (!networkOnly && !batteryOnly) {
        IFPrintLogo(color);
        printf("%s\n\n", IFColor(@"1;37", [NSString stringWithFormat:@"iFetch %@ — iOS system fetch", snapshot[@"version"]], color).UTF8String);
        IFPrintLine(IFT(@"Device", @"Устройство"), [NSString stringWithFormat:@"%@ (%@)", device[@"name"], device[@"identifier"]], color);
        IFPrintLine(IFT(@"System", @"Система"), [NSString stringWithFormat:@"iOS %@", system[@"ios"]], color);
        IFPrintLine(IFT(@"Chip", @"Чип"), device[@"chip"], color);
        IFPrintLine(IFT(@"Architecture", @"Архитектура"), device[@"architecture"], color);
        IFPrintLine(IFT(@"Kernel", @"Ядро"), system[@"kernel"], color);
        IFPrintLine(IFT(@"Uptime", @"Аптайм"), system[@"uptime"], color);
        IFPrintLine(IFT(@"Thermal", @"Термальный статус"), [NSString stringWithFormat:@"%@ (%@)", thermal[@"state"], [thermal[@"throttling"] boolValue] ? IFT(@"Throttling", @"Троттлинг") : IFT(@"Optimal", @"Оптимально")], color);
        IFPrintLine(IFT(@"Memory", @"ОЗУ"), [NSString stringWithFormat:@"%@ / %@",
            [IFetchCore formatBytes:[system[@"memory_used_bytes"] unsignedLongLongValue]],
            [IFetchCore formatBytes:[system[@"memory_total_bytes"] unsignedLongLongValue]]], color);
        IFPrintLine(IFT(@"Storage", @"Накопитель"), [NSString stringWithFormat:@"%@ / %@",
            [IFetchCore formatBytes:[system[@"storage_used_bytes"] unsignedLongLongValue]],
            [IFetchCore formatBytes:[system[@"storage_total_bytes"] unsignedLongLongValue]]], color);
        IFPrintLine(@"Jailbreak", jailbreak[@"environment"], color);
        IFPrintLine(IFT(@"Hook injector", @"Хук-инжектор"), jailbreak[@"injector"], color);
        IFPrintLine(IFT(@"Packages / tweaks", @"Пакеты / твики"),
            [NSString stringWithFormat:@"%@ / %@", jailbreak[@"packages"], jailbreak[@"tweaks"]], color);
        IFPrintLine(IFT(@"Crash logs 24h", @"Crash-логи 24ч"), [jailbreak[@"crash_logs_24h"] stringValue], color);
    }

    if (!networkOnly) {
        printf("\n%s\n", IFColor(@"1;33", IFT(@"Battery", @"Батарея"), color).UTF8String);
        IFPrintLine(IFT(@"Health", @"Здоровье"), [battery[@"health_percent"] doubleValue] > 0
            ? [NSString stringWithFormat:@"%.0f%%", [battery[@"health_percent"] doubleValue]] : IFT(@"Unavailable", @"Недоступно"), color);
        IFPrintLine(IFT(@"Capacity", @"Ёмкость"), [NSString stringWithFormat:@"%@ / %@ mAh",
            battery[@"maximum_capacity_mah"], battery[@"design_capacity_mah"]], color);
        IFPrintLine(IFT(@"Cycles", @"Циклы"), [battery[@"cycles"] stringValue], color);
        IFPrintLine(IFT(@"Temperature", @"Температура"), IFStringNumber(battery[@"temperature_celsius"], @" °C"), color);
        IFPrintLine(IFT(@"Charging power", @"Мощность зарядки"), IFStringNumber(battery[@"charging_watts"], @" W"), color);
    }

    if (!batteryOnly) {
        printf("\n%s\n", IFColor(@"1;33", IFT(@"Network", @"Сеть"), color).UTF8String);
        IFPrintLine(IFT(@"Local IP", @"Локальный IP"), network[@"local_ip"], color);
        IFPrintLine(IFT(@"Public IP", @"Публичный IP"), network[@"public_ip"], color);
        IFPrintLine(IFT(@"Interface", @"Интерфейс"), network[@"interface"], color);
        IFPrintLine(@"DNS", [network[@"dns"] count] ? [network[@"dns"] componentsJoinedByString:@", "] : IFT(@"Unavailable", @"Недоступно"), color);
        IFPrintLine(@"IPv6", network[@"details"][@"ipv6"], color);
        IFPrintLine(@"Wi-Fi", network[@"details"][@"ssid"], color);
        IFPrintLine(IFT(@"Cellular", @"Сотовая сеть"), network[@"details"][@"radio"], color);
        IFPrintLine(IFT(@"Network ↓ / ↑", @"Сеть ↓ / ↑"), [NSString stringWithFormat:@"%@ / %@",
            [IFetchCore formatRate:[network[@"download_bytes_per_second"] doubleValue]],
            [IFetchCore formatRate:[network[@"upload_bytes_per_second"] doubleValue]]], color);
    }

    if (!networkOnly && !batteryOnly && processLimit > 0) {
        for (NSString *metric in @[@"top_memory", @"top_cpu"]) {
            NSString *title = [metric isEqualToString:@"top_memory"] ? IFT(@"Top processes by memory", @"Top процессов по ОЗУ")
                                                                    : IFT(@"Top processes by CPU", @"Top процессов по CPU");
            printf("\n%s\n", IFColor(@"1;33", title, color).UTF8String);
            for (NSDictionary *process in snapshot[@"processes"][metric]) {
                printf("  %-22s %5.1f%%  %9s  PID %-5d  [%s]\n", [process[@"name"] UTF8String],
                       [process[@"cpu_percent"] doubleValue],
                       [IFetchCore formatBytes:[process[@"resident_bytes"] unsignedLongLongValue]].UTF8String,
                       [process[@"pid"] intValue],
                       [process[@"jetsam_band"] UTF8String]);
            }
        }
    }
    printf("\n");
}

static void IFPrintHelp(void) {
    printf("iFetch %s\n"
           "Usage: ifetch [options]\n\n",
           [IFetchCore versionString].UTF8String);
    printf(
           "  --report, -r         Output full system diagnostics report in Markdown\n"
           "  --json               Output machine-readable JSON\n"
           "  --watch              Refresh continuously\n"
           "  --interval SECONDS   Watch refresh interval (default: 1)\n"
           "  --processes COUNT    Number of processes to show (default: 3)\n"
           "  --network            Show only network diagnostics\n"
           "  --battery            Show only battery diagnostics\n"
           "  --lang en|ru         Select language for app and CLI\n"
           "  --no-color           Disable ANSI colors\n"
           "  --version            Print version\n"
           "  --help               Show this help\n");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BOOL json = NO;
        BOOL watch = NO;
        BOOL noColor = NO;
        BOOL networkOnly = NO;
        BOOL batteryOnly = NO;
        BOOL reportOnly = NO;
        NSUInteger processLimit = 3;
        double interval = 1;

        for (int index = 1; index < argc; index++) {
            NSString *argument = [NSString stringWithUTF8String:argv[index]];
            if ([argument isEqualToString:@"--help"] || [argument isEqualToString:@"-h"]) {
                IFPrintHelp();
                return 0;
            } else if ([argument isEqualToString:@"--version"]) {
                printf("%s\n", [IFetchCore versionString].UTF8String);
                return 0;
            } else if ([argument isEqualToString:@"--report"] || [argument isEqualToString:@"-r"]) {
                reportOnly = YES;
            } else if ([argument isEqualToString:@"--json"]) {
                json = YES;
            } else if ([argument isEqualToString:@"--watch"]) {
                watch = YES;
            } else if ([argument isEqualToString:@"--no-color"]) {
                noColor = YES;
            } else if ([argument isEqualToString:@"--network"]) {
                networkOnly = YES;
            } else if ([argument isEqualToString:@"--battery"]) {
                batteryOnly = YES;
            } else if ([argument isEqualToString:@"--interval"] && index + 1 < argc) {
                interval = MAX(0.2, atof(argv[++index]));
            } else if ([argument isEqualToString:@"--processes"] && index + 1 < argc) {
                processLimit = (NSUInteger)MAX(0, atoi(argv[++index]));
            } else if ([argument isEqualToString:@"--lang"] && index + 1 < argc) {
                NSString *language = [NSString stringWithUTF8String:argv[++index]];
                [IFLanguageManager setCurrentLanguage:[language isEqualToString:@"ru"] ? IFLanguageRussian : IFLanguageEnglish];
            } else {
                fprintf(stderr, "ifetch: unknown option: %s\n", argument.UTF8String);
                return 2;
            }
        }

        if (reportOnly) {
            NSString *report = [IFDiagnostics generateDiagnosticReportMarkdown];
            printf("%s\n", report.UTF8String);
            return 0;
        }

        BOOL color = isatty(STDOUT_FILENO) && !noColor && !json;
        IFNetworkMonitor *networkMonitor = [[IFNetworkMonitor alloc] init];
        IFProcessMonitor *processMonitor = [[IFProcessMonitor alloc] init];
        usleep(300000);
        NSString *publicIP = IFSynchronousPublicIP();

        do {
            @autoreleasepool {
                NSDictionary *snapshot = IFBuildSnapshot(networkMonitor, processMonitor, processLimit, publicIP);
                if (watch && !json) {
                    printf("\033[2J\033[H");
                }
                if (json) {
                    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot
                                                                   options:watch ? 0 : NSJSONWritingPrettyPrinted error:nil];
                    printf("%s\n", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] UTF8String]);
                } else {
                    IFPrintSnapshot(snapshot, color, processLimit, networkOnly, batteryOnly);
                    if (watch) {
                        printf("%s\n", IFColor(@"2;37", IFT(@"Press Ctrl+C to stop", @"Нажмите Ctrl+C для выхода"), color).UTF8String);
                    }
                }
            }
            if (watch) {
                usleep((useconds_t)(interval * 1000000.0));
            }
        } while (watch);
    }
    return 0;
}
