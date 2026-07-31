package cloud.shoplive.onboarding.ui

import android.app.Activity
import android.content.Context
import android.widget.Toast
import androidx.lifecycle.ViewModel
import cloud.shoplive.onboarding.BuildConfig
import cloud.shoplive.onboarding.DemoContainer
import cloud.shoplive.onboarding.ProductRouter
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoMode
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.data.DevSheetTab
import cloud.shoplive.onboarding.data.Mission
import cloud.shoplive.onboarding.data.MissionRun
import cloud.shoplive.onboarding.data.missionOf
import cloud.shoplive.onboarding.demo.DemoConfigurationFactory
import cloud.shoplive.onboarding.demo.DemoLabels
import cloud.shoplive.onboarding.integration.ShopliveDeepLinkRouter
import cloud.shoplive.onboarding.integration.ShopliveFailure
import cloud.shoplive.onboarding.integration.ShopliveInitializer
import cloud.shoplive.onboarding.integration.ShoplivePlayerEventLogger
import cloud.shoplive.onboarding.integration.ShoplivePlayerLauncher
import cloud.shoplive.onboarding.integration.ShopliveStudioLauncher
import cloud.shoplive.onboarding.integration.ShopliveUserSetup
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Screen state and the "tap a card, it runs" flow.
 *
 * Running a mission calls the SDK directly, with no screen in between. There are no
 * explanation or code-listing screens — the code is read in the project sources, and
 * the app is for watching it behave.
 *
 * This class is also where the demo meets the copy-paste layer: it supplies the
 * callbacks `:integration` asks for (navigate, failure, milestone, coupon text) and
 * keeps every piece of demo state on this side of the line.
 */
class MainViewModel : ViewModel() {

    data class UiState(
        val mode: DemoMode? = null,
        val accessKeyInput: String = "",
        val campaignKeyInput: String = "",
        val streamTokenInput: String = "",
        val userJwtInput: String = "",
        val ownFormExpanded: Boolean = false,
        val authMethod: ShopliveUserSetup.Method = ShopliveUserSetup.Method.GUEST,
        /** Whether the auth-method sheet is showing. */
        val askAuthMethod: Boolean = false,
        /** Whether the fake push banner is showing. */
        val showPushBanner: Boolean = false,
        val devSheetTab: DevSheetTab? = null,
        val message: String? = null,
        /** Why the start screen rejected the input. */
        val validationError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val credentials get() = DemoContainer.credentials
    private val progress get() = DemoContainer.progress

    val doneMissions get() = progress.done

    /**
     * One event receiver, reused, so the log does not split into several streams.
     *
     * The four callbacks below are everything the copy-paste layer needs from this
     * app. Note what each one keeps on this side: routing (the app's Activity),
     * localized text (the app's resources), mission progress (demo-only state).
     */
    private val playerDelegate = ShoplivePlayerEventLogger(
        onNavigation = { url -> ProductRouter.open(url) },
        onFailure = { failure -> reportFailure(failure) },
        onMilestone = { milestone -> progress.record(milestone) },
        couponMessage = { DemoContainer.string(R.string.coupon_issued) },
    )

    init {
        _state.value = UiState(
            mode = credentials.mode,
            accessKeyInput = credentials.accessKey,
            campaignKeyInput = credentials.campaignKey,
            streamTokenInput = credentials.streamToken,
            userJwtInput = credentials.userJwt,
            ownFormExpanded = credentials.mode == DemoMode.OWN && credentials.accessKey.isBlank(),
        )
    }

    // ── Effective credentials ────────────────────────────────────────────────

    val hasDemoKeys: Boolean get() = DemoContainer.hasDemoKeys

    private fun effectiveAccessKey(): String = when (_state.value.mode) {
        DemoMode.OWN -> credentials.accessKey
        DemoMode.TOUR -> DemoContainer.demoAccessKey
        null -> ""
    }

    fun effectiveCampaignKey(): String = when (_state.value.mode) {
        DemoMode.OWN -> credentials.campaignKey
        DemoMode.TOUR -> DemoContainer.demoCampaignKey
        null -> ""
    }

    private fun effectiveStreamToken(): String = when (_state.value.mode) {
        DemoMode.OWN -> credentials.streamToken
        DemoMode.TOUR -> DemoContainer.demoStreamToken
        null -> ""
    }

    /**
     * Why a card is locked. Null means it can run.
     *
     * A stream token is required even in tour mode: without one the studio opens but
     * cannot go live, so the card is locked and says why.
     */
    fun lockReason(mission: Mission): String? {
        if (_state.value.mode == null) return DemoContainer.string(R.string.lock_need_mode)
        if (effectiveAccessKey().isBlank() || effectiveCampaignKey().isBlank()) {
            return DemoContainer.string(R.string.lock_need_keys)
        }
        if (mission.needsStreamToken && effectiveStreamToken().isBlank()) {
            return DemoContainer.string(R.string.lock_need_stream_token)
        }
        return null
    }

    // ── Start screen ─────────────────────────────────────────────────────────

    fun onAccessKeyChange(value: String) = _state.update { it.copy(accessKeyInput = value) }
    fun onCampaignKeyChange(value: String) = _state.update { it.copy(campaignKeyInput = value) }
    fun onStreamTokenChange(value: String) = _state.update { it.copy(streamTokenInput = value) }
    fun onUserJwtChange(value: String) = _state.update { it.copy(userJwtInput = value) }

    fun toggleOwnForm() = _state.update {
        it.copy(ownFormExpanded = !it.ownFormExpanded, validationError = null)
    }

    /** Tour mode — initialize immediately with the built-in demo keys. */
    fun startTour(context: Context): Boolean {
        if (!hasDemoKeys) {
            _state.update {
                it.copy(
                    validationError = DemoContainer.string(R.string.msg_demo_keys_missing)
                )
            }
            return false
        }
        credentials.mode = DemoMode.TOUR
        ShopliveInitializer.initialize(context, DemoContainer.demoAccessKey)
        // Not signed in until an auth method is chosen.
        applyAuthMethod(ShopliveUserSetup.Method.GUEST)
        _state.update {
            it.copy(
                mode = DemoMode.TOUR,
                validationError = null,
                authMethod = ShopliveUserSetup.Method.GUEST,
            )
        }
        return true
    }

    /** Own credentials — validate the input, then initialize. */
    fun startOwn(context: Context): Boolean {
        val current = _state.value
        val accessKey = current.accessKeyInput.trim()
        val campaignKey = current.campaignKeyInput.trim()

        when (val result = ShopliveInitializer.validate(accessKey, campaignKey)) {
            is ShopliveInitializer.Validation.Invalid -> {
                _state.update {
                    it.copy(
                        validationError = DemoContainer.string(DemoLabels.messageRes(result.reason))
                    )
                }
                return false
            }

            ShopliveInitializer.Validation.Valid -> Unit
        }

        credentials.accessKey = accessKey
        credentials.campaignKey = campaignKey
        credentials.streamToken = current.streamTokenInput.trim()
        credentials.userJwt = current.userJwtInput.trim()
        credentials.mode = DemoMode.OWN

        ShopliveInitializer.initialize(context, accessKey)
        applyAuthMethod(ShopliveUserSetup.Method.GUEST)

        _state.update {
            it.copy(
                mode = DemoMode.OWN,
                validationError = null,
                authMethod = ShopliveUserSetup.Method.GUEST,
                message = DemoContainer.string(R.string.msg_validation_ok),
            )
        }
        return true
    }

    /** Back to the start screen (the gear icon). Credentials are kept. */
    fun openSettings() = _state.update {
        it.copy(ownFormExpanded = it.mode == DemoMode.OWN, validationError = null)
    }

    // ── Running a mission ────────────────────────────────────────────────────

    /**
     * @return true when the caller should navigate to the feed screen (Mission 4).
     */
    fun runMission(activity: Activity, number: Int): Boolean {
        val mission = missionOf(number)
        val lock = lockReason(mission)
        if (lock != null) {
            showMessage(lock)
            return false
        }

        progress.startMission(number)

        return when (mission.run) {
            MissionRun.PLAYER -> {
                openSheetFor(mission)
                launchPlayer(activity)
                false
            }

            MissionRun.DEEP_LINK -> {
                // No dedicated screen — a banner over the list.
                _state.update { it.copy(showPushBanner = true, devSheetTab = null) }
                false
            }

            MissionRun.AUTH -> {
                _state.update { it.copy(askAuthMethod = true, devSheetTab = null) }
                false
            }

            MissionRun.FEED -> {
                openSheetFor(mission)
                true
            }

            MissionRun.STUDIO -> {
                openSheetFor(mission)
                launchStudio(activity)
                false
            }
        }
    }

    private fun openSheetFor(mission: Mission) {
        _state.update { it.copy(devSheetTab = mission.openSheet) }
    }

    private fun launchPlayer(activity: Activity, referrerOverride: String? = null) {
        val options = DemoOptionsStore.current
        ShoplivePlayerLauncher.start(
            activity = activity,
            campaignKey = effectiveCampaignKey(),
            delegate = playerDelegate,
            // Demo-only assembly: every options-tab field at once. A customer app
            // would pass one of the ShoplivePlayerPresets instead.
            configuration = DemoConfigurationFactory.from(options),
            options = DemoConfigurationFactory.playOptions(options, referrerOverride),
        )
    }

    /** The options tab's "replay with these options". */
    fun replayWithCurrentOptions(activity: Activity) {
        if (effectiveCampaignKey().isBlank()) {
            showMessage(DemoContainer.string(R.string.msg_no_campaign_key))
            return
        }
        _state.update { it.copy(devSheetTab = null) }
        progress.startMission(7)
        launchPlayer(activity)
    }

    private fun launchStudio(activity: Activity) {
        val started = ShopliveStudioLauncher.start(
            activity = activity,
            campaignKey = effectiveCampaignKey(),
            streamToken = effectiveStreamToken(),
            onBroadcastLive = { progress.markBroadcastLive() },
            onFatalError = { text -> showMessage(text) },
        )
        if (!started) showMessage(DemoContainer.string(R.string.msg_studio_not_started))
    }

    // ── Deep link ────────────────────────────────────────────────────────────

    fun dismissPushBanner() = _state.update { it.copy(showPushBanner = false) }

    /** Banner tap fires a **real** deep-link Intent, which goes through SchemeActivity. */
    fun onPushBannerTap(activity: Activity) {
        _state.update { it.copy(showPushBanner = false) }
        ShopliveDeepLinkRouter.sendTestLink(
            context = activity,
            scheme = BuildConfig.DEEP_LINK_SCHEME,
            campaignKey = effectiveCampaignKey(),
            referrer = "push_demo",
        )
    }

    /** Playback that came in from a deep link. MainActivity receives the Intent. */
    fun playFromDeepLink(activity: Activity, link: ShopliveDeepLinkRouter.Link) {
        val accessKey = effectiveAccessKey()
        if (accessKey.isBlank()) {
            showMessage(DemoContainer.string(R.string.msg_deeplink_no_access_key))
            return
        }
        // Cold-start safety — make sure initialization finished before playing.
        ShopliveInitializer.initializeIfNeeded(activity, accessKey)
        progress.startMission(2)
        launchPlayer(activity, referrerOverride = link.referrer)
    }

    // ── Auth method ──────────────────────────────────────────────────────────

    fun dismissAuthSheet() = _state.update { it.copy(askAuthMethod = false) }

    fun chooseAuthMethod(activity: Activity, method: ShopliveUserSetup.Method) {
        val applied = applyAuthMethod(method)
        _state.update { it.copy(askAuthMethod = false, authMethod = applied) }
        if (applied != method) {
            showMessage(DemoContainer.string(R.string.msg_token_needs_jwt))
        }
        progress.startMission(3)
        launchPlayer(activity)
    }

    /**
     * The demo's profile values live here, not in `:integration` — a customer app
     * passes its own logged-in user the same way.
     */
    private fun applyAuthMethod(method: ShopliveUserSetup.Method): ShopliveUserSetup.Method =
        ShopliveUserSetup.apply(
            method = method,
            jwt = credentials.userJwt,
            profile = ShopliveUserSetup.exampleProfile(
                name = DemoContainer.string(R.string.demo_user_name),
            ),
        )

    // ── Developer sheet ──────────────────────────────────────────────────────

    fun openDevSheet(tab: DevSheetTab = DevSheetTab.LOG) =
        _state.update { it.copy(devSheetTab = tab) }

    fun selectDevTab(tab: DevSheetTab) = _state.update { it.copy(devSheetTab = tab) }

    fun closeDevSheet() = _state.update { it.copy(devSheetTab = null) }

    // ── Failures ─────────────────────────────────────────────────────────────

    /**
     * Turns a [ShopliveFailure] into something the viewer can read.
     *
     * A Toast is used for repeated playback failure because at that moment the
     * front-most window is the **SDK-owned player Activity** — this app's Compose
     * snackbar is behind it and would never be seen. The snackbar still gets the
     * long version for when the user comes back.
     */
    private fun reportFailure(failure: ShopliveFailure) {
        val code = failure.code ?: "-"
        when (failure.kind) {
            ShopliveFailure.Kind.REPEATED_PLAYBACK_FAILURE -> {
                // Toast wraps after two lines, so it gets the short sentence.
                Toast.makeText(
                    DemoContainer.appContext,
                    DemoContainer.string(R.string.err_playback_failed_short, code),
                    Toast.LENGTH_LONG,
                ).show()
                showMessage(DemoContainer.string(R.string.err_playback_failed, code))
            }

            ShopliveFailure.Kind.UNRECOVERABLE_ERROR -> {
                val cause = failure.cause?.let { DemoContainer.string(DemoLabels.messageRes(it)) }
                showMessage("${cause.orEmpty()} (code: $code)".trim())
            }
        }
    }

    // ── Misc ─────────────────────────────────────────────────────────────────

    fun showMessage(text: String) = _state.update { it.copy(message = text) }

    fun consumeMessage() = _state.update { it.copy(message = null) }

    fun resetProgress() {
        progress.reset()
        DemoLog.clear()
        showMessage(DemoContainer.string(R.string.msg_progress_reset))
    }

    /** The embedded view uses the **same** delegate — the contract is identical. */
    fun delegateForEmbeddedView(): ShoplivePlayerEventLogger = playerDelegate
}
