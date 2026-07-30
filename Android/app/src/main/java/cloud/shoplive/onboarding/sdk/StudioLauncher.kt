package cloud.shoplive.onboarding.sdk

import android.app.Activity
import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.MissionProgress
import cloud.shoplive.streamer.ShopliveAppearanceOptions
import cloud.shoplive.streamer.ShopliveBroadcastState
import cloud.shoplive.streamer.ShopliveStreamer
import cloud.shoplive.streamer.ShopliveStreamerDelegate
import cloud.shoplive.streamer.ShopliveStreamerEvent

/**
 * Mission 8 — 라이브 송출하기.
 *
 * ```kotlin
 * Shoplive.setStreamToken(streamerJwt)                 // 시청 인증과 별개 경로
 * ShopliveStreamer(activity).apply { streamerDelegate = ... }.start(campaignKey)
 * ```
 *
 * ## 송출 토큰은 시청 인증과 다른 경로다
 * `Shoplive.setUser(...)` 는 **시청자** 신원이고, `Shoplive.setStreamToken(...)` 는
 * **송출 권한**이다. 하나를 설정해도 다른 하나가 채워지지 않는다.
 * `Shoplive.logout()` 은 둘 다(+authToken) 비운다.
 *
 * ## 스튜디오 UI 전체를 SDK 가 제공한다
 * 카메라 프리뷰·전환·줌·채팅·설정·"Live in 3,2,1" 카운트다운까지 SDK 화면이다.
 * 해상도·비트레이트는 서버 주도이므로 앱 코드가 필요 없다. 앱이 커스터마이즈할 수 있는
 * 것은 [ShopliveAppearanceOptions](카운트다운 progress·텍스트·취소 버튼) 정도다.
 *
 * ## context 는 Activity 여야 한다
 * `start()` 가 카메라·마이크 **런타임 권한을 대신 요청**하는데, 그 요청이 Activity 의
 * lifecycleScope 를 쓴다. `intent()` 는 권한을 요청하지 않으므로 앱이 직접 받아야 한다.
 *
 * ## 세션은 한 번에 하나
 * 진행 중(IDLE·ENDED 가 아닌 상태)에 `start()` 를 다시 부르면 **무시**된다. 새 세션이
 * 슬롯을 차지하면 이전 세션은 종료 통지를 받는다.
 *
 * ## delegate 를 붙이기 전 이벤트는 버려진다
 * 재생되지 않으므로, delegate 를 붙인 직후 [ShopliveStreamer.state] 를 읽어 현재 상태를
 * 맞춰야 한다.
 */
object StudioLauncher {

    @Volatile
    private var current: ShopliveStreamer? = null

    val state: ShopliveBroadcastState
        get() = current?.state ?: ShopliveBroadcastState.IDLE

    /**
     * @param streamToken 송출 토큰. 비어 있으면 시작하지 않는다.
     * @return 시작을 시도했으면 true.
     */
    fun start(
        activity: Activity,
        campaignKey: String,
        streamToken: String,
        progress: MissionProgress,
        onFatalError: (String) -> Unit = {},
    ): Boolean {
        if (streamToken.isBlank()) {
            DemoLog.error("No stream token. Mission 8 requires one.")
            return false
        }

        Shoplive.setStreamToken(streamToken)
        DemoLog.sdkCall("Shoplive.setStreamToken(\"${DemoLog.mask(streamToken)}\")")

        val streamer = ShopliveStreamer(activity)
        streamer.streamerDelegate = DemoStreamerDelegate(progress, onFatalError)
        current = streamer

        // delegate 를 붙인 직후 상태를 한 번 읽어 맞춘다(이전 이벤트는 재생되지 않는다).
        DemoLog.event("StreamerEvent subscribed — current state: ${streamer.state}")

        DemoLog.sdkCall("ShopliveStreamer(activity).start(campaignKey: \"$campaignKey\")")
        streamer.start(
            campaignKey = campaignKey,
            // 카운트다운 외형만 앱이 정한다. 기본값이면 SDK 기본 리소스를 쓴다.
            appearance = ShopliveAppearanceOptions(),
        )
        return true
    }
}

/**
 * 송출 이벤트 수신자. 메인 스레드로 온다.
 *
 * 이벤트는 **StateChanged 와 Error 두 종류뿐**이다. 상태는 rank 순으로만 전진하므로
 * 늦게 도착한 신호가 세션을 뒤로 되돌리지 못한다. ENDED 는 종단이다.
 */
private class DemoStreamerDelegate(
    private val progress: MissionProgress,
    private val onFatalError: (String) -> Unit,
) : ShopliveStreamerDelegate {

    override fun onEvent(streamer: ShopliveStreamer, event: ShopliveStreamerEvent) {
        when (event) {
            is ShopliveStreamerEvent.StateChanged -> {
                DemoLog.event(
                    "StreamerEvent.stateChanged(${event.state}" +
                        ", isRehearsal: ${event.isRehearsal})"
                )
                if (event.state == ShopliveBroadcastState.LIVE) {
                    progress.markBroadcastLive()
                }
            }

            is ShopliveStreamerEvent.Error -> {
                val error = event.error
                val text = "StreamerEvent.error(code: ${error.code}" +
                    ", rawCode: ${error.rawCode}" +
                    ", isRecoverable: ${error.isRecoverable}) ${error.message}"
                DemoLog.error(text)
                if (!error.isRecoverable) onFatalError(text)
            }
        }
    }
}
