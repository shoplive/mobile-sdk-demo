//
//  SceneDelegate.swift
//  ShopliveOnboardingDemo
//
//  ★ The actual entry point for mission 2 (deep links). Parsing and playback logic live in
//    Integration/DeepLinkRouter.swift.
//    From this file you only need the two methods: openURLContexts, and the urlContexts handling in
//    willConnectTo.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootNavigationController()
        window.makeKeyAndVisible()
        self.window = window

        // Launched by a deep link from a fully terminated state — it arrives via willConnectTo.
        if let url = connectionOptions.urlContexts.first?.url {
            DeepLinkRouter.shared.handle(url)
        }
    }

    // A deep link received while the app is already running.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        DeepLinkRouter.shared.handle(url)
    }
}

/// The demo app's root navigation. Runs S1 (start) → S2 (feature list).
final class RootNavigationController: UINavigationController {

    init() {
        // If credentials already exist, skip S1 and go straight to S2
        // (prototype S1 rule: "on relaunch, enter the last mode used").
        let root: UIViewController = DemoCredentials.shared.isReadyForPlayback
            ? MissionListViewController()
            : StartViewController()
        super.init(rootViewController: root)
        navigationBar.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
