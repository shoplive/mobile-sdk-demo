package cloud.shoplive.onboarding.sdk

import android.widget.Toast
import cloud.shoplive.onboarding.DemoContainer
import cloud.shoplive.onboarding.ProductRouter
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.MissionProgress
import cloud.shoplive.player.ShopliveCouponResult
import cloud.shoplive.player.ShopliveCustomActionResult
import cloud.shoplive.player.ShopliveError
import cloud.shoplive.player.ShopliveErrorCode
import cloud.shoplive.player.ShopliveResultAlertType
import cloud.shoplive.player.ShopliveResultStatus
import cloud.shoplive.player.ShoplivePlaybackEvent
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerRequest
import cloud.shoplive.player.ShoplivePlayerState

/**
 * Mission 6 — 이벤트 · 상품 · 쿠폰.
 *
 * SDK 가 앱에 말을 거는 통로는 **딱 두 개**다.
 *
 * - [onEvent] — 알리기만 하는 통지. 필요한 것만 골라 처리하면 된다.
 * - [onRequest] — 앱의 **응답이 필요한** 요청.
 *
 * ## 반드시 처리해야 하는 것은 navigation 하나다
 * [ShoplivePlayerRequest.Navigation] 을 처리하지 않으면 상품·배너를 탭해도 아무 일도
 * 일어나지 않는다. 나머지는 처리하지 않아도 재생 자체는 정상이다.
 *
 * ## respond 를 부르지 않으면 화면이 멈춘 것처럼 보인다
 * [ShoplivePlayerRequest.Coupon] · [ShoplivePlayerRequest.CustomWebAction] 은 `respond` 를
 * 호출해야 오버레이 팝업이 닫힌다. "미응답 = 버그" 라서, 데모앱은 로그에 요청과 응답을
 * 한 쌍으로 남긴다.
 *
 * ## 스레드
 * 두 콜백 모두 **메인 스레드**로 온다. `respond` 는 아무 스레드에서 불러도 된다
 * (서버 왕복 후 응답하는 것이 정상적인 사용이다).
 *
 * ## 로그에 안 오는 것 두 가지
 * 1. **엔진 절체(HLS ↔ WebRTC)는 이벤트로 오지 않는다.** SDK 내부 사정이며 네트워크 상황은
 *    [ShoplivePlayerEvent.Playback] 의 rebuffering 신호로만 관측된다.
 * 2. **자동 복구 중인 이슈는 error 로 오지 않는다.** 복구 불가로 세션이 끝날 때만
 *    [ShoplivePlayerEvent.Error] 가 전달된다(`isRecoverable = false`).
 */
class DemoPlayerDelegate(
    private val progress: MissionProgress,
    /** 재생 중 오류를 화면에 띄우기 위한 훅. */
    private val onFatalError: (String) -> Unit = {},
) : ShoplivePlayerDelegate {

    /** 연속 재생 실패 횟수. 재생이 붙거나 새 세션이 시작되면 0으로 돌아간다. */
    private var consecutiveFailures = 0

    /** 이 세션에서 실패를 이미 알렸는지. 5초마다 같은 안내를 반복하지 않기 위한 래치. */
    private var failureNotified = false

    override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
        when (event) {
            is ShoplivePlayerEvent.StateChanged -> {
                DemoLog.event("stateChanged(${event.state})")
                when (event.state) {
                    // 새 세션 시작 — 이 delegate 는 세션 간 재사용되므로 카운터를 여기서 리셋한다.
                    ShoplivePlayerState.LOADING -> {
                        consecutiveFailures = 0
                        failureNotified = false
                    }

                    ShoplivePlayerState.IN_APP_PIP -> progress.markPipEntered()
                    // 세션이 끝나면 제어 핸들을 놓는다 — 죽은 핸들에 명령을 걸지 않기 위해서.
                    ShoplivePlayerState.CLOSED -> PlayerSession.detach(player)
                    else -> Unit
                }
            }

            is ShoplivePlayerEvent.CampaignStatusChanged ->
                DemoLog.event("campaignStatusChanged(${event.status})")

            is ShoplivePlayerEvent.CampaignInfoReceived ->
                DemoLog.event(
                    "campaignInfoReceived(campaignKey: \"${event.info.campaignKey}\"" +
                        ", title: ${event.info.title ?: "null"}" +
                        ", status: ${event.info.status ?: "null"})"
                )

            is ShoplivePlayerEvent.Playback -> {
                DemoLog.event("playback(${describe(event.event)})")
                when (val playback = event.event) {
                    is ShoplivePlaybackEvent.Started -> {
                        consecutiveFailures = 0
                        progress.markPlaybackStarted()
                    }

                    is ShoplivePlaybackEvent.Rendering -> consecutiveFailures = 0

                    // 반복 실패는 error 이벤트로 오지 않는다(아래 주석 참조) — 직접 알린다.
                    is ShoplivePlaybackEvent.Failed -> onRepeatedPlaybackFailure(playback.code)

                    else -> Unit
                }
            }

            is ShoplivePlayerEvent.ConnectionStateChanged ->
                DemoLog.event("connectionStateChanged(${event.state})")

            is ShoplivePlayerEvent.UserNameUpdateRequested ->
                DemoLog.event("userNameUpdateRequested(${event.payload})")

            is ShoplivePlayerEvent.Analytics ->
                DemoLog.event(
                    "analytics(campaignKey: \"${event.info.campaignKey}\"" +
                        ", isPlaying: ${event.info.isPlaying}" +
                        ", isMuted: ${event.info.isMuted}" +
                        ", durationMs: ${event.info.durationMs})"
                )

            is ShoplivePlayerEvent.Error -> {
                val text = describe(event.error)
                DemoLog.error(text)
                // 자동 복구 중인 것은 여기로 오지 않는다 — 도착했으면 사용자에게 알린다.
                if (!event.error.isRecoverable) onFatalError(text)
            }
        }
    }

    override fun onRequest(player: ShoplivePlayerControlling, request: ShoplivePlayerRequest) {
        when (request) {
            // ── 반드시 처리해야 하는 유일한 요청 ──────────────────────────────
            is ShoplivePlayerRequest.Navigation -> {
                DemoLog.request("navigation(url: \"${request.url}\") — the app MUST handle this")
                progress.markRequestReceived()
                ProductRouter.open(request.url)
                DemoLog.respond("→ ProductRouter.open(url) called")
            }

            // ── respond 를 불러야 팝업이 닫힌다 ──────────────────────────────
            is ShoplivePlayerRequest.Coupon -> {
                DemoLog.request("coupon(id: \"${request.id}\") received")
                progress.markRequestReceived()

                // 실제 앱이라면 여기서 쿠폰 서버를 호출하고 그 결과로 respond 한다.
                // respond 는 아무 스레드에서 불러도 된다.
                request.respond(
                    ShopliveCouponResult(
                        couponId = request.id,
                        success = true,
                        message = DemoContainer.string(R.string.coupon_issued),
                        status = ShopliveResultStatus.HIDE,
                        alertType = ShopliveResultAlertType.TOAST,
                    )
                )
                DemoLog.respond("→ respond(success = true, status = HIDE, alert = TOAST) called")
            }

            is ShoplivePlayerRequest.CustomWebAction -> {
                DemoLog.request(
                    "customWebAction(id: \"${request.id}\", type: \"${request.type}\"" +
                        ", payload: ${request.payload})"
                )
                progress.markRequestReceived()
                request.respond(
                    ShopliveCustomActionResult(
                        id = request.id,
                        success = true,
                        message = null,
                        status = ShopliveResultStatus.HIDE,
                    )
                )
                DemoLog.respond("→ respond(success = true) called")
            }
        }
    }

    /**
     * 재생 실패가 이어질 때 사용자에게 알린다.
     *
     * ## 왜 이 처리가 필요한가 (실측 2026-07-30, 에뮬레이터 API 37)
     * 방송 중이 아닌 캠페인을 재생하면 `playback(failed(code: 404))` 가 5초 주기로 계속
     * 올라오고, 세션이 `ended → IDLE → CLOSED` 로 끝나도 **[ShoplivePlayerEvent.Error] 는
     * 한 번도 오지 않았다.** `campaignInfoReceived` · `campaignStatusChanged` 도 발화되지
     * 않았다. 즉 error 이벤트만 보고 있으면 앱은 "스트림이 없다"를 영원히 알 수 없고,
     * 사용자는 검은 화면만 본다.
     *
     * 그래서 `playback(failed)` 을 직접 세어 [FAILURE_THRESHOLD] 회 연속이면 알린다.
     *
     * ## 왜 Toast 인가
     * 이 시점에 화면 맨 앞은 **SDK 가 소유한 플레이어 Activity** 다. 데모앱의 Compose
     * 스낵바는 그 뒤에 있어 보이지 않는다. Toast 는 다른 Activity 위에도 뜨는 유일한
     * 수단이라, SDK 화면 위에 무언가 띄워야 할 때 쓸 수 있는 실질적인 선택지다.
     */
    private fun onRepeatedPlaybackFailure(code: Int?) {
        consecutiveFailures += 1
        if (failureNotified || consecutiveFailures < FAILURE_THRESHOLD) return
        failureNotified = true

        val codeText = code?.toString() ?: "-"
        // 로그·스낵바에는 전문을, Toast 에는 짧은 문장을 쓴다 — Toast 는 2줄에서 잘린다.
        val detail = DemoContainer.string(R.string.err_playback_failed, codeText)
        DemoLog.error(detail)
        Toast.makeText(
            DemoContainer.appContext,
            DemoContainer.string(R.string.err_playback_failed_short, codeText),
            Toast.LENGTH_LONG,
        ).show()
        onFatalError(detail)
    }

    // ── 표시용 변환 ──────────────────────────────────────────────────────────

    private fun describe(event: ShoplivePlaybackEvent): String = when (event) {
        is ShoplivePlaybackEvent.Requested -> "requested"
        is ShoplivePlaybackEvent.Started -> "started"
        is ShoplivePlaybackEvent.Rendering -> "rendering"
        is ShoplivePlaybackEvent.RebufferingStarted -> "rebufferingStarted"
        is ShoplivePlaybackEvent.RebufferingEnded -> "rebufferingEnded"
        is ShoplivePlaybackEvent.Buffering -> "buffering"
        is ShoplivePlaybackEvent.AudioLoaded -> "audioLoaded"
        is ShoplivePlaybackEvent.Ended -> "ended"
        is ShoplivePlaybackEvent.Failed -> "failed(code: ${event.code}, message: ${event.message})"
    }

    /**
     * 오류를 **원인별 문장**으로 번역한다.
     *
     * SDK 에는 키 유효성을 미리 확인하는 API 가 없다. 그래서 잘못된 키·없는 캠페인·인증
     * 문제·네트워크는 모두 재생 시도 후 error 이벤트로 구분된다 — 이 매핑이 시작 화면의
     * "원인별 안내" 를 만든다.
     */
    private fun describe(error: ShopliveError): String {
        val causeRes = when (error.code) {
            ShopliveErrorCode.NOT_INITIALIZED_ACCESS_KEY -> R.string.err_access_key

            ShopliveErrorCode.CAMPAIGN_NOT_FOUND -> R.string.err_campaign_not_found

            ShopliveErrorCode.CAMPAIGN_NOT_ON_AIR -> R.string.err_not_on_air

            ShopliveErrorCode.AUTHENTICATION_FAILED,
            ShopliveErrorCode.GUEST_LOGIN_NOT_ALLOWED,
            ShopliveErrorCode.CUSTOM_ACCOUNT_NOT_FOUND,
            ShopliveErrorCode.CUSTOM_ACCOUNT_EXPIRED,
            ShopliveErrorCode.INVALID_SIGNATURE,
            ShopliveErrorCode.DUPLICATE_SESSION,
            ShopliveErrorCode.EXPIRED_SESSION -> R.string.err_auth_required

            ShopliveErrorCode.CONNECTION_ISSUE,
            ShopliveErrorCode.FAILED_NETWORK -> R.string.err_network

            ShopliveErrorCode.SERVER_ERROR -> R.string.err_server

            else -> R.string.err_other
        }
        val cause = DemoContainer.string(causeRes)
        return "error(code: ${error.code}, rawCode: ${error.rawCode}" +
            ", isRecoverable: ${error.isRecoverable}) $cause · ${error.message}"
    }

    private companion object {
        /** 이 횟수만큼 연속 실패하면 사용자에게 알린다. 한 번은 일시적 실패일 수 있다. */
        const val FAILURE_THRESHOLD = 2
    }
}
