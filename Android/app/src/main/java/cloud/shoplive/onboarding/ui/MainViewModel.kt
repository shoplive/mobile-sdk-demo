package cloud.shoplive.onboarding.ui

import android.app.Activity
import android.content.Context
import androidx.lifecycle.ViewModel
import cloud.shoplive.onboarding.DemoContainer
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.data.DemoMode
import cloud.shoplive.onboarding.data.DemoOptionsStore
import cloud.shoplive.onboarding.data.DevSheetTab
import cloud.shoplive.onboarding.data.Mission
import cloud.shoplive.onboarding.data.MissionRun
import cloud.shoplive.onboarding.data.missionOf
import cloud.shoplive.onboarding.sdk.DeepLinkRouter
import cloud.shoplive.onboarding.sdk.DemoPlayerDelegate
import cloud.shoplive.onboarding.sdk.PlayerLauncher
import cloud.shoplive.onboarding.sdk.ShopliveInitializer
import cloud.shoplive.onboarding.sdk.StudioLauncher
import cloud.shoplive.onboarding.sdk.UserSetup
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * 화면 상태와 "카드 탭 → 즉시 실행" 흐름을 담당한다.
 *
 * 미션 실행은 **중간 화면 없이** 바로 SDK 를 호출한다. 설명·코드를 보여주는 화면은 두지
 * 않는다 — 코드는 프로젝트 소스에서 보고, 앱은 동작만 확인한다.
 */
class MainViewModel : ViewModel() {

    data class UiState(
        val mode: DemoMode? = null,
        val accessKeyInput: String = "",
        val campaignKeyInput: String = "",
        val streamTokenInput: String = "",
        val userJwtInput: String = "",
        val ownFormExpanded: Boolean = false,
        val authMethod: UserSetup.Method = UserSetup.Method.GUEST,
        /** 인증 방식 선택 시트(Mission 3) 표시 여부. */
        val askAuthMethod: Boolean = false,
        /** 가짜 푸시 배너(Mission 2) 표시 여부. */
        val showPushBanner: Boolean = false,
        val devSheetTab: DevSheetTab? = null,
        val message: String? = null,
        /** 시작 화면에서 검증에 실패한 사유. */
        val validationError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val credentials get() = DemoContainer.credentials
    private val progress get() = DemoContainer.progress

    val doneMissions get() = progress.done

    /** 이벤트 수신자는 하나만 만들어 재사용한다 — 로그가 여러 벌로 갈라지지 않게. */
    private val playerDelegate = DemoPlayerDelegate(
        progress = DemoContainer.progress,
        onFatalError = { text -> showMessage(text) },
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

    // ── 유효 자격증명 ────────────────────────────────────────────────────────

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
     * 카드가 잠기는 사유. null 이면 실행 가능하다.
     *
     * 프로토타입과 다른 점: 송출 토큰은 둘러보기 모드에서도 필요하다. 토큰이 없으면
     * 스튜디오는 열려도 방송을 시작할 수 없으므로, 없으면 잠그고 사유를 밝힌다.
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

    // ── 시작 화면 ────────────────────────────────────────────────────────────

    fun onAccessKeyChange(value: String) = _state.update { it.copy(accessKeyInput = value) }
    fun onCampaignKeyChange(value: String) = _state.update { it.copy(campaignKeyInput = value) }
    fun onStreamTokenChange(value: String) = _state.update { it.copy(streamTokenInput = value) }
    fun onUserJwtChange(value: String) = _state.update { it.copy(userJwtInput = value) }

    fun toggleOwnForm() = _state.update {
        it.copy(ownFormExpanded = !it.ownFormExpanded, validationError = null)
    }

    /** 둘러보기 — 내장 데모 키로 즉시 초기화. */
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
        // 인증 방식을 따로 고르기 전까지는 비로그인이다.
        UserSetup.apply(UserSetup.Method.GUEST)
        _state.update {
            it.copy(mode = DemoMode.TOUR, validationError = null, authMethod = UserSetup.Method.GUEST)
        }
        return true
    }

    /** 내 계정 — 입력값을 검증하고 초기화. */
    fun startOwn(context: Context): Boolean {
        val current = _state.value
        val accessKey = current.accessKeyInput.trim()
        val campaignKey = current.campaignKeyInput.trim()

        when (val result = ShopliveInitializer.validate(accessKey, campaignKey)) {
            is ShopliveInitializer.Validation.Invalid -> {
                _state.update { it.copy(validationError = result.message) }
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
        UserSetup.apply(UserSetup.Method.GUEST)

        _state.update {
            it.copy(
                mode = DemoMode.OWN,
                validationError = null,
                authMethod = UserSetup.Method.GUEST,
                message = DemoContainer.string(R.string.msg_validation_ok),
            )
        }
        return true
    }

    /** 시작 화면으로 되돌린다(⚙). 자격증명은 지우지 않는다. */
    fun openSettings() = _state.update {
        it.copy(ownFormExpanded = it.mode == DemoMode.OWN, validationError = null)
    }

    // ── 미션 실행 ────────────────────────────────────────────────────────────

    /**
     * @return 피드 화면으로 이동해야 하면 true (Mission 4).
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
                // 전용 화면을 만들지 않는다 — 목록 위에 배너를 띄운다.
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
        PlayerLauncher.startWithOptions(
            activity = activity,
            campaignKey = effectiveCampaignKey(),
            delegate = playerDelegate,
            demoOptions = DemoOptionsStore.current,
            referrerOverride = referrerOverride,
        )
    }

    /** 옵션 탭의 "이 옵션으로 다시 재생". */
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
        val started = StudioLauncher.start(
            activity = activity,
            campaignKey = effectiveCampaignKey(),
            streamToken = effectiveStreamToken(),
            progress = progress,
            onFatalError = { text -> showMessage(text) },
        )
        if (!started) showMessage(DemoContainer.string(R.string.msg_studio_not_started))
    }

    // ── Mission 2 · 가짜 푸시 ────────────────────────────────────────────────

    fun dismissPushBanner() = _state.update { it.copy(showPushBanner = false) }

    /** 배너 탭 → **실제 딥링크 Intent** 를 발사한다. SchemeActivity 를 통과한다. */
    fun onPushBannerTap(activity: Activity) {
        _state.update { it.copy(showPushBanner = false) }
        DeepLinkRouter.sendFakePush(activity, effectiveCampaignKey(), referrer = "push_demo")
    }

    /** 딥링크로 들어온 재생. MainActivity 가 Intent 를 받아 호출한다. */
    fun playFromDeepLink(activity: Activity, link: DeepLinkRouter.Link) {
        val accessKey = effectiveAccessKey()
        if (accessKey.isBlank()) {
            showMessage(DemoContainer.string(R.string.msg_deeplink_no_access_key))
            return
        }
        // 콜드 스타트 대비 — 재생 전에 초기화가 끝났음을 보장한다.
        ShopliveInitializer.initializeIfNeeded(activity, accessKey)
        progress.startMission(2)
        PlayerLauncher.startWithOptions(
            activity = activity,
            campaignKey = link.campaignKey,
            delegate = playerDelegate,
            demoOptions = DemoOptionsStore.current,
            referrerOverride = link.referrer,
        )
    }

    // ── Mission 3 · 인증 방식 ────────────────────────────────────────────────

    fun dismissAuthSheet() = _state.update { it.copy(askAuthMethod = false) }

    fun chooseAuthMethod(activity: Activity, method: UserSetup.Method) {
        val applied = UserSetup.apply(method, credentials.userJwt)
        _state.update { it.copy(askAuthMethod = false, authMethod = applied) }
        if (applied != method) {
            showMessage(DemoContainer.string(R.string.msg_token_needs_jwt))
        }
        progress.startMission(3)
        launchPlayer(activity)
    }

    // ── 개발자 시트 ──────────────────────────────────────────────────────────

    fun openDevSheet(tab: DevSheetTab = DevSheetTab.LOG) =
        _state.update { it.copy(devSheetTab = tab) }

    fun selectDevTab(tab: DevSheetTab) = _state.update { it.copy(devSheetTab = tab) }

    fun closeDevSheet() = _state.update { it.copy(devSheetTab = null) }

    // ── 기타 ────────────────────────────────────────────────────────────────

    fun showMessage(text: String) = _state.update { it.copy(message = text) }

    fun consumeMessage() = _state.update { it.copy(message = null) }

    fun resetProgress() {
        progress.reset()
        DemoLog.clear()
        showMessage(DemoContainer.string(R.string.msg_progress_reset))
    }

    /** 임베드 뷰(Mission 4)도 **같은 delegate** 를 쓴다 — 계약이 동일함을 드러내려고. */
    fun delegateForEmbeddedView(): DemoPlayerDelegate = playerDelegate
}
