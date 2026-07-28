#import <Foundation/Foundation.h>

#import "IFDiagnostics.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IFIntegritySeverity) {
    IFIntegritySeverityInfo,
    IFIntegritySeverityWarning,
    IFIntegritySeverityProblem
};

@interface IFProcessConnection : NSObject
@property (nonatomic, assign) pid_t pid;
@property (nonatomic, copy) NSString *processName;
@property (nonatomic, copy) NSString *protocolName;
@property (nonatomic, copy) NSString *localEndpoint;
@property (nonatomic, copy) NSString *remoteEndpoint;
@property (nonatomic, copy) NSString *state;
@end

@interface IFCrashAnalysis : NSObject
@property (nonatomic, copy) NSString *processName;
@property (nonatomic, copy) NSString *exceptionType;
@property (nonatomic, copy) NSString *terminationReason;
@property (nonatomic, copy) NSString *faultingThread;
@property (nonatomic, copy) NSArray<NSString *> *suspectedTweaks;
@property (nonatomic, copy) NSString *summary;
@end

@interface IFInjectionGroup : NSObject
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSArray<NSString *> *tweaks;
@property (nonatomic, copy) NSArray<NSString *> *runningProcesses;
@end

@interface IFLaunchDaemonRecord : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *program;
@property (nonatomic, assign, getter=isLoaded) BOOL loaded;
@property (nonatomic, assign) pid_t pid;
@end

@interface IFIntegrityIssue : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) IFIntegritySeverity severity;
@end

@interface IFAdvancedDiagnostics : NSObject

+ (NSArray<IFProcessConnection *> *)connectionsForProcess:(IFProcessSample *)process;
+ (IFCrashAnalysis *)analysisForCrashLog:(IFCrashLog *)log;
+ (NSArray<IFInjectionGroup *> *)injectionMap;
+ (NSArray<IFLaunchDaemonRecord *> *)launchDaemons;
+ (NSArray<IFIntegrityIssue *> *)integrityIssues;

+ (NSArray<NSDictionary<NSString *, id> *> *)systemSnapshots;
+ (nullable NSDictionary<NSString *, id> *)captureSystemSnapshotNamed:(NSString *)name
                                                                 error:(NSError **)error;
+ (BOOL)deleteSystemSnapshot:(NSDictionary<NSString *, id> *)snapshot error:(NSError **)error;
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)compareSnapshot:(NSDictionary<NSString *, id> *)older
                                                                  with:(NSDictionary<NSString *, id> *)newer;

+ (BOOL)diagnosticModeEnabled;
+ (NSUInteger)diagnosticModeDisabledCount;
+ (BOOL)enableDiagnosticModeWithError:(NSError **)error;
+ (BOOL)restoreDiagnosticModeWithError:(NSError **)error;

+ (BOOL)alertsEnabled;
+ (void)setAlertsEnabled:(BOOL)enabled completion:(void (^)(BOOL granted))completion;
+ (void)evaluateAlertsWithMonitor:(IFLiveMetricsMonitor *)monitor;

@end

NS_ASSUME_NONNULL_END
