package cloud.shoplive.onboarding.ui.devtools

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.ui.theme.MonoStyle

/**
 * V1 · 로그 탭 — 무슨 이벤트가 오는지 본다.
 *
 * `request` 는 **respond 호출 여부까지** 남긴다. 미응답이 곧 버그임을 눈으로 배우게 하는
 * 것이 이 화면의 목적이다.
 */
@Composable
fun LogTab(
    entries: List<DemoLog.Entry>,
    modifier: Modifier = Modifier,
) {
    val clipboard = LocalClipboardManager.current

    Column(modifier.fillMaxWidth()) {
        if (entries.isEmpty()) {
            Text(
                stringResource(R.string.log_empty),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 28.dp),
            )
        } else {
            LazyColumn(
                Modifier
                    .weight(1f, fill = false)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            ) {
                items(entries) { entry -> LogLine(entry) }
            }
        }

        // 고정 안내 — 로그에 "오지 않는" 두 가지. 없다고 오판하는 것을 막는다.
        Column(
            Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                stringResource(R.string.log_note_engine_switch),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                stringResource(R.string.log_note_auto_recovery),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedButton(
                onClick = { clipboard.setText(AnnotatedString(DemoLog.asPlainText())) },
                modifier = Modifier.weight(1f),
            ) {
                Text(stringResource(R.string.log_copy), style = MaterialTheme.typography.bodySmall)
            }
            OutlinedButton(
                onClick = { DemoLog.clear() },
                modifier = Modifier.weight(1f),
            ) {
                Text(stringResource(R.string.log_clear), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun LogLine(entry: DemoLog.Entry) {
    val (label, color) = when (entry.kind) {
        DemoLog.Kind.EVENT -> "EVENT" to Color(0xFF79C0FF)
        DemoLog.Kind.REQUEST -> "REQUEST" to Color(0xFFFFA657)
        DemoLog.Kind.RESPOND -> "RESPOND" to Color(0xFF7EE787)
        DemoLog.Kind.SDK_CALL -> "→SDK" to Color(0xFF7EE787)
        DemoLog.Kind.ERROR -> "ERROR" to Color(0xFFFF7B72)
    }

    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            entry.timeText,
            style = MonoStyle.copy(fontSize = 10.sp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            label,
            style = MonoStyle.copy(fontSize = 10.sp, fontWeight = FontWeight.Bold),
            color = color,
        )
        Text(
            entry.message + if (entry.repeated > 1) "  (x${entry.repeated})" else "",
            style = MonoStyle.copy(fontSize = 10.sp),
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
    }
}
