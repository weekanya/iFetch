#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IFLanguage) {
    IFLanguageEnglish = 0,
    IFLanguageRussian = 1
};

@interface IFLanguageManager : NSObject

+ (IFLanguage)currentLanguage;
+ (void)setCurrentLanguage:(IFLanguage)language;
+ (BOOL)isRussian;
+ (NSString *)english:(NSString *)english russian:(NSString *)russian;

@end

@interface IFDeviceInfo : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *modelName;
@property (nonatomic, copy, readonly) NSString *chipName;
@property (nonatomic, copy, readonly) NSString *architectureName;
@property (nonatomic, copy, readonly) NSString *imageName;
@property (nonatomic, copy, readonly) NSString *systemVersion;

+ (instancetype)currentDevice;

@end

@interface IFProcessSample : NSObject

@property (nonatomic, assign) pid_t pid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *executablePath;
@property (nonatomic, assign) uint64_t residentBytes;
@property (nonatomic, assign) double cpuPercent;
@property (nonatomic, assign) NSInteger threadCount;
@property (nonatomic, assign) NSTimeInterval runningTime;

@end

@interface IFProcessMonitor : NSObject

- (NSArray<IFProcessSample *> *)topProcessesByMemory:(NSUInteger)limit;
- (NSArray<IFProcessSample *> *)topProcessesByCPU:(NSUInteger)limit;
- (NSArray<IFProcessSample *> *)allProcesses;
- (void)refresh;

@end

@interface IFNetworkSnapshot : NSObject

@property (nonatomic, assign) double downloadBytesPerSecond;
@property (nonatomic, assign) double uploadBytesPerSecond;
@property (nonatomic, copy) NSString *localIPAddress;
@property (nonatomic, copy) NSString *activeInterface;
@property (nonatomic, copy) NSArray<NSString *> *dnsServers;

@end

@interface IFNetworkMonitor : NSObject

- (IFNetworkSnapshot *)refresh;
+ (void)fetchPublicIPAddressWithCompletion:(void (^)(NSString *address))completion;

@end

@interface IFJailbreakInfo : NSObject

@property (nonatomic, copy) NSString *environmentName;
@property (nonatomic, copy) NSString *rootPrefix;
@property (nonatomic, copy) NSString *injectorDescription;
@property (nonatomic, assign) NSInteger installedPackageCount;
@property (nonatomic, assign) NSInteger activeTweakCount;
@property (nonatomic, assign) NSInteger recentCrashCount;

@end

@interface IFetchCore : NSObject

+ (NSString *)versionString;
+ (uint64_t)totalMemoryBytes;
+ (nullable NSNumber *)usedMemoryBytes;
+ (nullable NSNumber *)totalStorageBytes;
+ (nullable NSNumber *)usedStorageBytes;
+ (NSString *)systemUptime;
+ (NSString *)darwinVersion;
+ (nullable NSString *)batteryCycleCount;
+ (IFJailbreakInfo *)jailbreakInfo;
+ (nullable NSString *)executablePathForCandidates:(NSArray<NSString *> *)candidates;
+ (NSString *)formatBytes:(uint64_t)bytes;
+ (NSString *)formatRate:(double)bytesPerSecond;

@end

NS_ASSUME_NONNULL_END
