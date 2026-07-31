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
 * The developer sheet.
 *
 * The two things needed while verifying, in **one sheet with two tabs**:
 * - log: which events arrive
 * - options: what changes when you change an option
 *
 * Opened with the ⌗ button from the demo's own screens. It **cannot** appear over the
 * SDK-owned player or studio — events arriving during those pile up in the log and are
 * read afterwards.
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
