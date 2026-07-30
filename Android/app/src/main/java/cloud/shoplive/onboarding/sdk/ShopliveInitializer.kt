package cloud.shoplive.onboarding.sdk

import android.content.Context
import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.core.publicsurface.ShopliveAttribution
import cloud.shoplive.core.publicsurface.ShopliveConfiguration
import cloud.shoplive.onboarding.DemoContainer
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog

/**
 * SDK 초기화 — 앱 전체에서 **한 번** 하는 일.
 *
 * ```kotlin
 * Shoplive.initialize(context, ShopliveConfiguration(accessKey = "{ACCESS_KEY}"))
 * ```
 *
 * 보통 `Application.onCreate()` 에 둔다. 딥링크로 콜드 스타트하는 경로(Mission 2)에서도
 * 플레이어를 띄우기 전에 초기화가 끝나 있어야 하기 때문이다.
 *
 * 계정을 바꿀 때는 [Shoplive.initialize] 를 다시 부르면 된다(accessKey 는 마지막 값이 이긴다).
 * 다만 신원까지 바꾸려면 [Shoplive.logout] 을 먼저 불러 인증 슬롯을 비워야 한다.
 */
object ShopliveInitializer {

    @Volatile
    private var initializedAccessKey: String? = null

    val isInitialized: Boolean get() = initializedAccessKey != null

    val currentAccessKey: String? get() = initializedAccessKey

    /**
     * @param allowedWebViewDomains 오버레이 웹뷰가 열 수 있는 도메인을 제한한다. 비우면 제한 없음.
     * @param attribution UTM 파라미터. **덮어쓰기(full replace)** 다 — 일부만 바꿀 수 없고,
     *   넘기지 않으면 기존 값이 유지된다.
     */
    fun initialize(
        context: Context,
        accessKey: String,
        allowedWebViewDomains: List<String> = emptyList(),
        attribution: ShopliveAttribution? = null,
    ) {
        Shoplive.initialize(
            context,
            ShopliveConfiguration(
                accessKey = accessKey,
                allowedWebViewDomains = allowedWebViewDomains,
                attribution = attribution,
            ),
        )
        initializedAccessKey = accessKey
        DemoLog.sdkCall("Shoplive.initialize(accessKey: \"${DemoLog.mask(accessKey)}\")")
        DemoLog.sdkCall("SDK version ${Shoplive.sdkVersion}")
    }

    /**
     * 아직 초기화되지 않았거나 accessKey 가 달라졌을 때만 다시 초기화한다.
     * 같은 키로 반복 호출하는 것은 무해하지만, 로그를 깨끗하게 두기 위한 가드다.
     */
    fun initializeIfNeeded(context: Context, accessKey: String) {
        if (accessKey.isBlank()) return
        if (initializedAccessKey == accessKey) return
        initialize(context, accessKey)
    }

    /**
     * 인증 신원을 해제한다 — user·auth token·stream token 3개 슬롯을 한 번에 비운다.
     * accessKey 와 UTM 은 유지된다. `setUser(Guest)` 는 이 일을 하지 **않는다**(no-op).
     */
    fun logout() {
        Shoplive.logout()
        DemoLog.sdkCall("Shoplive.logout() — cleared user/authToken/streamToken")
    }

    // ── 키 형식 사전 검증 ────────────────────────────────────────────────────
    //
    // SDK 에는 "이 키가 유효한가"를 미리 물어보는 API 가 없다(initialize 는 값만 저장한다).
    // 그래서 데모앱은 ① 형식만 로컬에서 걸러내고 ② 실제 유효성은 재생 시 도착하는
    // error 이벤트를 원인별 문장으로 번역해 보여준다(DemoPlayerDelegate.describe 참고).

    sealed interface Validation {
        data object Valid : Validation
        data class Invalid(val message: String) : Validation
    }

    fun validate(accessKey: String, campaignKey: String): Validation = when {
        accessKey.isBlank() || campaignKey.isBlank() ->
            Validation.Invalid(DemoContainer.string(R.string.validate_keys_required))

        accessKey.any(Char::isWhitespace) ->
            Validation.Invalid(DemoContainer.string(R.string.validate_access_key_whitespace))

        campaignKey.any(Char::isWhitespace) ->
            Validation.Invalid(DemoContainer.string(R.string.validate_campaign_key_whitespace))

        else -> Validation.Valid
    }
}
