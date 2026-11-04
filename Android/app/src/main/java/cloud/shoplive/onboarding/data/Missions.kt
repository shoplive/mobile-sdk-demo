package cloud.shoplive.onboarding.data

import androidx.annotation.StringRes
import cloud.shoplive.onboarding.R

/**
 * A mission's identity. **Branching and completion use this, never a number.**
 *
 * [raw] is what gets stored on disk and is shared with the iOS demo, so the nine
 * values are frozen — renaming one silently drops everybody's progress for it
 * (SMV-1922 contract 2). The number a viewer sees is [displayNumber], derived from
 * the position in [MISSIONS] and never stored.
 */
enum class MissionId(val raw: String) {
    PLAYER("player"),
    NUDGE("nudge"),
    PIP("pip"),
    DEEPLINK("deeplink"),
    USER("user"),
    EVENTS("events"),
    INLINE("inline"),
    UI("ui"),
    STUDIO("studio"),
    ;

    /** 1-based position in [MISSIONS] — the integration guide's mission number. */
    val displayNumber: Int get() = MISSIONS.indexOfFirst { it.id == this } + 1

    companion object {
        /** Null for anything that is not one of the nine stored values. */
        fun fromRaw(raw: String): MissionId? = entries.firstOrNull { it.raw == raw }
    }
}

/** How tapping the card runs it. */
enum class MissionRun {
    /** Launches the SDK's full-screen player Activity. */
    PLAYER,

    /** The demo's own product screen, with a nudge preview floating over it. */
    NUDGE,

    /** Fake push banner -> a real deep-link Intent -> the player. */
    DEEP_LINK,

    /** Asks for an auth method, then plays. */
    AUTH,

    /** Asks native (a view in the feed) or hybrid (a web list), then opens that screen. */
    INLINE,

    /** Launches the SDK's studio Activity. */
    STUDIO,
}

/**
 * One feature card.
 *
 * [sourcePaths] are the only bridge between this app and the project sources, so
 * they must match real files — reading a card, opening that file and copying the
 * code is how the demo is meant to be used. Paths are code locations, never
 * translated. Every path points into `:integration`, the copy-paste module: what
 * the card demonstrates is exactly what a customer takes. The inline-preview card
 * names two files because it shows two ways (native view and web bridge).
 */
data class Mission(
    val id: MissionId,
    @StringRes val titleRes: Int,
    @StringRes val descriptionRes: Int,
    /** What you should see if it worked. */
    @StringRes val checkPointRes: Int,
    val sourcePaths: List<String>,
    val run: MissionRun,
    /** Which developer-sheet tab to open right after running. Null opens nothing. */
    val openSheet: DevSheetTab? = null,
    val needsStreamToken: Boolean = false,
)

enum class DevSheetTab { LOG, OPTIONS }

/** The copy-paste module. Everything under here is meant to be taken as-is. */
private const val INT_DIR = "integration/src/main/java/cloud/shoplive/onboarding/integration"

/**
 * The cards, **in the integration guide's mission-map order**. The list position is
 * the number on screen and the list size is the total — nothing else may hold
 * either. Reordering the guide means reordering this list, and nothing more.
 */
val MISSIONS: List<Mission> = listOf(
    Mission(
        id = MissionId.PLAYER,
        titleRes = R.string.mission_player_title,
        descriptionRes = R.string.mission_player_desc,
        checkPointRes = R.string.mission_player_check,
        sourcePaths = listOf("$INT_DIR/ShoplivePlayerLauncher.kt"),
        run = MissionRun.PLAYER,
    ),
    Mission(
        id = MissionId.NUDGE,
        titleRes = R.string.mission_nudge_title,
        descriptionRes = R.string.mission_nudge_desc,
        checkPointRes = R.string.mission_nudge_check,
        sourcePaths = listOf("$INT_DIR/ShopliveNudgePreview.kt"),
        run = MissionRun.NUDGE,
    ),
    Mission(
        id = MissionId.PIP,
        titleRes = R.string.mission_pip_title,
        descriptionRes = R.string.mission_pip_desc,
        checkPointRes = R.string.mission_pip_check,
        sourcePaths = listOf("$INT_DIR/ShoplivePipPresets.kt"),
        run = MissionRun.PLAYER,
    ),
    Mission(
        id = MissionId.DEEPLINK,
        titleRes = R.string.mission_deeplink_title,
        descriptionRes = R.string.mission_deeplink_desc,
        checkPointRes = R.string.mission_deeplink_check,
        sourcePaths = listOf("$INT_DIR/ShopliveDeepLinkRouter.kt"),
        run = MissionRun.DEEP_LINK,
    ),
    Mission(
        id = MissionId.USER,
        titleRes = R.string.mission_user_title,
        descriptionRes = R.string.mission_user_desc,
        checkPointRes = R.string.mission_user_check,
        sourcePaths = listOf("$INT_DIR/ShopliveUserSetup.kt"),
        run = MissionRun.AUTH,
    ),
    Mission(
        id = MissionId.EVENTS,
        titleRes = R.string.mission_events_title,
        descriptionRes = R.string.mission_events_desc,
        checkPointRes = R.string.mission_events_check,
        sourcePaths = listOf("$INT_DIR/ShoplivePlayerEventLogger.kt"),
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.LOG,
    ),
    Mission(
        id = MissionId.INLINE,
        titleRes = R.string.mission_inline_title,
        descriptionRes = R.string.mission_inline_desc,
        checkPointRes = R.string.mission_inline_check,
        sourcePaths = listOf(
            "$INT_DIR/ShopliveEmbeddedPlayer.kt",
            "$INT_DIR/ShopliveWebBridge.kt",
        ),
        run = MissionRun.INLINE,
    ),
    Mission(
        id = MissionId.UI,
        titleRes = R.string.mission_ui_title,
        descriptionRes = R.string.mission_ui_desc,
        checkPointRes = R.string.mission_ui_check,
        sourcePaths = listOf("$INT_DIR/ShoplivePlayerPresets.kt"),
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.OPTIONS,
    ),
    Mission(
        id = MissionId.STUDIO,
        titleRes = R.string.mission_studio_title,
        descriptionRes = R.string.mission_studio_desc,
        checkPointRes = R.string.mission_studio_check,
        sourcePaths = listOf("$INT_DIR/ShopliveStudioLauncher.kt"),
        run = MissionRun.STUDIO,
        needsStreamToken = true,
    ),
)
