package cloud.shoplive.onboarding.data

import androidx.annotation.StringRes
import cloud.shoplive.onboarding.R

/**
 * The eight feature cards. The numbers are **the same Mission numbers as the
 * integration guide** (https://sdk.shoplive.cloud).
 *
 * [sourcePath] is the only bridge between this app and the project sources, so it
 * must match the real file path — reading a card, opening that file and copying the
 * code is how the demo is meant to be used. Paths are code locations, never
 * translated.
 *
 * Every path but one points into `:integration`, the copy-paste module: what the card
 * demonstrates is exactly what a customer takes. Mission 4 is the exception worth
 * noting — the SDK-facing half lives in `ShopliveEmbeddedPlayer.kt`, while the Compose
 * screen that hosts it stays in the demo.
 */
enum class MissionRun {
    /** Launches the SDK's full-screen player Activity. */
    PLAYER,

    /** Fake push banner -> a real deep-link Intent -> the player. */
    DEEP_LINK,

    /** Asks for an auth method, then plays. */
    AUTH,

    /** The demo's own home feed screen, with an embedded view. */
    FEED,

    /** Launches the SDK's studio Activity. */
    STUDIO,
}

data class Mission(
    val number: Int,
    @StringRes val titleRes: Int,
    @StringRes val descriptionRes: Int,
    /** What you should see if it worked. */
    @StringRes val checkPointRes: Int,
    val sourcePath: String,
    val run: MissionRun,
    /** Which developer-sheet tab to open right after running. Null opens nothing. */
    val openSheet: DevSheetTab? = null,
    val needsStreamToken: Boolean = false,
)

enum class DevSheetTab { LOG, OPTIONS }

/** The copy-paste module. Everything under here is meant to be taken as-is. */
private const val INT_DIR = "integration/src/main/java/cloud/shoplive/onboarding/integration"

val MISSIONS: List<Mission> = listOf(
    Mission(
        number = 1,
        titleRes = R.string.mission1_title,
        descriptionRes = R.string.mission1_desc,
        checkPointRes = R.string.mission1_check,
        sourcePath = "$INT_DIR/ShoplivePlayerLauncher.kt",
        run = MissionRun.PLAYER,
    ),
    Mission(
        number = 2,
        titleRes = R.string.mission2_title,
        descriptionRes = R.string.mission2_desc,
        checkPointRes = R.string.mission2_check,
        sourcePath = "$INT_DIR/ShopliveDeepLinkRouter.kt",
        run = MissionRun.DEEP_LINK,
    ),
    Mission(
        number = 3,
        titleRes = R.string.mission3_title,
        descriptionRes = R.string.mission3_desc,
        checkPointRes = R.string.mission3_check,
        sourcePath = "$INT_DIR/ShopliveUserSetup.kt",
        run = MissionRun.AUTH,
    ),
    Mission(
        number = 4,
        titleRes = R.string.mission4_title,
        descriptionRes = R.string.mission4_desc,
        checkPointRes = R.string.mission4_check,
        sourcePath = "$INT_DIR/ShopliveEmbeddedPlayer.kt",
        run = MissionRun.FEED,
    ),
    Mission(
        number = 5,
        titleRes = R.string.mission5_title,
        descriptionRes = R.string.mission5_desc,
        checkPointRes = R.string.mission5_check,
        sourcePath = "$INT_DIR/ShoplivePipPresets.kt",
        run = MissionRun.PLAYER,
    ),
    Mission(
        number = 6,
        titleRes = R.string.mission6_title,
        descriptionRes = R.string.mission6_desc,
        checkPointRes = R.string.mission6_check,
        sourcePath = "$INT_DIR/ShoplivePlayerEventLogger.kt",
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.LOG,
    ),
    Mission(
        number = 7,
        titleRes = R.string.mission7_title,
        descriptionRes = R.string.mission7_desc,
        checkPointRes = R.string.mission7_check,
        sourcePath = "$INT_DIR/ShoplivePlayerPresets.kt",
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.OPTIONS,
    ),
    Mission(
        number = 8,
        titleRes = R.string.mission8_title,
        descriptionRes = R.string.mission8_desc,
        checkPointRes = R.string.mission8_check,
        sourcePath = "$INT_DIR/ShopliveStudioLauncher.kt",
        run = MissionRun.STUDIO,
        needsStreamToken = true,
    ),
)

fun missionOf(number: Int): Mission = MISSIONS.first { it.number == number }
