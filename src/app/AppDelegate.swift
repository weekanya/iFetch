import UIKit
import UserNotifications

@main
@objc(AppDelegate)
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    private var rootViewController: RootViewController? {
        guard let navigationController = window?.rootViewController as? UINavigationController else {
            return nil
        }
        return navigationController.viewControllers.first as? RootViewController
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        IFAppStyle.configureGlobalAppearance()
        let rootViewController = RootViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController
        self.window = window

        UNUserNotificationCenter.current().delegate = self
        window.makeKeyAndVisible()

        if let url = launchOptions?[.url] as? URL {
            DispatchQueue.main.async {
                rootViewController.openDeepLink(url)
            }
        }

        IFWidgetRefreshBridge.reload()
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        IFWidgetRefreshBridge.reload()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        IFWidgetRefreshBridge.reload()
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard let rootViewController else {
            return false
        }
        rootViewController.openDeepLink(url)
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let route = IFAppRoute(destination: response.notification.request.content.userInfo["destination"])
        if let url = route.url {
            rootViewController?.openDeepLink(url)
        }
        completionHandler()
    }
}
