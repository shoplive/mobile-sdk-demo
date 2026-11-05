//
//  PlayerHostOverlay.swift  (S3 · what the demo app layers on top of the running screen)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The SDK player, subclassed, with just two demo-only controls on top:
//    · ‹ List      — end the session and go back to the list
//    · ⌗ Developer — the developer sheet (logs / options)
//
//  ★ Why this is needed: if the overlay web view fails to load or there is no stream, the SDK's own
//    close button disappears along with it. With no way out the user is stuck on a black screen, so
//    these two controls must keep working regardless of the SDK's UI.
//
//  ★ Why a subclass and not a child VC: the SDK takes its modal down on in-App PIP only when the player
//    is **presented as itself**. Embedded as a child it just floats the video and leaves the full-screen
//    modal in place — black, and swallowing every touch, so the app behind the small window is unusable.
//    Presented directly, the modal goes away on PIP and comes back on return, and these controls go and
//    come back with it — nothing here has to step aside.
//
//  ★ Why the controls stay on top: the view's subviews are [SDK player view, controls]. Whatever the SDK
//    puts up internally (the overlay web view and so on) lives **inside** the SDK player view and cannot
//    beat that ordering.

import UIKit
import ShoplivePlayerSDK

/// The SDK player with the demo controls layered on top. Present it directly — never embed it.
final class DemoPlayerViewController: ShoplivePlayerViewController {

    /// A player that starts in the small window is never presented, and nothing else owns it until it
    /// is floating — the SDK only takes hold after entering PIP succeeds — so without this it is released
    /// before it plays. One slot: there is one session at a time, and the next start replaces it.
    private static var startedInSmallWindow: DemoPlayerViewController?

    func keepAliveUntilClosed() { Self.startedInSmallWindow = self }

    private let onClose: (DemoPlayerViewController) -> Void
    private let onDevSheet: (DemoPlayerViewController) -> Void
    private var controls: UIView?
    private var milestoneObserver: NSObjectProtocol?

    init(campaignKey: String,
         options: ShoplivePlayOptions,
         configuration: ShoplivePlayerConfiguration,
         onClose: @escaping (DemoPlayerViewController) -> Void,
         onDevSheet: @escaping (DemoPlayerViewController) -> Void) {
        self.onClose = onClose
        self.onDevSheet = onDevSheet
        super.init(campaignKey: campaignKey, options: options, configuration: configuration)

        // Only this player (`===`) — a late `.closed` from a previous session must not touch a newer
        // session's record (SMV-1922 S39).
        milestoneObserver = DemoPlayerDelegate.observeMilestones(of: self) { [weak self] _, milestone in
            guard let self, case .closed = milestone else { return }
            if DevSheetViewController.activePlayer === self { DevSheetViewController.activePlayer = nil }
            if Self.startedInSmallWindow === self { Self.startedInSmallWindow = nil }
        }
    }

    deinit {
        if let milestoneObserver { NotificationCenter.default.removeObserver(milestoneObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Added after the SDK's player view, so they are hit-tested above it.
        let back = DemoFab(L("player.overlay.back"))
        let dev = DemoFab(L("player.overlay.dev"))
        back.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onClose(self)
        }, for: .touchUpInside)
        dev.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onDevSheet(self)
        }, for: .touchUpInside)

        let badge = UILabel.demo(L("player.overlay.badge"), size: 9, weight: .bold, color: .white)
        badge.backgroundColor = UIColor(white: 0, alpha: 0.45)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true

        let controls = UIStackView.demo(.horizontal, spacing: 6, alignment: .center, [back, dev, badge])
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            badge.heightAnchor.constraint(equalToConstant: 18),
        ])
        self.controls = controls
    }

    /// Keeps the controls the top-most sibling even if the SDK re-adds its player view later.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let controls { view.bringSubviewToFront(controls) }
    }
}
