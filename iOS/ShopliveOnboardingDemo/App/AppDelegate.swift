//
//  AppDelegate.swift
//  ShopliveOnboardingDemo
//
//  App entry point. SDK initialization (Shoplive.initialize) is handled by
//  Integration/ShopliveBootstrap.swift.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // If credentials are already stored, initialize right at startup so relaunches can skip S1.
        // If not, initialization happens in S1 once the user enters their keys.
        DemoBootstrap.start()
        return true
    }

    // MARK: UISceneSession

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
