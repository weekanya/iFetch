#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>
#import <objc/message.h>

#import "../IFDiagnostics.h"
#import "../IFetchCore.h"

@interface IFetchModuleViewController : UIViewController <CCUIContentModuleContentViewController>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metricsLabel;
@property (nonatomic, strong) IFLiveMetricsMonitor *monitor;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation IFetchModuleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.monitor = [[IFLiveMetricsMonitor alloc] init];
    self.view.clipsToBounds = YES;
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"iFetch";
    self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = UIColor.labelColor;
    self.metricsLabel = [[UILabel alloc] init];
    self.metricsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metricsLabel.numberOfLines = 0;
    self.metricsLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    self.metricsLabel.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.metricsLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:9],
        [self.metricsLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metricsLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-6],
        [self.metricsLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3],
        [self.metricsLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:-7]
    ]];
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openIFetch)]];
    [self refresh:nil];
}

- (CGFloat)preferredExpandedContentHeight {
    return 160;
}

- (CGFloat)preferredExpandedContentWidth {
    return 300;
}

- (BOOL)providesOwnPlatter {
    return NO;
}

- (void)controlCenterWillPresent {
    [self refresh:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}

- (void)controlCenterDidDismiss {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)refresh:(__unused NSTimer *)timer {
    [self.monitor refresh];
    IFMetricSample *sample = self.monitor.history.lastObject;
    IFBatteryDetails *battery = [IFDiagnostics batteryDetails];
    self.metricsLabel.text = [NSString stringWithFormat:@"CPU %.0f%%  RAM %.0f%%\n↓%@ ↑%@\n%@",
        sample.cpuPercent, sample.memoryPercent,
        [IFetchCore formatRate:sample.downloadBytesPerSecond],
        [IFetchCore formatRate:sample.uploadBytesPerSecond],
        battery.temperatureCelsius ? [NSString stringWithFormat:@"%.1f°C", battery.temperatureCelsius.doubleValue] : @"—"];
}

- (void)openIFetch {
    @try {
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        id workspace = [workspaceClass valueForKey:@"defaultWorkspace"];
        SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if ([workspace respondsToSelector:selector]) {
            ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, selector, @"com.wee1ka.ifetch");
        }
    } @catch (__unused NSException *exception) {
    }
}

@end

@interface IFetchModule : NSObject <CCUIContentModule>
@property (nonatomic, strong) IFetchModuleViewController *controller;
@end

@implementation IFetchModule

- (instancetype)init {
    self = [super init];
    if (self) {
        _controller = [[IFetchModuleViewController alloc] init];
    }
    return self;
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController {
    return self.controller;
}

- (UIViewController *)backgroundViewController {
    return nil;
}

@end
