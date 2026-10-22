package cloud.shoplive.onboarding.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The process-wide log that the developer sheet's "event log" tab reads.
 *
 * This is the demo's own logger — `:integration` never calls it directly. It arrives
 * here through `DemoLogBridge`, which installs it as the `shopliveLog` sink.
 *
 * Events keep arriving while the SDK's player or studio screen is in front, and the
 * demo cannot draw on top of an SDK-owned Activity, so they are collected here and
 * read after coming back.
 *
 * ## Why a cap and a coalescing rule are needed
 * `Playback(Rendering(..))` arrives **once per second** during playback. Appending
 * blindly gives hundreds of lines within minutes and the log stops being useful.
 * So (1) it is truncated to [MAX_ENTRIES] lines, and (2) an identical event repeated
 * back-to-back bumps a counter instead of adding a line.
 */
object DemoLog {

    private const val MAX_ENTRIES = 300

    enum class Kind {
        /** SDK -> app notification (`ShoplivePlayerDelegate.onEvent`). */
        EVENT,

        /** SDK -> app request (`onRequest`), which the app has to answer. */
        REQUEST,

        /** The app's answer to a request (a `respond(...)` call). */
        RESPOND,

        /** App -> SDK call (initialize / setUser / start / play ...). */
        SDK_CALL,

        /** A failure. */
        ERROR,
    }

    data class Entry(
        val kind: Kind,
        val message: String,
        val timeText: String,
        /** How many times this same message repeated in a row. 1 is not shown. */
        val repeated: Int = 1,
    )

    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.US)

    private val _entries = MutableStateFlow<List<Entry>>(emptyList())

    /** Newest first (index 0). */
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

        // Same kind and same text in a row: bump the count instead of adding a line.
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

    /** Plain text, for the copy button. */
    fun asPlainText(): String = _entries.value.joinToString("\n") { entry ->
        val times = if (entry.repeated > 1) " (x${entry.repeated})" else ""
        "[${entry.timeText}] ${entry.kind.name} ${entry.message}$times"
    }

    private fun now(): String = timeFormat.format(Date())

    /**
     * Shows only the first 8 characters of a key or token.
     *
     * The log has a copy button, so anything written in full leaves the device in
     * full. Mirrors `shopliveMasked` in the copy-paste layer.
     */
    fun mask(secret: String?): String = when {
        secret.isNullOrBlank() -> "(none)"
        secret.length <= 8 -> "$secret…"
        else -> "${secret.take(8)}…"
    }
}
