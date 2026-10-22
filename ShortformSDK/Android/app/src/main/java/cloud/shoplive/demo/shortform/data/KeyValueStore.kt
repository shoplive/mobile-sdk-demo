package cloud.shoplive.demo.shortform.data

import android.content.SharedPreferences

/** The small slice of SharedPreferences the app uses, so stores can be tested on the JVM. */
interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
    fun remove(keys: Collection<String>)
    fun clear()
}

class SharedPreferencesStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun putString(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }

    override fun remove(keys: Collection<String>) {
        prefs.edit().apply { keys.forEach { remove(it) } }.apply()
    }

    override fun clear() {
        prefs.edit().clear().apply()
    }
}
