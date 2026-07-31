package cloud.shoplive.onboarding.integration

import android.app.Activity
import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.streamer.ShopliveAppearanceOptions
import cloud.shoplive.streamer.ShopliveBroadcastState
import cloud.shoplive.streamer.ShopliveStreamer
import cloud.shoplive.streamer.ShopliveStreamerDelegate
import cloud.shoplive.streamer.ShopliveStreamerEvent

/**
 * Broadcasting from the app.
 *
 * ```kotlin
 * Shoplive.setStreamToken(streamerJwt)                 // a different path from viewer auth
 * ShopliveStreamer(activity).apply { streamerDelegate = ... }.start(campaignKey)
 * ```
 *
 * ## The stream token is not the viewer identity
 * `Shoplive.setUser(...)` is **who is watching**; `Shoplive.setStreamToken(...)` is
 * **permission to broadcast**. Setting one does not fill the other.
 * `Shoplive.logout()` clears both (plus the auth token).
 *
 * ## The SDK provides the whole studio UI
 * Camera preview, switching, zoom, chat, settings and the "Live in 3, 2, 1"
 * countdown are all SDK screens. Resolution and bitrate are server-driven, so there
 * is no app code for them. The only thing you can customise is
 * [ShopliveAppearanceOptions] (countdown progress, text, cancel button).
 *
 * ## The context must be an Activity
 * `start()` **requests the camera and microphone runtime permissions for you**, and
 * that request uses the Activity's lifecycleScope. `intent()` does not request
 * anything — take the permissions yourself if you use it.
 *
 * Your manifest must still declare `RECORD_AUDIO`: it is not in the AAR manifest.
 *
 * ## One session at a time
 * Calling `start()` again while a session is in progress (any state other than IDLE
 * or ENDED) is **ignored**. When a new session does take the slot, the previous one
 * is notified that it ended.
 *
 * ## Events before the delegate is attached are dropped
 * They are not replayed, so read [ShopliveStreamer.state] right after attaching to
 * sync up with where the session already is.
 */
object ShopliveStudioLauncher {

    @Volatile
    private var current: ShopliveStreamer? = null

    val state: ShopliveBroadcastState
        get() = current?.state ?: ShopliveBroadcastState.IDLE

    /**
     * @param streamToken broadcast permission token. Blank means "do not start".
     * @param onBroadcastLive called when the broadcast reaches
     *   [ShopliveBroadcastState.LIVE] — viewers can see it from this point.
     * @param onFatalError an unrecoverable streamer error, already formatted for a
     *   log. Show your own localized message; use this text for bug reports.
     * @return true if a start was attempted.
     */
    fun start(
        activity: Activity,
        campaignKey: String,
        streamToken: String,
        appearance: ShopliveAppearanceOptions = ShopliveAppearanceOptions(),
        onBroadcastLive: () -> Unit = {},
        onFatalError: (String) -> Unit = {},
    ): Boolean {
        if (streamToken.isBlank()) {
            logError("No stream token — broadcasting requires one.")
            return false
        }

        Shoplive.setStreamToken(streamToken)
        logCall("Shoplive.setStreamToken(\"${shopliveMasked(streamToken)}\")")

        val streamer = ShopliveStreamer(activity)
        streamer.streamerDelegate = ShopliveStreamerEventLogger(onBroadcastLive, onFatalError)
        current = streamer

        // Read the state once, right after attaching — earlier events are gone.
        logEvent("StreamerEvent subscribed — current state: ${streamer.state}")

        logCall("ShopliveStreamer(activity).start(campaignKey: \"$campaignKey\")")
        streamer.start(
            campaignKey = campaignKey,
            appearance = appearance,
        )
        return true
    }
}

/**
 * Broadcast event receiver. Delivered on the main thread.
 *
 * There are only **two** event kinds, StateChanged and Error. State only ever moves
 * forward by rank, so a signal that arrives late cannot rewind the session, and
 * ENDED is terminal.
 */
class ShopliveStreamerEventLogger(
    private val onBroadcastLive: () -> Unit = {},
    private val onFatalError: (String) -> Unit = {},
) : ShopliveStreamerDelegate {

    override fun onEvent(streamer: ShopliveStreamer, event: ShopliveStreamerEvent) {
        when (event) {
            is ShopliveStreamerEvent.StateChanged -> {
                logEvent(
                    "StreamerEvent.stateChanged(${event.state}" +
                        ", isRehearsal: ${event.isRehearsal})"
                )
                if (event.state == ShopliveBroadcastState.LIVE) onBroadcastLive()
            }

            is ShopliveStreamerEvent.Error -> {
                val error = event.error
                val text = "StreamerEvent.error(code: ${error.code}" +
                    ", rawCode: ${error.rawCode}" +
                    ", isRecoverable: ${error.isRecoverable}) ${error.message}"
                logError(text)
                if (!error.isRecoverable) onFatalError(text)
            }
        }
    }
}
