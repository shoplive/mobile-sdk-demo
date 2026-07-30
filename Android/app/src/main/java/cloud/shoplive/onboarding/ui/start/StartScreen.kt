package cloud.shoplive.onboarding.ui.start

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoMode
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.ui.MainViewModel
import cloud.shoplive.onboarding.ui.feed.findActivity
import cloud.shoplive.onboarding.ui.components.Pill
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.onboarding.ui.theme.Brand

/**
 * S1 — 시작.
 *
 * 입력 없이 바로 볼 길과 내 키로 확인할 길을 **한 화면에서** 고른다. 입력 폼은 접힌 상태가
 * 기본이라 "둘러보기" 가 먼저 눈에 들어온다. 인증 방식(guest/profile/token)은 여기서
 * 묻지 않는다 — Mission 3 에서 고른다.
 */
@Composable
fun StartScreen(
    viewModel: MainViewModel,
    isEncryptedStorage: Boolean,
    onProceed: () -> Unit,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(top = 40.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .size(54.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(Brand),
            contentAlignment = Alignment.Center,
        ) {
            Text("▶", color = Color.White, style = MaterialTheme.typography.headlineSmall)
        }

        LanguageSwitcher()

        Text(
            stringResource(R.string.start_title),
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            stringResource(R.string.start_subtitle),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.height(4.dp))

        Button(
            onClick = { if (viewModel.startTour(context)) onProceed() },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(13.dp),
        ) {
            Text(stringResource(R.string.start_tour_button), style = MaterialTheme.typography.titleMedium)
        }
        Text(
            stringResource(
                if (viewModel.hasDemoKeys) {
                    R.string.start_tour_hint_ready
                } else {
                    R.string.start_tour_hint_missing
                }
            ),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        OutlinedButton(
            onClick = viewModel::toggleOwnForm,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(13.dp),
        ) {
            Text(
                stringResource(
                    R.string.start_own_button,
                    if (state.ownFormExpanded) "▲" else "▼",
                ),
                style = MaterialTheme.typography.titleMedium,
            )
        }

        if (state.ownFormExpanded) {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                shape = RoundedCornerShape(14.dp),
            ) {
                Column(
                    Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Tip(stringResource(R.string.start_own_tip))

                    KeyField(
                        label = stringResource(R.string.field_access_key),
                        value = state.accessKeyInput,
                        onValueChange = viewModel::onAccessKeyChange,
                        hint = stringResource(R.string.field_access_key_hint),
                    )
                    KeyField(
                        label = stringResource(R.string.field_campaign_key),
                        value = state.campaignKeyInput,
                        onValueChange = viewModel::onCampaignKeyChange,
                        hint = stringResource(R.string.field_campaign_key_hint),
                    )
                    KeyField(
                        label = stringResource(R.string.field_stream_token),
                        value = state.streamTokenInput,
                        onValueChange = viewModel::onStreamTokenChange,
                        hint = stringResource(R.string.field_stream_token_hint),
                        trailingPill = "Mission 8",
                    )
                    KeyField(
                        label = stringResource(R.string.field_user_jwt),
                        value = state.userJwtInput,
                        onValueChange = viewModel::onUserJwtChange,
                        hint = stringResource(R.string.field_user_jwt_hint),
                        trailingPill = "Mission 3",
                    )
                }
            }

            Button(
                onClick = { if (viewModel.startOwn(context)) onProceed() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(13.dp),
            ) {
                Text(stringResource(R.string.start_validate_button), style = MaterialTheme.typography.titleMedium)
            }

            Tip(stringResource(R.string.start_validation_tip), TipTone.WARN)
        }

        state.validationError?.let { error -> Tip(error, TipTone.WARN) }

        if (state.mode != null) {
            OutlinedButton(
                onClick = onProceed,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(13.dp),
            ) {
                Text(
                    stringResource(
                        R.string.start_back_to_missions,
                        stringResource(
                            if (state.mode == DemoMode.OWN) R.string.mode_label_own else R.string.mode_label_tour
                        ),
                    )
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        Tip(stringResource(R.string.start_code_tip), TipTone.OK)
        Tip(
            stringResource(
                if (isEncryptedStorage) {
                    R.string.start_storage_encrypted
                } else {
                    R.string.start_storage_plain
                }
            ),
            if (isEncryptedStorage) TipTone.INFO else TipTone.WARN,
        )
    }
}

@Composable
private fun KeyField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    hint: String,
    trailingPill: String? = null,
) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (trailingPill != null) {
                Spacer(Modifier.width(6.dp))
                Pill(trailingPill)
            }
        }
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
            shape = RoundedCornerShape(10.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            hint,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

/**
 * 표시 언어 전환. **기본값은 English** 이고 기기 언어를 따르지 않는다.
 *
 * 리소스는 Activity 생성 시점에 확정되므로, 바꾼 뒤 [Activity.recreate] 로 화면을 다시 만든다.
 */
@Composable
private fun LanguageSwitcher() {
    val context = LocalContext.current
    val current = LocaleSetting.current

    Column {
        Text(
            stringResource(R.string.language_label),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(4.dp))
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            LocaleSetting.supported.forEachIndexed { index, language ->
                SegmentedButton(
                    selected = language == current,
                    onClick = {
                        if (language == current) return@SegmentedButton
                        LocaleSetting.set(language)
                        // 언어가 바뀌면 리소스를 다시 읽어야 한다.
                        context.findActivity()?.recreate()
                    },
                    shape = SegmentedButtonDefaults.itemShape(
                        index = index,
                        count = LocaleSetting.supported.size,
                    ),
                ) {
                    Text(language.label, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.language_note),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
