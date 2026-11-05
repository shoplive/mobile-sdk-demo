//
//  EmbeddedPlayerView.swift
//  ★ COPY THIS — mission 7 · inline preview in a list (native · View approach)
//
//  A thin wrapper you place inside the host app's layout. The host owns layout entirely, while
//  controls, events, and PIP use **exactly the same API** as full screen (the same
//  `ShoplivePlayerControlling`). The only VC-specific parts are present/dismiss/close.
//
//  This file contains SDK calls only — copy it and use it as-is.
//  (Demo scaffolding such as feed cards and callouts lives in
//  Screens/FeedDemoViewController.swift.)
//

import UIKit
import ShoplivePlayerSDK

/// Wraps `ShoplivePlayerView` to make it easy to drop into a host layout.
public final class EmbeddedPlayerView: UIView {

    /// ★ `configuration` is a required argument. The SDK sealed off the no-argument
    ///   `ShoplivePlayerView()` and storyboard-based construction — if the view were created without
    ///   the host supplying any settings, the PIP host window, overlay, and sound policy would
    ///   silently freeze at their defaults.
    ///   To get the defaults, pass `.init()` **explicitly**.
    private let playerView: ShoplivePlayerView

    private var campaignKey: String?

    /// The embedded player, read-only — e.g. to tell its events apart from another player's (the same
    /// delegate object often serves several players). Control it through this wrapper.
    public var player: ShoplivePlayerControlling { playerView }

    public init(configuration: ShoplivePlayerConfiguration) {
        self.playerView = ShoplivePlayerView(configuration: configuration)
        super.init(frame: .zero)

        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported — use init(configuration:)") }

    // MARK: - Delegate

    /// `delegate` is **weak** — the host owns its lifetime. If nothing holds it strongly, events stop
    /// arriving silently.
    public var delegate: ShoplivePlayerDelegate? {
        get { playerView.delegate }
        set { playerView.delegate = newValue }
    }

    // MARK: - Lifecycle

    /// The embedded view never starts playback on its own — the host calls this.
    public func play(campaignKey: String, options: ShoplivePlayOptions = .init()) {
        self.campaignKey = campaignKey
        playerView.play(campaignKey: campaignKey, options: options)
        shopliveLog(.call, "playerView.play(campaignKey: \"\(campaignKey)\")")

        // ★ Design doc §3.4: the View approach is **video-only** and `overlayUI` is pinned to
        //   `.hidden`. The SDK does not enforce that pin yet (the setter accepts `.builtIn`), so a
        //   full-screen overlay gets drawn shrunken inside the embed box (measured). Hence the host
        //   hides it explicitly.
        //   The command channel stays alive, so coupon and product requests keep arriving
        //   (hidden ≠ teardown).
        playerView.overlayUI = .hidden
        shopliveLog(.call, "playerView.overlayUI = .hidden (§3.4 View = video only)")
    }

    /// Must be called when leaving the screen. Skip it and audio keeps playing.
    public func stop() {
        playerView.stop()
        shopliveLog(.call, "playerView.stop() — session ended")
    }

    public var state: ShoplivePlayerState { playerView.state }

    // MARK: - Controls (identical API to full screen)

    public var isMuted: Bool {
        get { playerView.isMuted }
        set {
            playerView.isMuted = newValue
            shopliveLog(.call, "playerView.isMuted = \(newValue)")
        }
    }

    public var resizeMode: ShopliveResizeMode {
        get { playerView.resizeMode }
        set { playerView.resizeMode = newValue }
    }

    public func reload() { playerView.reload() }

    public func enterPictureInPicture() { PipSetup.enter(playerView) }
    public func exitPictureInPicture() { PipSetup.exit(playerView) }
    public var isInPictureInPicture: Bool { playerView.isInPictureInPicture }

    public func send(command: String, payload: [String: Any]?) {
        playerView.send(command: command, payload: payload)
    }

    // MARK: - Embedded → full screen

    /// - Important: The iOS SDK has **no session-handoff API** equivalent to Android's
    ///   `expandToFullScreen()`. So we tear down the embedded session and present a fresh full-screen
    ///   VC — that re-resolves the stream, which means one more brief loading pass. If true session
    ///   handoff is needed, it is follow-up work on the SDK side.
    @discardableResult
    public func expandToFullScreen(from presenter: UIViewController,
                                   options: ShoplivePlayOptions = .init(),
                                   configuration: ShoplivePlayerConfiguration = .init(),
                                   delegate: ShoplivePlayerDelegate? = nil) -> ShoplivePlayerViewController? {
        guard let campaignKey else { return nil }
        stop()
        shopliveLog(.call, "embedded session ended → presenting a new full-screen VC (iOS has no session-handoff API)")
        return PlayerLauncher.present(campaignKey: campaignKey,
                                      from: presenter,
                                      options: options,
                                      configuration: configuration,
                                      delegate: delegate)
    }
}
