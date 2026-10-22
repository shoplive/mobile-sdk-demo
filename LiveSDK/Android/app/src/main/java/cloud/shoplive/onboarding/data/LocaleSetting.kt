package cloud.shoplive.onboarding.data

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import java.util.Locale

/**
 * The app's display language. **English by default**, and it does not follow the
 * device language.
 *
 * ## Why not follow the device
 * This demo is handed to customers in several countries. Following the device would
 * make it open only in Korean on a Korean phone, with no way to see how the English
 * or Japanese screens look. So English is pinned as the default and all three
 * languages can be switched inside the app.
 *
 * ## How
 * Not through per-app language settings (`LocaleManager`, Android 13+) but through
 * our own setting plus `attachBaseContext` — it has to behave **identically** down to
 * minSdk 24, and this avoids the system setting and the app setting overwriting each
 * other.
 *
 * Every Activity wraps with `attachBaseContext(LocaleSetting.wrap(newBase))`, and
 * string lookups outside Compose go through
 * [cloud.shoplive.onboarding.DemoContainer.string], which uses the same context.
 */
object LocaleSetting {

    /** Supported languages. The first is the default. */
    val supported: List<Language> = listOf(Language.EN, Language.KO, Language.JA)

    enum class Language(val tag: String, val label: String) {
        /** The default — `res/values/`, the fallback resources. */
        EN("en", "English"),
        KO("ko", "한국어"),
        JA("ja", "日本語"),
    }

    private const val PREFS = "shoplive_demo_locale"
    private const val KEY_TAG = "languageTag"

    @Volatile
    private var cached: Language = Language.EN

    private var appContext: Context? = null

    /** Called first thing by [cloud.shoplive.onboarding.DemoApplication]. */
    fun install(context: Context) {
        appContext = context.applicationContext
        val saved = context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TAG, null)
        cached = supported.firstOrNull { it.tag == saved } ?: Language.EN
    }

    val current: Language get() = cached

    /**
     * Changes the language. The caller redraws with `Activity.recreate()`, because
     * resources are resolved when the Activity is created.
     */
    fun set(language: Language) {
        cached = language
        appContext
            ?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            ?.edit()
            ?.putString(KEY_TAG, language.tag)
            ?.apply()
    }

    /** Builds a Context with the chosen language, for `attachBaseContext`. */
    fun wrap(base: Context): Context {
        val locale = Locale.forLanguageTag(cached.tag)
        val config = Configuration(base.resources.configuration)
        Locale.setDefault(locale)
        config.setLocale(locale)
        config.setLocales(LocaleList(locale))
        return base.createConfigurationContext(config)
    }
}
