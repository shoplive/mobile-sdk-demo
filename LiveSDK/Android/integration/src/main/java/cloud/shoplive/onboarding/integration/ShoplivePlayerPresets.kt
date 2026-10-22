package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveOverlayUIMode
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerType

/**
 * Ready-made `ShoplivePlayerConfiguration` examples — copy the one closest to
 * what you need and edit it.
 *
 * `ShoplivePlayerConfiguration` is **the initial values and policy for one
 * playback**. It replaces the static option setters of older SDK versions with a
 * single immutable object.
 *
 * ## Immutable, and only read before playback starts
 * Every field is a `val`, and assignments made after playback has started are
 * **ignored** (you only get a warning log). To see a different value take effect,
 * start playback again with a new configuration.
 *
 * The things you change *during* playback are not configuration but runtime
 * properties: `isMuted`, `resizeMode`, `overlayUI` — see [ShoplivePlayerSession].
 *
 * ## You do not have to specify anything
 * Every field has a default. `ShoplivePlayerConfiguration()` plays fine.
 *
 * ## What `overlay.ui = HIDDEN` means
 * It only **hides** the built-in overlay UI (chat, products, coupons). The command
 * channel stays alive, so product and coupon data keep arriving — that is the mode
 * to use when your app draws its own UI. There is no public mode that destroys the
 * WebView; that happens when the session ends.
 */
object ShoplivePlayerPresets {

    /** No configuration at all — the three-line integration. */
    fun default(): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration()

    /**
     * Full-screen live viewing with sound on.
     *
     * [ShoplivePlayerType.LIVE] is what decides the volume-key policy and the
     * default receive resolution, so set it deliberately rather than by accident.
     */
    fun fullScreenLive(
        muteOnStart: Boolean = false,
        mixWithOthers: Boolean = false,
    ): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration(
        type = ShoplivePlayerType.LIVE,
        sound = ShoplivePlayerConfiguration.SoundOptions(
            muteOnStart = muteOnStart,
            // true keeps other apps' audio playing alongside the stream.
            mixWithOthers = mixWithOthers,
            autoResumeOnFocusGained = true,
        ),
    )

    /**
     * An inline preview inside your own layout (see [createEmbeddedPlayer]).
     *
     * [ShoplivePlayerType.PREVIEW] blocks the volume keys and receives at preview
     * resolution, which is what you want for a card in a feed — less traffic, and
     * the hardware keys keep controlling your app instead of the video. Muted on
     * start, because autoplaying sound in a feed is hostile.
     */
    fun embeddedPreview(
        muteOnStart: Boolean = true,
    ): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration(
        type = ShoplivePlayerType.PREVIEW,
        sound = ShoplivePlayerConfiguration.SoundOptions(muteOnStart = muteOnStart),
    )

    /**
     * Your brand colour on the loading indicator, and optionally your own loading
     * animation.
     *
     * @param indicatorColor `@ColorInt`, e.g. `0xFFFF2D55.toInt()`.
     * @param loadingAnimationResId a drawable resource id from **your** app, or
     *   null for the SDK default. Passed as an Int on purpose: this file must not
     *   reference any particular app's `R` class.
     */
    fun branded(
        indicatorColor: Int,
        loadingAnimationResId: Int? = null,
        isStatusBarVisible: Boolean = true,
    ): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration(
        appearance = ShoplivePlayerConfiguration.AppearanceOptions(
            indicatorColor = indicatorColor,
            loadingAnimation = loadingAnimationResId,
            isStatusBarVisible = isStatusBarVisible,
        ),
    )

    /**
     * Video only, no built-in overlay — for apps that render chat, products and
     * coupons themselves.
     *
     * You still receive every event and request through your delegate, so your own
     * UI has the same data the built-in overlay would have used.
     */
    fun overlayHidden(): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration(
        overlay = ShoplivePlayerConfiguration.OverlayOptions(
            ui = ShopliveOverlayUIMode.HIDDEN,
        ),
    )

    /**
     * Screenshots and screen mirroring blacked out.
     *
     * `allowScreenCapture = false` makes the SDK set `FLAG_SECURE` on the player
     * window. The SDK default is `true`.
     */
    fun captureProtected(): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration(
        appearance = ShoplivePlayerConfiguration.AppearanceOptions(
            allowScreenCapture = false,
        ),
    )

    /**
     * Per-playback options. Unlike a configuration, these can differ on every
     * `start()` / `play()` call.
     *
     * @param referrer where this view came from — push id, campaign slot, screen
     *   name. Truncated at 1024 characters. It is the only link between "which
     *   entry point" and "how long they watched".
     */
    fun playOptions(
        referrer: String? = null,
        keepWindowStateOnPlayExecuted: Boolean = false,
    ): ShoplivePlayOptions = ShoplivePlayOptions(
        referrer = referrer?.takeIf { it.isNotBlank() },
        keepWindowStateOnPlayExecuted = keepWindowStateOnPlayExecuted,
    )
}
