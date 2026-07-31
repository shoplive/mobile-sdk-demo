package cloud.shoplive.onboarding.data

import android.content.Context
import cloud.shoplive.onboarding.integration.ShopliveMilestone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The "verified" judgement. **Decided automatically from SDK events, not by the user
 * ticking a box.**
 *
 * Which mission is running is recorded first ([activeMission]); then when the events
 * coming out of the delegate satisfy that mission's success condition, it is marked
 * done. The rules live in [markPlaybackStarted], [markPipEntered],
 * [markRequestReceived] and [markBroadcastLive] and nowhere else.
 *
 * This whole class is demo harness — mission numbers mean nothing to a customer app.
 * It is fed by [record], which maps the milestones `:integration` reports onto the
 * demo's own idea of progress.
 */
class MissionProgress(context: Context) {

    private val prefs = context.getSharedPreferences("shoplive_demo_progress", Context.MODE_PRIVATE)

    private val _done = MutableStateFlow(load())
    val done: StateFlow<Set<Int>> = _done.asStateFlow()

    /** The mission currently running, which decides where an event is credited. */
    @Volatile
    var activeMission: Int? = null
        private set

    fun startMission(number: Int) {
        activeMission = number
    }

    /** Translates a copy-paste-layer milestone into this demo's progress rules. */
    fun record(milestone: ShopliveMilestone) = when (milestone) {
        ShopliveMilestone.PLAYBACK_STARTED -> markPlaybackStarted()
        ShopliveMilestone.IN_APP_PIP_ENTERED -> markPipEntered()
        ShopliveMilestone.REQUEST_RECEIVED -> markRequestReceived()
    }

    /** Playback started — the success condition for missions 1, 2, 3, 4 and 7. */
    fun markPlaybackStarted() {
        val active = activeMission ?: return
        if (active in setOf(1, 2, 3, 4, 7)) complete(active)
    }

    /** Entered in-app PIP — mission 5. Seeing PIP counts even during another mission. */
    fun markPipEntered() {
        complete(5)
    }

    /** A navigation or coupon request arrived — mission 6. */
    fun markRequestReceived() {
        complete(6)
    }

    /** The broadcast went LIVE — mission 8. */
    fun markBroadcastLive() {
        complete(8)
    }

    fun reset() {
        _done.value = emptySet()
        prefs.edit().remove(KEY).apply()
    }

    private fun complete(number: Int) {
        val current = _done.value
        if (number in current) return
        val next = current + number
        _done.value = next
        prefs.edit().putStringSet(KEY, next.map(Int::toString).toSet()).apply()
    }

    private fun load(): Set<Int> =
        prefs.getStringSet(KEY, emptySet()).orEmpty().mapNotNull(String::toIntOrNull).toSet()

    private companion object {
        const val KEY = "doneMissions"
    }
}
