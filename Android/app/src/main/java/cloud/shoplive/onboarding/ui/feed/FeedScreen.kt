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
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.demo.DemoConfigurationFactory
import cloud.shoplive.onboarding.integration.ShoplivePlayerSession
import cloud.shoplive.onboarding.integration.createEmbeddedPlayer
import cloud.shoplive.onboarding.integration.expandEmbeddedToFullScreen
import cloud.shoplive.onboarding.integration.releaseEmbeddedPlayer
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.player.ShoplivePlayerDelegate
import cloud.shoplive.player.ShoplivePlayerType
import cloud.shoplive.player.ShoplivePlayerView

/**
 * Mission 4 — embedded in one of the app's own screens.
 *
 * `ShoplivePlayerView` goes straight into the app layout. **The app owns only the
 * layout**; control, events and PIP use the **same API** as full screen
 * ([cloud.shoplive.player.ShoplivePlayerControlling]).
 *
 * The SDK-facing part — create the view, configure it, start playing, release it —
 * is `createEmbeddedPlayer` in `:integration`, written in plain View code so that an
 * XML-based customer app can copy it. What stays here is the Compose glue and the
 * demo's cards.
 *
 * ## Why not LazyColumn (important)
 * `ShoplivePlayerView` **releases its resources when it leaves the window**
 * (`onDetachedFromWindow`). LazyColumn discards off-screen items, so a player used as
 * a lazy item stops playing the moment you scroll. Hence `Column + verticalScroll` —
 * right for a feed of a few cards, and playback survives scrolling.
 *
 * For a long list in a real app, keep the view out of the recycling pool (a fixed
 * header, for instance) or promote it to PIP as it scrolls away.
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
                        createEmbeddedPlayer(
                            activity = activity,
                            lifecycleOwner = lifecycleOwner,
                            campaignKey = campaignKey,
                            delegate = delegate,
                            // The demo keeps the options tab in charge of every
                            // field, forcing PREVIEW for the inline case. A customer
                            // app would use ShoplivePlayerPresets.embeddedPreview().
                            configuration = DemoConfigurationFactory.from(
                                DemoOptionsStore.current.copy(type = ShoplivePlayerType.PREVIEW)
                            ),
                        )
                    },
                    onRelease = { view -> releaseEmbeddedPlayer(view) },
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
                            ShoplivePlayerSession.setMuted(isMuted)
                        },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(if (isMuted) "🔇" else "🔊")
                    }
                    FilledTonalButton(
                        onClick = { ShoplivePlayerSession.enterPictureInPicture() },
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            stringResource(R.string.feed_btn_pip),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                    FilledTonalButton(
                        onClick = { expandEmbeddedToFullScreen() },
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

    // Clean up any handle left behind when leaving the screen.
    DisposableEffect(Unit) {
        onDispose {
            (ShoplivePlayerSession.current as? ShoplivePlayerView)
                ?.let { ShoplivePlayerSession.detach(it) }
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

/** Walks up the context chain to find the host Activity. */
internal tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
