//
//  MissionListViewController.swift  (S2 · feature list)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Effectively the app's only menu. Tapping a card runs it immediately (zero intermediate screens).
//  Feature 2 shows a fake push banner and feature 3 an auth-mode action sheet over the list before
//  running.
//

import UIKit
import ShoplivePlayerSDK

final class MissionListViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private lazy var navBar = DemoNavBar(title: L("list.title", 0),
                                        actionSymbol: "⚙",
                                        onAction: { [weak self] in self?.openSettings() })
    private lazy var fab = DemoFab(L("player.overlay.dev"))
    private var modeBar = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        build()
        wireNotifications()
        reload()

        // Route product landings (navigation) to the V2 modal.
        DemoPlayerDelegate.shared.onNavigation = { [weak self] url in
            self?.presentProductDetail(url: url)
        }

        // Unrecoverable error handling — **we do not close the player.**
        //
        // This used to auto-close after a 6-second grace period, which presented as "the player
        // screen never appears": on a campaign with no stream, playback is never reached, so the SDK
        // screen vanished after 6 seconds. The whole point of the demo is to **show** the SDK screen,
        // so auto-closing worked against it.
        // Being stuck is prevented instead by `‹ List` in PlayerHostViewController — a sibling view
        // above the player that is always tappable.
        //
        // Errors repeat several times a second, so a toast per error would bury the screen — we
        // surface it once per session.
        DemoPlayerDelegate.shared.onFatalError = { [weak self] error in
            guard let self, !self.didNotifyPlaybackFailure else { return }
            self.didNotifyPlaybackFailure = true

            EventLog.shared.log(.sdk, "demo: showing the playback-failure notice (player kept alive) — use '‹ List' to leave")

            guard let host = DeepLinkRouter.topViewController()?.view else { return }
            DemoToast.show(L("player.failure.notice", error.code.logLabel), in: host)
        }
    }

    /// Notifies the user only on the first of the repeating errors (per session).
    private var didNotifyPlaybackFailure = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Running a mission

    private func run(_ mission: Mission) {
        // Credential gate — if anything is missing, send the user to S1 with the reason.
        if let reason = lockReason(for: mission) {
            DemoToast.show(L("list.locked.hint", reason), in: view)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.openSettings()
            }
            return
        }

        switch mission.run {
        case .player:
            startPlayer(mission)

        case .feed:
            openDevSheetIfNeeded(mission)
            navigationController?.pushViewController(
                FeedDemoViewController(campaignKey: DemoCredentials.shared.campaignKey),
                animated: true)

        case .deeplink:
            // ★ Do not open the developer sheet first here — the sheet covers the fake push banner,
            //   making it untappable and mission 2 impossible to complete (measured). Open the sheet
            //   after the banner is tapped.
            showFakePushBanner()

        case .auth:
            presentAuthActionSheet(mission)

        case .studio:
            startStudio(mission)
        }
    }

    private func startPlayer(_ mission: Mission) {
        didNotifyPlaybackFailure = false        // new playback session — allow the failure notice again
        // Automatic "verified" marking — the harness turns the playback-reached signal into progress.
        DemoPlayerDelegate.shared.onPlaybackReached = { MissionProgress.shared.markDone(mission.number) }
        openDevSheetIfNeeded(mission)

        // Rather than presenting the player, we embed it as a **child of the host VC** so the demo
        // controls are reliably on top.
        // The minimal code to copy is the present path in ShopliveIntegration/PlayerLauncher.swift,
        // exactly as written there.
        let player = ShoplivePlayerViewController(
            campaignKey: DemoCredentials.shared.campaignKey,
            options: DemoConfigBuilder.makePlayOptions(),
            configuration: DemoConfigBuilder.makeConfiguration(.fullScreenLive))
        player.delegate = DemoPlayerDelegate.shared
        DevSheetViewController.activePlayer = player

        EventLog.shared.log(.sdk, "ShoplivePlayerViewController(campaignKey: \"\(DemoCredentials.shared.campaignKey)\") → embedded into the host")

        let host = PlayerHostViewController(
            player: player,
            onClose: { [weak self] in
                player.stop()
                DevSheetViewController.activePlayer = nil
                self?.dismiss(animated: true) { self?.reload() }
            },
            onDevSheet: { hostVC in
                guard hostVC.presentedViewController == nil else { return }
                hostVC.present(DevSheetViewController(initialTab: .log), animated: true)
            })

        // On PIP promotion, step the host out of the way (prevents the black-screen cover) and restore
        // it on return.
        // As a safety net for a missed exit signal, we also poll isInPictureInPicture briefly.
        DemoPlayerDelegate.shared.onPipStateChanged = { [weak host, weak player] pipActive in
            host?.setPipPresentation(pipActive)
            guard pipActive else { return }
            Self.watchPipExit(host: host, player: player)
        }

        present(host, animated: true)

        // Mission 7: if .hidden was chosen, also apply it through the runtime property. On older SDK
        // builds the overlay.ui configuration path was not wired at all; on the current build it is,
        // so this is belt-and-braces.
        if DemoConfigStore.shared.overlayUI == .hidden {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                PlayerConfigurationFactory.applyRuntimeOverlay(.hidden, to: player)
            }
        }
    }

    /// Safety net for when PIP return does not arrive via stateChanged.
    /// Shows the host again once `isInPictureInPicture` goes back to false.
    private static func watchPipExit(host: PlayerHostViewController?,
                                     player: ShoplivePlayerViewController?) {
        guard let host, let player else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard host.viewIfLoaded?.window != nil || host.isViewLoaded else { return }
            if player.isInPictureInPicture {
                watchPipExit(host: host, player: player)      // still in PIP — keep watching
            } else {
                host.setPipPresentation(false)                // returned — restore the host
            }
        }
    }

    private func startStudio(_ mission: Mission) {
        StudioLauncher.present(
            campaignKey: DemoCredentials.shared.campaignKey,
            streamToken: DemoCredentials.shared.streamToken,
            from: self,
            delegate: DemoStreamerDelegate.shared)
    }

    private func lockReason(for mission: Mission) -> String? {
        let credentials = DemoCredentials.shared
        if !credentials.isReadyForPlayback { return L("list.locked.credentials") }
        if mission.needsStreamToken && credentials.streamToken.isEmpty { return L("list.locked.streamToken") }
        return nil
    }

    private func openDevSheetIfNeeded(_ mission: Mission) {
        guard let sheet = mission.autoSheet else { return }
        // Surface the verification point right after launching — the log for mission 6, options for
        // mission 7.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.presentDevSheet(tab: sheet == .log ? .log : .options)
        }
    }

    // MARK: - Mission 2 · fake push banner

    private func showFakePushBanner() {
        let campaignKey = DemoCredentials.shared.campaignKey
        let urlString = "shopliveDemo://live?campaign=\(campaignKey)&ref=push_demo"

        let banner = UIView()
        banner.backgroundColor = UIColor.white.withAlphaComponent(0.98)
        banner.layer.cornerRadius = 16
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = 0.22
        banner.layer.shadowRadius = 15
        banner.layer.shadowOffset = CGSize(width: 0, height: 10)

        let text = UIStackView.demo(.vertical, spacing: 3, [
            UILabel.demo(L("banner.app"), size: 11, weight: .bold, color: DemoTheme.textSecondary),
            UILabel.demo(L("banner.title"), size: 12.5, weight: .bold),
            UILabel.demo(urlString, size: 10, color: DemoTheme.textTertiary),
        ])
        text.isLayoutMarginsRelativeArrangement = true
        text.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        banner.addSubview(text)

        view.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        text.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            text.topAnchor.constraint(equalTo: banner.topAnchor),
            text.leadingAnchor.constraint(equalTo: banner.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: banner.trailingAnchor),
            text.bottomAnchor.constraint(equalTo: banner.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(bannerTapped(_:)))
        banner.addGestureRecognizer(tap)
        banner.accessibilityHint = urlString
        bannerURLString = urlString

        EventLog.shared.log(.sdk, "demo: showing the fake push banner — \(urlString)")
        // 8 seconds is easy to miss (it disappeared mid-explanation during a walkthrough). Use 20.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { banner.removeFromSuperview() }
    }

    private var bannerURLString: String?

    @objc private func bannerTapped(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
        guard let urlString = bannerURLString, let url = URL(string: urlString) else { return }
        // Take exactly the same path as a real OS deep link — this is the function SceneDelegate calls.
        DeepLinkRouter.shared.handle(url)
        // Open the log sheet after the banner is tapped (mission 2's verification point =
        // ref → referrer being passed through).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.presentDevSheet(tab: .log)
        }
    }

    // MARK: - Mission 3 · choosing an auth mode

    private func presentAuthActionSheet(_ mission: Mission) {
        let sheet = UIAlertController(
            title: L("auth.sheet.title"),
            message: L("auth.sheet.message"),
            preferredStyle: .actionSheet)

        for mode in DemoConfigStore.AuthMode.allCases {
            sheet.addAction(UIAlertAction(title: mode.label, style: .default) { [weak self] _ in
                DemoConfigStore.shared.authMode = mode
                DemoAuthApplier.applyCurrentSelection()
                self?.startPlayer(mission)
            })
        }
        sheet.addAction(UIAlertAction(title: L("auth.logout"), style: .destructive) { _ in
            UserSetup.logout()
        })
        sheet.addAction(UIAlertAction(title: L("auth.cancel"), style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Overlays

    @objc private func openDevSheet() { presentDevSheet(tab: .log) }

    private func presentDevSheet(tab: DevSheetViewController.Tab) {
        if let presented = presentedViewController as? DevSheetViewController {
            presented.select(tab)
            return
        }
        guard presentedViewController == nil else { return }
        let sheet = DevSheetViewController(initialTab: tab)
        present(sheet, animated: true)
    }

    private func presentProductDetail(url: URL) {
        let detail = ProductDetailViewController(receivedURL: url)
        // If a player is on screen, put this above it.
        let presenter = DeepLinkRouter.topViewController() ?? self
        presenter.present(detail, animated: true)
    }

    private func openSettings() {
        navigationController?.setViewControllers(
            [StartViewController(expandForm: DemoCredentials.shared.mode == .own)], animated: true)
    }

    // MARK: - List construction

    private func wireNotifications() {
        NotificationCenter.default.addObserver(
            forName: MissionProgress.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.reload()
            }
    }

    private func reload() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        stack.addArrangedSubview(DemoTipView(.info, L("list.tip.tapToRun")))

        for mission in MissionCatalog.all {
            stack.addArrangedSubview(card(for: mission))
        }

        stack.addArrangedSubview(DemoTipView(.ok, L("list.tip.openFiles")))

        navBar.subviews.compactMap { $0 as? UIStackView }.first?
            .arrangedSubviews.compactMap { $0 as? UILabel }.first?
            .text = L("list.title", MissionProgress.shared.doneCount)

        buildModeBar()
    }

    private func card(for mission: Mission) -> UIView {
        let isDone = MissionProgress.shared.isDone(mission.number)
        let lockReason = self.lockReason(for: mission)

        let card = UIControl()
        card.backgroundColor = .white
        card.layer.cornerRadius = DemoTheme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = DemoTheme.hairline.cgColor
        card.tag = mission.number
        card.addTarget(self, action: #selector(cardTapped(_:)), for: .touchUpInside)

        // Number badge
        let badge = UIView()
        badge.backgroundColor = isDone ? DemoTheme.ok : (lockReason != nil ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.07, alpha: 1))
        badge.layer.cornerRadius = 8
        let badgeLabel = UILabel.demo(isDone ? "✓" : "\(mission.number)", size: 12.5, weight: .heavy, color: .white)
        badgeLabel.textAlignment = .center
        badge.addSubview(badgeLabel)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),
            badgeLabel.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])

        let texts = UIStackView.demo(.vertical, spacing: 2, [
            UILabel.demo(mission.title, size: 14, weight: .bold),
            UILabel.demo(mission.summary, size: 11.5, color: DemoTheme.textSecondary),
            UILabel.demo("📄 \(mission.sourceFile)", size: 10, color: DemoTheme.textTertiary),
        ])

        let trailing: UIView = isDone
            ? pill(L("list.badge.done"), background: UIColor(red: 0.90, green: 0.965, blue: 0.918, alpha: 1), foreground: DemoTheme.ok)
            : UILabel.demo("›", size: 17, color: UIColor(white: 0.78, alpha: 1))

        let row = UIStackView.demo(.horizontal, spacing: 11, alignment: .center, [badge, texts, trailing])
        let content = UIStackView.demo(.vertical, spacing: 9, [row])

        if let reason = lockReason {
            content.addArrangedSubview(DemoTipView(.warn, L("list.locked.hint", reason)))
        }

        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        content.isUserInteractionEnabled = false

        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    @objc private func cardTapped(_ sender: UIControl) {
        guard let mission = MissionCatalog.mission(sender.tag) else { return }
        run(mission)
    }

    private func pill(_ text: String, background: UIColor, foreground: UIColor) -> UIView {
        let label = UILabel.demo(text, size: 10.5, weight: .bold, color: foreground)
        let box = UIView()
        box.backgroundColor = background
        box.layer.cornerRadius = DemoTheme.Radius.pill
        box.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -7),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -3),
        ])
        return box
    }

    private func buildModeBar() {
        modeBar.subviews.forEach { $0.removeFromSuperview() }
        let credentials = DemoCredentials.shared
        let isOwn = credentials.mode == .own
        modeBar.backgroundColor = isOwn
            ? UIColor(red: 0.90, green: 0.965, blue: 0.918, alpha: 1)
            : UIColor(red: 0.91, green: 0.945, blue: 1.0, alpha: 1)

        let text = isOwn
            ? L("list.mode.own", DemoCredentials.masked(credentials.accessKey))
            : L("list.mode.tour")
        let label = UILabel.demo(text, size: 10, weight: .bold,
                                 color: isOwn ? DemoTheme.ok : DemoTheme.info)
        label.textAlignment = .center
        modeBar.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: modeBar.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: modeBar.trailingAnchor),
            label.topAnchor.constraint(equalTo: modeBar.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: modeBar.bottomAnchor, constant: -3),
        ])
    }

    private func build() {
        stack.axis = .vertical
        stack.spacing = 9
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 80, right: 16)

        fab.addTarget(self, action: #selector(openDevSheet), for: .touchUpInside)

        view.addSubview(modeBar)
        view.addSubview(navBar)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        view.addSubview(fab)

        [modeBar, navBar, scrollView, stack, fab].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            modeBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            modeBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modeBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            navBar.topAnchor.constraint(equalTo: modeBar.bottomAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            fab.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
        ])
    }
}
