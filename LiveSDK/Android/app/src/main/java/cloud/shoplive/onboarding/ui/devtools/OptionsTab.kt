package cloud.shoplive.onboarding.ui.devtools

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.ChatInputFont
import cloud.shoplive.onboarding.data.DemoOptions
import cloud.shoplive.onboarding.data.IndicatorColor
import cloud.shoplive.onboarding.data.LoadingAnimation
import cloud.shoplive.onboarding.integration.ShoplivePlayerSession
import cloud.shoplive.onboarding.ui.components.GroupLabel
import cloud.shoplive.onboarding.ui.components.OptionRow
import cloud.shoplive.onboarding.ui.components.Tip
import cloud.shoplive.onboarding.ui.components.TipTone
import cloud.shoplive.player.ShopliveNavigationAction
import cloud.shoplive.player.ShopliveOverlayUIMode
import cloud.shoplive.player.ShoplivePipPosition
import cloud.shoplive.player.ShoplivePipRatio
import cloud.shoplive.player.ShoplivePlayerType
import cloud.shoplive.player.ShopliveResizeMode

/**
 * The options tab.
 *
 * **Every field of `ShoplivePlayerConfiguration` has exactly one control here**,
 * including the ones no mission uses — being able to try all of them is the whole
 * reason this screen exists.
 *
 * Each row shows the SDK default next to the current value, which is how "you do not
 * have to specify anything" becomes visible.
 *
 * A configuration is immutable and only read before playback starts, so after changing
 * a value you have to start a new session with "replay with these options" at the
 * bottom. The only group that applies immediately is "control" (runtime properties).
 */
@Composable
fun OptionsTab(
    options: DemoOptions,
    onChange: ((DemoOptions) -> DemoOptions) -> Unit,
    onReplay: () -> Unit,
    onReset: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var showAdvanced by remember { mutableStateOf(false) }

    Column(
        modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
            .padding(bottom = 24.dp),
    ) {
        // ── Playback shape ───────────────────────────────────────────────────
        GroupLabel(stringResource(R.string.group_playback_type))
        Tip(stringResource(R.string.tip_playback_type))
        CycleOption(
            name = "type",
            defaultHint = "LIVE",
            value = options.type.name,
            onTap = {
                onChange { it.copy(type = it.type.next(ShoplivePlayerType.entries)) }
            },
        )

        // ── Authentication (Mission 3) ───────────────────────────────────────
        GroupLabel(stringResource(R.string.group_auth))
        Tip(stringResource(R.string.tip_auth))

        // ── PIP (Mission 5) ──────────────────────────────────────────────────
        GroupLabel(stringResource(R.string.group_pip))
        SwitchOption(
            name = "pip.isInAppPipEnabled",
            defaultHint = "true",
            checked = options.isInAppPipEnabled,
            onChange = { v -> onChange { it.copy(isInAppPipEnabled = v) } },
        )
        SwitchOption(
            name = "pip.isOSPipEnabled",
            defaultHint = "true",
            checked = options.isOSPipEnabled,
            onChange = { v -> onChange { it.copy(isOSPipEnabled = v) } },
            warning = stringResource(R.string.warn_os_pip_activity_only),
        )
        SwitchOption(
            name = "pip.enterOSPipOnBackPressed",
            defaultHint = "false",
            checked = options.enterOSPipOnBackPressed,
            onChange = { v -> onChange { it.copy(enterOSPipOnBackPressed = v) } },
        )
        CycleOption(
            name = "pip.defaultPosition",
            defaultHint = "BOTTOM_RIGHT",
            value = options.pipPosition.name,
            onTap = {
                onChange { it.copy(pipPosition = it.pipPosition.next(ShoplivePipPosition.entries)) }
            },
        )
        SliderOption(
            name = "pip.scale",
            defaultHint = "0.4",
            value = options.pipScale,
            range = 0.2f..0.8f,
            steps = 11,
            onChange = { v -> onChange { it.copy(pipScale = v) } },
        )
        CycleOption(
            name = "pip.aspectRatio",
            defaultHint = "RATIO_9X16",
            value = options.pipAspectRatio.name,
            onTap = {
                onChange {
                    it.copy(pipAspectRatio = it.pipAspectRatio.next(ShoplivePipRatio.entries))
                }
            },
        )
        CycleOption(
            name = "pip.padding",
            defaultHint = "0dp",
            value = "${options.pipPaddingDp}dp",
            onTap = {
                onChange { it.copy(pipPaddingDp = (it.pipPaddingDp + 8) % 32) }
            },
        )
        CycleOption(
            name = "navigation.actionOnNavigation",
            defaultHint = "PIP",
            value = options.actionOnNavigation.name,
            onTap = {
                onChange {
                    it.copy(
                        actionOnNavigation = it.actionOnNavigation.next(
                            ShopliveNavigationAction.entries
                        )
                    )
                }
            },
        )

        // ── Overlay and appearance (Mission 7) ───────────────────────────────
        GroupLabel(stringResource(R.string.group_overlay_appearance))
        CycleOption(
            name = "overlay.ui",
            defaultHint = "BUILT_IN",
            value = options.overlayUI.name,
            onTap = {
                onChange { it.copy(overlayUI = it.overlayUI.next(ShopliveOverlayUIMode.entries)) }
            },
            warning = stringResource(R.string.warn_overlay_hidden),
        )
        CycleOption(
            name = "appearance.indicatorColor",
            defaultHint = "white",
            value = options.indicatorColor.labelRes
                ?.let { stringResource(it) }
                ?: options.indicatorColor.literalLabel.orEmpty(),
            onTap = {
                onChange { it.copy(indicatorColor = it.indicatorColor.next(IndicatorColor.entries)) }
            },
        )
        CycleOption(
            name = "appearance.loadingAnimation",
            defaultHint = stringResource(R.string.value_null_sdk_default),
            value = stringResource(options.loadingAnimation.labelRes),
            onTap = {
                onChange {
                    it.copy(loadingAnimation = it.loadingAnimation.next(LoadingAnimation.entries))
                }
            },
        )
        SwitchOption(
            name = "appearance.isStatusBarVisible",
            defaultHint = "true",
            checked = options.isStatusBarVisible,
            onChange = { v -> onChange { it.copy(isStatusBarVisible = v) } },
        )
        SwitchOption(
            name = "sound.muteOnStart",
            defaultHint = "false",
            checked = options.muteOnStart,
            onChange = { v -> onChange { it.copy(muteOnStart = v) } },
            warning = stringResource(R.string.warn_mute_on_start),
        )

        // ── Control (runtime properties) ─────────────────────────────────────
        GroupLabel(stringResource(R.string.group_control))
        Tip(stringResource(R.string.tip_control_runtime), TipTone.OK)
        SwitchOption(
            name = "isMuted",
            defaultHint = "sound.muteOnStart",
            checked = options.muteOnStart,
            onChange = { v ->
                ShoplivePlayerSession.setMuted(v)
                onChange { it.copy(muteOnStart = v) }
            },
        )
        CycleOption(
            name = "resizeMode",
            defaultHint = "FILL",
            value = options.resizeMode.name,
            onTap = {
                onChange { current ->
                    val next = current.resizeMode.next(ShopliveResizeMode.entries)
                    ShoplivePlayerSession.setResizeMode(next)
                    current.copy(resizeMode = next)
                }
            },
        )
        ActionRow("reload()", stringResource(R.string.action_call)) { ShoplivePlayerSession.reload() }
        ActionRow("send(command:)", stringResource(R.string.action_send)) {
            ShoplivePlayerSession.send("HIGHLIGHT_PRODUCT", mapOf("sku" to "A-1024"))
        }
        ActionRow("enterPictureInPicture()", stringResource(R.string.action_enter)) {
            ShoplivePlayerSession.enterPictureInPicture()
        }
        ActionRow("exitPictureInPicture()", stringResource(R.string.action_exit)) {
            ShoplivePlayerSession.exitPictureInPicture()
        }
        ActionRow("stop()", stringResource(R.string.action_stop)) { ShoplivePlayerSession.stop() }

        // ── Advanced — every remaining field ─────────────────────────────────
        Spacer(Modifier.height(10.dp))
        HorizontalDivider()
        Text(
            text = stringResource(
                if (showAdvanced) R.string.advanced_collapse else R.string.advanced_expand
            ),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showAdvanced = !showAdvanced }
                .padding(vertical = 12.dp),
        )

        if (showAdvanced) {
            SwitchOption(
                name = "sound.mixWithOthers",
                defaultHint = "false",
                checked = options.mixWithOthers,
                onChange = { v -> onChange { it.copy(mixWithOthers = v) } },
            )
            SwitchOption(
                name = "sound.autoResumeOnFocusGained",
                defaultHint = "true",
                checked = options.autoResumeOnFocusGained,
                onChange = { v -> onChange { it.copy(autoResumeOnFocusGained = v) } },
            )
            CycleOption(
                name = "sound.isVolumeKeyEnabled",
                defaultHint = stringResource(R.string.value_null_by_type),
                value = when (options.isVolumeKeyEnabled) {
                    null -> "null → ${options.type == ShoplivePlayerType.LIVE}"
                    else -> options.isVolumeKeyEnabled.toString()
                },
                onTap = {
                    onChange {
                        it.copy(
                            isVolumeKeyEnabled = when (it.isVolumeKeyEnabled) {
                                null -> true
                                true -> false
                                false -> null
                            }
                        )
                    }
                },
            )
            CycleOption(
                name = "appearance.chatInputTypeface",
                defaultHint = stringResource(R.string.value_null_sdk_default),
                value = options.chatInputFont.labelRes
                    ?.let { stringResource(it) }
                    ?: options.chatInputFont.literalLabel.orEmpty(),
                onTap = {
                    onChange { it.copy(chatInputFont = it.chatInputFont.next(ChatInputFont.entries)) }
                },
            )
            SwitchOption(
                name = "appearance.allowScreenCapture",
                defaultHint = "true",
                checked = options.allowScreenCapture,
                onChange = { v -> onChange { it.copy(allowScreenCapture = v) } },
                warning = stringResource(R.string.warn_allow_screen_capture),
            )
            CycleOption(
                name = "navigation.shareScheme",
                defaultHint = "null",
                value = options.shareScheme.ifBlank { "null" },
                onTap = {
                    onChange {
                        it.copy(
                            shareScheme = if (it.shareScheme.isBlank()) "shoplivedemo://share" else ""
                        )
                    }
                },
            )
            SwitchOption(
                name = "navigation.closeWhenAppDestroyed",
                defaultHint = "true",
                checked = options.closeWhenAppDestroyed,
                onChange = { v -> onChange { it.copy(closeWhenAppDestroyed = v) } },
            )
            CycleOption(
                name = "customParameters",
                defaultHint = "{}",
                value = if (options.customParameters.isEmpty()) "{}" else options.customParameters.toString(),
                onTap = {
                    onChange {
                        it.copy(
                            customParameters = if (it.customParameters.isEmpty()) {
                                mapOf("tier" to "vip")
                            } else {
                                emptyMap()
                            }
                        )
                    }
                },
            )

            GroupLabel(stringResource(R.string.group_play_options))
            Tip(stringResource(R.string.tip_play_options))
            CycleOption(
                name = "PlayOptions.referrer",
                defaultHint = "null",
                value = options.referrer.ifBlank { "null" },
                onTap = {
                    onChange {
                        it.copy(referrer = if (it.referrer.isBlank()) "demo_referrer" else "")
                    }
                },
            )
            SwitchOption(
                name = "PlayOptions.keepWindowStateOnPlayExecuted",
                defaultHint = "false",
                checked = options.keepWindowStateOnPlayExecuted,
                onChange = { v -> onChange { it.copy(keepWindowStateOnPlayExecuted = v) } },
            )

            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.advanced_note),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onReplay,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text(stringResource(R.string.btn_replay_with_options), style = MaterialTheme.typography.titleSmall)
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = onReset,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text(stringResource(R.string.btn_reset_defaults), style = MaterialTheme.typography.bodySmall)
        }
    }
}

// ── Row components ──────────────────────────────────────────────────────────

@Composable
private fun SwitchOption(
    name: String,
    defaultHint: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    warning: String? = null,
) {
    OptionRow(name = name, defaultHint = defaultHint, warning = warning) {
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun CycleOption(
    name: String,
    defaultHint: String,
    value: String,
    onTap: () -> Unit,
    warning: String? = null,
) {
    OptionRow(name = name, defaultHint = defaultHint, warning = warning) {
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier
                .clickable(onClick = onTap)
                .padding(horizontal = 8.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun SliderOption(
    name: String,
    defaultHint: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    onChange: (Float) -> Unit,
) {
    Column {
        OptionRow(name = name, defaultHint = defaultHint) {
            Text(
                text = String.format(java.util.Locale.US, "%.2f", value),
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            steps = steps,
        )
    }
}

@Composable
private fun ActionRow(name: String, actionLabel: String, onClick: () -> Unit) {
    OptionRow(name = name, defaultHint = null) {
        Text(
            text = actionLabel,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier
                .clickable(onClick = onClick)
                .padding(horizontal = 8.dp, vertical = 6.dp),
        )
    }
}

/** Cycles an enum value to the next one. */
private fun <T : Enum<T>> T.next(all: List<T>): T = all[(all.indexOf(this) + 1) % all.size]
