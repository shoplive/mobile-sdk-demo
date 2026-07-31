package cloud.shoplive.onboarding.ui.product

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.integration.ShoplivePlayerSession
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.theme.Brand
import cloud.shoplive.player.ShopliveNavigationAction

/**
 * The product detail screen.
 *
 * This is the **result** of the app routing a `navigation(url)` request. It shows the
 * received URL verbatim, so that "the app got this URL and opened this screen" is
 * visible rather than assumed.
 *
 * Checkout and cart are out of scope. The screen exists for two things only:
 * 1. navigation is the one request the app must handle.
 * 2. the `actionOnNavigation` policy (pip/keep/close) changes what the player does.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductDetailScreen(
    receivedUrl: String,
    onClose: () -> Unit,
) {
    val options by DemoOptionsStore.options.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(R.string.product_toolbar_title),
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
                actions = {
                    IconButton(onClick = onClose) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = stringResource(R.string.cd_close),
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Tip(stringResource(R.string.product_tip_result), TipTone.OK)

            Column {
                Text(
                    stringResource(R.string.product_received_url),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    receivedUrl,
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )

            Text(stringResource(R.string.product_name), style = MaterialTheme.typography.titleMedium)
            Text(
                stringResource(R.string.product_price),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.ExtraBold,
                color = Brand,
            )

            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Text(
                        "actionOnNavigation",
                        style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    )
                    Text(
                        stringResource(R.string.product_action_default),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    options.actionOnNavigation.name,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Tip(
                stringResource(
                    when (options.actionOnNavigation) {
                        ShopliveNavigationAction.PIP -> R.string.product_action_pip_desc
                        ShopliveNavigationAction.KEEP -> R.string.product_action_keep_desc
                        ShopliveNavigationAction.CLOSE -> R.string.product_action_close_desc
                    }
                )
            )

            Tip(stringResource(R.string.product_warn_required), TipTone.WARN)

            Spacer(Modifier.height(4.dp))

            OutlinedButton(
                onClick = {
                    // The call is logged by ShoplivePlayerSession itself.
                    ShoplivePlayerSession.exitPictureInPicture()
                    onClose()
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(stringResource(R.string.product_btn_exit_pip))
            }

            Tip(stringResource(R.string.product_tip_policy), TipTone.INFO)
        }
    }
}
