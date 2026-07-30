//
//  PlayerHostOverlay.swift  (S3 · what the demo app layers on top of the running screen)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  A host that **embeds the SDK player as a child VC**, with just two demo-only controls on top:
//    · ‹ List      — end the session and go back to the list
//    · ⌗ Developer — the developer sheet (logs / options)
//
//  ★ Why this is needed: if the overlay web view fails to load or there is no stream, the SDK's own
//    close button disappears along with it. With no way out the user is stuck on a black screen, so
//    these two controls must keep working regardless of the SDK's UI.
//
//  ★ Why a child VC: so the controls sit above the player **deterministically**.
//    With the host view's subviews ordered [player.view, controls], controls is the last sibling and
//    is therefore always hit-tested first. Whatever the SDK puts up internally (the overlay web view
//    and so on) lives **inside** player.view and cannot beat that ordering. Unlike a separate UIWindow
//    or an addSubview approach, there is no layer race.

import UIKit
import ShoplivePlayerSDK

/// A host that embeds the SDK player as a child and layers the demo controls on top.
final class PlayerHostViewController: UIViewController {

    let player: ShoplivePlayerViewController

    private let onClose: () -> Void
    private let onDevSheet: (PlayerHostViewController) -> Void

    init(player: ShoplivePlayerViewController,
         onClose: @escaping () -> Void,
         onDevSheet: @escaping (PlayerHostViewController) -> Void) {
        self.player = player
        self.onClose = onClose
        self.onDevSheet = onDevSheet
        super.init(nibName: nil, bundle: nil)
        // ★ .overFullScreen, not .fullScreen.
        //   When we move to in-App PIP this host has to hide itself (see setPipPresentation below),
        //   but .fullScreen detaches the presenter's view (the list) from the hierarchy once the
        //   presentation completes — so hiding the host would leave nothing behind it but black.
        modalPresentationStyle = .overFullScreen
    }

    /// Steps the host out of the way depending on whether in-App PIP is active.
    ///
    /// On promotion to PIP the render surface moves into a **floating container above the app
    /// window**, leaving nothing in this host's full-screen view. Left alone, the whole screen is
    /// covered in black with just the small PIP window on top (the symptom users reported). So we hide
    /// the host while PIP is active, letting the list screen behind it show through, and restore it on
    /// return.
    func setPipPresentation(_ pipActive: Bool) {
        guard viewIfLoaded != nil else { return }
        view.isHidden = pipActive
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 1) Embed the SDK player as a child — playback starts automatically in the player's
        //    viewDidAppear.
        addChild(player)
        player.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(player.view)
        NSLayoutConstraint.activate([
            player.view.topAnchor.constraint(equalTo: view.topAnchor),
            player.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            player.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            player.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        player.didMove(toParent: self)

        // 2) Demo controls — added after player.view, so they are always hit-tested above it.
        let back = DemoFab(L("player.overlay.back"))
        let dev = DemoFab(L("player.overlay.dev"))
        back.addAction(UIAction { [weak self] _ in self?.onClose() }, for: .touchUpInside)
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
    }

    /// Keeps the controls the top-most sibling even if the SDK adds its overlay web view later.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let controls = view.subviews.last, controls !== player.view { return }
        // If player.view ended up last (i.e. the SDK reordered), bring the controls forward again.
        view.subviews.forEach { if $0 !== player.view { view.bringSubviewToFront($0) } }
    }
}
