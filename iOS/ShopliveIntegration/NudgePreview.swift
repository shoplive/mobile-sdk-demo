//
//  NudgePreview.swift
//  ★ COPY THIS — mission 2 · nudge preview
//
//  A small, muted window over a screen the viewer is already using (a product page, home) that invites
//  them into a live they have not watched yet. Tapping it grows the same window to full screen with
//  sound (iOS 3.0.4+) — the SDK does that; the app does nothing on tap.
//
//  Two presets make a nudge, and both must be passed (guide mission 2, step 2):
//    · configuration .preview — preview stream · muted · overlay hidden
//    · play options  .preview — presentationStyle = .pip (start in the small window)
//
//  A nudge is not PIP: PIP (mission 3) keeps a live the viewer is already watching; a nudge comes
//  before watching.
//

import UIKit
import ShoplivePlayerSDK

enum NudgePreview {

    /// `ShoplivePlayerConfiguration.preview` with in-App PIP switched on explicitly.
    ///
    /// The guide's prerequisite is `pip.isInAppPipEnabled = true`. If it were false, iOS would play full
    /// screen instead of in the small window without saying so (guide mission 3). The preset's own value
    /// is not visible in the SDK interface, so it is logged and then set — change only what you need
    /// (the guide's "start from the preset" pattern).
    static func presetConfiguration() -> ShoplivePlayerConfiguration {
        var configuration = ShoplivePlayerConfiguration.preview
        shopliveLog(.call, "ShoplivePlayerConfiguration.preview — preset pip.isInAppPipEnabled = \(configuration.pip.isInAppPipEnabled)")
        configuration.pip.isInAppPipEnabled = true
        return configuration
    }

    /// Starts a nudge and returns its player.
    ///
    /// The caller **must hold the returned player strongly** while its screen lives — a small window
    /// that is not presented has no other owner — and `close()` it when the screen goes away (unless the
    /// viewer expanded it and is watching).
    ///
    /// - Parameters:
    ///   - presenter: the screen the nudge floats over.
    ///   - beforePlay: runs with the new player right before `play` — register listeners and keep the
    ///     player here, or the first events (e.g. entering the small window) can arrive unobserved.
    @discardableResult
    static func start(campaignKey: String,
                      over presenter: UIViewController,
                      configuration: ShoplivePlayerConfiguration = presetConfiguration(),
                      delegate: ShoplivePlayerDelegate?,
                      beforePlay: (ShoplivePlayerViewController) -> Void = { _ in }) -> ShoplivePlayerViewController {
        let player = ShoplivePlayerViewController(campaignKey: campaignKey,
                                                  options: .preview,
                                                  configuration: configuration)
        player.delegate = delegate      // weak — the caller owns the delegate's lifetime
        shopliveLog(.call, "nudge — pip.isInAppPipEnabled = \(configuration.pip.isInAppPipEnabled), options: .preview (presentationStyle .pip)")

        // TODO(SDP-VERIFY): 요확인 — presentationStyle .pip 이면 VC 를 present 하지 않고 play(campaignKey:options:) 만으로 작은 창이 뜨는지, present 가 필요한지(S28). 필요하면 이 함수 안에서만 presenter.present(player, animated: false) 로 바꾼다(호출부 무변경) · 근거 SMV-1922
        beforePlay(player)
        player.play(campaignKey: campaignKey, options: .preview)
        shopliveLog(.call, "play(campaignKey: \"\(campaignKey)\", options: .preview) — small window, not presented")
        return player
    }
}
