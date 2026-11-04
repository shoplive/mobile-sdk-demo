package cloud.shoplive.onboarding.data

import android.content.Context
import cloud.shoplive.onboarding.integration.ShopliveMilestone
import cloud.shoplive.player.ShoplivePlayerControlling
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.getAndUpdate
import java.lang.ref.WeakReference

/**
 * The "verified" judgement. **Decided automatically from SDK events, not by the user
 * ticking a box.**
 *
 * Every start path calls [startMission] first: it records which mission is running
 * and which player that mission started (the owner). When a milestone arrives,
 * [creditFor] decides which mission — if any — it completes. That function is the
 * only place the rules live (SMV-1922 contract 5 and 6).
 *
 * This whole class is demo harness — mission identifiers mean nothing to a customer
 * app. It is fed by [record], which maps the milestones `:integration` reports onto
 * the demo's own idea of progress. Storage, judgement and display state stay
 * together on purpose: there is one implementation and one screen reading it.
 */
class MissionProgress(context: Context) {

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _done = MutableStateFlow(loadAndMigrate())
    val done: StateFlow<Set<MissionId>> = _done.asStateFlow()

    /** The mission currently running, which decides where an event is credited. */
    @Volatile
    var activeMission: MissionId? = null
        private set

    /**
     * The player [activeMission] started. Weak on purpose: a full-screen player holds
     * its view, and that view holds the Activity it was created with — this object
     * lives for the whole process. While the session runs, the SDK and
     * `ShoplivePlayerSession` keep it alive; a cleared reference (the reference is
     * set, `get()` is null) is logged apart from "never recorded" in [record].
     */
    @Volatile
    private var owner: WeakReference<ShoplivePlayerControlling>? = null

    /**
     * The player the nudge mission last started. Its PIP is the nudge's own small
     * window, never the PIP mission — even after another mission became active.
     */
    @Volatile
    private var lastNudge: WeakReference<ShoplivePlayerControlling>? = null

    // ── Start paths ──────────────────────────────────────────────────────────

    /** For runs that never hand back a player (the studio). Clears the owner. */
    fun startMission(id: MissionId) {
        activeMission = id
        owner = null
    }

    /**
     * Records [id] as running **before** [start] runs, then remembers the player it
     * returned as the owner. Doing both here keeps the order fixed: an event raised
     * while the player is still starting is judged against the right mission.
     */
    fun <P : ShoplivePlayerControlling> startMission(id: MissionId, start: () -> P): P {
        startMission(id)
        val player = start()
        owner = WeakReference(player)
        if (id == MissionId.NUDGE) lastNudge = WeakReference(player)
        return player
    }

    // ── Judgement ────────────────────────────────────────────────────────────

    /** Translates a copy-paste-layer milestone into this demo's progress rules. */
    fun record(milestone: ShopliveMilestone, player: ShoplivePlayerControlling) {
        val active = activeMission
        val ownerRef = owner
        val ownerPlayer = ownerRef?.get()
        val credited = creditFor(milestone, player, active, ownerPlayer, lastNudge?.get())
        if (credited != null) {
            complete(credited)
            return
        }
        // Say why a success signal was not credited, so a missing tick is explainable.
        when {
            milestone == ShopliveMilestone.PLAYBACK_STARTED && active in PLAYBACK_MISSIONS -> when {
                ownerRef == null ->
                    DemoLog.error("progress: playback reached during \"${active?.raw}\" but no owning player was recorded — not credited")

                ownerPlayer == null ->
                    DemoLog.error("progress: playback reached during \"${active?.raw}\" but the owning player reference was released — not credited")

                else ->
                    DemoLog.event("progress: playback during \"${active?.raw}\" — sender is not the owner, ignored")
            }

            milestone == ShopliveMilestone.IN_APP_PIP_ENTERED ->
                DemoLog.event("progress: in-App PIP of the nudge session — not the PIP mission")

            else -> Unit
        }
    }

    /** The broadcast went LIVE. */
    fun markBroadcastLive() {
        complete(MissionId.STUDIO)
    }

    /**
     * Clears both keys — an old key left behind would be migrated back next launch.
     * `commit()` rather than `apply()` because a failed delete must be reported (S40);
     * it is a user action on a tiny file.
     */
    fun reset() {
        _done.value = emptySet()
        val saved = prefs.edit().remove(KEY).remove(LEGACY_KEY).commit()
        if (!saved) {
            DemoLog.error("progress: reset could not be saved — the old record may come back on the next launch")
        }
    }

    private fun complete(id: MissionId) {
        val before = _done.getAndUpdate { it + id }
        if (id in before) return
        prefs.edit().putStringSet(KEY, _done.value.mapTo(mutableSetOf()) { it.raw }).apply()
    }

    // ── Storage and migration ────────────────────────────────────────────────

    /**
     * Reads both keys, migrates, and writes the result **in one commit** together with
     * removing the old key — there is no moment where only one of them is updated. If
     * the old key cannot be read it is left alone so the next launch can try again.
     *
     * Runs on the main thread at app start (via `DemoContainer.install`). Accepted:
     * the file holds one small string set, and the synchronous `commit()` only happens
     * when there is something to migrate or drop — once, on the first launch after
     * an update. `commit()` is needed to know the write landed before the old key is
     * considered gone.
     */
    private fun loadAndMigrate(): Set<MissionId> {
        var legacyReadable = true
        val legacy = try {
            prefs.getStringSet(LEGACY_KEY, null)?.toSet()
        } catch (e: ClassCastException) {
            legacyReadable = false
            DemoLog.error("progress: \"$LEGACY_KEY\" is not a string set (${e.message}) — migration skipped, the old key is kept for the next launch")
            null
        }
        val stored = try {
            prefs.getStringSet(KEY, null)?.toSet()
        } catch (e: ClassCastException) {
            DemoLog.error("progress: \"$KEY\" is not a string set (${e.message}) — starting from what could be read")
            null
        }

        val result = migrate(legacy, stored)
        if (result.dropped.isNotEmpty()) {
            DemoLog.error("progress: dropped values that name no mission: ${result.dropped}")
        }
        if (result.needsWrite) {
            val editor = prefs.edit().putStringSet(KEY, result.storedValues)
            if (legacyReadable) editor.remove(LEGACY_KEY)
            if (!editor.commit()) {
                DemoLog.error("progress: saving migrated progress failed — the old key stays and migration reruns next launch")
            }
        }
        return result.ids
    }

    /** The outcome of reading stored progress. [needsWrite] is false when nothing changes. */
    data class Migration(
        val ids: Set<MissionId>,
        /** Values that named no mission. Logged, then gone for good. */
        val dropped: List<String>,
        val needsWrite: Boolean,
    ) {
        val storedValues: Set<String> get() = ids.mapTo(mutableSetOf()) { it.raw }
    }

    companion object {
        const val PREFS_NAME = "shoplive_demo_progress"

        /** Same string on iOS (UserDefaults). */
        const val KEY = "demo.completedMissionIds"

        /** Builds before SMV-1922 stored the 8-mission guide numbers here. */
        const val LEGACY_KEY = "doneMissions"

        /**
         * Old guide number -> the same feature today. Frozen: it describes what old
         * builds wrote, not the current order. The nudge is new and has no entry.
         */
        private val LEGACY_NUMBERS: Map<Int, MissionId> = mapOf(
            1 to MissionId.PLAYER,
            2 to MissionId.DEEPLINK,
            3 to MissionId.USER,
            4 to MissionId.INLINE,
            5 to MissionId.PIP,
            6 to MissionId.EVENTS,
            7 to MissionId.UI,
            8 to MissionId.STUDIO,
        )

        /** Missions whose success signal is "playback reached". */
        private val PLAYBACK_MISSIONS: Set<MissionId> = setOf(
            MissionId.PLAYER,
            MissionId.NUDGE,
            MissionId.DEEPLINK,
            MissionId.USER,
            MissionId.INLINE,
            MissionId.UI,
        )

        /**
         * Old numbers and new identifiers in, one identifier set out. Union of both, so
         * a run interrupted after writing the new key and before deleting the old one
         * converges to the same set; anything that names no mission is dropped rather
         * than guessed (crediting a wrong mission is worse than losing a tick).
         */
        fun migrate(legacy: Set<String>?, stored: Set<String>?): Migration {
            val dropped = mutableListOf<String>()
            val fromStored = stored.orEmpty().mapNotNull { raw ->
                MissionId.fromRaw(raw) ?: null.also { dropped += raw }
            }
            val fromLegacy = legacy.orEmpty().mapNotNull { value ->
                value.toIntOrNull()?.let(LEGACY_NUMBERS::get) ?: null.also { dropped += value }
            }
            return Migration(
                ids = (fromStored + fromLegacy).toSet(),
                dropped = dropped,
                needsWrite = legacy != null || dropped.isNotEmpty(),
            )
        }

        /**
         * Which mission [milestone] completes, or null.
         *
         * - Playback reached: the running mission, if it is a playback mission **and**
         *   [sender] is the player it started. No owner, no credit.
         * - In-App PIP entered: the PIP mission, from any session — except the nudge
         *   session's: the last nudge player ([nudge]) whatever runs now, and anything
         *   while the nudge mission is still starting (no owner yet).
         * - A navigation / coupon / custom request: the events mission, any session.
         */
        fun creditFor(
            milestone: ShopliveMilestone,
            sender: ShoplivePlayerControlling,
            active: MissionId?,
            owner: ShoplivePlayerControlling?,
            nudge: ShoplivePlayerControlling? = null,
        ): MissionId? = when (milestone) {
            // TODO(SDP-VERIFY): 요확인 — S51 delegate가 넘기는 player가 Launcher·startMission이 돌려준 객체와 같은지(이 === 비교들의 전제) 실기기 확인, 다르면 재생 도달 완료가 기록되지 않음 · 근거 SMV-1922 S51
            ShopliveMilestone.PLAYBACK_STARTED ->
                active?.takeIf { it in PLAYBACK_MISSIONS && owner != null && sender === owner }

            ShopliveMilestone.IN_APP_PIP_ENTERED -> when {
                nudge != null && sender === nudge -> null
                active == MissionId.NUDGE && (owner == null || sender === owner) -> null
                else -> MissionId.PIP
            }

            ShopliveMilestone.REQUEST_RECEIVED -> MissionId.EVENTS
        }
    }
}
