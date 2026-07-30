//
//  FeedDemoViewController.swift  (S3 · home feed variant)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The demo shell for mission 4. It only owns the feed cards, callouts, and control buttons — the SDK
//  embedding is handled entirely by ShopliveIntegration/EmbeddedPlayerView.swift.
//

import UIKit
import ShoplivePlayerSDK

final class FeedDemoViewController: UIViewController {

    private let campaignKey: String
    /// ★ The embed uses the **preview preset** (the SDK's `.preview`).
    ///   PIP off, overlay hidden, muteOnStart, and resizeMode .fill are all applied at once.
    private lazy var embedded = EmbeddedPlayerView(
        configuration: DemoConfigBuilder.makeConfiguration(.embeddedPreview)
    )

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private lazy var muteButton = makePill("🔊")
    private lazy var expandButton = makePill(L("feed.expand"), background: .white, foreground: DemoTheme.text)

    init(campaignKey: String) {
        self.campaignKey = campaignKey
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildFeed()

        embedded.delegate = DemoPlayerDelegate.shared
        DemoPlayerDelegate.shared.onPlaybackReached = { MissionProgress.shared.markDone(4) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if embedded.state == .idle || embedded.state == .closed {
            embedded.play(campaignKey: campaignKey,
                          options: DemoConfigBuilder.makePlayOptions())
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            embedded.stop()
            DemoPlayerDelegate.shared.onPlaybackReached = nil
        }
    }

    // MARK: - Controls

    @objc private func toggleMute() {
        embedded.isMuted.toggle()
        DemoConfigStore.shared.isMuted = embedded.isMuted
        muteButton.configuration?.attributedTitle = AttributedString(
            embedded.isMuted ? "🔇" : "🔊",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 10.5, weight: .bold),
                                            .foregroundColor: UIColor.white]))
    }

    @objc private func expandToFullScreen() {
        // After promotion we are full screen, so switch to the **live preset**.
        embedded.expandToFullScreen(from: self,
                                    options: DemoConfigBuilder.makePlayOptions(),
                                    configuration: DemoConfigBuilder.makeConfiguration(.fullScreenLive),
                                    delegate: DemoPlayerDelegate.shared)
    }

    // MARK: - Feed construction

    private func buildFeed() {
        let nav = DemoNavBar(title: L("feed.title"), onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })

        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        contentStack.addArrangedSubview(feedCard(L("feed.card1.title"), L("feed.card1.detail")))
        contentStack.addArrangedSubview(DemoTipView(.ok, L("feed.tip.embed")))
        contentStack.addArrangedSubview(playerContainer())
        contentStack.addArrangedSubview(feedCard(L("feed.card2.title"), L("feed.card2.detail")))
        contentStack.addArrangedSubview(feedCard(L("feed.card3.title"), L("feed.card3.detail")))
        contentStack.addArrangedSubview(DemoTipView(.warn, L("feed.warn.autoPip")))

        view.addSubview(nav)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        [nav, scrollView, contentStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            nav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: nav.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func playerContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.layer.cornerRadius = DemoTheme.Radius.card
        container.clipsToBounds = true

        container.addSubview(embedded)
        let controls = UIStackView.demo(.horizontal, spacing: 6, [muteButton, expandButton])
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        expandButton.addTarget(self, action: #selector(expandToFullScreen), for: .touchUpInside)
        container.addSubview(controls)

        embedded.translatesAutoresizingMaskIntoConstraints = false
        controls.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 210),
            embedded.topAnchor.constraint(equalTo: container.topAnchor),
            embedded.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            embedded.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            embedded.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            controls.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            controls.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
        ])
        return container
    }

    private func feedCard(_ title: String, _ detail: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = DemoTheme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = DemoTheme.hairline.cgColor

        let thumb = UIView()
        thumb.backgroundColor = DemoTheme.fill
        thumb.layer.cornerRadius = 10

        let text = UIStackView.demo(.vertical, spacing: 2, [
            UILabel.demo(title, size: 13, weight: .bold),
            UILabel.demo(detail, size: 11.5, color: DemoTheme.textSecondary),
        ])

        let row = UIStackView.demo(.horizontal, spacing: 11, alignment: .center, [thumb, text])
        card.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        thumb.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumb.widthAnchor.constraint(equalToConstant: 44),
            thumb.heightAnchor.constraint(equalToConstant: 44),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
        return card
    }

    private func makePill(_ title: String,
                          background: UIColor = UIColor(white: 0, alpha: 0.5),
                          foreground: UIColor = .white) -> UIButton {
        let b = UIButton(type: .system)
        b.backgroundColor = background
        b.layer.cornerRadius = DemoTheme.Radius.pill
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 10.5, weight: .bold),
            .foregroundColor: foreground,
        ]))
        b.configuration = config
        return b
    }
}
