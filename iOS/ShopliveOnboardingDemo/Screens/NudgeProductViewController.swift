//
//  NudgeProductViewController.swift  (mission 2 · the screen a nudge floats over)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  A stand-in product page. When it appears, a nudge preview (ShopliveIntegration/NudgePreview.swift)
//  floats over it — small, muted, no overlay — and tapping the small window grows it to full screen.
//
//  Why not reuse ProductDetailViewController: that screen is mission 6's landing for navigation(url)
//  and a modal sheet — sharing it would make a product tap inside the nudge land on the nudge's own
//  host (SMV-1922 design ③).
//
//  What this screen decides (the guide's recommendations, "Tip" ①⑤):
//    · when it shows again — not after the viewer closed it here (closeReason .userAction); yes after
//      an app close, an accessKey change, or no reason; a new visit of this screen starts fresh (S04)
//    · leaving — a nudge still small is closed (.appRequest); one the viewer expanded keeps playing (S05)
//    · not live — optional close, behind a developer-sheet switch that is off by default (S38)
//

import UIKit
import ShoplivePlayerSDK

final class NudgeProductViewController: UIViewController {

    private let campaignKey: String

    /// This screen's nudge. Held strongly: the small window is not presented, so nothing else keeps it.
    /// The close reason and state are read from it directly (S04).
    private var nudge: ShoplivePlayerViewController?
    private var nudgeObserver: NSObjectProtocol?

    /// The nudge has been in the small window …
    private var sawSmallWindow = false
    /// … and later left it while still alive = the viewer expanded it.
    private var sawExpanded = false
    /// Latched by the first viewDidAppear: the first one follows the card tap, later ones are automatic.
    private var hasAppeared = false

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(campaignKey: String) {
        self.campaignKey = campaignKey
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let nudgeObserver { NotificationCenter.default.removeObserver(nudgeObserver) }
        EventLog.shared.log(.sdk, "demo: nudge product screen deinit")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        build()
    }

    /// The moment to decide (again) whether to show the nudge — the screen is visible (S04).
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let isFirstAppearance = !hasAppeared
        hasAppeared = true
        showNudgeIfAppropriate(isFirstAppearance: isFirstAppearance)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Leaving for good — not merely covered (an expanded nudge covering this screen is neither).
        if isMovingFromParent || isBeingDismissed { leave() }
    }

    // MARK: - Nudge

    private func showNudgeIfAppropriate(isFirstAppearance: Bool) {
        // This is an automatic request: never replace a switch already waiting (e.g. a deep link the
        // user tapped). The next viewDidAppear decides again.
        guard !DevSheetViewController.isSwitchingSession else {
            EventLog.shared.log(.sdk, "demo: a session switch is in progress — automatic nudge skipped")
            return
        }
        if let nudge {
            guard nudge.state == .closed else { return }      // still up — never a second one
            if nudge.closeReason == .userAction {
                // Guide "Tip" ⑤ (recommended): the viewer closed it on this screen — do not bring it back.
                EventLog.shared.log(.sdk, "demo: nudge was closed by the viewer on this screen — not shown again")
                return
            }
            // .appRequest / .accessKeyChanged / nil → show again.
        }

        // A later appearance is automatic: a session the viewer is still watching (another player
        // open or in PIP) is left alone. The first appearance follows the card tap and replaces it like
        // any card does (same rule as Android X2).
        let current = DevSheetViewController.activePlayer
        let otherSessionInProgress = current.map { $0 !== nudge && ($0.state != .closed || $0.isInPictureInPicture) } ?? false
        guard MissionID.nudgeMayStart(isFirstAppearance: isFirstAppearance,
                                      otherSessionInProgress: otherSessionInProgress) else {
            EventLog.shared.log(.sdk, "demo: another session is in progress — automatic nudge not started")
            return
        }

        DevSheetViewController.replaceCurrentSession { [weak self] in
            guard let self else {
                EventLog.shared.log(.sdk, "demo: nudge screen already gone — nudge not started")
                return
            }
            guard self.viewIfLoaded?.window != nil else {
                EventLog.shared.log(.sdk, "demo: nudge screen no longer visible — nudge not started")
                return
            }
            // The mission first, so a PIP signal that arrives inside play() — before the player is
            // known — is already the nudge's and cannot complete "keep watching in PIP" (S26).
            MissionProgress.shared.startMission(.nudge, owner: nil)
            // Owner and listener are registered before play() — no first signal goes unobserved (I3).
            NudgePreview.start(campaignKey: self.campaignKey,
                               over: self,
                               configuration: DemoConfigBuilder.makeNudgeConfiguration(),
                               delegate: DemoPlayerDelegate.shared,
                               beforePlay: { player in
                                   DemoPlayerDelegate.adopt(player)
                                   self.adopt(player)
                               })
        }
    }

    private func adopt(_ player: ShoplivePlayerViewController) {
        if let nudgeObserver { NotificationCenter.default.removeObserver(nudgeObserver) }
        nudge = player
        sawSmallWindow = player.isInPictureInPicture      // a starting value in case the SDK is already there
        sawExpanded = false
        DevSheetViewController.activePlayer = player
        MissionProgress.shared.attachOwner(player, to: .nudge)
        // Only this nudge's signals (`===`).
        nudgeObserver = DemoPlayerDelegate.observeMilestones(of: player) { [weak self] _, milestone in
            self?.handle(milestone)
        }
    }

    private func handle(_ milestone: PlayerMilestone) {
        guard let nudge else { return }
        switch milestone {
        case .pipStateChanged(let isActive):
            if isActive {
                sawSmallWindow = true
            } else if sawSmallWindow, !nudge.isInPictureInPicture, nudge.state != .closed, !sawExpanded {
                sawExpanded = true
                EventLog.shared.log(.sdk, "demo: nudge expanded to full screen — it keeps playing if you leave this screen")
            }

        case .campaignStatusChanged(let status):
            guard status != .live else { return }
            // TODO(SDP-VERIFY): 요확인 — 라이브가 아닌 캠페인(.ready/.ended)에서 넛지 작은 창이 무엇을 보여 주는지(대기 화면 / 즉시 닫힘·closeReason)는 SDK 동작, 실측 · 근거 SMV-1922 U06
            if DemoConfigStore.shared.closeNudgeWhenNotLive, !hasBeenExpanded {
                EventLog.shared.log(.sdk, "demo: campaign is .\(status.logLabel), not live — closing the nudge (option on)")
                nudge.close()
            } else {
                EventLog.shared.log(.sdk, "demo: campaign is .\(status.logLabel), not live — nudge kept (option off, or already expanded)")
            }

        case .closed:
            if DevSheetViewController.activePlayer === nudge { DevSheetViewController.activePlayer = nil }

        case .playbackReached, .requestReceived, .fatalError:
            break
        }
    }

    /// "The viewer expanded it": the expand signal, or — at decision time, as a fallback for a missed
    /// signal — it was small once and is now out of the small window but alive. No timer (CG-7.1).
    private var hasBeenExpanded: Bool {
        guard let nudge else { return false }
        return sawExpanded || (sawSmallWindow && !nudge.isInPictureInPicture && nudge.state != .closed)
    }

    private func leave() {
        guard let nudge, nudge.state != .closed else { return }
        if hasBeenExpanded {
            // TODO(SDP-VERIFY): 요확인 — 이 화면이 해제된 뒤 키운 넛지 VC 를 누가 보유하는지(SDK 가 키울 때 present 하는지). 보유자가 없으면 세션이 함께 끝난다 · 근거 SMV-1922 S52
            EventLog.shared.log(.sdk, "demo: leaving with the nudge expanded — the viewing session is kept")
            return
        }
        // A preview the viewer never opened should not follow them around the app (E2).
        EventLog.shared.log(.sdk, "demo: leaving while the nudge is still a preview — close() (closeReason .appRequest)")
        nudge.close()
    }

    // MARK: - Layout

    private func build() {
        let nav = DemoNavBar(title: L("nudge.title", MissionCatalog.number(of: .nudge)), onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })

        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        let hero = UIView()
        hero.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.886, alpha: 1)
        hero.layer.cornerRadius = DemoTheme.Radius.card
        hero.heightAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(hero)
        stack.addArrangedSubview(UILabel.demo(L("product.name"), size: 15, weight: .heavy))
        stack.addArrangedSubview(UILabel.demo(L("product.price"), size: 18, weight: .heavy, color: DemoTheme.brand))
        stack.addArrangedSubview(DemoTipView(.info, L("nudge.tip")))

        view.addSubview(nav)
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        [nav, scrollView, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            nav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: nav.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
}
