package cloud.shoplive.onboarding.sdk

import android.app.Activity
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoOptions
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayer
import cloud.shoplive.player.ShoplivePlayerConfiguration
import cloud.shoplive.player.ShoplivePlayerDelegate

/**
 * Mission 1 — 플레이어 띄우기.
 *
 * 연동은 사실상 3줄이다.
 *
 * ```kotlin
 * Shoplive.initialize(context, ShopliveConfiguration("{ACCESS_KEY}"))   // 앱 시작 시 1회
 * Shoplive.setUser(ShopliveUser.Guest)                                  // 선택
 * ShoplivePlayer(activity).start(campaignKey = "{CAMPAIGN_KEY}")
 * ```
 *
 * ## context 는 반드시 Activity 다
 * `ShoplivePlayer(context)` 의 context 는 **LifecycleOwner**(Activity 등)여야 한다.
 * `applicationContext` 를 넘기면 SDK 가 기동을 거부하고 경고 로그만 남긴다 — 화면이
 * 아무 반응 없는 것처럼 보이는 흔한 실수다.
 *
 * ## 인스턴스를 붙잡아 둬야 하는 이유
 * `delegate` 는 **인스턴스 소유**다. 지역 변수로 만들고 버리면 이벤트를 받을 수 없다.
 * 데모앱은 [PlayerSession] 에 담아 두고 개발자 시트의 제어에 그대로 쓴다.
 *
 * ## 화면 전환을 앱이 직접 하고 싶을 때
 * `start()` 대신 `intent()` 로 Intent 만 받아 `startActivity` 할 수 있다
 * (전환 애니메이션·Task 정책을 앱이 정하는 경우).
 */
object PlayerLauncher {

    /**
     * 풀스크린 재생을 시작한다.
     *
     * @param activity SDK Activity 를 띄울 화면. LifecycleOwner 여야 한다.
     * @param configuration 재생 1건의 초기값. 넘기지 않으면 SDK 기본값.
     */
    fun start(
        activity: Activity,
        campaignKey: String,
        delegate: ShoplivePlayerDelegate,
        configuration: ShoplivePlayerConfiguration = PlayerConfigurationFactory.default(),
        options: ShoplivePlayOptions = ShoplivePlayOptions(),
    ) {
        val player = ShoplivePlayer(activity)
        player.delegate = delegate

        PlayerSession.attach(player)

        DemoLog.sdkCall(
            "ShoplivePlayer(activity).start(campaignKey: \"$campaignKey\"" +
                ", referrer: ${options.referrer ?: "null"})"
        )
        player.start(
            campaignKey = campaignKey,
            options = options,
            configuration = configuration,
        )
    }

    /** 개발자 시트의 옵션을 반영해서 재생한다 (Mission 5·7 이 쓰는 경로). */
    fun startWithOptions(
        activity: Activity,
        campaignKey: String,
        delegate: ShoplivePlayerDelegate,
        demoOptions: DemoOptions,
        referrerOverride: String? = null,
    ) = start(
        activity = activity,
        campaignKey = campaignKey,
        delegate = delegate,
        configuration = PlayerConfigurationFactory.from(demoOptions),
        options = PlayerConfigurationFactory.playOptions(demoOptions, referrerOverride),
    )
}
