package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveInsets
import cloud.shoplive.player.ShoplivePipPosition
import cloud.shoplive.player.ShoplivePipRatio
import cloud.shoplive.player.ShoplivePlayerConfiguration

/**
 * Keeping the stream visible after the viewer leaves the player.
 *
 * ## The two toggles choose *where* PIP is allowed, not which window
 * Since SDK 3.0.5:
 *
 * | | `isInAppPipEnabled` | `isOSPipEnabled` |
 * | --- | --- | --- |
 * | Covers | PIP requested **while your app is on screen**: the PIP button, back press, a product tap, [cloud.shoplive.player.ShoplivePlayerControlling.enterPictureInPicture] | PIP when the viewer **leaves your app** (home, recents) |
 * | When false | those requests do nothing (no error) | leaving the app does not open PIP, and a PIP opened inside the app closes with the session when the app goes to the background |
 *
 * Neither toggle disables the other.
 *
 * ## Which window opens is up to the SDK
 * - **Full screen ([cloud.shoplive.player.ShoplivePlayer])** — every PIP is the
 *   system (OS) PIP window, shown over your app's screen. The SDK's own floating
 *   window is no longer used here.
 * - **Embedded ([cloud.shoplive.player.ShoplivePlayerView])** — a PIP request hands the
 *   session to the SDK's full-screen player, which enters OS PIP over your screen. The
 *   view stays in your layout; expanding the PIP window opens full screen, not the view.
 * - **The SDK-drawn floating window** now opens only for `presentationStyle = PIP`
 *   (`ShoplivePlayer.startPreview` included). [floating]'s position, scale and padding
 *   style that window.
 *
 * If the viewer turned PIP off for your app in system settings, full screen reports
 * `ShopliveErrorCode.PIP_DISABLED_BY_USER` (9511) and the request falls back: the PIP
 * button leaves full screen as it is, back press closes the player, and a product tap
 * brings your app's screen up. An embedded view keeps playing and gets
 * `PIP_ENTER_FAILED`.
 *
 * ## OS PIP is not a player state
 * `ShoplivePlayerState.InAppPIP` is emitted only for the floating window. While the
 * player is in OS PIP the state stays `Playing` / `Paused`, and there is no delegate
 * callback for entering it.
 *
 * ## Automatic PIP on scroll-away is the app's job
 * The public surface has no "PIP when the view leaves the screen" option. If you
 * want that, watch scroll or lifecycle yourself and call
 * [cloud.shoplive.player.ShoplivePlayerControlling.enterPictureInPicture].
 *
 * ## Relationship with product landing
 * With `navigation.actionOnNavigation = PIP` (the default), the SDK enters PIP by itself
 * when a product tap navigates away. "Tap a product, video shrinks into a corner" is
 * that value, not something you implement.
 *
 * ## Back press
 * Back press is an in-app request: with `isInAppPipEnabled = true` (the default) it
 * goes to PIP when PIP is possible, and closes the player as before when entry fails.
 * `PipOptions.enterOSPipOnBackPressed` is kept for 3.0.x compatibility but the SDK no
 * longer reads it.
 */
object ShoplivePipPresets {

    /**
     * SDK defaults, which already work: PIP allowed both inside and outside your app;
     * the floating window at bottom-right, 9:16, 40% of the screen width.
     */
    val DEFAULT = ShoplivePlayerConfiguration.PipOptions()

    /**
     * Styles the SDK's floating window — inset from the screen edges, the usual choice
     * when your app has a bottom navigation bar the window should not sit on top of.
     *
     * Since 3.0.5 that window opens only for `presentationStyle = PIP` (the preview
     * included). The system PIP window that full screen opens ignores position, scale
     * and padding, but takes its shape from [aspectRatio].
     *
     * @param paddingDp applied to all four sides. `ShopliveInsets(left, top, right,
     *   bottom)` lets you set them individually.
     */
    fun floating(
        position: ShoplivePipPosition = ShoplivePipPosition.BOTTOM_RIGHT,
        scale: Float = 0.4f,
        aspectRatio: ShoplivePipRatio = ShoplivePipRatio.RATIO_9X16,
        paddingDp: Int = 16,
    ): ShoplivePlayerConfiguration.PipOptions = ShoplivePlayerConfiguration.PipOptions(
        isInAppPipEnabled = true,
        isOSPipEnabled = true,
        defaultPosition = position,
        scale = scale,
        aspectRatio = aspectRatio,
        padding = ShopliveInsets.all(paddingDp),
    )

    /**
     * PIP only while the viewer is in your app.
     *
     * PIP requests inside the app still open PIP, but leaving the app (home, recents)
     * does not — and a PIP already open closes with the session when the app goes to
     * the background. Use this when playback should not follow the viewer out of your
     * app.
     */
    fun inAppOnly(): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isInAppPipEnabled = true,
            isOSPipEnabled = false,
        )

    /** No PIP at all — back press closes the player, and leaving the app does not open PIP. */
    fun disabled(): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isInAppPipEnabled = false,
            isOSPipEnabled = false,
        )
}
