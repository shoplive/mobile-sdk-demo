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
        /// Full-screen live viewing — missions 1, 2, 3, 5, 6, 7
        case fullScreenLive
        /// Embedded preview — mission 4
        case embeddedPreview
    }

    static func makeConfiguration(_ usage: Usage = .fullScreenLive,
                                  from store: DemoConfigStore = .shared) -> ShoplivePlayerConfiguration {
        // Base = the SDK-provided preset. The preview one already has PIP off, overlay hidden,
        // muteOnStart, and fill baked in.
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

        config.overlay.ui = store.overlayUI
        config.customParameters = store.customParameters
        return config
    }

    static func makePlayOptions(from store: DemoConfigStore = .shared) -> ShoplivePlayOptions {
        var options = ShoplivePlayOptions()
        options.referrer = store.referrer
        options.keepWindowStateOnPlayExecuted = store.keepWindowStateOnPlayExecuted
        return options
    }
}
