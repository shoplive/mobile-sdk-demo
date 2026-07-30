package cloud.shoplive.onboarding.ui.feed

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.LocalLifecycleOwner
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.sdk.PlayerConfigurationFactory
import cloud.shoplive.onboarding.sdk.PlayerSession
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerType
import cloud.shoplive.player.ShoplivePlayerView

/**
 * Mission 4 — 화면 안에 임베드.
 *
 * `ShoplivePlayerView` 를 앱 레이아웃에 직접 넣는다. **레이아웃만 앱이 소유**하고,
 * 컨트롤·이벤트·PIP 는 풀스크린과 **동일한 API**([cloud.shoplive.player.ShoplivePlayerControlling])다.
 *
 * ## 임베드 뷰는 영상 전용이다
 * 채팅·상품·쿠폰 오버레이 UI 는 나오지 않는다(`overlayUI` 는 HIDDEN 고정). 호스트 레이아웃
 * 안에 들어가는 뷰가 오버레이까지 그리면 앱 UI 와 충돌하기 때문이다. 오버레이가 필요하면
 * 풀스크린(`ShoplivePlayer`)을 쓴다. 단 **커맨드 채널은 살아 있어** 이벤트·요청은 계속 온다.
 *
 * ## LazyColumn 을 쓰지 않은 이유 (중요)
 * `ShoplivePlayerView` 는 **화면에서 떨어질 때(onDetachedFromWindow) 자원을 해제**한다.
 * LazyColumn 은 화면 밖 아이템을 폐기하므로, 플레이어를 lazy 아이템으로 두면 스크롤만 해도
 * 재생이 끊긴다. 그래서 이 화면은 `Column + verticalScroll` 을 쓴다 — 카드가 몇 장뿐인
 * 피드라면 이 방식이 맞고, 스크롤해도 재생이 유지된다.
 *
 * 실제 앱에서 긴 리스트 안에 넣어야 한다면 뷰를 재사용 대상에서 빼거나(예: 헤더 영역 고정)
 * 화면 밖으로 나갈 때 PIP 로 승격시켜야 한다.
 *
 * ## 화면 밖 자동 PIP 는 앱이 정한다
 * 현재 공개 표면에는 "뷰가 화면을 벗어나면 자동 PIP" 옵션이 없다. 필요하면 아래 ⤡ 버튼처럼
 * 앱이 [cloud.shoplive.player.ShoplivePlayerControlling.enterPictureInPicture] 를 직접 부른다.
 */
@Composable
fun FeedScreen(
    delegate: ShoplivePlayerDelegate,
    campaignKey: String,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val activity = remember(context) { context.findActivity() }
    var isMuted by remember { mutableStateOf(false) }

    Column(
        modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 96.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        FeedCard(
            stringResource(R.string.feed_card1_title),
            stringResource(R.string.feed_card1_desc),
        )

        Tip(stringResource(R.string.feed_tip_embed), TipTone.OK)

        if (activity == null) {
            Tip(stringResource(R.string.feed_warn_activity_context), TipTone.WARN)
        } else if (campaignKey.isBlank()) {
            Tip(stringResource(R.string.feed_warn_no_campaign), TipTone.WARN)
        } else {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { _ ->
                        ShoplivePlayerView(activity).apply {
                            this.delegate = delegate

                            // 파괴 시 자원 해제를 lifecycle 에 맡긴다.
                            bindLifecycle(lifecycleOwner)

                            // configuration 은 재생 시작 전에만 반영된다.
                            // 인라인 프리뷰는 PREVIEW 로 두면 볼륨키가 막히고 프리뷰
                            // 해상도로 받아 트래픽이 줄어든다.
                            configuration = PlayerConfigurationFactory.from(
                                DemoOptionsStore.current.copy(type = ShoplivePlayerType.PREVIEW)
                            )

                            PlayerSession.attach(this)
                            DemoLog.sdkCall(
                                "ShoplivePlayerView.play(campaignKey: \"$campaignKey\") — embedded"
                            )
                            play(campaignKey)
                        }
                    },
                    onRelease = { view ->
                        PlayerSession.detach(view)
                        view.stop()
                    },
                )

                Row(
                    Modifier
                        .align(Alignment.BottomEnd)
                        .padding(9.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    FilledTonalButton(
                        onClick = {
                            isMuted = !isMuted
                            PlayerSession.setMuted(isMuted)
                        },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(if (isMuted) "🔇" else "🔊")
                    }
                    FilledTonalButton(
                        onClick = { PlayerSession.enterPictureInPicture() },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            stringResource(R.string.feed_btn_pip),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                    FilledTonalButton(
                        onClick = {
                            val view = PlayerSession.current as? ShoplivePlayerView
                            if (view == null) {
                                DemoLog.error("expandToFullScreen() — no embedded view handle.")
                            } else {
                                DemoLog.sdkCall("expandToFullScreen() — promote to full screen")
                                view.expandToFullScreen()
                            }
                        },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            stringResource(R.string.feed_btn_fullscreen),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                }
            }
        }

        FeedCard(
            stringResource(R.string.feed_card2_title),
            stringResource(R.string.feed_card2_desc),
        )
        FeedCard(
            stringResource(R.string.feed_card3_title),
            stringResource(R.string.feed_card3_desc),
        )
        FeedCard(
            stringResource(R.string.feed_card4_title),
            stringResource(R.string.feed_card4_desc),
        )

        Tip(stringResource(R.string.feed_warn_expand_restream), TipTone.WARN)
    }

    // 화면을 떠날 때 남은 핸들을 정리한다.
    DisposableEffect(Unit) {
        onDispose {
            (PlayerSession.current as? ShoplivePlayerView)?.let { PlayerSession.detach(it) }
        }
    }
}

@Composable
private fun FeedCard(title: String, description: String) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Row(
            Modifier.padding(13.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
            Spacer(Modifier.size(11.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleSmall)
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/** Context 체인을 거슬러 host Activity 를 찾는다. */
internal tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
