//
//  PlayerConfigurationFactory.swift
//  ★ COPY THIS — mission 8 · UI customization & repositioning
//
//  ShoplivePlayerConfiguration is a bundle of "playback policy". Every field has a default, so
//  `.init()` alone works and you override only what you want to change (design principle:
//  progressive disclosure).
//
//  Don't confuse it with ShoplivePlayOptions (per-playback options) — values that differ on every
//  play, such as `referrer`, belong there.
//

import UIKit
import ShoplivePlayerSDK

enum PlayerConfigurationFactory {

    // MARK: - Presets by usage (provided by the SDK)

    /// Full-screen live viewing — all features on.
    ///
    /// The SDK provides a `.default` constant. Its value equals `.init()`, but using it leaves the
    /// intent visible by name at the call site.
    static func fullScreenLive() -> ShoplivePlayerConfiguration {
        ShoplivePlayerConfiguration.default
    }

    // TODO(SDP-VERIFY): 요확인 — 3.0.4 .preview 의 pip.isInAppPipEnabled·resizeMode 값은 swiftinterface 에 없음(예전 주석의 "PIP fully off"·"resizeMode .fill" 은 근거 없어 삭제). NudgePreview.presetConfiguration() 이 넛지 시작 때 PIP 값을 로그로 남기므로 실기기 로그로 확정 · 근거 SMV-1922 S07
    /// Embedded preview — a small inline preview placed in a product list and the like.
    ///
    /// The SDK's `.preview` preset (3.0.4) sets these at once (guide missions 2 · 7):
    /// the preview stream (`type = .preview`, lower resolution) · muted start · overlay UI `.hidden`.
    /// So several previews can play in one list on little traffic, a tiny thumbnail carries no
    /// chat/coupon UI, and no audio plays before the viewer chooses to watch.
    static func embeddedPreview() -> ShoplivePlayerConfiguration {
        ShoplivePlayerConfiguration.preview
    }

    // MARK: - Approach ① standard appearance options

    /// The default configuration with only brand color and fonts swapped in.
    static func branded(indicatorColor: UIColor,
                        chatInputFont: UIFont? = nil,
                        chatSendButtonFont: UIFont? = nil) -> ShoplivePlayerConfiguration {
        var config = ShoplivePlayerConfiguration()
        config.appearance.indicatorColor = indicatorColor
        config.appearance.chatInputFont = chatInputFont
        config.appearance.chatSendButtonFont = chatSendButtonFont
        return config
    }

    // MARK: - Approach ② hide the built-in UI and draw your own

    /// A configuration that hides the built-in overlay UI (chat, products, coupons) so the app draws
    /// everything itself from delegate data.
    ///
    /// - Important: `.hidden` turns off **display only**. The overlay web view stays alive internally
    ///   (it is the command channel), which is why coupon, product, and custom-action requests keep
    ///   arriving. This is not a teardown.
    static func overlayHidden() -> ShoplivePlayerConfiguration {
        var config = ShoplivePlayerConfiguration()
        config.overlay.ui = .hidden
        return config
    }

    /// Applies the overlay mode through the runtime property instead of the configuration.
    ///
    /// Older SDK builds did not consume the `overlay.ui` configuration field at all, so this was the
    /// only way to hide the overlay. On the current build the configuration path **is** wired
    /// (`ShoplivePlayerView` reads `configuration.overlay.ui` on play), so this is no longer a
    /// workaround — keep it only when you need to toggle the overlay *during* playback.
    static func applyRuntimeOverlay(_ mode: ShopliveOverlayUIMode, to player: ShoplivePlayerControlling) {
        player.overlayUI = mode
        shopliveLog(.call, "overlayUI = .\(mode.logLabel) (runtime property — takes effect mid-playback)")
    }
}
