import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var brandObserver: NSObjectProtocol?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let navigation = AppNavigationController(rootViewController: HomeViewController())
        window.rootViewController = navigation
        window.tintColor = AppEnvironment.shared.brandColor
        window.makeKeyAndVisible()
        self.window = window
        ShortformBridge.shared.navigationController = navigation

        brandObserver = NotificationCenter.default.addObserver(forName: AppEnvironment.brandDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.window?.tintColor = AppEnvironment.shared.brandColor
        }

        Task { @MainActor in
            await AppEnvironment.shared.reloadCatalog()
        }
    }
}

/// Navigation with a standard, always-visible bar.
final class AppNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.prefersLargeTitles = false
    }
}
