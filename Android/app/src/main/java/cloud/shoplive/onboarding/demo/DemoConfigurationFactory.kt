package cloud.shoplive.onboarding.demo

import android.graphics.Typeface
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.ChatInputFont
import cloud.shoplive.onboarding.data.DemoOptions
import cloud.shoplive.onboarding.data.LoadingAnimation
import cloud.shoplive.player.ShopliveInsets
import cloud.shoplive.player.ShoplivePlayOptions
import cloud.shoplive.player.ShoplivePlayerConfiguration

/**
 * Demo-only: maps **every** control in the options tab onto its configuration field.
 *
 * ## Why this is not in `:integration`
 * This is the trap worth naming. "Assembling a configuration" looks like one job,
 * but it is two:
 *
 * - *Examples a customer would copy* — `branded()`, `overlayHidden()`,
 *   `embeddedPreview()`. Those live in
 *   [cloud.shoplive.onboarding.integration.ShoplivePlayerPresets].
 * - *Reflecting a demo screen's mutable state into all fields at once* — this file.
 *   It exists so a developer can flip any field and replay, which no customer app
 *   wants. It is bound to [DemoOptions] and to this app's drawables, so it is
 *   harness by definition.
 *
 * The iOS refactor put the equivalent function in the copy-paste set, and only the
 * isolated compile target caught it.
 */
object DemoConfigurationFactory {

    /** Turns the current options-tab state into a configuration. */
    fun from(options: DemoOptions): ShoplivePlayerConfiguration =
        ShoplivePlayerConfiguration(
            // LIVE / PREVIEW — decides the volume-key policy and receive resolution.
            type = options.type,

            pip = pip(options),

            sound = ShoplivePlayerConfiguration.SoundOptions(
                muteOnStart = options.muteOnStart,
                mixWithOthers = options.mixWithOthers,
                autoResumeOnFocusGained = options.autoResumeOnFocusGained,
                // null follows the type default (LIVE=true, PREVIEW=false).
                isVolumeKeyEnabled = options.isVolumeKeyEnabled,
            ),

            appearance = ShoplivePlayerConfiguration.AppearanceOptions(
                indicatorColor = options.indicatorColor.argb,
                loadingAnimation = when (options.loadingAnimation) {
                    LoadingAnimation.SDK_DEFAULT -> null
                    LoadingAnimation.DEMO_CUSTOM -> R.drawable.ic_demo_loading
                },
                isStatusBarVisible = options.isStatusBarVisible,
                chatInputTypeface = when (options.chatInputFont) {
                    ChatInputFont.SDK_DEFAULT -> null
                    ChatInputFont.BOLD -> Typeface.DEFAULT_BOLD
                    ChatInputFont.MONOSPACE -> Typeface.MONOSPACE
                },
                // false makes the SDK set FLAG_SECURE, blacking out screenshots
                // and mirroring.
                allowScreenCapture = options.allowScreenCapture,
            ),

            navigation = ShoplivePlayerConfiguration.NavigationOptions(
                actionOnNavigation = options.actionOnNavigation,
                shareScheme = options.shareScheme.takeIf { it.isNotBlank() },
                closeWhenAppDestroyed = options.closeWhenAppDestroyed,
            ),

            overlay = ShoplivePlayerConfiguration.OverlayOptions(
                ui = options.overlayUI,
            ),

            // Extra query parameters appended to the overlay URL.
            customParameters = options.customParameters,
        )

    private fun pip(options: DemoOptions): ShoplivePlayerConfiguration.PipOptions =
        ShoplivePlayerConfiguration.PipOptions(
            isInAppPipEnabled = options.isInAppPipEnabled,
            isOSPipEnabled = options.isOSPipEnabled,
            enterOSPipOnBackPressed = options.enterOSPipOnBackPressed,
            defaultPosition = options.pipPosition,
            scale = options.pipScale,
            aspectRatio = options.pipAspectRatio,
            padding = ShopliveInsets.all(options.pipPaddingDp),
        )

    /** Per-playback options, which may differ on every `start()` / `play()`. */
    fun playOptions(options: DemoOptions, referrerOverride: String? = null): ShoplivePlayOptions =
        ShoplivePlayOptions(
            referrer = (referrerOverride ?: options.referrer).takeIf { it.isNotBlank() },
            keepWindowStateOnPlayExecuted = options.keepWindowStateOnPlayExecuted,
        )
}
