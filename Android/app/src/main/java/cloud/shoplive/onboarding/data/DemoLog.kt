package cloud.shoplive.onboarding.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 개발자 시트(V1) "이벤트 로그" 탭이 읽는 프로세스 전역 로그.
 *
 * SDK 플레이어·스튜디오 화면이 앞에 떠 있는 동안에도 이벤트는 계속 도착한다. 데모앱은
 * 그 화면 위에 UI 를 얹을 수 없으므로(SDK 소유 Activity), 로그를 여기에 모아 두고 앱
 * 화면으로 돌아온 뒤 확인한다.
 *
 * ## 왜 상한과 합치기가 필요한가
 * `Playback(Rendering(..))` 은 재생 중 **초당 1회** 올라온다. 그냥 쌓으면 몇 분 만에
 * 수백 줄이 되어 로그가 쓸모없어진다. 그래서 (1) 최대 [MAX_ENTRIES] 줄로 자르고
 * (2) 같은 반복 이벤트가 연속으로 오면 새 줄을 만들지 않고 카운터를 올린다.
 */
object DemoLog {

    private const val MAX_ENTRIES = 300

    enum class Kind {
        /** SDK → 앱 통지 (`ShoplivePlayerDelegate.onEvent`) */
        EVENT,

        /** SDK → 앱 요청 (`onRequest`). 앱이 응답해야 한다. */
        REQUEST,

        /** 요청에 대한 앱의 응답 (`respond(...)` 호출). */
        RESPOND,

        /** 앱 → SDK 호출 (initialize / setUser / start / play …). */
        SDK_CALL,

        /** 오류. */
        ERROR,
    }

    data class Entry(
        val kind: Kind,
        val message: String,
        val timeText: String,
        /** 같은 메시지가 연속으로 반복된 횟수. 1이면 표시하지 않는다. */
        val repeated: Int = 1,
    )

    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.US)

    private val _entries = MutableStateFlow<List<Entry>>(emptyList())

    /** 최신이 앞(index 0)에 온다. */
    val entries: StateFlow<List<Entry>> = _entries.asStateFlow()

    fun event(message: String) = add(Kind.EVENT, message)
    fun request(message: String) = add(Kind.REQUEST, message)
    fun respond(message: String) = add(Kind.RESPOND, message)
    fun sdkCall(message: String) = add(Kind.SDK_CALL, message)
    fun error(message: String) = add(Kind.ERROR, message)

    @Synchronized
    private fun add(kind: Kind, message: String) {
        val current = _entries.value
        val head = current.firstOrNull()

        // 같은 종류·같은 문구가 연속으로 오면 줄을 늘리지 않고 횟수만 올린다.
        if (head != null && head.kind == kind && head.message == message) {
            _entries.value = current.toMutableList().apply {
                this[0] = head.copy(timeText = now(), repeated = head.repeated + 1)
            }
            return
        }

        val next = ArrayList<Entry>(minOf(current.size + 1, MAX_ENTRIES))
        next.add(Entry(kind, message, now()))
        next.addAll(current.take(MAX_ENTRIES - 1))
        _entries.value = next
    }

    @Synchronized
    fun clear() {
        _entries.value = emptyList()
    }

    /** 로그 복사용 평문. */
    fun asPlainText(): String = _entries.value.joinToString("\n") { entry ->
        val times = if (entry.repeated > 1) " (x${entry.repeated})" else ""
        "[${entry.timeText}] ${entry.kind.name} ${entry.message}$times"
    }

    private fun now(): String = timeFormat.format(Date())

    /**
     * 키·토큰을 로그에 남길 때 앞 8자만 노출한다.
     *
     * 로그 복사 기능이 있으므로 원문을 남기면 그대로 밖으로 나간다.
     */
    fun mask(secret: String?): String = when {
        secret.isNullOrBlank() -> "(none)"
        secret.length <= 8 -> "$secret…"
        else -> "${secret.take(8)}…"
    }
}
