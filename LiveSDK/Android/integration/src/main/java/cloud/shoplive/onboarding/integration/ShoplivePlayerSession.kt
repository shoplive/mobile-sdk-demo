package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveOverlayUIMode
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShopliveResizeMode

/**
 * Holds the currently live player handle.
 *
 * ## Why this exists
 * `isMuted`, `resizeMode`, `reload()`, `send()` and the PIP transitions are **not**
 * configuration — they are commands to a running player. Something has to know
 * where that player is, and it cannot be the screen that started it, because by
 * then the SDK Activity is in front and your screen may have been recreated.
 *
 * Full screen ([cloud.shoplive.player.ShoplivePlayer]) and embedded
 * ([cloud.shoplive.player.ShoplivePlayerView]) both implement
 * [ShoplivePlayerControlling], so the control code below is **identical** for
 * either one. Storing the common type is how that becomes visible.
 *
 * ## Lifetime
 * [attach] is called by [ShoplivePlayerLauncher] and [createEmbeddedPlayer].
 * [detach] must be called when the session ends, otherwise commands are sent to a
 * dead handle — [ShoplivePlayerEventLogger] does it on `CLOSED`, and the embedded
 * view does it on release. A single slot is enough because the SDK plays one
 * session at a time.
 */
object ShoplivePlayerSession {

    @Volatile
    var current: ShoplivePlayerControlling? = null
        private set

    fun attach(player: ShoplivePlayerControlling) {
        current = player
    }

    fun detach(player: ShoplivePlayerControlling) {
        if (current === player) current = null
    }

    val isActive: Boolean get() = current != null

    // ── Runtime control (things a configuration cannot change) ───────────────

    fun setMuted(muted: Boolean) = withPlayer("isMuted = $muted") { it.isMuted = muted }

    fun setResizeMode(mode: ShopliveResizeMode) =
        withPlayer("resizeMode = $mode") { it.resizeMode = mode }

    /**
     * Toggles the built-in overlay.
     *
     * Measured 2026-07-30, SDK 3.0.0: an embedded view is pinned to HIDDEN (video
     * only) and ignores this assignment, and the full-screen runtime toggle is not
     * wired up yet either. To be certain the value applies, start playback again
     * with `overlay.ui` set in the configuration
     * ([ShoplivePlayerPresets.overlayHidden]). Delete this note once the SDK wires
     * the runtime path.
     */
    fun setOverlayUI(mode: ShopliveOverlayUIMode) =
        withPlayer("overlayUI = $mode") { it.overlayUI = mode }

    fun reload() = withPlayer("reload()") { it.reload() }

    /**
     * Sends a command into the overlay WebView — this is the app-to-overlay channel
     * for anything the SDK does not model, e.g. highlighting a product your own UI
     * selected.
     */
    fun send(command: String, payload: Map<String, Any?>?) =
        withPlayer("send(command: \"$command\", payload: $payload)") { it.send(command, payload) }

    fun enterPictureInPicture() = withPlayer("enterPictureInPicture()") {
        it.enterPictureInPicture()
    }

    fun exitPictureInPicture() = withPlayer("exitPictureInPicture()") {
        it.exitPictureInPicture()
    }

    fun stop() = withPlayer("stop()") { it.stop() }

    private inline fun withPlayer(logLine: String, block: (ShoplivePlayerControlling) -> Unit) {
        val player = current
        if (player == null) {
            logError("$logLine — no running player. Start playback first.")
            return
        }
        logCall(logLine)
        block(player)
    }
}
