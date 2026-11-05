//
//  DemoConfigBuilder.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  V1 options-tab state (DemoConfigStore) → SDK configuration object.
//  This assembly exists only because the demo requires "one control per configuration field"; your
//  own app doesn't need it. That is why it lives in the harness rather than ShopliveIntegration/.
//  (For examples meant to be copied, see branded()/overlayHidden() in
//  ShopliveIntegration/PlayerConfigurationFactory.swift.)
//

import UIKit
import ShoplivePlayerSDK

enum DemoConfigBuilder {

    /// Picks a usage, takes the matching SDK preset as the base, and paints the options-tab values
    /// on top of it.
    enum Usage {
        /// Full-screen live viewing — every card player, deep links, the hybrid list, the feed's expand
        case fullScreenLive
        /// Embedded preview — the inline (native) feed
        case embeddedPreview
    }

    static func makeConfiguration(_ usage: Usage = .fullScreenLive,
                                  from store: DemoConfigStore = .shared) -> ShoplivePlayerConfiguration {
        // Base = the SDK-provided preset. The preview one already has overlay hidden, muteOnStart and
        // fill baked in (its PIP value: see PlayerConfigurationFactory.embeddedPreview).
        var config: ShoplivePlayerConfiguration
        switch usage {
        case .fullScreenLive:   config = PlayerConfigurationFactory.fullScreenLive()
        case .embeddedPreview:  config = PlayerConfigurationFactory.embeddedPreview()
        }

        // Preview keeps the preset values as they are — painting the options tab over them would
        // destroy what the preset means.
        guard usage == .fullScreenLive else {
            config.appearance.indicatorColor = store.indicatorColor
            config.customParameters = store.customParameters
            return config
        }

        config.pip.isInAppPipEnabled = store.isInAppPipEnabled
        config.pip.isOSPipEnabled = store.isOSPipEnabled
        config.pip.defaultPosition = store.pipPosition
        config.pip.scale = store.pipScale
        config.pip.padding = UIEdgeInsets(top: store.pipPadding, left: store.pipPadding,
                                         bottom: store.pipPadding, right: store.pipPadding)
        config.pip.floatingOffset = UIEdgeInsets(top: store.pipFloatingOffset, left: store.pipFloatingOffset,
                                                 bottom: store.pipFloatingOffset, right: store.pipFloatingOffset)
        config.pip.fixedWidth = store.pipFixedWidth

        config.sound.muteOnStart = store.muteOnStart
        config.sound.mixWithOthers = store.mixWithOthers
        config.sound.autoResumeOnCallEnded = store.autoResumeOnCallEnded

        config.appearance.indicatorColor = store.indicatorColor
        config.appearance.allowScreenCapture = store.allowScreenCapture
        config.appearance.resizeMode = store.resizeMode   // field that moved under appearance on dev

        config.navigation.actionOnNavigation = store.actionOnNavigation
        config.navigation.shareScheme = store.shareScheme
        DemoPlayerDelegate.enableCustomShare(store.isCustomShareEnabled, in: &config)

        if store.customPipButtons {
            let closeImage = UIImage(systemName: pipCloseSymbol)
            if closeImage == nil {
                EventLog.shared.log(.error, "demo: SF Symbol \"\(pipCloseSymbol)\" not found — the PIP close button keeps the default image")
            }
            PipSetup.applyButtons(closeImage: closeImage, hideRestoreButton: true, to: &config)
        }

        config.overlay.ui = store.overlayUI
        config.customParameters = store.customParameters
        return config
    }

    /// Nudge: the `.preview` preset plus only the options changed from the SDK default.
    static func makeNudgeConfiguration(from store: DemoConfigStore = .shared) -> ShoplivePlayerConfiguration {
        var config = NudgePreview.presetConfiguration()
        let options = makeConfiguration(.fullScreenLive, from: store)
        let sdkDefault = ShoplivePlayerConfiguration()
        func paint<T: Equatable>(_ field: WritableKeyPath<ShoplivePlayerConfiguration, T>) {
            if options[keyPath: field] != sdkDefault[keyPath: field] { config[keyPath: field] = options[keyPath: field] }
        }
        paint(\.pip.isOSPipEnabled); paint(\.pip.defaultPosition); paint(\.pip.scale)
        paint(\.pip.padding); paint(\.pip.floatingOffset); paint(\.pip.fixedWidth)
        paint(\.sound.muteOnStart); paint(\.sound.mixWithOthers); paint(\.sound.autoResumeOnCallEnded)
        paint(\.appearance.allowScreenCapture); paint(\.appearance.resizeMode)
        paint(\.navigation.actionOnNavigation); paint(\.navigation.shareScheme); paint(\.navigation.isCustomShareEnabled)
        paint(\.overlay.ui); paint(\.customParameters)
        config.appearance.indicatorColor = options.appearance.indicatorColor
        if store.customPipButtons {
            config.pip.closeButton = options.pip.closeButton
            config.pip.restoreButton = options.pip.restoreButton
        }
        return config
    }

    /// The PIP close-button image for the options-tab switch. The demo has no asset catalog, so an SF
    /// Symbol stands in for your own image.
    private static let pipCloseSymbol = "xmark.circle.fill"

    /// Card players only: the per-playback options plus the options tab's start style. Embeds, deep
    /// links and the hybrid list keep full screen.
    static func makeCardPlayOptions(for configuration: ShoplivePlayerConfiguration,
                                    from store: DemoConfigStore = .shared) -> ShoplivePlayOptions {
        var options = makePlayOptions(from: store)
        PipSetup.applyStartStyle(store.startInPip ? .pip : .fullScreen, to: &options, configuration: configuration)
        return options
    }

    static func makePlayOptions(from store: DemoConfigStore = .shared) -> ShoplivePlayOptions {
        var options = ShoplivePlayOptions()
        options.referrer = store.referrer
        options.keepWindowStateOnPlayExecuted = store.keepWindowStateOnPlayExecuted
        return options
    }
}
