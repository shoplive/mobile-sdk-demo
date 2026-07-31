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
 * The state edited by the developer sheet's "options" tab.
 *
 * **Every field of `ShoplivePlayerConfiguration` has one control here** — including
 * fields no mission uses, so that all of them can be tried. The conversion into a
 * `ShoplivePlayerConfiguration` is
 * [cloud.shoplive.onboarding.demo.DemoConfigurationFactory]'s job.
 *
 * This class is demo harness: it is a screen's mutable state, which is why it does
 * not live in `:integration`. Customer-facing configuration examples are in
 * [cloud.shoplive.onboarding.integration.ShoplivePlayerPresets] instead.
 *
 * The defaults are **kept identical to the SDK defaults**, so that running without
 * touching anything demonstrates "you do not have to specify anything".
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
    /** The same value on all four sides. `ShopliveInsets` can set them separately. */
    val pipPaddingDp: Int = 0,

    // ── sound ────────────────────────────────────────────────────────────────
    val muteOnStart: Boolean = false,
    val mixWithOthers: Boolean = false,
    val autoResumeOnFocusGained: Boolean = true,
    /** null follows the default the type sets (LIVE=true, PREVIEW=false). */
    val isVolumeKeyEnabled: Boolean? = null,

    // ── appearance ───────────────────────────────────────────────────────────
    val indicatorColor: IndicatorColor = IndicatorColor.WHITE,
    val loadingAnimation: LoadingAnimation = LoadingAnimation.SDK_DEFAULT,
    val isStatusBarVisible: Boolean = true,
    val chatInputFont: ChatInputFont = ChatInputFont.SDK_DEFAULT,
    /**
     * The SDK default is `true` (capture allowed). With `false` the SDK sets
     * FLAG_SECURE on the player window, blacking out screenshots and mirroring.
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

    // ── PlayOptions (per playback) ───────────────────────────────────────────
    val referrer: String = "",
    val keepWindowStateOnPlayExecuted: Boolean = false,

    // ── Runtime properties (control during playback, not configuration) ──────
    val resizeMode: ShopliveResizeMode = ShopliveResizeMode.FILL,
) {
    /** Whether anything differs from the defaults — used by mission 7 and the UI. */
    val isModified: Boolean get() = this != DEFAULT

    companion object {
        val DEFAULT = DemoOptions()
    }
}

/**
 * `appearance.indicatorColor` is a `@ColorInt Int`; the demo cycles a few presets.
 *
 * When [labelRes] is null, [literalLabel] is used as-is — a colour code has nothing
 * to translate.
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
 * The options state is process-wide: it has to read the same values while an SDK
 * Activity is in front, and survive the demo's screens being recreated.
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
