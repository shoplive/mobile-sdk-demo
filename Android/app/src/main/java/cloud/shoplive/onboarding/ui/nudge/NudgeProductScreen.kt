package cloud.shoplive.onboarding.ui.nudge

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.integration.ShopliveNudgePreview
import cloud.shoplive.onboarding.integration.ShopliveNudgePreview.HostVisit
import cloud.shoplive.onboarding.integration.ShoplivePlayerSession
import cloud.shoplive.onboarding.integration.isOngoing
import cloud.shoplive.onboarding.ui.MainViewModel
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.feed.findActivity
import cloud.shoplive.player.ShoplivePlayer

/**
 * Nudge-preview mission — the app's own product page with a nudge floating over it.
 *
 * A dedicated screen rather than the product-detail screen, which already has two
 * other jobs: it is where a product tap lands (events mission), and its "exit PIP"
 * button ends the current session. Sharing it would make the nudge collide with both
 * (SMV-1922 contract, hidden responsibility 3).
 *
 * The SDK-facing part is `ShopliveNudgePreview` in `:integration`. What stays here
 * is when to call it: when the page shows ([Lifecycle.Event.ON_RESUME]) and when the
 * page is gone for good ([NudgeViewModel.onCleared]).
 */
@Composable
fun NudgeProductScreen(
    mainViewModel: MainViewModel,
    modifier: Modifier = Modifier,
    // Scoped to this screen's back-stack entry: it survives rotation and is cleared
    // only when the page is popped, which is exactly "the host left".
    nudgeViewModel: NudgeViewModel = viewModel(),
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }

    // Re-checked every time the page shows: first visit, back from full screen,
    // back from another app, after rotation.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        val host = activity ?: return@LifecycleEventEffect
        nudgeViewModel.onHostVisible(
            start = { session -> mainViewModel.startNudge(host, session) },
            newSession = mainViewModel::newNudgeSession,
        )
    }

    Column(
        modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 96.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(240.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Text("👕", style = MaterialTheme.typography.displayMedium)
        }
        Text(stringResource(R.string.product_name), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.product_price), style = MaterialTheme.typography.titleSmall)
        Text(
            stringResource(R.string.nudge_product_desc),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        if (activity == null) {
            Tip(stringResource(R.string.feed_warn_activity_context), TipTone.WARN)
        }
        Tip(stringResource(R.string.nudge_tip_page), TipTone.OK)
        Tip(stringResource(R.string.nudge_tip_reshow))
        Tip(stringResource(R.string.nudge_tip_leave), TipTone.WARN)
    }
}

/**
 * The nudge state of **one** product page: the current [ShopliveNudgePreview.Session]
 * and nothing else. The session holds the player until it closes (only as long as
 * the SDK does anyway) and records the facts the decisions need, so there is one
 * place to read them.
 */
class NudgeViewModel : ViewModel() {

    private var session: ShopliveNudgePreview.Session? = null

    /**
     * False until the page has shown once. This holder lives as long as the page's
     * back-stack entry, so rotation and coming back from another screen are revisits.
     */
    private var hasShown = false

    fun onHostVisible(
        start: (ShopliveNudgePreview.Session) -> ShoplivePlayer,
        newSession: () -> ShopliveNudgePreview.Session,
    ) {
        val current = session
        val own = current?.player
        val isShowing = own?.state?.isOngoing == true
        // Someone else's session (a PIP from the options-tab replay, say) would be
        // closed by re-showing a nudge. Opening the page from its card still starts one.
        val other = ShoplivePlayerSession.current
        val otherSessionOngoing = other != null && other !== own && other.state.isOngoing
        val isFirstVisit = !hasShown
        hasShown = true

        when (ShopliveNudgePreview.onHostVisible(isShowing, current?.closeReason, otherSessionOngoing, isFirstVisit)) {
            HostVisit.START -> {
                val next = newSession()
                session = next
                start(next)
            }

            HostVisit.ALREADY_SHOWING ->
                DemoLog.event("nudge: still showing on this page — not started again")

            HostVisit.OTHER_SESSION_ONGOING ->
                DemoLog.event("nudge: another session is up (${other?.state}) — not started, it would close that session")

            HostVisit.CLOSED_BY_VIEWER ->
                DemoLog.event("nudge: closed by the viewer (USER_ACTION) on this page — not shown again")
        }
    }

    /** The page was popped (rotation does not get here). */
    override fun onCleared() {
        session?.let(ShopliveNudgePreview::onHostLeft)
    }
}
