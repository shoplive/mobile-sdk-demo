package cloud.shoplive.onboarding.integration

import android.app.Activity
import androidx.lifecycle.LifecycleOwner
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerView

/**
 * Embedding the player inside your own layout.
 *
 * This is plain View code on purpose — no Compose, no data binding, no XML of ours.
 * Add the returned view to any container you like:
 *
 * ```kotlin
 * val player = createEmbeddedPlayer(activity, this, campaignKey, myDelegate)
 * findViewById<FrameLayout>(R.id.playerSlot).addView(player)
 * ```
 *
 * ## An embedded view is video only
 * The overlay UI (chat, products, coupons) does not appear — `overlayUI` is pinned
 * to HIDDEN, because a view living inside your layout cannot also draw overlays
 * without colliding with your UI. Use full screen ([ShoplivePlayerLauncher]) if you
 * need the overlay. The **command channel is still alive**, so events and requests
 * keep arriving at your delegate either way.
 *
 * ## Do not put it in a recycling list
 * `ShoplivePlayerView` **releases its resources when it leaves the window**
 * (`onDetachedFromWindow`). RecyclerView and LazyColumn discard off-screen items, so
 * a player used as a list item stops playing as soon as you scroll. Keep it in a
 * non-recycled slot (a fixed header, a `ScrollView`), or promote it to PIP when it
 * scrolls away.
 *
 * ## Automatic PIP on scroll-away is your call
 * There is no "PIP when the view leaves the screen" option in the public surface.
 * Watch scroll or lifecycle yourself and call
 * [ShoplivePlayerSession.enterPictureInPicture].
 */

/**
 * Creates an embedded player, wires it up and starts playing.
 *
 * @param activity host Activity. As with full screen, an application context does
 *   not work — the view needs a LifecycleOwner-backed context.
 * @param lifecycleOwner whose lifecycle releases the player. Usually the host
 *   Activity or Fragment's `viewLifecycleOwner`.
 * @param delegate event receiver. The **same** [ShoplivePlayerDelegate] contract as
 *   full screen — you can pass the one instance to both.
 * @param configuration read only before playback starts, exactly like full screen.
 */
fun createEmbeddedPlayer(
    activity: Activity,
    lifecycleOwner: LifecycleOwner,
    campaignKey: String,
    delegate: ShoplivePlayerDelegate,
    configuration: ShoplivePlayerConfiguration = ShoplivePlayerPresets.embeddedPreview(),
): ShoplivePlayerView = ShoplivePlayerView(activity).apply {
    this.delegate = delegate

    // Hand resource release to the lifecycle so a destroyed host cannot leak the
    // player.
    bindLifecycle(lifecycleOwner)

    this.configuration = configuration

    ShoplivePlayerSession.attach(this)
    logCall("ShoplivePlayerView.play(campaignKey: \"$campaignKey\") — embedded")
    play(campaignKey)
}

/**
 * Stops an embedded player and gives up its control handle.
 *
 * Call this when you remove the view yourself. Lifecycle destruction is already
 * covered by `bindLifecycle`, but a view removed from the tree while the host lives
 * on is not — and a stale handle in [ShoplivePlayerSession] would swallow later
 * commands.
 */
fun releaseEmbeddedPlayer(view: ShoplivePlayerView) {
    ShoplivePlayerSession.detach(view)
    logCall("ShoplivePlayerView.stop() — embedded released")
    view.stop()
}

/**
 * Promotes the embedded playback to the full-screen player.
 *
 * Measured 2026-07-30, SDK 3.0.0: this restarts the stream rather than handing the
 * running session over, so the viewer sees a brief reload.
 */
fun expandEmbeddedToFullScreen() {
    val view = ShoplivePlayerSession.current as? ShoplivePlayerView
    if (view == null) {
        logError("expandToFullScreen() — no embedded view handle.")
        return
    }
    logCall("expandToFullScreen() — promote to full screen")
    view.expandToFullScreen()
}
