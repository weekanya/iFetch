#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>
#import <objc/message.h>

#import "../core/IFDiagnostics.h"
#import "../core/IFetchCore.h"

static NSString *IFCCText(NSString *english, NSString *russian) {
    return [IFLanguageManager english:english russian:russian];
}

@interface IFCCMetricView : UIView
@property (nonatomic, strong) UIImageView *metricIconView;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIProgressView *progressView;
- (instancetype)initWithSymbol:(NSString *)symbol color:(UIColor *)color;
- (void)setValue:(double)value;
@end

@implementation IFCCMetricView

- (instancetype)initWithSymbol:(NSString *)symbol color:(UIColor *)color {
    self = [super init];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.96];
        self.layer.cornerRadius = 11;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:symbol withConfiguration:configuration];
        self.metricIconView = [[UIImageView alloc] initWithImage:image];
        self.metricIconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.metricIconView.tintColor = color;
        self.metricIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.valueLabel = [[UILabel alloc] init];
        self.valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBold];
        self.valueLabel.textColor = UIColor.whiteColor;
        self.valueLabel.textAlignment = NSTextAlignmentRight;
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
        self.progressView.progressTintColor = color;
        self.progressView.trackTintColor = [UIColor colorWithWhite:1 alpha:0.14];
        [self addSubview:self.metricIconView];
        [self addSubview:self.valueLabel];
        [self addSubview:self.progressView];
        [NSLayoutConstraint activateConstraints:@[
            [self.metricIconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:9],
            [self.metricIconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [self.metricIconView.widthAnchor constraintEqualToConstant:14],
            [self.metricIconView.heightAnchor constraintEqualToConstant:14],
            [self.valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-9],
            [self.valueLabel.centerYAnchor constraintEqualToAnchor:self.metricIconView.centerYAnchor],
            [self.valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.metricIconView.trailingAnchor constant:4],
            [self.progressView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:9],
            [self.progressView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-9],
            [self.progressView.topAnchor constraintEqualToAnchor:self.metricIconView.bottomAnchor constant:5],
            [self.progressView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-7]
        ]];
    }
    return self;
}

- (void)setValue:(double)value {
    double normalized = MIN(100.0, MAX(0.0, value));
    self.valueLabel.text = [NSString stringWithFormat:@"%.0f%%", normalized];
    [self.progressView setProgress:(float)(normalized / 100.0) animated:YES];
}

@end

@interface IFetchModuleViewController : UIViewController <CCUIContentModuleContentViewController>
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *temperatureLabel;
@property (nonatomic, strong) UILabel *networkLabel;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) IFCCMetricView *cpuView;
@property (nonatomic, strong) IFCCMetricView *memoryView;
@property (nonatomic, strong) IFLiveMetricsMonitor *monitor;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation IFetchModuleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.monitor = [[IFLiveMetricsMonitor alloc] init];
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 20;
    self.gradient = [CAGradientLayer layer];
    self.gradient.colors = @[
        (id)[UIColor colorWithRed:0.025 green:0.03 blue:0.045 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.065 green:0.085 blue:0.13 alpha:1].CGColor
    ];
    self.gradient.startPoint = CGPointMake(0, 0);
    self.gradient.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradient atIndex:0];

    UIView *iconBackground = [[UIView alloc] init];
    iconBackground.translatesAutoresizingMaskIntoConstraints = NO;
    iconBackground.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.17 alpha:1];
    iconBackground.layer.cornerRadius = 12;
    self.iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.path.ecg.rectangle.fill"]];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.tintColor = [UIColor colorWithRed:0.28 green:0.62 blue:1 alpha:1];
    [iconBackground addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"iFetch";
    self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.titleLabel.textColor = UIColor.whiteColor;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightMedium];
    self.subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.64];

    self.temperatureLabel = [[UILabel alloc] init];
    self.temperatureLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.temperatureLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    self.temperatureLabel.textColor = UIColor.whiteColor;
    self.temperatureLabel.textAlignment = NSTextAlignmentRight;

    self.cpuView = [[IFCCMetricView alloc] initWithSymbol:@"cpu" color:UIColor.systemOrangeColor];
    self.memoryView = [[IFCCMetricView alloc] initWithSymbol:@"memorychip"
                                                       color:[UIColor colorWithRed:0.70 green:0.48 blue:1 alpha:1]];

    UIView *networkBackground = [[UIView alloc] init];
    networkBackground.translatesAutoresizingMaskIntoConstraints = NO;
    networkBackground.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.96];
    networkBackground.layer.cornerRadius = 10;
    networkBackground.layer.borderWidth = 0.5;
    networkBackground.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    UIImageView *networkIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"]];
    networkIcon.translatesAutoresizingMaskIntoConstraints = NO;
    networkIcon.tintColor = [UIColor colorWithRed:0.28 green:0.62 blue:1 alpha:1];
    self.networkLabel = [[UILabel alloc] init];
    self.networkLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.networkLabel.font = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightSemibold];
    self.networkLabel.textColor = UIColor.whiteColor;
    self.networkLabel.adjustsFontSizeToFitWidth = YES;
    self.networkLabel.minimumScaleFactor = 0.7;
    [networkBackground addSubview:networkIcon];
    [networkBackground addSubview:self.networkLabel];

    [self.view addSubview:iconBackground];
    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.subtitleLabel];
    [self.view addSubview:self.temperatureLabel];
    [self.view addSubview:self.cpuView];
    [self.view addSubview:self.memoryView];
    [self.view addSubview:networkBackground];

    [NSLayoutConstraint activateConstraints:@[
        [iconBackground.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [iconBackground.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:9],
        [iconBackground.widthAnchor constraintEqualToConstant:24],
        [iconBackground.heightAnchor constraintEqualToConstant:24],
        [self.iconView.centerXAnchor constraintEqualToAnchor:iconBackground.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:iconBackground.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:15],
        [self.iconView.heightAnchor constraintEqualToConstant:15],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconBackground.trailingAnchor constant:7],
        [self.titleLabel.topAnchor constraintEqualToAnchor:iconBackground.topAnchor constant:-1],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:-1],
        [self.temperatureLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.temperatureLabel.centerYAnchor constraintEqualToAnchor:iconBackground.centerYAnchor],
        [self.temperatureLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.trailingAnchor constant:5],
        [self.cpuView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:9],
        [self.cpuView.topAnchor constraintEqualToAnchor:iconBackground.bottomAnchor constant:7],
        [self.cpuView.heightAnchor constraintEqualToConstant:39],
        [self.memoryView.leadingAnchor constraintEqualToAnchor:self.cpuView.trailingAnchor constant:6],
        [self.memoryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-9],
        [self.memoryView.topAnchor constraintEqualToAnchor:self.cpuView.topAnchor],
        [self.memoryView.widthAnchor constraintEqualToAnchor:self.cpuView.widthAnchor],
        [self.memoryView.heightAnchor constraintEqualToAnchor:self.cpuView.heightAnchor],
        [networkBackground.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:9],
        [networkBackground.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-9],
        [networkBackground.topAnchor constraintEqualToAnchor:self.cpuView.bottomAnchor constant:6],
        [networkBackground.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-9],
        [networkIcon.leadingAnchor constraintEqualToAnchor:networkBackground.leadingAnchor constant:8],
        [networkIcon.centerYAnchor constraintEqualToAnchor:networkBackground.centerYAnchor],
        [networkIcon.widthAnchor constraintEqualToConstant:13],
        [networkIcon.heightAnchor constraintEqualToConstant:13],
        [self.networkLabel.leadingAnchor constraintEqualToAnchor:networkIcon.trailingAnchor constant:6],
        [self.networkLabel.trailingAnchor constraintEqualToAnchor:networkBackground.trailingAnchor constant:-7],
        [self.networkLabel.centerYAnchor constraintEqualToAnchor:networkBackground.centerYAnchor]
    ]];
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openIFetch)]];
    [self refresh:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradient.frame = self.view.bounds;
}

- (CGFloat)preferredExpandedContentHeight {
    return 190;
}

- (CGFloat)preferredExpandedContentWidth {
    return 320;
}

- (BOOL)providesOwnPlatter {
    return YES;
}

- (void)controlCenterWillPresent {
    [self refresh:nil];
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
}

- (void)controlCenterDidDismiss {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)refresh:(__unused NSTimer *)timer {
    [self.monitor refresh];
    IFMetricSample *sample = self.monitor.history.lastObject;
    if (sample == nil) {
        return;
    }
    IFBatteryDetails *battery = [IFDiagnostics batteryDetails];
    [self.cpuView setValue:sample.cpuPercent];
    [self.memoryView setValue:sample.memoryPercent];
    self.subtitleLabel.text = IFCCText(@"LIVE SYSTEM", @"СИСТЕМА");
    self.temperatureLabel.text = battery.temperatureCelsius
        ? [NSString stringWithFormat:@"%.1f°C", battery.temperatureCelsius.doubleValue] : @"—";
    self.networkLabel.text = [NSString stringWithFormat:@"↓ %@   ↑ %@",
        [IFetchCore formatRate:sample.downloadBytesPerSecond],
        [IFetchCore formatRate:sample.uploadBytesPerSecond]];
}

- (void)openIFetch {
    @try {
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        id workspace = workspaceClass ? [workspaceClass valueForKey:@"defaultWorkspace"] : nil;
        SEL selector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if (workspace != nil && [workspace respondsToSelector:selector]) {
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
