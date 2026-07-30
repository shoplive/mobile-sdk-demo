package cloud.shoplive.onboarding.ui.devtools

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.data.DevSheetTab

/**
 * V1 — 개발자 시트.
 *
 * 확인에 필요한 두 가지를 **한 시트 두 탭**으로 합쳤다.
 * - 로그: 무슨 이벤트가 오는지
 * - 옵션: 옵션을 바꾸면 어떻게 달라지는지
 *
 * 데모앱 화면(기능 목록·홈 피드)에서 ⌗ 버튼으로 열린다. SDK 가 소유한 플레이어·스튜디오
 * 화면 **위에는 뜨지 않는다** — 그 동안의 이벤트는 로그에 쌓이므로 돌아와서 확인한다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DevSheet(
    selectedTab: DevSheetTab,
    onSelectTab: (DevSheetTab) -> Unit,
    onDismiss: () -> Unit,
    onReplayWithOptions: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val entries by DemoLog.entries.collectAsStateWithLifecycle()
    val options by DemoOptionsStore.options.collectAsStateWithLifecycle()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(Modifier.fillMaxHeight(0.9f)) {
            TabRow(selectedTabIndex = selectedTab.ordinal) {
                Tab(
                    selected = selectedTab == DevSheetTab.LOG,
                    onClick = { onSelectTab(DevSheetTab.LOG) },
                    text = { Text(stringResource(R.string.tab_event_log), style = MaterialTheme.typography.titleSmall) },
                )
                Tab(
                    selected = selectedTab == DevSheetTab.OPTIONS,
                    onClick = { onSelectTab(DevSheetTab.OPTIONS) },
                    text = { Text(stringResource(R.string.tab_options), style = MaterialTheme.typography.titleSmall) },
                )
            }

            when (selectedTab) {
                DevSheetTab.LOG -> LogTab(
                    entries = entries,
                    modifier = Modifier.fillMaxWidth(),
                )

                DevSheetTab.OPTIONS -> OptionsTab(
                    options = options,
                    onChange = { transform -> DemoOptionsStore.update(transform) },
                    onReplay = onReplayWithOptions,
                    onReset = {
                        DemoOptionsStore.reset()
                        DemoLog.sdkCall("configuration reset to defaults")
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp),
                )
            }
        }
    }
}
