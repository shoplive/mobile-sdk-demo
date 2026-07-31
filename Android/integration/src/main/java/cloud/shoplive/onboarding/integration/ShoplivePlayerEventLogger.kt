package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveCouponResult
import cloud.shoplive.player.ShopliveCustomActionResult
import cloud.shoplive.player.ShopliveError
import cloud.shoplive.player.ShoplivePlaybackEvent
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerRequest
import cloud.shoplive.player.ShoplivePlayerState
import cloud.shoplive.player.ShopliveResultAlertType
import cloud.shoplive.player.ShopliveResultStatus

/**
 * Events, products and coupons — a delegate that logs everything and hands the
 * app-specific decisions back to you through constructor callbacks.
 *
 * The SDK talks to your app through **exactly two** channels:
 *
 * - [onEvent] — notifications. Handle the ones you care about.
 * - [onRequest] — requests that **need your answer**.
 *
 * ## Navigation is the only one you must handle
 * If you ignore [ShoplivePlayerRequest.Navigation], tapping a product or a banner
 * does nothing at all. Everything else can be left alone and playback still works.
 * That is why [onNavigation] has no default value.
 *
 * ## Not calling respond looks like a freeze
 * [ShoplivePlayerRequest.Coupon] and [ShoplivePlayerRequest.CustomWebAction] only
 * dismiss their overlay popup once `respond` has been called. "No answer" is a bug,
 * so this class logs the request and the answer as a pair — if you ever see a
 * REQUEST with no RESPOND after it, that is the bug.
 *
 * ## Threading
 * Both callbacks arrive on the **main thread**. `respond` may be called from any
 * thread, which is the point: calling your coupon server and answering afterwards
 * is the normal use.
 *
 * ## Two things that never reach the log
 * 1. **Engine switches (HLS <-> WebRTC) are not events.** They are internal to the
 *    SDK; network conditions are only observable through the rebuffering signals in
 *    [ShoplivePlayerEvent.Playback].
 * 2. **Issues being auto-recovered are not errors.** [ShoplivePlayerEvent.Error]
 *    arrives only when the session dies unrecoverably (`isRecoverable = false`).
 *    See [onFailure] for what that costs you.
 *
 * @param onNavigation the URL of a product or banner the viewer tapped. Open it.
 *   Nothing else in the SDK will.
 * @param onFailure something the viewer should be told about. See [ShopliveFailure].
 * @param onMilestone progress signals, if your app tracks them (analytics,
 *   onboarding state). Ignore it and nothing breaks.
 * @param couponMessage the text shown in the coupon popup, localized by you.
 *   Returning null lets the overlay show its own default.
 */
open class ShoplivePlayerEventLogger(
    private val onNavigation: (url: String) -> Unit,
    private val onFailure: (ShopliveFailure) -> Unit = {},
    private val onMilestone: (ShopliveMilestone) -> Unit = {},
    private val couponMessage: (couponId: String) -> String? = { null },
) : ShoplivePlayerDelegate {

    /** Consecutive playback failures. Reset when playback works or a new session starts. */
    private var consecutiveFailures = 0

    /** Whether this session already reported a failure, so we do not repeat every 5s. */
    private var failureNotified = false

    override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
        when (event) {
            is ShoplivePlayerEvent.StateChanged -> {
                logEvent("stateChanged(${event.state})")
                when (event.state) {
                    // A new session starts here. This delegate is reused across
                    // sessions, so the failure counters reset at this point.
                    ShoplivePlayerState.LOADING -> {
                        consecutiveFailures = 0
                        failureNotified = false
                    }

                    ShoplivePlayerState.IN_APP_PIP -> onMilestone(ShopliveMilestone.IN_APP_PIP_ENTERED)

                    // Session over — release the control handle so later commands
                    // do not hit a dead player.
                    ShoplivePlayerState.CLOSED -> ShoplivePlayerSession.detach(player)

                    else -> Unit
                }
            }

            is ShoplivePlayerEvent.CampaignStatusChanged ->
                logEvent("campaignStatusChanged(${event.status})")

            is ShoplivePlayerEvent.CampaignInfoReceived ->
                logEvent(
                    "campaignInfoReceived(campaignKey: \"${event.info.campaignKey}\"" +
                        ", title: ${event.info.title ?: "null"}" +
                        ", status: ${event.info.status ?: "null"})"
                )

            is ShoplivePlayerEvent.Playback -> {
                logEvent("playback(${event.event.logLabel})")
                when (val playback = event.event) {
                    is ShoplivePlaybackEvent.Started -> {
                        consecutiveFailures = 0
                        onMilestone(ShopliveMilestone.PLAYBACK_STARTED)
                    }

                    is ShoplivePlaybackEvent.Rendering -> consecutiveFailures = 0

                    // Repeated failures never arrive as an error event — see below.
                    is ShoplivePlaybackEvent.Failed -> onRepeatedPlaybackFailure(playback.code)

                    else -> Unit
                }
            }

            is ShoplivePlayerEvent.ConnectionStateChanged ->
                logEvent("connectionStateChanged(${event.state})")

            is ShoplivePlayerEvent.UserNameUpdateRequested ->
                logEvent("userNameUpdateRequested(${event.payload})")

            is ShoplivePlayerEvent.Analytics ->
                logEvent(
                    "analytics(campaignKey: \"${event.info.campaignKey}\"" +
                        ", isPlaying: ${event.info.isPlaying}" +
                        ", isMuted: ${event.info.isMuted}" +
                        ", durationMs: ${event.info.durationMs})"
                )

            is ShoplivePlayerEvent.Error -> onError(event.error)
        }
    }

    override fun onRequest(player: ShoplivePlayerControlling, request: ShoplivePlayerRequest) {
        when (request) {
            // ── The one request you must handle ──────────────────────────────
            is ShoplivePlayerRequest.Navigation -> {
                logRequest("navigation(url: \"${request.url}\") — the app MUST handle this")
                onMilestone(ShopliveMilestone.REQUEST_RECEIVED)
                onNavigation(request.url)
                logRespond("→ navigation handled by the app")
            }

            // ── respond is what dismisses the popup ─────────────────────────
            is ShoplivePlayerRequest.Coupon -> {
                logRequest("coupon(id: \"${request.id}\") received")
                onMilestone(ShopliveMilestone.REQUEST_RECEIVED)

                // A real app calls its coupon server here and responds with the
                // result. respond may be called from any thread, so an async
                // round-trip is fine — just do not forget to answer.
                request.respond(
                    ShopliveCouponResult(
                        couponId = request.id,
                        success = true,
                        message = couponMessage(request.id),
                        status = ShopliveResultStatus.HIDE,
                        alertType = ShopliveResultAlertType.TOAST,
                    )
                )
                logRespond("→ respond(success = true, status = HIDE, alert = TOAST) called")
            }

            is ShoplivePlayerRequest.CustomWebAction -> {
                logRequest(
                    "customWebAction(id: \"${request.id}\", type: \"${request.type}\"" +
                        ", payload: ${request.payload})"
                )
                onMilestone(ShopliveMilestone.REQUEST_RECEIVED)
                request.respond(
                    ShopliveCustomActionResult(
                        id = request.id,
                        success = true,
                        message = null,
                        status = ShopliveResultStatus.HIDE,
                    )
                )
                logRespond("→ respond(success = true) called")
            }
        }
    }

    private fun onError(error: ShopliveError) {
        val line = error.logLine
        logError(line)
        // Anything the SDK is still recovering from does not get here. If it did
        // arrive, the session is over — tell the viewer.
        if (!error.isRecoverable) {
            onFailure(
                ShopliveFailure(
                    kind = ShopliveFailure.Kind.UNRECOVERABLE_ERROR,
                    cause = error.causeGroup,
                    code = error.code.toString(),
                    logLine = line,
                )
            )
        }
    }

    /**
     * Reports repeated playback failure.
     *
     * ## Why this is needed (measured 2026-07-30, SDK 3.0.0, emulator API 37)
     * Playing a campaign that is not on air produces `playback(failed(code: 404))`
     * every ~5 seconds, and when the session finally ends
     * (`ended → IDLE → CLOSED`), **[ShoplivePlayerEvent.Error] never arrives once**.
     * `campaignInfoReceived` and `campaignStatusChanged` did not fire either.
     *
     * So an app watching only the error event can never learn "there is no stream",
     * and the viewer just stares at a black screen. Counting `playback(failed)`
     * ourselves is the only signal available. Delete this if the SDK starts
     * emitting a terminal error for that case.
     */
    private fun onRepeatedPlaybackFailure(code: Int?) {
        consecutiveFailures += 1
        if (failureNotified || consecutiveFailures < FAILURE_THRESHOLD) return
        failureNotified = true

        val codeText = code?.toString() ?: "-"
        val line = "playback keeps failing (code: $codeText) after " +
            "$consecutiveFailures attempts — no stream available"
        logError(line)
        onFailure(
            ShopliveFailure(
                kind = ShopliveFailure.Kind.REPEATED_PLAYBACK_FAILURE,
                cause = null,
                code = codeText,
                logLine = line,
            )
        )
    }

    private companion object {
        /** Report after this many consecutive failures — one can be transient. */
        const val FAILURE_THRESHOLD = 2
    }
}

/**
 * Something went wrong in a way the viewer should hear about.
 *
 * Handed to you as data rather than as a finished sentence, so that the text stays
 * in your app's localized resources. [logLine] is the English detail already
 * written to the log; use it for bug reports, not for the UI.
 *
 * ## Where to show it
 * When this arrives, the front-most window is usually the **SDK-owned player
 * Activity**, so a Snackbar or dialog belonging to your own screen is behind it and
 * invisible. A `Toast` is the one thing that draws above another Activity, which
 * makes it the practical choice here.
 */
data class ShopliveFailure(
    val kind: Kind,
    /** Null for [Kind.REPEATED_PLAYBACK_FAILURE] — those carry no SDK error code. */
    val cause: ShopliveErrorCause?,
    /** SDK error code, or the HTTP-ish playback code. "-" when the SDK gave none. */
    val code: String?,
    val logLine: String,
) {
    enum class Kind {
        /** Playback failed repeatedly. Usually: the campaign has no live stream. */
        REPEATED_PLAYBACK_FAILURE,

        /** The session ended and the SDK will not retry. */
        UNRECOVERABLE_ERROR,
    }
}

/**
 * Playback progress worth recording, for apps that track it.
 *
 * These are derived from SDK events, not from the SDK's own vocabulary, so this
 * enum is the stable thing to switch on rather than event classes.
 */
enum class ShopliveMilestone {
    /** The stream is actually playing (not merely requested). */
    PLAYBACK_STARTED,

    /** The viewer moved the video into the SDK's floating window. */
    IN_APP_PIP_ENTERED,

    /** A request arrived that the app had to answer (navigation, coupon, custom). */
    REQUEST_RECEIVED,
}
