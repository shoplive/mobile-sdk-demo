package cloud.shoplive.onboarding.data

import cloud.shoplive.onboarding.integration.ShoplivePreviewWindow
import cloud.shoplive.onboarding.integration.ShoplivePreviewWindow.HostVisit
import cloud.shoplive.onboarding.integration.isOngoing
import cloud.shoplive.player.ShopliveCampaignStatus
import cloud.shoplive.player.ShopliveCloseReason
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

/**
 * The preview's guards (SMV-1922 cases S04 / S05 / S38 / U08): when the host
 * screen shows again, and what a session remembers about itself.
 */
class PreviewGuardTest {

    // ── Re-show guard: the four close reasons (three + none) ─────────────────

    @Test
    fun closedByTheViewerIsNotShownAgainOnTheSameScreen() {
        assertEquals(HostVisit.CLOSED_BY_VIEWER, ShoplivePreviewWindow.onHostVisible(false, ShopliveCloseReason.USER_ACTION, otherSessionOngoing = false, isFirstVisit = false))
    }

    @Test
    fun closedByTheAppIsShownAgain() {
        assertEquals(HostVisit.START, ShoplivePreviewWindow.onHostVisible(false, ShopliveCloseReason.APP_REQUEST, otherSessionOngoing = false, isFirstVisit = false))
    }

    @Test
    fun closedByAnAccessKeyChangeIsShownAgain() {
        assertEquals(HostVisit.START, ShoplivePreviewWindow.onHostVisible(false, ShopliveCloseReason.ACCESS_KEY_CHANGED, otherSessionOngoing = false, isFirstVisit = false))
    }

    /** Nothing known (first visit, or no reason recorded) never blocks. */
    @Test
    fun noReasonIsShownAgain() {
        assertEquals(HostVisit.START, ShoplivePreviewWindow.onHostVisible(false, null, otherSessionOngoing = false, isFirstVisit = false))
    }

    /** Coming back (rotation, returning from full screen) must not start a second one. */
    @Test
    fun aRunningPreviewIsNotStartedAgain() {
        ShopliveCloseReason.entries.forEach { reason ->
            assertEquals(HostVisit.ALREADY_SHOWING, ShoplivePreviewWindow.onHostVisible(true, reason, otherSessionOngoing = false, isFirstVisit = false))
        }
        assertEquals(HostVisit.ALREADY_SHOWING, ShoplivePreviewWindow.onHostVisible(true, null, otherSessionOngoing = false, isFirstVisit = false))
    }

    /**
     * Another session is playing (a PIP from the options-tab replay, say): starting a
     * preview would close it, so the page only logs (S54, code cross-check R1 X2).
     */
    @Test
    fun anotherOngoingSessionIsNotReplaced() {
        listOf(null, ShopliveCloseReason.APP_REQUEST, ShopliveCloseReason.ACCESS_KEY_CHANGED).forEach { reason ->
            assertEquals(
                HostVisit.OTHER_SESSION_ONGOING,
                ShoplivePreviewWindow.onHostVisible(false, reason, otherSessionOngoing = true, isFirstVisit = false),
            )
        }
        // This page's own preview still showing wins: nothing to do either way.
        assertEquals(
            HostVisit.ALREADY_SHOWING,
            ShoplivePreviewWindow.onHostVisible(true, null, otherSessionOngoing = true, isFirstVisit = false),
        )
    }

    /**
     * The other-session rule is for coming back to the page only. Tapping the card is
     * a start like any other card — the SDK closes the previous session.
     */
    @Test
    fun firstVisitStartsEvenWhileAnotherSessionIsOngoing() {
        assertEquals(
            HostVisit.START,
            ShoplivePreviewWindow.onHostVisible(false, null, otherSessionOngoing = true, isFirstVisit = true),
        )
    }

    @Test
    fun revisitSkipsWhileAnotherSessionIsOngoing() {
        assertEquals(
            HostVisit.OTHER_SESSION_ONGOING,
            ShoplivePreviewWindow.onHostVisible(false, null, otherSessionOngoing = true, isFirstVisit = false),
        )
    }

    // ── "Still showing" — what keeps the guards closed ───────────────────────

    /**
     * Only a session that is starting or showing a stream holds a page's guard. Idle
     * (never started, start refused, ended) and Closed release it, so a failed start
     * cannot lock the page for good (pair review R1 A2).
     */
    @Test
    fun onlyStartingOrShowingStatesCountAsOngoing() {
        assertTrue(ShoplivePlayerState.Loading.isOngoing)
        assertTrue(ShoplivePlayerState.Playing.isOngoing)
        assertTrue(ShoplivePlayerState.Paused.isOngoing)
        assertTrue(ShoplivePlayerState.InAppPIP.isOngoing)
        assertFalse(ShoplivePlayerState.Idle.isOngoing)
        ShopliveCloseReason.entries.forEach { reason ->
            assertFalse(ShoplivePlayerState.Closed(reason).isOngoing)
        }
    }

    // ── Session facts ────────────────────────────────────────────────────────

    private class FakePlayer(var inPip: Boolean)

    private fun player(fake: FakePlayer): ShoplivePlayerControlling = Proxy.newProxyInstance(
        ShoplivePlayerControlling::class.java.classLoader,
        arrayOf(ShoplivePlayerControlling::class.java),
    ) { proxy, method, args ->
        when (method.name) {
            "isInPictureInPicture" -> fake.inPip
            "equals" -> proxy === args?.get(0)
            "hashCode" -> System.identityHashCode(proxy)
            "toString" -> "FakePlayer"
            else -> null
        }
    } as ShoplivePlayerControlling

    private val forwarded = mutableListOf<ShoplivePlayerEvent>()
    private val inner = object : ShoplivePlayerDelegate {
        override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
            forwarded += event
        }
    }

    private fun state(s: ShoplivePlayerState) = ShoplivePlayerEvent.StateChanged(s)

    @Test
    fun startingInTheSmallWindowIsNotExpanding() {
        val fake = FakePlayer(inPip = true)
        val p = player(fake)
        val session = ShoplivePreviewWindow.Session(inner)
        session.onEvent(p, state(ShoplivePlayerState.Loading))
        session.onEvent(p, state(ShoplivePlayerState.InAppPIP))
        // Still in the small window while the stream starts playing.
        session.onEvent(p, state(ShoplivePlayerState.Playing))
        assertFalse(session.wasExpanded)
    }

    @Test
    fun leavingTheSmallWindowForPlaybackIsExpanding() {
        val fake = FakePlayer(inPip = true)
        val p = player(fake)
        val session = ShoplivePreviewWindow.Session(inner)
        session.onEvent(p, state(ShoplivePlayerState.InAppPIP))
        fake.inPip = false
        session.onEvent(p, state(ShoplivePlayerState.Loading))
        session.onEvent(p, state(ShoplivePlayerState.Playing))
        assertTrue(session.wasExpanded)
    }

    @Test
    fun theCloseReasonIsRemembered() {
        val p = player(FakePlayer(inPip = true))
        val session = ShoplivePreviewWindow.Session(inner)
        assertNull(session.closeReason)
        session.onEvent(p, state(ShoplivePlayerState.Closed(ShopliveCloseReason.USER_ACTION)))
        assertEquals(ShopliveCloseReason.USER_ACTION, session.closeReason)
    }

    @Test
    fun everyEventStillReachesTheWrappedDelegate() {
        val p = player(FakePlayer(inPip = true))
        val session = ShoplivePreviewWindow.Session(inner)
        val events = listOf(
            state(ShoplivePlayerState.InAppPIP),
            ShoplivePlayerEvent.CampaignStatusChanged(ShopliveCampaignStatus.READY),
        )
        events.forEach { session.onEvent(p, it) }
        assertEquals(events, forwarded)
        assertEquals(ShopliveCampaignStatus.READY, session.campaignStatus)
    }
}
