package cloud.shoplive.onboarding.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.ui.theme.Info
import cloud.shoplive.onboarding.ui.theme.MonoStyle
import cloud.shoplive.onboarding.ui.theme.Ok
import cloud.shoplive.onboarding.ui.theme.Warn

enum class TipTone { INFO, WARN, OK }

/** 안내 박스. 프로토타입의 `.tip` / `.tip.w` / `.tip.g` 에 대응한다. */
@Composable
fun Tip(
    text: String,
    tone: TipTone = TipTone.INFO,
    modifier: Modifier = Modifier,
) {
    val accent = when (tone) {
        TipTone.INFO -> Info
        TipTone.WARN -> Warn
        TipTone.OK -> Ok
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(10.dp))
            .background(accent.copy(alpha = 0.10f))
    ) {
        // 왼쪽 강조 바. Row 높이를 텍스트에 맞추려고 IntrinsicSize.Min 을 쓴다.
        Box(
            Modifier
                .width(3.dp)
                .fillMaxHeight()
                .background(accent)
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
        )
    }
}

/** 작은 상태 배지. */
@Composable
fun Pill(
    text: String,
    color: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    background: Color = MaterialTheme.colorScheme.surfaceVariant,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = color,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(background)
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}

/** 미션 번호 원형 배지. */
@Composable
fun NumberBadge(
    label: String,
    background: Color,
    contentColor: Color = Color.White,
) {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.ExtraBold,
            color = contentColor,
        )
    }
}

/** 소스 파일 경로 한 줄. 이 앱과 프로젝트 소스를 잇는 다리다. */
@Composable
fun SourcePathLine(path: String, modifier: Modifier = Modifier) {
    Text(
        text = "📄 $path",
        style = MonoStyle,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier,
    )
}

/** 섹션 제목. */
@Composable
fun GroupLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(top = 14.dp, bottom = 2.dp),
    )
}

/** 키-값 한 줄 (탭하면 값이 순환하는 형태에 쓴다). */
@Composable
fun OptionRow(
    name: String,
    defaultHint: String?,
    modifier: Modifier = Modifier,
    warning: String? = null,
    trailing: @Composable () -> Unit,
) {
    Column(modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(Modifier.weight(1f)) {
                Text(name, style = MonoStyle, color = MaterialTheme.colorScheme.onSurface)
                if (defaultHint != null) {
                    Text(
                        stringResource(R.string.option_default_prefix, defaultHint),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            trailing()
        }
        if (warning != null) {
            Tip(warning, TipTone.WARN, Modifier.padding(top = 6.dp))
        }
    }
}
