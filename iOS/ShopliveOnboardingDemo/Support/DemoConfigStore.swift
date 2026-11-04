//
//  DemoConfigStore.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The mutable state driven by the "Options" tab of the V1 developer sheet.
//  Prototype V1 rule: the options tab is the home for every configuration field that no mission
//  covers.
//  → Every public field of ShoplivePlayerConfiguration has exactly one control here.
//
//  The actual ShoplivePlayerConfiguration assembly is done by
//  ShopliveIntegration/PlayerConfigurationFactory.swift.
//

import UIKit
import ShoplivePlayerSDK
import ShopliveCore

final class DemoConfigStore {

    static let shared = DemoConfigStore()
    static let didChange = Notification.Name("DemoConfigStore.didChange")

    private init() {}

    // MARK: - Authentication (user info mission)

    enum AuthMode: String, CaseIterable {
        case guest, profile, token

        var label: String {
            switch self {
            case .guest:   return L("auth.guest")
            case .profile: return L("auth.profile")
            case .token:   return L("auth.token")
            }
        }
    }

    var authMode: AuthMode = .guest

    // MARK: - PipOptions

    var isInAppPipEnabled = true
    var isOSPipEnabled = true
    var pipPosition: ShoplivePipPosition = .bottomRight
    var pipScale: CGFloat = 0.4
    /// The spec default is `.zero`, but at 0 the PIP window sits flush against the right/bottom edge
    /// and runs into the home indicator area, where it looks clipped (measured). Only the demo's
    /// default is nudged to 12 — you can set it back to 0 from the options tab.
    var pipPadding: CGFloat = 12
    var pipFloatingOffset: CGFloat = 0
    var pipFixedWidth: CGFloat? = nil

    /// Card players start in the small window (`ShoplivePlayOptions.presentationStyle = .pip`, 3.0.4+).
    var startInPip = false
    /// pip.closeButton gets an SF Symbol image and pip.restoreButton is hidden (3.0.4+). Off = SDK defaults.
    var customPipButtons = false

    // MARK: - SoundOptions

    var muteOnStart = false
    var mixWithOthers = false
    var autoResumeOnCallEnded = true

    // MARK: - ShopliveAppearanceOptions

    var indicatorColor: UIColor = .white
    var allowScreenCapture = false

    // MARK: - NavigationOptions

    var actionOnNavigation: ShopliveNavigationAction = .pip
    var shareScheme: String? = nil
    /// `true` → the share button sends shareRequested and the app shows its own sheet (3.0.4+). Same
    /// default as the SDK.
    var isCustomShareEnabled = false

    // MARK: - OverlayOptions

    var overlayUI: ShopliveOverlayUIMode = .builtIn

    // MARK: - Miscellaneous

    var customParameters: [String: String] = [:]

    // MARK: - ShoplivePlayOptions

    var referrer: String? = nil
    var keepWindowStateOnPlayExecuted = false

    // MARK: - Nudge preview (demo behavior, not an SDK field)

    /// Close a nudge the viewer has not expanded when its campaign is not live (the guide's recommended
    /// practice). Off by default so VOD and scheduled campaigns can still be demoed (S38).
    var closeNudgeWhenNotLive = false

    // MARK: - Runtime controls (applied immediately via properties, not through config)

    var isMuted = false
    var resizeMode: ShopliveResizeMode = .fill

    // MARK: - Cycling helpers (tap a value in the options tab → next value)

    func notifyChanged() {
        NotificationCenter.default.post(name: DemoConfigStore.didChange, object: nil)
    }

    static let pipPositionCycle: [ShoplivePipPosition] = [
        .bottomRight, .bottomCenter, .bottomLeft,
        .middleRight, .middleCenter, .middleLeft,
        .topRight, .topCenter, .topLeft,
    ]

    static let indicatorColorCycle: [(String, UIColor)] = [
        ("white", .white),
        ("brand", DemoTheme.brand),
        ("blue", DemoTheme.info),
        ("black", .black),
    ]
}

// MARK: - Demo UI copy (needs localization — not a copy target)

extension ShopliveNavigationAction {
    /// The line that explains the policy on the V2 product detail screen.

    var explanation: String {
        switch self {
        case .pip:   return L("nav.action.pip.explain")
        case .keep:  return L("nav.action.keep.explain")
        case .close: return L("nav.action.close.explain")
        @unknown default: return ""
        }
    }
}
