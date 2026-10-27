package cloud.shoplive.demo.shortform.shortform

import java.util.concurrent.CopyOnWriteArrayList

/** In-memory log of Shortform SDK callbacks, shown in Settings → SDK event log. */
object EventLog {
    data class Entry(val timeMillis: Long, val name: String, val detail: String)

    private const val MAX_ENTRIES = 300
    private const val MAX_DETAIL = 400

    private val entries = CopyOnWriteArrayList<Entry>()
    private val listeners = CopyOnWriteArrayList<() -> Unit>()

    fun add(name: String, detail: String = "") {
        entries.add(0, Entry(System.currentTimeMillis(), name, detail.take(MAX_DETAIL)))
        while (entries.size > MAX_ENTRIES) entries.removeAt(entries.size - 1)
        listeners.forEach { it() }
    }

    fun all(): List<Entry> = entries.toList()

    fun clear() {
        entries.clear()
        listeners.forEach { it() }
    }

    fun addListener(listener: () -> Unit) = listeners.add(listener)
    fun removeListener(listener: () -> Unit) = listeners.remove(listener)
}
