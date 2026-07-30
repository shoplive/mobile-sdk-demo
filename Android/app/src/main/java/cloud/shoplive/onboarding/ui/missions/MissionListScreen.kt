package cloud.shoplive.onboarding.ui.missions

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.MISSIONS
import cloud.shoplive.onboarding.data.Mission
import cloud.shoplive.onboarding.ui.components.NumberBadge
import cloud.shoplive.onboarding.ui.components.Pill
import cloud.shoplive.onboarding.ui.components.SourcePathLine
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.theme.Ok

/**
 * S2 — 기능 목록. 앱의 사실상 유일한 메뉴.
 *
 * **카드 탭 = 즉시 실행.** 설명·단계·코드를 보여주는 중간 화면을 두지 않는다. 번호는
 * 연동 가이드의 Mission 번호와 같고, 카드의 파일 경로가 앱과 프로젝트 소스를 잇는
 * 유일한 다리다.
 *
 * "확인됨" 은 SDK 이벤트로 **자동 판정**된다 — 사용자가 체크할 것은 없다.
 */
@Composable
fun MissionListScreen(
    doneMissions: Set<Int>,
    lockReasonOf: (Mission) -> String?,
    onMissionClick: (Mission) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 96.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        item {
            Tip(stringResource(R.string.mission_list_tip))
        }

        items(MISSIONS, key = { it.number }) { mission ->
            MissionCard(
                mission = mission,
                isDone = mission.number in doneMissions,
                lockReason = lockReasonOf(mission),
                onClick = { onMissionClick(mission) },
            )
        }

        item {
            Spacer(Modifier.height(4.dp))
            Tip(stringResource(R.string.mission_list_code_tip), TipTone.OK)
        }

        item {
            Tip(stringResource(R.string.mission_list_sdk_screen_tip), TipTone.WARN)
        }
    }
}

@Composable
private fun MissionCard(
    mission: Mission,
    isDone: Boolean,
    lockReason: String?,
    onClick: () -> Unit,
) {
    val isLocked = lockReason != null

    Card(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 13.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                NumberBadge(
                    label = if (isDone) "✓" else mission.number.toString(),
                    background = when {
                        isDone -> Ok
                        isLocked -> MaterialTheme.colorScheme.outline
                        else -> MaterialTheme.colorScheme.onSurface
                    },
                    contentColor = if (isLocked && !isDone) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MaterialTheme.colorScheme.surface
                    },
                )

                Spacer(Modifier.width(11.dp))

                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(mission.titleRes),
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        stringResource(mission.descriptionRes),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(6.dp))
                    SourcePathLine(mission.sourcePath)
                }

                Spacer(Modifier.width(8.dp))

                when {
                    isDone -> Pill(
                        text = stringResource(R.string.badge_confirmed),
                        color = Ok,
                        background = Ok.copy(alpha = 0.14f),
                    )

                    isLocked -> Icon(
                        Icons.Default.Lock,
                        contentDescription = stringResource(R.string.cd_locked),
                        tint = MaterialTheme.colorScheme.outline,
                    )

                    else -> Icon(
                        Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.outline,
                    )
                }
            }

            if (lockReason != null) {
                Spacer(Modifier.height(9.dp))
                Tip(stringResource(R.string.lock_message, lockReason), TipTone.WARN)
            }
        }
    }
}

/** 모드 표시 바. 어떤 자격증명으로 도는 중인지 항상 보이게 둔다. */
@Composable
fun ModeBar(text: String, isOwnMode: Boolean, modifier: Modifier = Modifier) {
    val tone = if (isOwnMode) Ok else MaterialTheme.colorScheme.primary
    Box(
        modifier
            .fillMaxWidth()
            .background(tone.copy(alpha = 0.12f))
            .padding(vertical = 3.dp),
    ) {
        Text(
            text,
            style = MaterialTheme.typography.labelSmall,
            color = tone,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
