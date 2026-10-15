import UIKit

/// UIScene lifecycle is required by recent SDKs. The app still keeps all of its state on AppDelegate;
/// this class creates the window and forwards the lifecycle callbacks that UIKit no longer sends to
/// the AppDelegate once scenes are adopted.
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate { AppDelegate.sharedInstance() }

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        self.appDelegate.window = window
        self.appDelegate.sceneDidCreateWindow(window)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if self.appDelegate.window === self.window {
            self.appDelegate.window = nil
        }
        self.window = nil
    }

    // UIApplicationDelegate's lifecycle callbacks are not called under the scene lifecycle.
    func sceneWillEnterForeground(_ scene: UIScene) {
        self.appDelegate.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        self.appDelegate.applicationDidBecomeActive(UIApplication.shared)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        self.appDelegate.applicationWillResignActive(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        self.appDelegate.applicationDidEnterBackground(UIApplication.shared)
    }
}
