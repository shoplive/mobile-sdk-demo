package cloud.shoplive.onboarding.sdk

import android.graphics.Typeface
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.ChatInputFont
import cloud.shoplive.onboarding.data.DemoOptions
import cloud.shoplive.onboarding.data.LoadingAnimation
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayerConfiguration

/**
 * Mission 7 — UI 커스터마이즈.
 *
 * `ShoplivePlayerConfiguration` 는 **재생 1건의 초기값·정책 묶음**이다. 예전 SDK 의 정적
 * 옵션 setter 들을 하나의 불변 객체로 대체한다.
 *
 * ## 불변이고, 재생 시작 전에만 반영된다
 * 모든 필드가 `val` 이고, 재생이 시작된 뒤의 대입은 **무시된다**(경고 로그만 남는다).
 * 값을 바꿔 확인하려면 새 configuration 으로 다시 재생해야 한다 — 데모앱 옵션 탭의
 * "이 옵션으로 다시 재생" 버튼이 그 흐름이다.
 *
 * 재생 중에 바꿔야 하는 것은 configuration 이 아니라 런타임 프로퍼티다:
 * `isMuted` · `resizeMode` · `overlayUI`.
 *
 * ## 지정하지 않아도 동작한다
 * 모든 필드에 기본값이 있다. `ShoplivePlayerConfiguration()` 만으로도 정상 재생된다.
 *
 * ## overlay.ui = HIDDEN 의 의미
 * 기본 오버레이 UI(채팅·상품·쿠폰)를 **감추기만** 한다. 커맨드 채널은 살아 있으므로
 * 상품·쿠폰 데이터는 계속 들어온다 — 앱이 자체 UI 를 그릴 때 쓰는 모드다.
 * 웹뷰를 완전히 파괴하는 모드는 공개돼 있지 않다(세션 종료 시에만 일어난다).
 */
object PlayerConfigurationFactory {

    /** 3줄 연동에 쓰는 무설정 기본값. */
    fun default(): ShoplivePlayerConfiguration = ShoplivePlayerConfiguration()

    /** 개발자 시트에서 조정한 값 전체를 configuration 으로 만든다. */
    fun from(options: DemoOptions): ShoplivePlayerConfiguration =
        ShoplivePlayerConfiguration(
            // LIVE / PREVIEW — 볼륨키 정책과 수신 해상도의 기본값을 이 값이 정한다.
            type = options.type,

            pip = PipOptions.from(options),

            sound = ShoplivePlayerConfiguration.SoundOptions(
                muteOnStart = options.muteOnStart,
                mixWithOthers = options.mixWithOthers,
                autoResumeOnFocusGained = options.autoResumeOnFocusGained,
                // null 이면 type 기본값(LIVE=true · PREVIEW=false)을 따른다.
                isVolumeKeyEnabled = options.isVolumeKeyEnabled,
            ),

            appearance = ShoplivePlayerConfiguration.AppearanceOptions(
                indicatorColor = options.indicatorColor.argb,
                loadingAnimation = when (options.loadingAnimation) {
                    LoadingAnimation.SDK_DEFAULT -> null
                    LoadingAnimation.DEMO_CUSTOM -> R.drawable.ic_demo_loading
                },
                isStatusBarVisible = options.isStatusBarVisible,
                chatInputTypeface = when (options.chatInputFont) {
                    ChatInputFont.SDK_DEFAULT -> null
                    ChatInputFont.BOLD -> Typeface.DEFAULT_BOLD
                    ChatInputFont.MONOSPACE -> Typeface.MONOSPACE
                },
                // false 로 두면 SDK 가 FLAG_SECURE 를 걸어 스크린샷·미러링이 검게 나온다.
                allowScreenCapture = options.allowScreenCapture,
            ),

            navigation = ShoplivePlayerConfiguration.NavigationOptions(
                actionOnNavigation = options.actionOnNavigation,
                shareScheme = options.shareScheme.takeIf { it.isNotBlank() },
                closeWhenAppDestroyed = options.closeWhenAppDestroyed,
            ),

            overlay = ShoplivePlayerConfiguration.OverlayOptions(
                ui = options.overlayUI,
            ),

            // 오버레이 URL 에 실릴 추가 쿼리 파라미터.
            customParameters = options.customParameters,
        )

    /** 회차 단위 옵션. configuration 과 달리 `play()`/`start()` 호출마다 다르게 줄 수 있다. */
    fun playOptions(options: DemoOptions, referrerOverride: String? = null): ShoplivePlayOptions =
        ShoplivePlayOptions(
            referrer = (referrerOverride ?: options.referrer).takeIf { it.isNotBlank() },
            keepWindowStateOnPlayExecuted = options.keepWindowStateOnPlayExecuted,
        )
}
