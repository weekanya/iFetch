#import <Foundation/Foundation.h>

#import "IFetchCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IFHealthState) {
    IFHealthStateGood,
    IFHealthStateWarning,
    IFHealthStateProblem
};

@interface IFBatteryDetails : NSObject
@property (nonatomic, strong, nullable) NSNumber *currentCapacity;
@property (nonatomic, strong, nullable) NSNumber *maximumCapacity;
@property (nonatomic, strong, nullable) NSNumber *designCapacity;
@property (nonatomic, strong, nullable) NSNumber *cycleCount;
@property (nonatomic, strong, nullable) NSNumber *temperatureCelsius;
@property (nonatomic, strong, nullable) NSNumber *voltageMillivolts;
@property (nonatomic, strong, nullable) NSNumber *amperageMilliamps;
@property (nonatomic, assign) BOOL charging;
@property (nonatomic, assign) BOOL externalConnected;
@property (nonatomic, readonly) double healthPercent;
@property (nonatomic, readonly) double chargingWatts;
@end

@interface IFCrashLog : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *preview;
@end

@interface IFTweakRecord : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *dylibPath;
@property (nonatomic, copy) NSString *packageIdentifier;
@property (nonatomic, copy) NSString *packageVersion;
@property (nonatomic, copy) NSArray<NSString *> *targetBundles;
@property (nonatomic, copy) NSArray<NSString *> *targetExecutables;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@end

@interface IFHealthItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) IFHealthState state;
@end

@interface IFMetricSample : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) double cpuPercent;
@property (nonatomic, assign) double memoryPercent;
@property (nonatomic, assign) double downloadBytesPerSecond;
@property (nonatomic, assign) double uploadBytesPerSecond;
@property (nonatomic, assign) double batteryTemperature;
@property (nonatomic, assign) double batteryLevel;
@end

@interface IFLiveMetricsMonitor : NSObject
@property (nonatomic, readonly) NSArray<IFMetricSample *> *history;
@property (nonatomic, readonly) IFNetworkSnapshot *network;
@property (nonatomic, readonly) IFProcessMonitor *processes;
- (void)refresh;
- (NSArray<IFProcessSample *> *)sustainedHighCPUProcesses;
@end

@interface IFDiagnostics : NSObject
+ (IFBatteryDetails *)batteryDetails;
+ (NSArray<IFCrashLog *> *)recentCrashLogsWithLimit:(NSUInteger)limit;
+ (NSArray<IFTweakRecord *> *)installedTweaks;
+ (NSArray<IFHealthItem *> *)healthItemsWithJailbreak:(IFJailbreakInfo *)jailbreak
                                              battery:(IFBatteryDetails *)battery
                                            processes:(NSArray<IFProcessSample *> *)hotProcesses;
+ (NSDictionary<NSString *, id> *)extendedNetworkDetails;
+ (NSString *)redactedAddress:(NSString *)address;
@end

NS_ASSUME_NONNULL_END
