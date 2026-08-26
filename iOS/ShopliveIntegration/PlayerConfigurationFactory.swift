//
//  PlayerConfigurationFactory.swift
//  ★ COPY THIS — mission 7 · UI customization & repositioning
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
    /// The SDK provides a `.live` constant. Its value equals `.init()`, but using it leaves the
    /// intent visible by name at the call site.
    static func fullScreenLive() -> ShoplivePlayerConfiguration {
        ShoplivePlayerConfiguration.default
    }

    /// Embedded preview — a small inline preview placed in a product list and the like.
    ///
    /// The SDK's `.preview` preset handles all of this at once:
    /// PIP fully off (in-App and OS) · overlay UI `.hidden` · `muteOnStart` · `resizeMode = .fill`.
    /// This prevents a PIP window popping up from a preview slot, chat/coupon UI overlapping a tiny
    /// thumbnail, and audio playing without the user's consent.
    ///
    /// - Important: This preset changes **display policy only**. The switch to a preview-only stream
    ///   (`previewLiveUrl`) that v2's `ShopLive.preview()` also performed is not included, because
    ///   the embedded path has no wiring for it — the stream that plays is the same as live.
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
