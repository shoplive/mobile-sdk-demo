//
//  PlayerLauncher.swift
//  ★ COPY THIS — mission 1 · presenting the player directly
//
//  The minimum code to open a full-screen live stream from a single button. This file alone
//  completes mission 1.
//

import UIKit
import ShoplivePlayerSDK

enum PlayerLauncher {

    /// Presents the full-screen player.
    ///
    /// `ShoplivePlayerViewController` prepares playback as soon as it is created and plays
    /// automatically when presented (at `viewDidAppear`) — you do not call `play()` yourself.
    ///
    /// - Note: `campaignKey` is required. v3 does not expose a "create an empty VC and play later"
    ///         path, because a VC with nothing to play does nothing when presented, which makes the
    ///         cause hard to track down.
    @discardableResult
    static func present(campaignKey: String,
                        from presenter: UIViewController,
                        options: ShoplivePlayOptions = .init(),
                        configuration: ShoplivePlayerConfiguration = .init(),
                        delegate: ShoplivePlayerDelegate? = nil) -> ShoplivePlayerViewController {

        let player = ShoplivePlayerViewController(
            campaignKey: campaignKey,
            options: options,
            configuration: configuration
        )

        // The delegate is weak — the host owns its lifetime.
        // The caller must hold the delegate object passed in here strongly, or events stop arriving.
        player.delegate = delegate

        shopliveLog(.call, "ShoplivePlayerViewController(campaignKey: \"\(campaignKey)\") → present")
        presenter.present(player, animated: true)
        return player
    }
}
