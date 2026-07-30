package cloud.shoplive.onboarding.data

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import java.util.Locale

/**
 * 앱 표시 언어. **기본값은 영어**이고, 기기 언어를 따라가지 않는다.
 *
 * ## 왜 기기 언어를 따르지 않나
 * 이 데모앱은 여러 국가의 고객사에 그대로 전달된다. 기기 언어를 따르면 한국 기기에서는
 * 한국어로만 열려서, 영어·일본어 화면이 어떻게 보이는지 확인할 방법이 없다. 그래서
 * **영어를 기본으로 고정**하고 앱 안에서 3개 언어를 즉시 바꿀 수 있게 했다.
 *
 * ## 구현 방식
 * 안드로이드 13+ 의 앱별 언어 설정(`LocaleManager`)을 쓰지 않고 자체 설정 + `attachBaseContext`
 * 로 처리한다 — minSdk 24 까지 **동일하게** 동작해야 하고, 시스템 설정과 앱 설정이 서로
 * 덮어쓰는 상황을 피하기 위해서다.
 *
 * 각 Activity 는 `attachBaseContext(LocaleSetting.wrap(newBase))` 로 감싸고, Compose 밖에서
 * 문자열을 읽는 경로는 [cloud.shoplive.onboarding.DemoContainer.string] 이 같은 컨텍스트를 쓴다.
 */
object LocaleSetting {

    /** 지원 언어. 첫 번째가 기본값이다. */
    val supported: List<Language> = listOf(Language.EN, Language.KO, Language.JA)

    enum class Language(val tag: String, val label: String) {
        /** 기본값 — `res/values/` (폴백 리소스). */
        EN("en", "English"),
        KO("ko", "한국어"),
        JA("ja", "日本語"),
    }

    private const val PREFS = "shoplive_demo_locale"
    private const val KEY_TAG = "languageTag"

    @Volatile
    private var cached: Language = Language.EN

    private var appContext: Context? = null

    /** [cloud.shoplive.onboarding.DemoApplication] 이 가장 먼저 호출한다. */
    fun install(context: Context) {
        appContext = context.applicationContext
        val saved = context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TAG, null)
        cached = supported.firstOrNull { it.tag == saved } ?: Language.EN
    }

    val current: Language get() = cached

    /**
     * 언어를 바꾼다. 화면은 호출한 쪽에서 `Activity.recreate()` 로 다시 그린다 —
     * 리소스는 Activity 생성 시점에 확정되기 때문이다.
     */
    fun set(language: Language) {
        cached = language
        appContext
            ?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            ?.edit()
            ?.putString(KEY_TAG, language.tag)
            ?.apply()
    }

    /** 선택된 언어가 적용된 Context 를 만든다. Activity 의 `attachBaseContext` 에서 쓴다. */
    fun wrap(base: Context): Context {
        val locale = Locale.forLanguageTag(cached.tag)
        val config = Configuration(base.resources.configuration)
        Locale.setDefault(locale)
        config.setLocale(locale)
        config.setLocales(LocaleList(locale))
        return base.createConfigurationContext(config)
    }
}
