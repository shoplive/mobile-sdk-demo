package cloud.shoplive.onboarding.ui.hybrid

import android.net.Uri
import android.webkit.WebView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.integration.ShopliveWebBridge
import cloud.shoplive.onboarding.integration.isOngoing
import cloud.shoplive.onboarding.ui.MainViewModel
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.feed.findActivity
import cloud.shoplive.player.ShoplivePlayerControlling
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerEvent
import cloud.shoplive.player.ShoplivePlayerRequest
import cloud.shoplive.player.ShoplivePlayerState
import java.lang.ref.WeakReference

/** The bundled page. Only URLs under this prefix stay inside the WebView. */
private const val PAGE_PREFIX = "file:///android_asset/hybrid/"

/**
 * Inline-preview mission, hybrid way — the list is a web page in a WebView, and a
 * tap hands one campaignKey to the app, which opens the native full-screen player.
 *
 * The page is a local file (`assets/hybrid/index.html`) that uses the guide's step-1
 * branching code but no Web SDK, so the demo needs no hosted page. The SDK-facing and
 * WebView-safety parts are `ShopliveWebBridge` in `:integration`.
 *
 * A new WebView, and a new bridge registered before `loadUrl`, every time this screen
 * is composed — including after rotation. Both are released when it leaves.
 */
@Composable
fun HybridListScreen(
    mainViewModel: MainViewModel,
    modifier: Modifier = Modifier,
    hybridViewModel: HybridViewModel = viewModel(),
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    var pageError by remember { mutableStateOf<String?>(null) }

    Column(
        modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Tip(stringResource(R.string.hybrid_tip_bridge), TipTone.OK)
        pageError?.let { reason -> Tip(stringResource(R.string.hybrid_page_error, reason), TipTone.WARN) }

        if (activity == null) {
            Tip(stringResource(R.string.feed_warn_activity_context), TipTone.WARN)
            return@Column
        }

        // One bridge per WebView: created and released together with it.
        val bridge = remember(activity) {
            ShopliveWebBridge(activity) { host, campaignKey ->
                hybridViewModel.onCampaignKey(campaignKey) { key, wrap ->
                    mainViewModel.playFromHybrid(host, key, wrap)
                }
            }
        }

        AndroidView(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            factory = { viewContext ->
                WebView(viewContext).also { webView ->
                    bridge.attachTo(
                        webView = webView,
                        ownPagePrefix = PAGE_PREFIX,
                        onPageError = { reason -> pageError = reason },
                    )
                    webView.loadUrl(pageUrl(mainViewModel.effectiveCampaignKey()))
                }
            },
            onRelease = { webView ->
                bridge.detachFrom(webView)
                webView.destroy()
                DemoLog.event("hybrid: WebView released (bridge removed)")
            },
        )
    }
}

/**
 * The campaignKey goes in as a query parameter, encoded, and the page reads it with
 * `URLSearchParams` — never pasted into script text.
 */
private fun pageUrl(campaignKey: String): String =
    "${PAGE_PREFIX}index.html" +
        "?campaignKey=${Uri.encode(campaignKey)}" +
        "&lang=${Uri.encode(LocaleSetting.current.tag)}"

/**
 * The double-tap guard of **this** page. A tap is ignored while the start it made
 * last is still pending (the SDK has not reported anything past Idle yet — a
 * full-screen `start()` only launches an Activity) or while that player is starting or
 * showing ([isOngoing]). Reading this page's own start, instead of a global flag,
 * means a late "closed" from an older session can never unlock a newer one; a new
 * page (re-entry) starts unlocked.
 *
 * The player is held weakly: it keeps a view made with the Activity and this object
 * survives rotation. Losing the reference only opens the guard; on Android the next
 * `start()` closes the previous session, so two players never coexist.
 */
class HybridViewModel : ViewModel() {

    /** One start from this page. A new object per start doubles as the stale-event token. */
    private class Launch {
        var player: WeakReference<ShoplivePlayerControlling> = WeakReference(null)

        /** `start()` was called and the session has not reported anything past Idle. */
        var isStarting = true
    }

    private var launch: Launch? = null

    /**
     * @param play starts the player; it must pass its delegate through `wrap`, which
     *   is how this page hears its own session leave Idle, close or fail.
     */
    fun onCampaignKey(
        campaignKey: String,
        play: (
            campaignKey: String,
            wrap: (ShoplivePlayerDelegate) -> ShoplivePlayerDelegate,
        ) -> ShoplivePlayerControlling,
    ) {
        val previous = launch
        val previousPlayer = previous?.player?.get()
        when {
            previous != null && previous.isStarting -> {
                // TODO(SDP-VERIFY): 요확인 — S53 시작 요청 뒤 Idle 구간 잠금이 Loading·Closed·복구 불가 Error 중 하나로 실제로 풀리는지, 시작이 거부돼 아무 이벤트도 오지 않으면 화면 재진입 전까지 잠기는지 실기기 확인 · 근거 SMV-1922 S53
                DemoLog.event("hybrid: the start this page made has not left Idle yet — \"$campaignKey\" ignored")
                return
            }

            previousPlayer != null && previousPlayer.state.isOngoing -> {
                DemoLog.event("hybrid: the player this page opened is still up (${previousPlayer.state}) — \"$campaignKey\" ignored")
                return
            }

            previous != null && previousPlayer == null ->
                DemoLog.event("hybrid: reference to the previous player was released — not known whether it is still up; starting \"$campaignKey\"")

            else -> Unit
        }

        val next = Launch()
        launch = next
        try {
            next.player = WeakReference(play(campaignKey) { inner -> tracking(next, inner) })
        } catch (e: RuntimeException) {
            launch = previous
            throw e
        }
    }

    /** Forwards everything to [inner]; ends [owner]'s pending start on its own session's signals. */
    private fun tracking(owner: Launch, inner: ShoplivePlayerDelegate) = object : ShoplivePlayerDelegate {
        override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
            inner.onEvent(player, event)
            if (owner !== launch || !owner.isStarting) return
            val leftStart = when (event) {
                is ShoplivePlayerEvent.StateChanged -> event.state != ShoplivePlayerState.Idle
                is ShoplivePlayerEvent.Error -> !event.error.isRecoverable
                else -> false
            }
            if (leftStart) owner.isStarting = false
        }

        override fun onRequest(player: ShoplivePlayerControlling, request: ShoplivePlayerRequest) {
            inner.onRequest(player, request)
        }
    }
}
