#import "AppDelegate.h"
#import "RootViewController.h"
#import <objc/message.h>

static void IFReloadWidgetTimelines(void) {
    Class bridge = NSClassFromString(@"IFWidgetRefreshBridge");
    SEL selector = NSSelectorFromString(@"reload");
    if (bridge != Nil && [bridge respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(bridge, selector);
    }
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    RootViewController *root = [[RootViewController alloc] init];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    [self.window makeKeyAndVisible];
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    if (url != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [root openDeepLink:url];
        });
    }
    IFReloadWidgetTimelines();
    return YES;
}

- (void)applicationWillEnterForeground:(__unused UIApplication *)application {
    IFReloadWidgetTimelines();
}

- (void)applicationDidEnterBackground:(__unused UIApplication *)application {
    IFReloadWidgetTimelines();
}

- (BOOL)application:(__unused UIApplication *)application openURL:(NSURL *)url
            options:(__unused NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    UINavigationController *navigation = (UINavigationController *)self.window.rootViewController;
    RootViewController *root = (RootViewController *)navigation.viewControllers.firstObject;
    [root openDeepLink:url];
    return YES;
}

- (void)userNotificationCenter:(__unused UNUserNotificationCenter *)center
       willPresentNotification:(__unused UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(__unused UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSString *destination = response.notification.request.content.userInfo[@"destination"] ?: @"diagnostics";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"ifetch://%@", destination]];
    UINavigationController *navigation = (UINavigationController *)self.window.rootViewController;
    RootViewController *root = (RootViewController *)navigation.viewControllers.firstObject;
    [root openDeepLink:url];
    completionHandler();
}

@end
