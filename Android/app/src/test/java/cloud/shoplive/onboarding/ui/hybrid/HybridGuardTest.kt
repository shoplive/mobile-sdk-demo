package cloud.shoplive.onboarding.ui.hybrid

import cloud.shoplive.core.publicsurface.ShopliveError
import cloud.shoplive.core.publicsurface.ShopliveErrorCode
import cloud.shoplive.player.ShopliveCloseReason
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerState
import org.junit.Assert.assertEquals
import org.junit.Test
import java.lang.reflect.Proxy

/**
 * The hybrid page's double-tap guard (SMV-1922 S11 / S53, code cross-check R1 X1).
 * A full-screen start() only launches an Activity, so the player stays Idle for a
 * moment — that window must be locked too, and released by the page's own session
 * leaving Idle, closing or failing.
 */
class HybridGuardTest {

    private class Fake(var state: ShoplivePlayerState = ShoplivePlayerState.Idle)

    private fun player(fake: Fake): ShoplivePlayerControlling = Proxy.newProxyInstance(
        ShoplivePlayerControlling::class.java.classLoader,
        arrayOf(ShoplivePlayerControlling::class.java),
    ) { proxy, method, args ->
        when (method.name) {
            "getState" -> fake.state
            "equals" -> proxy === args?.get(0)
            "hashCode" -> System.identityHashCode(proxy)
            "toString" -> "FakePlayer"
            else -> null
        }
    } as ShoplivePlayerControlling

    private val noop = object : ShoplivePlayerDelegate {}
    private val vm = HybridViewModel()
    private val starts = mutableListOf<Pair<ShoplivePlayerControlling, ShoplivePlayerDelegate>>()
    private val fakes = mutableListOf<Fake>()

    /** One web-card tap. Each real start gets a new fake player. */
    private fun tap() = vm.onCampaignKey("campaign") { _, wrap ->
        val fake = Fake().also { fakes += it }
        val p = player(fake)
        p.also { starts += it to wrap(noop) }
    }

    private fun send(index: Int, state: ShoplivePlayerState) {
        fakes[index].state = state
        val (p, delegate) = starts[index]
        delegate.onEvent(p, ShoplivePlayerEvent.StateChanged(state))
    }

    private fun error(index: Int, recoverable: Boolean) {
        val (p, delegate) = starts[index]
        val e = ShopliveError(ShopliveErrorCode.AUTHENTICATION_FAILED, 0, "test", null, recoverable)
        delegate.onEvent(p, ShoplivePlayerEvent.Error(e))
    }

    @Test
    fun tapsWhileTheStartIsStillIdleAreIgnored() {
        tap()
        tap()
        tap()
        assertEquals(1, starts.size)
    }

    @Test
    fun leavingIdleHandsOverToTheShowingGuard() {
        tap()
        send(0, ShoplivePlayerState.Loading)
        tap()
        send(0, ShoplivePlayerState.Playing)
        tap()
        assertEquals(1, starts.size)

        send(0, ShoplivePlayerState.Closed(ShopliveCloseReason.USER_ACTION))
        tap()
        assertEquals(2, starts.size)
    }

    @Test
    fun anUnrecoverableErrorReleasesTheStartingLock() {
        tap()
        error(0, recoverable = false)
        tap()
        assertEquals(2, starts.size)
    }

    @Test
    fun aRecoverableErrorDoesNot() {
        tap()
        error(0, recoverable = true)
        tap()
        assertEquals(1, starts.size)
    }

    /** A late event from an older start must not unlock a newer one (stale token). */
    @Test
    fun anOlderSessionsLateEventIsIgnored() {
        tap()
        send(0, ShoplivePlayerState.Closed(ShopliveCloseReason.APP_REQUEST))
        tap()
        assertEquals(2, starts.size)

        error(0, recoverable = false)
        send(0, ShoplivePlayerState.Loading)
        tap()
        assertEquals(2, starts.size)
    }
}
