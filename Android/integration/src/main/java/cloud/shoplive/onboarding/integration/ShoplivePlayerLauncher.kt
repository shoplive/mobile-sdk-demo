package cloud.shoplive.onboarding.integration

import android.app.Activity
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayer
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerPresentationStyle

/**
 * Starting full-screen playback.
 *
 * The integration is three lines:
 *
 * ```kotlin
 * Shoplive.initialize(context, ShopliveConfiguration("{ACCESS_KEY}"))   // once, at app start
 * Shoplive.setUser(ShopliveUser.Guest)                                  // optional
 * ShoplivePlayer(activity).start(campaignKey = "{CAMPAIGN_KEY}")
 * ```
 *
 * ## The context must be an Activity
 * `ShoplivePlayer(context)` needs a **LifecycleOwner** (an Activity). Hand it
 * `applicationContext` and the SDK refuses to start, leaving only a warning in
 * logcat — which looks exactly like "the button does nothing". This is the most
 * common integration mistake.
 *
 * ## Why you must hold on to the instance
 * `delegate` is **owned by the instance**. Create the player in a local variable
 * and let it go, and no events reach you. [ShoplivePlayerSession] is where this
 * package keeps the handle.
 *
 * ## When your app wants to own the transition
 * Use `intent()` instead of `start()` to get the Intent and call `startActivity`
 * yourself — that is how you control the transition animation or the task policy.
 */
object ShoplivePlayerLauncher {

    /**
     * @param activity the screen the SDK Activity is launched from. Must be a
     *   LifecycleOwner.
     * @param delegate event receiver. Keep a reference to it for as long as you
     *   want events — see [ShoplivePlayerEventLogger].
     * @param configuration initial values for this one playback. Omit for the SDK
     *   defaults; see [ShoplivePlayerPresets].
     * @return the player, so the caller can tell its events apart from another
     *   session's (the delegate is handed the player on every callback).
     */
    fun start(
        activity: Activity,
        campaignKey: String,
        delegate: ShoplivePlayerDelegate,
        configuration: ShoplivePlayerConfiguration = ShoplivePlayerPresets.default(),
        options: ShoplivePlayOptions = ShoplivePlayOptions(),
    ): ShoplivePlayer {
        val player = ShoplivePlayer(activity)
        player.delegate = delegate

        ShoplivePlayerSession.attach(player)

        val startsInPip = options.presentationStyle == ShoplivePlayerPresentationStyle.PIP
        if (startsInPip && !configuration.pip.isInAppPipEnabled) {
            // iOS documents a silent fall back to full screen; Android documents nothing.
            // TODO(SDP-VERIFY): needs verification — what Android 3.0.4 does with presentationStyle = PIP and pip.isInAppPipEnabled = false (full screen / ignored / exception) is undocumented; measure on a device · ref SMV-1922 S08
            logError("start in PIP requested while pip.isInAppPipEnabled = false — Android behaviour undocumented")
        }
        logCall(
            "ShoplivePlayer(activity).start(campaignKey: \"$campaignKey\"" +
                ", referrer: ${options.referrer ?: "null"}" +
                ", presentationStyle: ${options.presentationStyle}" +
                ", pip.isInAppPipEnabled: ${configuration.pip.isInAppPipEnabled})"
        )
        player.start(
            campaignKey = campaignKey,
            options = options,
            configuration = configuration,
        )
        return player
    }
}
