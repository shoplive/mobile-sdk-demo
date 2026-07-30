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
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.sdk.PlayerSession
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.theme.Brand
import cloud.shoplive.player.ShopliveNavigationAction

/**
 * V2 — 상품 상세.
 *
 * `navigation(url)` 요청을 앱이 라우팅한 **결과 화면**이다. 수신 URL 을 그대로 노출해
 * "이 URL 을 앱이 받아 이 화면을 열었다"를 눈으로 확인시킨다.
 *
 * 결제·장바구니는 범위 밖이다. 이 화면의 목적은 두 가지뿐이다.
 * 1. navigation 은 앱이 반드시 처리해야 하는 유일한 요청임을 보여준다.
 * 2. `actionOnNavigation` 정책(pip/keep/close)에 따라 플레이어 거동이 달라짐을 보여준다.
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
                    DemoLog.sdkCall("exitPictureInPicture() — returning to full screen")
                    PlayerSession.exitPictureInPicture()
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
