package cloud.shoplive.onboarding.data

import cloud.shoplive.onboarding.integration.ShopliveMilestone
import cloud.shoplive.player.ShoplivePlayerControlling
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.lang.reflect.Proxy

/**
 * Which milestone completes which mission (SMV-1922 contract 5 and 6, cases S26 / S27
 * / U05). Credit goes to the running mission, and playback only counts when it comes
 * from the player that mission started.
 */
class MissionProgressRuleTest {

    private fun player(): ShoplivePlayerControlling = Proxy.newProxyInstance(
        ShoplivePlayerControlling::class.java.classLoader,
        arrayOf(ShoplivePlayerControlling::class.java),
    ) { proxy, method, args ->
        when (method.name) {
            "equals" -> proxy === args?.get(0)
            "hashCode" -> System.identityHashCode(proxy)
            "toString" -> "FakePlayer"
            else -> null
        }
    } as ShoplivePlayerControlling

    private val owner = player()
    private val other = player()

    @Test
    fun playbackFromTheOwnerCompletesTheRunningMission() {
        val playbackMissions = listOf(
            MissionId.PLAYER, MissionId.NUDGE, MissionId.DEEPLINK,
            MissionId.USER, MissionId.INLINE, MissionId.UI,
        )
        playbackMissions.forEach { active ->
            assertEquals(
                active,
                MissionProgress.creditFor(ShopliveMilestone.PLAYBACK_STARTED, owner, active, owner),
            )
        }
    }

    /** A covered feed embed still rendering must not complete the deep-link mission. */
    @Test
    fun playbackFromAnotherPlayerIsIgnored() {
        assertNull(
            MissionProgress.creditFor(ShopliveMilestone.PLAYBACK_STARTED, other, MissionId.DEEPLINK, owner),
        )
    }

    /** No owner recorded means a start path forgot it — undone is safer than misplaced. */
    @Test
    fun playbackWithoutAnOwnerIsIgnored() {
        assertNull(
            MissionProgress.creditFor(ShopliveMilestone.PLAYBACK_STARTED, owner, MissionId.PLAYER, null),
        )
    }

    @Test
    fun playbackDoesNotCompleteMissionsWithOtherSuccessSignals() {
        listOf(MissionId.PIP, MissionId.EVENTS, MissionId.STUDIO).forEach { active ->
            assertNull(MissionProgress.creditFor(ShopliveMilestone.PLAYBACK_STARTED, owner, active, owner))
        }
        assertNull(MissionProgress.creditFor(ShopliveMilestone.PLAYBACK_STARTED, owner, null, owner))
    }

    @Test
    fun inAppPipCompletesPipDuringAnyMission() {
        assertEquals(
            MissionId.PIP,
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, other, MissionId.PLAYER, owner),
        )
        assertEquals(
            MissionId.PIP,
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, other, null, null),
        )
    }

    /** E1: the nudge's own small window is not "keep watching in PIP". */
    @Test
    fun nudgeSessionPipIsNotPipCompletion() {
        assertNull(
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, owner, MissionId.NUDGE, owner),
        )
        // Arriving while the nudge is still being started (owner not known yet).
        assertNull(
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, owner, MissionId.NUDGE, null),
        )
        // Another session entering PIP while the nudge mission is current still counts.
        assertEquals(
            MissionId.PIP,
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, other, MissionId.NUDGE, owner),
        )
    }

    /**
     * Contract 5 says "not the nudge session", not "not while the nudge mission runs":
     * the last nudge player's PIP never completes PIP, whatever runs now (R1 X4).
     */
    @Test
    fun theNudgePlayersPipIsExcludedWhateverMissionRuns() {
        val nudge = player()
        listOf(MissionId.PLAYER, MissionId.PIP, MissionId.INLINE, null).forEach { active ->
            assertNull(
                MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, nudge, active, owner, nudge = nudge),
            )
        }
        assertEquals(
            MissionId.PIP,
            MissionProgress.creditFor(ShopliveMilestone.IN_APP_PIP_ENTERED, other, MissionId.PLAYER, owner, nudge = nudge),
        )
    }

    @Test
    fun requestsCompleteEventsRegardlessOfSession() {
        assertEquals(
            MissionId.EVENTS,
            MissionProgress.creditFor(ShopliveMilestone.REQUEST_RECEIVED, other, MissionId.STUDIO, owner),
        )
        assertEquals(
            MissionId.EVENTS,
            MissionProgress.creditFor(ShopliveMilestone.REQUEST_RECEIVED, other, null, null),
        )
    }
}
