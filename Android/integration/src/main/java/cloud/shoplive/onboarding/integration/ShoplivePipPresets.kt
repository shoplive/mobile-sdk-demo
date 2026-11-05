package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveInsets
import cloud.shoplive.player.ShoplivePipPosition
import cloud.shoplive.player.ShoplivePipRatio
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerPresentationStyle

/**
 * Keeping the stream visible after the viewer leaves the player.
 *
 * There are two kinds of PIP and they behave **differently**:
 *
 * | | in-App PIP | OS PIP |
 * | --- | --- | --- |
 * | Owner | a floating window drawn by the SDK | `Activity.enterPictureInPictureMode()` |
 * | Works with | full screen ([cloud.shoplive.player.ShoplivePlayer]) **and** embedded ([cloud.shoplive.player.ShoplivePlayerView]) | full screen **only** |
 * | Why | the SDK re-parents its own container | the whole host Activity shrinks, which cannot work for a view inside your layout |
 *
 * So in an embedded view, turning `isOSPipEnabled` on does nothing.
 *
 * ## Automatic PIP on scroll-away is the app's job
 * The public surface has no "PIP when the view leaves the screen" option. If you
 * want that, watch scroll or lifecycle yourself and call
 * [cloud.shoplive.player.ShoplivePlayerControlling.enterPictureInPicture].
 *
 * ## Relationship with product landing
 * With `navigation.actionOnNavigation = PIP`, the SDK switches to PIP by itself
 * when a product tap navigates away. "Tap a product, video shrinks into a corner"
 * is that value, not something you implement.
 *
 * ## Starting in PIP, and the PIP buttons (3.0.4+)
 * [startInPip] skips full screen and opens straight in the in-App PIP window — for a
 * viewer who came in through a notification and wants to keep the screen they are
 * on. A viewer who has not started watching yet gets a nudge preview instead (see
 * `ShopliveNudgePreview`). [withButtons] swaps or hides the window's close and
 * restore buttons.
 */
object ShoplivePipPresets {

    /**
     * SDK defaults, which already work: both PIP kinds enabled, bottom-right,
     * 9:16, 40% of the screen width.
     */
    val DEFAULT = ShoplivePlayerConfiguration.PipOptions()

    /**
     * A small floating window inset from the screen edges — the usual choice when
     * your app has a bottom navigation bar the window should not sit on top of.
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
     * in-App PIP only — the SDK-drawn window, never the OS one.
     *
     * Use this when you do not want the whole app to shrink into an OS PIP window
     * (which also hides the rest of your UI), or for an embedded view where OS PIP
     * would not work anyway.
     */
    fun inAppOnly(
        position: ShoplivePipPosition = ShoplivePipPosition.BOTTOM_RIGHT,
        scale: Float = 0.4f,
    ): ShoplivePlayerConfiguration.PipOptions = ShoplivePlayerConfiguration.PipOptions(
        isInAppPipEnabled = true,
        isOSPipEnabled = false,
        defaultPosition = position,
        scale = scale,
    )

    /**
     * Back press shrinks to OS PIP instead of closing the player.
     *
     * Requires `android:supportsPictureInPicture="true"` on the SDK player Activity
     * to be merged in from the AAR manifest — it is, but check if you override it.
     */
    fun osPipOnBackPressed(): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isOSPipEnabled = true,
            enterOSPipOnBackPressed = true,
        )

    /** No PIP at all — playback ends when the viewer leaves. */
    fun disabled(): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isInAppPipEnabled = false,
            isOSPipEnabled = false,
        )

    /**
     * Play options that open the session in the in-App PIP window instead of full
     * screen (3.0.4+). The default `presentationStyle` is FULLSCREEN, so existing code
     * is unaffected.
     *
     * Needs `pip.isInAppPipEnabled = true` (the default). Use
     * `ShoplivePlayer.start()`; an Intent from `intent()` always opens full screen and
     * ignores this.
     */
    fun startInPip(base: ShoplivePlayOptions = ShoplivePlayOptions()): ShoplivePlayOptions =
        base.copy(presentationStyle = ShoplivePlayerPresentationStyle.PIP)

    /**
     * The in-App PIP window's close and restore buttons (3.0.4+). Leaving both at
     * their defaults keeps the SDK's own buttons.
     *
     * @param closeImageResId a drawable from **your** app for the close button, or
     *   null for the SDK image. An Int on purpose: this file must not reference any
     *   particular app's `R` class.
     * @param hideRestore true hides the "back to full screen" button.
     */
    fun withButtons(
        pip: ShoplivePlayerConfiguration.PipOptions = ShoplivePlayerConfiguration.PipOptions(),
        closeImageResId: Int? = null,
        hideRestore: Boolean = false,
    ): ShoplivePlayerConfiguration.PipOptions = pip.copy(
        closeButton = ShoplivePlayerConfiguration.ButtonOptions(imageResId = closeImageResId),
        restoreButton = ShoplivePlayerConfiguration.ButtonOptions(isHidden = hideRestore),
    )
}
