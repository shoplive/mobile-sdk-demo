package cloud.shoplive.onboarding.sdk

import cloud.shoplive.onboarding.data.DemoOptions
import cloud.shoplive.player.ShopliveInsets
import cloud.shoplive.player.ShoplivePlayerConfiguration

/**
 * Mission 5 — PIP 로 계속 보기.
 *
 * PIP 는 두 종류가 있고 **성질이 다르다**.
 *
 * | | in-App PIP | OS PIP |
 * | --- | --- | --- |
 * | 주체 | SDK 가 그리는 플로팅 창 | `Activity.enterPictureInPictureMode()` |
 * | 지원 | 풀스크린([cloud.shoplive.player.ShoplivePlayer])·임베드([cloud.shoplive.player.ShoplivePlayerView]) **공통** | 풀스크린 **전용** |
 * | 왜 | SDK 소유 컨테이너를 재부모화 | host Activity 전체가 축소되므로 임베드 뷰에는 성립하지 않음 |
 *
 * 그래서 임베드 뷰(Mission 4)에서는 `isOSPipEnabled` 를 켜도 OS PIP 가 동작하지 않는다.
 *
 * ## 화면을 벗어날 때 자동 PIP 는 앱이 정한다
 * 현재 공개 표면에는 "뷰가 화면 밖으로 나가면 자동으로 PIP" 옵션이 없다. 그런 동작이
 * 필요하면 앱이 스크롤·생명주기를 보고 [cloud.shoplive.player.ShoplivePlayerControlling.enterPictureInPicture]
 * 를 직접 부른다 — 데모앱은 피드 화면의 버튼으로 그 지점을 드러낸다.
 *
 * ## 랜딩과의 관계
 * `navigation.actionOnNavigation = PIP` 면 상품을 탭해 화면이 이동할 때 SDK 가 내부적으로
 * PIP 로 전환한다. 즉 Mission 5 의 "상품 탭 → 작은 창" 은 이 값이 만드는 동작이다.
 */
object PipOptions {

    /** 데모앱 옵션 상태 → SDK PIP 옵션. */
    fun from(options: DemoOptions): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isInAppPipEnabled = options.isInAppPipEnabled,
            isOSPipEnabled = options.isOSPipEnabled,
            enterOSPipOnBackPressed = options.enterOSPipOnBackPressed,
            defaultPosition = options.pipPosition,
            scale = options.pipScale,
            aspectRatio = options.pipAspectRatio,
            // 변별로 다르게 줄 수도 있다: ShopliveInsets(left, top, right, bottom)
            padding = ShopliveInsets.all(options.pipPaddingDp),
        )

    /**
     * 아무것도 지정하지 않은 기본값. 이대로도 PIP 는 동작한다 —
     * in-App·OS 모두 켜져 있고, 우하단 9:16, 화면의 40% 크기.
     */
    val DEFAULT = ShoplivePlayerConfiguration.PipOptions()
}
