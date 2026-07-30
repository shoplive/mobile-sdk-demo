package cloud.shoplive.onboarding.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * "확인됨" 판정. **사용자가 체크하는 것이 아니라 SDK 이벤트로 자동 판정**한다.
 *
 * 어느 미션을 실행 중인지([activeMission])를 먼저 기록해 두고, 델리게이트에서 올라오는
 * 이벤트가 그 미션의 성공 조건을 만족할 때 완료로 넘긴다. 판정 규칙은
 * [markPlaybackStarted] · [markPipEntered] · [markRequestReceived] · [markBroadcastLive]
 * 네 곳에만 있다.
 */
class MissionProgress(context: Context) {

    private val prefs = context.getSharedPreferences("shoplive_demo_progress", Context.MODE_PRIVATE)

    private val _done = MutableStateFlow(load())
    val done: StateFlow<Set<Int>> = _done.asStateFlow()

    /** 지금 실행 중인 미션 번호. 이벤트를 어느 미션에 귀속시킬지 정한다. */
    @Volatile
    var activeMission: Int? = null
        private set

    fun startMission(number: Int) {
        activeMission = number
    }

    /** 재생이 시작됐다 → 미션 1·2·3·4·7 의 성공 조건. */
    fun markPlaybackStarted() {
        val active = activeMission ?: return
        if (active in setOf(1, 2, 3, 4, 7)) complete(active)
    }

    /** in-App PIP 진입 → 미션 5. 다른 미션 중이어도 PIP 를 봤으면 5는 확인된 것으로 본다. */
    fun markPipEntered() {
        complete(5)
    }

    /** navigation·coupon 요청 수신 → 미션 6. */
    fun markRequestReceived() {
        complete(6)
    }

    /** 방송이 LIVE 로 전이 → 미션 8. */
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
