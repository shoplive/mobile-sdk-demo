package cloud.shoplive.onboarding.sdk

import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.player.ShopliveOverlayUIMode
import cloud.shoplive.player.ShopliveResizeMode
import cloud.shoplive.player.ShoplivePlayerControlling

/**
 * 지금 살아 있는 플레이어 핸들을 담아 둔다.
 *
 * ## 왜 필요한가
 * `isMuted` · `resizeMode` · `reload()` · `send()` · PIP 전환은 **configuration 이 아니라
 * 실행 중인 핸들**에 건다. 개발자 시트의 "제어" 항목이 그 핸들을 찾을 곳이 필요하다.
 *
 * 풀스크린([cloud.shoplive.player.ShoplivePlayer])과 임베드
 * ([cloud.shoplive.player.ShoplivePlayerView])는 같은 [ShoplivePlayerControlling] 계약을
 * 구현하므로, 제어 코드는 어느 쪽이든 **동일**하다 — 그 점을 드러내려고 공통 타입으로 담는다.
 */
object PlayerSession {

    @Volatile
    var current: ShoplivePlayerControlling? = null
        private set

    fun attach(player: ShoplivePlayerControlling) {
        current = player
    }

    fun detach(player: ShoplivePlayerControlling) {
        if (current === player) current = null
    }

    val isActive: Boolean get() = current != null

    // ── 런타임 제어 (configuration 으로는 바꿀 수 없는 값들) ────────────────────

    fun setMuted(muted: Boolean) = withPlayer("isMuted = $muted") { it.isMuted = muted }

    fun setResizeMode(mode: ShopliveResizeMode) =
        withPlayer("resizeMode = $mode") { it.resizeMode = mode }

    /**
     * 오버레이 표시 토글.
     *
     * ⚠️ 임베드 뷰는 항상 HIDDEN 고정이라 대입이 무시된다(영상 전용). 풀스크린 쪽 런타임
     * 토글도 현재 버전에서는 배선 전이다 — 확실히 적용하려면 `overlay.ui` 를 넣은
     * configuration 으로 다시 재생하세요.
     */
    fun setOverlayUI(mode: ShopliveOverlayUIMode) =
        withPlayer("overlayUI = $mode") { it.overlayUI = mode }

    fun reload() = withPlayer("reload()") { it.reload() }

    fun send(command: String, payload: Map<String, Any?>?) =
        withPlayer("send(command: \"$command\", payload: $payload)") { it.send(command, payload) }

    fun enterPictureInPicture() = withPlayer("enterPictureInPicture()") {
        it.enterPictureInPicture()
    }

    fun exitPictureInPicture() = withPlayer("exitPictureInPicture()") {
        it.exitPictureInPicture()
    }

    fun stop() = withPlayer("stop()") { it.stop() }

    private inline fun withPlayer(logLine: String, block: (ShoplivePlayerControlling) -> Unit) {
        val player = current
        if (player == null) {
            DemoLog.error("$logLine — no running player. Start playback first.")
            return
        }
        DemoLog.sdkCall(logLine)
        block(player)
    }
}
