package cloud.shoplive.onboarding.integration

import android.app.Activity
import cloud.shoplive.player.ShopliveCampaignStatus
import cloud.shoplive.player.ShopliveCloseReason
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayer
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerRequest
import cloud.shoplive.player.ShoplivePlayerState

/**
 * A nudge preview — a silent small window floating over one of your screens (a
 * product page, say) that invites a viewer who has **not** started watching yet.
 * Tapping it grows the same window to full screen with sound; the SDK does that, so
 * there is nothing for you to call.
 *
 * It is two presets, and both must be passed:
 *
 * | | constant | decides |
 * | --- | --- | --- |
 * | configuration | `ShoplivePlayerConfiguration.PREVIEW` | preview stream, muted, overlay hidden, in-App PIP policy |
 * | play options | `ShoplivePlayOptions.PREVIEW` | `presentationStyle = PIP` — start in the small window |
 *
 * ```kotlin
 * val session = ShopliveNudgePreview.Session(myDelegate)
 * ShopliveNudgePreview.start(activity, campaignKey, session)
 * ```
 *
 * A viewer who is already watching and moves to another screen gets PIP instead
 * (see [ShoplivePipPresets]); the window looks the same, the purpose does not.
 *
 * ## The guide's recommendations, as code
 * - Not again on the same screen once the viewer closed it ([onHostVisible]).
 * - Not while the campaign is not live — your policy, see [Session].
 * - A nudge nobody expanded belongs to the screen it floats over: when that screen
 *   goes away, close it ([onHostLeft]). One the viewer expanded is now a viewing
 *   session and is left alone.
 */
object ShopliveNudgePreview {

    /**
     * PREVIEW, with in-App PIP spelled out. The preset already enables it; writing it
     * down keeps the small window from silently becoming full screen if the base you
     * pass in has it off.
     */
    fun configuration(
        base: ShoplivePlayerConfiguration = ShoplivePlayerConfiguration.PREVIEW,
    ): ShoplivePlayerConfiguration = base.copy(pip = base.pip.copy(isInAppPipEnabled = true))

    /**
     * Starts the nudge over [activity]. Goes through [ShoplivePlayerLauncher], so it
     * becomes the [ShoplivePlayerSession] like any other session — and, as with any
     * `start()`, closes another full-screen or PIP session that is open.
     *
     * @param session a new [Session] for this start; it is the player's delegate and
     *   keeps the player until it closes.
     */
    fun start(
        activity: Activity,
        campaignKey: String,
        session: Session,
        configuration: ShoplivePlayerConfiguration = configuration(),
    ): ShoplivePlayer {
        logCall(
            "nudge preview — configuration PREVIEW (pip.isInAppPipEnabled: " +
                "${configuration.pip.isInAppPipEnabled}) + ShoplivePlayOptions.PREVIEW"
        )
        val player = ShoplivePlayerLauncher.start(
            activity = activity,
            campaignKey = campaignKey,
            delegate = session,
            configuration = configuration,
            options = ShoplivePlayOptions.PREVIEW,
        )
        session.adopt(player)
        return player
    }

    /** What to do when the host screen becomes visible. */
    enum class HostVisit {
        /** Nothing running and nothing against it — start one. */
        START,

        /** This screen's nudge is still up (rotation, back from full screen). */
        ALREADY_SHOWING,

        /**
         * Coming back to the page while another session is starting or playing (a PIP
         * the viewer is watching, say). Re-showing a nudge would close it, and a
         * viewer who is watching is not the one to nudge.
         */
        OTHER_SESSION_ONGOING,

        /** The viewer closed it on this screen. Do not push it again. */
        CLOSED_BY_VIEWER,
    }

    /**
     * Decides whether the host screen should start a nudge. Only a viewer's own close
     * ([ShopliveCloseReason.USER_ACTION]) holds it back; a close the app caused, an
     * access-key change, or no known reason does not.
     *
     * @param isShowing this screen's nudge player is starting or showing
     *   (see [isOngoing]).
     * @param lastCloseReason why this screen's previous nudge closed, if one did.
     * @param otherSessionOngoing a session that is not this screen's nudge is
     *   starting or showing — e.g. `ShoplivePlayerSession.current` is someone else.
     * @param isFirstVisit the screen is showing for the first time (the viewer just
     *   opened it). Then the nudge starts like any other explicit start, and the SDK
     *   closes the other session; [otherSessionOngoing] only holds back re-showing.
     */
    fun onHostVisible(
        isShowing: Boolean,
        lastCloseReason: ShopliveCloseReason?,
        otherSessionOngoing: Boolean,
        isFirstVisit: Boolean,
    ): HostVisit = when {
        isShowing -> HostVisit.ALREADY_SHOWING
        otherSessionOngoing && !isFirstVisit -> HostVisit.OTHER_SESSION_ONGOING
        lastCloseReason == ShopliveCloseReason.USER_ACTION -> HostVisit.CLOSED_BY_VIEWER
        else -> HostVisit.START
    }

    /**
     * Call when the host screen is gone for good (popped, not rotated). Closes the
     * nudge unless the viewer expanded it; `close()` reports APP_REQUEST. An idle
     * player (a start that never got going) is closed too, so nothing is left behind.
     *
     * Not expanded is the safe default: if the expansion signal never arrived, the
     * window is treated as the screen's own and closed with it.
     */
    fun onHostLeft(session: Session) {
        val player = session.player
        when {
            player == null ->
                logEvent("nudge host left — the nudge had already closed (${session.closeReason ?: "never started"})")

            session.wasExpanded ->
                logEvent("nudge host left — the viewer expanded it, so it keeps playing")

            else -> {
                logCall("ShoplivePlayer.close() — nudge host left before it was expanded (state: ${player.state})")
                player.close()
            }
        }
    }

    /**
     * What one nudge session has shown about itself, recorded from its own events.
     * Create one per [start]; it becomes the player's delegate, and every event and
     * request is forwarded unchanged to [delegate].
     *
     * It keeps [player] **strongly, and only until the session closes**: a weak
     * reference could be cleared while the window is still up, and the page would
     * then fail to close it on leaving. The SDK's `ShoplivePlayer` itself holds the
     * Activity strongly until `Closed` (and [ShoplivePlayerSession] holds the player),
     * so this does not extend how long anything is retained; after `Closed` only
     * plain facts remain. To be confirmed with a heap dump after rotation (S43).
     *
     * @param closeWhenNotLive the guide's "do not show it while not live", as a
     *   switch: when the campaign is not live and the viewer never expanded the
     *   window, it is closed. Off keeps VOD and upcoming campaigns visible.
     */
    class Session(
        private val delegate: ShoplivePlayerDelegate,
        private val closeWhenNotLive: Boolean = false,
    ) : ShoplivePlayerDelegate {

        /** Why this session closed. Null while it runs. */
        var closeReason: ShopliveCloseReason? = null
            private set

        /** The viewer grew the small window to full screen at least once. */
        var wasExpanded: Boolean = false
            private set

        var campaignStatus: ShopliveCampaignStatus? = null
            private set

        /** The player this session started. Null before [start] and after it closed. */
        var player: ShoplivePlayer? = null
            private set

        private var hasBeenInPip = false

        /** Called by [start]. A session that already closed while starting keeps nothing. */
        internal fun adopt(started: ShoplivePlayer) {
            if (closeReason == null) player = started
        }

        override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
            delegate.onEvent(player, event)
            when (event) {
                is ShoplivePlayerEvent.StateChanged -> track(player, event.state)
                is ShoplivePlayerEvent.CampaignStatusChanged -> onCampaignStatus(player, event.status)
                // The page's next visit starts a new one: an errored session goes idle
                // or closed, and neither counts as "still showing" (isOngoing).
                is ShoplivePlayerEvent.Error ->
                    if (!event.error.isRecoverable) {
                        logError("nudge session ended by an unrecoverable error — a new one starts when the page shows again")
                    }
                else -> Unit
            }
        }

        override fun onRequest(player: ShoplivePlayerControlling, request: ShoplivePlayerRequest) {
            delegate.onRequest(player, request)
        }

        /**
         * Expanded = playing again after being in the small window, **and** no longer
         * in it. The second check matters: a nudge starts in the window, so it can
         * report playing while still small.
         */
        private fun track(player: ShoplivePlayerControlling, state: ShoplivePlayerState) {
            when (state) {
                ShoplivePlayerState.InAppPIP -> hasBeenInPip = true

                ShoplivePlayerState.Playing ->
                    if (hasBeenInPip && !player.isInPictureInPicture && !wasExpanded) {
                        wasExpanded = true
                        logEvent("nudge expanded to full screen — now a viewing session")
                    }

                is ShoplivePlayerState.Closed -> {
                    closeReason = state.reason
                    this.player = null
                }

                else -> Unit
            }
        }

        private fun onCampaignStatus(player: ShoplivePlayerControlling, status: ShopliveCampaignStatus) {
            campaignStatus = status
            if (status == ShopliveCampaignStatus.LIVE) return
            // TODO(SDP-VERIFY): needs verification — what the nudge window shows for a campaign that is not live (a waiting screen, or closing at once with which closeReason) is SDK behaviour; measure on Android · ref SMV-1922 U06
            when {
                wasExpanded -> logEvent("nudge: campaign is $status — expanded by the viewer, kept")
                !closeWhenNotLive -> logEvent("nudge: campaign is $status — kept (closeWhenNotLive is off)")
                else -> {
                    val fullScreen = player as? ShoplivePlayer
                    if (fullScreen == null) {
                        logError("nudge: campaign is $status but the player cannot be closed from here")
                    } else {
                        logCall("ShoplivePlayer.close() — nudge campaign is $status, not live")
                        fullScreen.close()
                    }
                }
            }
        }
    }
}
