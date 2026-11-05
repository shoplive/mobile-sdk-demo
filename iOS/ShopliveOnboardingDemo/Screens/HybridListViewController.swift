//
//  HybridListViewController.swift  (mission 7 · hybrid — a web list that hands a key to the app)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Loads Resources/hybrid/index.html (bundled, no network) into a WKWebView. The page draws a few
//  cards; tapping one posts the campaignKey through ShopLiveAppInterface, and this screen opens the
//  native full-screen player. The SDK-facing part — the bridge and its input rules — is
//  ShopliveIntegration/WebBridge.swift.
//
//  Ownership (S13): screen → web view → content controller → bridge → (weak) screen. The screen removes
//  the handler in deinit.
//

import UIKit
import WebKit
import ShoplivePlayerSDK

final class HybridListViewController: UIViewController {

    private let campaignKey: String
    private let contentController = WKUserContentController()
    private var bridge: WebBridge?
    private var webView: WKWebView?

    /// The player this screen opened. Repeated taps are judged by this player itself, not a flag — a
    /// late `.closed` from an older session cannot unblock a newer one (S11 · L9).
    private weak var openedPlayer: ShoplivePlayerViewController?

    init(campaignKey: String) {
        self.campaignKey = campaignKey
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        WebBridge.uninstall(from: contentController)
        EventLog.shared.log(.sdk, "demo: hybrid list screen deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        build()
    }

    // MARK: - Bridge → player

    private func open(campaignKey: String) {
        if let openedPlayer, openedPlayer.state != .closed {
            EventLog.shared.log(.sdk, "demo: bridge message ignored — the player this screen opened is still open")
            return
        }
        DevSheetViewController.replaceCurrentSession { [weak self] in
            guard let self else {
                EventLog.shared.log(.sdk, "demo: hybrid list already gone — campaignKey ignored")
                return
            }
            guard let presenter = DeepLinkRouter.topViewController() else {
                EventLog.shared.log(.error, "demo: no view controller to present the player from")
                return
            }
            let player = PlayerLauncher.present(campaignKey: campaignKey,
                                                from: presenter,
                                                options: DemoConfigBuilder.makePlayOptions(),
                                                configuration: DemoConfigBuilder.makeConfiguration(.fullScreenLive),
                                                delegate: DemoPlayerDelegate.shared)
            DemoPlayerDelegate.adopt(player)
            self.openedPlayer = player        // at once — repeated taps are judged by this player
            DevSheetViewController.recordSession(player, presentedAs: player, for: .inline)
        }
    }

    // MARK: - Layout

    private func build() {
        let nav = DemoNavBar(title: L("hybrid.title", MissionCatalog.number(of: .inline)), onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        let tip = DemoTipView(.info, L("hybrid.tip"))

        view.addSubview(nav)
        view.addSubview(tip)
        [nav, tip].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            nav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nav.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tip.topAnchor.constraint(equalTo: nav.bottomAnchor, constant: 10),
            tip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        guard let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "hybrid") else {
            // The folder reference was not copied into the bundle (pbxproj Resources) — say so on screen.
            EventLog.shared.log(.error, "demo: hybrid/index.html is missing from the app bundle")
            let missing = DemoTipView(.warn, L("hybrid.missingPage"))
            view.addSubview(missing)
            missing.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                missing.topAnchor.constraint(equalTo: tip.bottomAnchor, constant: 10),
                missing.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                missing.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ])
            return
        }
        let pageFolder = page.deletingLastPathComponent()

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController = contentController
        injectCampaignKey()

        let bridge = WebBridge(
            isOwnPage: { url in url.isFileURL && url.standardizedFileURL.path.hasPrefix(pageFolder.standardizedFileURL.path) },
            onCampaignKey: { [weak self] key in self?.open(campaignKey: key) })
        bridge.install(on: configuration)               // before the web view is created
        self.bridge = bridge

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = bridge
        webView.uiDelegate = bridge
        self.webView = webView

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: tip.bottomAnchor, constant: 10),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webView.loadFileURL(page, allowingReadAccessTo: pageFolder)
        EventLog.shared.log(.sdk, "demo: hybrid list — loaded bundled \(page.lastPathComponent)")
    }

    /// Hands the demo's campaignKey to the page before its scripts run. The key is embedded as a JSON
    /// string literal, never pasted raw — quotes, backslashes or `</script>` in a key cannot break out (L7).
    private func injectCampaignKey() {
        guard let literal = WebBridgeInput.javaScriptStringLiteral(campaignKey) else {
            EventLog.shared.log(.error, "demo: could not encode the campaignKey for the page — cards will send an empty key")
            return
        }
        contentController.addUserScript(WKUserScript(source: "window.demoCampaignKey = \(literal);",
                                                     injectionTime: .atDocumentStart,
                                                     forMainFrameOnly: true))
    }
}
