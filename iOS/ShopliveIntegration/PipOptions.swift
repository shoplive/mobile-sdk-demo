//
//  PipOptions.swift
//  ★ COPY THIS — mission 3 · keep watching in PIP
//
//  There are two kinds of PIP:
//    · in-App PIP — a floating window the SDK puts above the host window. Controlled directly with
//                   enter/exit.
//    · OS PIP     — owned by the system. Happens automatically when the app goes to the background,
//                   provided `pip.isOSPipEnabled` is on.
//
//  ★ The app does not designate a target view. `enterPictureInPicture()` promotes the internal
//    render surface the SDK owns, so the host passes no view reference, container, or frame.
//

import UIKit
import ShoplivePlayerSDK

enum PipSetup {

    // MARK: - Configuration

    /// PIP policy such as position and scale. The VC approach and the View approach share the same
    /// settings.
    /// - Note: `autoEnterOnLeaveScreen` (automatic promotion when leaving the screen) was **removed
    ///   from the public surface** in this SDK build. Only manual `enterPictureInPicture()` is
    ///   available now.
    static func configuration(position: ShoplivePipPosition = .bottomRight,
                              scale: CGFloat = 0.4,
                              enableOSPip: Bool = true) -> ShoplivePlayerConfiguration {
        var config = ShoplivePlayerConfiguration()
        config.pip.isInAppPipEnabled = true
        config.pip.defaultPosition = position
        config.pip.scale = scale                    // ratio relative to the window width (0...1)
        config.pip.isOSPipEnabled = enableOSPip
        return config
    }

    // MARK: - Starting in the small window (3.0.4+)

    /// Starts this playback in the in-App PIP window instead of full screen — for a viewer who came to
    /// watch (a push, a deep link) but should keep the screen they are on (guide mission 3).
    ///
    /// With `pip.isInAppPipEnabled == false` iOS plays full screen instead, without an error — so that
    /// combination is logged here rather than discovered later.
    static func applyStartStyle(_ style: ShoplivePlayerPresentationStyle,
                                to options: inout ShoplivePlayOptions,
                                configuration: ShoplivePlayerConfiguration) {
        options.presentationStyle = style
        guard style == .pip else { return }
        if configuration.pip.isInAppPipEnabled {
            shopliveLog(.call, "ShoplivePlayOptions.presentationStyle = .pip — starts in the small window")
        } else {
            shopliveLog(.call, "presentationStyle = .pip · pip.isInAppPipEnabled = false → the SDK plays full screen")
        }
    }

    // MARK: - PIP window buttons (3.0.4+)

    /// Replaces the small window's close button image and/or hides its "back to full screen" button.
    /// A nil image keeps the SDK's default button.
    static func applyButtons(closeImage: UIImage?,
                             hideRestoreButton: Bool,
                             to configuration: inout ShoplivePlayerConfiguration) {
        configuration.pip.closeButton = .init(image: closeImage)
        configuration.pip.restoreButton = .init(isHidden: hideRestoreButton)
        shopliveLog(.call, "pip.closeButton = .init(image: \(closeImage == nil ? "nil — default" : "custom")), pip.restoreButton = .init(isHidden: \(hideRestoreButton))")
    }

    // MARK: - Control

    /// Promotes to in-App PIP. The same method works for both VC and View (shared control contract).
    ///
    /// Promotion requires all four conditions: ① playback is active (a render surface exists),
    /// ② `pip.isInAppPipEnabled == true`, ③ the window to attach to resolves successfully, and
    /// ④ no other instance is already floating.
    /// Failure is ignored silently, so confirm success via `isInPictureInPicture` or the
    /// `stateChanged(.inAppPIP)` event.
    static func enter(_ player: ShoplivePlayerControlling) {
        player.enterPictureInPicture()
        shopliveLog(.call, "enterPictureInPicture() → isInPictureInPicture=\(player.isInPictureInPicture)")
    }

    /// Returns to the original position.
    static func exit(_ player: ShoplivePlayerControlling) {
        player.exitPictureInPicture()
        shopliveLog(.call, "exitPictureInPicture() → isInPictureInPicture=\(player.isInPictureInPicture)")
    }

    static func toggle(_ player: ShoplivePlayerControlling) {
        player.isInPictureInPicture ? exit(player) : enter(player)
    }

    // MARK: - Default behavior on navigation

    /// What to do with the player when the app navigates elsewhere, e.g. to a product landing page.
    /// With `.pip`, the SDK performs `enterPictureInPicture()` internally.
    static func applyNavigationPolicy(_ action: ShopliveNavigationAction,
                                      to config: inout ShoplivePlayerConfiguration) {
        config.navigation.actionOnNavigation = action
    }
}

// MARK: - Constraints worth knowing

/*
 · Only **one** in-App PIP can be active at a time. If another instance is already floating, `enter`
   is refused — it does not shut down someone else's PIP instead (ownership is checked).

 · Automatic promotion on leaving the screen (`pip.autoEnterOnLeaveScreen`) was removed from the
   public surface. By the time a view's window becomes nil, the window to attach to is gone too, so
   resolution cannot succeed. Only manual `enterPictureInPicture()` is dependable today.

 · OS PIP for WebRTC campaigns uses iOS 15+ only APIs. This demo's deployment target is 15.0, so
   that is fine.

 · `pip.isOSPipEnabled` had no consumer in earlier builds. On the current build it is wired
   (the configuration bridge forwards it, and the engine skips registering the OS PIP controller when
   it is false). Runtime behavior has not been measured on a real device yet.
 */
