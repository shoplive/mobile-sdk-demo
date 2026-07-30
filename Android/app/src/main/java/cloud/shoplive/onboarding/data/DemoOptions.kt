package cloud.shoplive.onboarding.data

import androidx.annotation.StringRes
import cloud.shoplive.onboarding.R
import cloud.shoplive.player.ShopliveNavigationAction
import cloud.shoplive.player.ShopliveOverlayUIMode
import cloud.shoplive.player.ShoplivePipPosition
import cloud.shoplive.player.ShoplivePipRatio
import cloud.shoplive.player.ShoplivePlayerType
import cloud.shoplive.player.ShopliveResizeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 개발자 시트(V1) "옵션" 탭이 편집하는 상태.
 *
 * **`ShoplivePlayerConfiguration` 의 모든 필드에 컨트롤이 하나씩 대응한다** — 미션에
 * 등장하지 않는 필드도 여기서 전부 확인할 수 있게 하는 것이 이 화면의 목적이다.
 * 값 → `ShoplivePlayerConfiguration` 변환은
 * [cloud.shoplive.onboarding.sdk.PlayerConfigurationFactory] 가 담당한다.
 *
 * 기본값은 SDK 기본값과 **같게 유지**한다. 아무것도 만지지 않고 실행했을 때 "지정하지
 * 않아도 동작한다"가 성립해야 하기 때문이다.
 */
data class DemoOptions(
    // ── type ─────────────────────────────────────────────────────────────────
    val type: ShoplivePlayerType = ShoplivePlayerType.LIVE,

    // ── pip ──────────────────────────────────────────────────────────────────
    val isInAppPipEnabled: Boolean = true,
    val isOSPipEnabled: Boolean = true,
    val enterOSPipOnBackPressed: Boolean = false,
    val pipPosition: ShoplivePipPosition = ShoplivePipPosition.BOTTOM_RIGHT,
    val pipScale: Float = 0.4f,
    val pipAspectRatio: ShoplivePipRatio = ShoplivePipRatio.RATIO_9X16,
    /** 네 변에 같은 값을 준다. `ShopliveInsets` 는 변별 지정도 가능하다. */
    val pipPaddingDp: Int = 0,

    // ── sound ────────────────────────────────────────────────────────────────
    val muteOnStart: Boolean = false,
    val mixWithOthers: Boolean = false,
    val autoResumeOnFocusGained: Boolean = true,
    /** null = type 이 정한 기본값을 따른다 (LIVE=true · PREVIEW=false). */
    val isVolumeKeyEnabled: Boolean? = null,

    // ── appearance ───────────────────────────────────────────────────────────
    val indicatorColor: IndicatorColor = IndicatorColor.WHITE,
    val loadingAnimation: LoadingAnimation = LoadingAnimation.SDK_DEFAULT,
    val isStatusBarVisible: Boolean = true,
    val chatInputFont: ChatInputFont = ChatInputFont.SDK_DEFAULT,
    /**
     * SDK 기본값은 `true`(캡처 허용)다. `false` 로 두면 SDK 가 플레이어 창에
     * FLAG_SECURE 를 걸어 스크린샷·미러링에서 영상이 검게 나온다.
     */
    val allowScreenCapture: Boolean = true,

    // ── navigation ───────────────────────────────────────────────────────────
    val actionOnNavigation: ShopliveNavigationAction = ShopliveNavigationAction.PIP,
    val shareScheme: String = "",
    val closeWhenAppDestroyed: Boolean = true,

    // ── overlay ──────────────────────────────────────────────────────────────
    val overlayUI: ShopliveOverlayUIMode = ShopliveOverlayUIMode.BUILT_IN,

    // ── customParameters ─────────────────────────────────────────────────────
    val customParameters: Map<String, String> = emptyMap(),

    // ── PlayOptions (회차 단위) ───────────────────────────────────────────────
    val referrer: String = "",
    val keepWindowStateOnPlayExecuted: Boolean = false,

    // ── 런타임 프로퍼티 (configuration 이 아니라 실행 중 제어) ─────────────────
    val resizeMode: ShopliveResizeMode = ShopliveResizeMode.FILL,
) {
    /** 기본값에서 하나라도 바뀌었는지 — 미션 7 판정과 화면 표시에 쓴다. */
    val isModified: Boolean get() = this != DEFAULT

    companion object {
        val DEFAULT = DemoOptions()
    }
}

/**
 * `appearance.indicatorColor` 는 `@ColorInt Int` 다. 데모에서는 몇 가지 프리셋만 돌린다.
 *
 * [labelRes] 가 null 이면 [literalLabel] 을 그대로 쓴다 — 색상 코드처럼 번역할 것이 없는 값이다.
 */
enum class IndicatorColor(
    val argb: Int,
    @StringRes val labelRes: Int? = null,
    val literalLabel: String? = null,
) {
    WHITE(0xFFFFFFFF.toInt(), labelRes = R.string.value_white_default),
    BRAND(0xFFFF2D55.toInt(), literalLabel = "#FF2D55"),
    BLUE(0xFF1F6FEB.toInt(), literalLabel = "#1F6FEB"),
    BLACK(0xFF111111.toInt(), literalLabel = "#111111"),
}

enum class LoadingAnimation(@StringRes val labelRes: Int) {
    SDK_DEFAULT(R.string.value_sdk_default),
    DEMO_CUSTOM(R.string.value_demo_drawable),
}

enum class ChatInputFont(
    @StringRes val labelRes: Int? = null,
    val literalLabel: String? = null,
) {
    SDK_DEFAULT(labelRes = R.string.value_sdk_default),
    BOLD(literalLabel = "Typeface.DEFAULT_BOLD"),
    MONOSPACE(literalLabel = "Typeface.MONOSPACE"),
}

/**
 * 옵션 상태는 프로세스 전역이다 — SDK Activity 가 앞에 떠 있는 동안에도 같은 값을 읽어야
 * 하고, 데모앱 화면이 다시 만들어져도 유지되어야 한다.
 */
object DemoOptionsStore {

    private val _options = MutableStateFlow(DemoOptions())
    val options: StateFlow<DemoOptions> = _options.asStateFlow()

    val current: DemoOptions get() = _options.value

    fun update(transform: (DemoOptions) -> DemoOptions) {
        _options.value = transform(_options.value)
    }

    fun reset() {
        _options.value = DemoOptions()
    }
}
