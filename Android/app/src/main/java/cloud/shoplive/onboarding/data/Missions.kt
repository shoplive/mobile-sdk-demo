package cloud.shoplive.onboarding.data

import androidx.annotation.StringRes
import cloud.shoplive.onboarding.R

/**
 * 기능 카드 8개. 번호는 **연동 가이드의 Mission 번호와 같다**
 * (https://sdk.shoplive.cloud — 한국어·English·日本語 가이드).
 *
 * [sourcePath] 는 이 앱과 프로젝트 소스를 잇는 유일한 다리다. 실제 파일 경로와 반드시
 * 일치해야 한다 — 카드를 보고 그 파일을 열어 코드를 복사하는 것이 데모앱의 사용법이다.
 * 경로는 코드 위치라서 번역하지 않는다.
 */
enum class MissionRun {
    /** SDK 풀스크린 플레이어 Activity 를 띄운다. */
    PLAYER,

    /** 가짜 푸시 배너 → 실제 딥링크 Intent → 플레이어. */
    DEEP_LINK,

    /** 인증 방식 선택 시트를 띄운 뒤 플레이어. */
    AUTH,

    /** 데모앱이 소유하는 홈 피드 화면(임베드 View). */
    FEED,

    /** SDK 스튜디오 Activity 를 띄운다. */
    STUDIO,
}

data class Mission(
    val number: Int,
    @StringRes val titleRes: Int,
    @StringRes val descriptionRes: Int,
    /** 무엇이 보이면 성공인지. */
    @StringRes val checkPointRes: Int,
    val sourcePath: String,
    val run: MissionRun,
    /** 실행 직후 개발자 시트를 어느 탭으로 열지. null 이면 열지 않는다. */
    val openSheet: DevSheetTab? = null,
    val needsStreamToken: Boolean = false,
)

enum class DevSheetTab { LOG, OPTIONS }

private const val SDK_DIR = "app/src/main/java/cloud/shoplive/onboarding/sdk"
private const val UI_DIR = "app/src/main/java/cloud/shoplive/onboarding/ui"

val MISSIONS: List<Mission> = listOf(
    Mission(
        number = 1,
        titleRes = R.string.mission1_title,
        descriptionRes = R.string.mission1_desc,
        checkPointRes = R.string.mission1_check,
        sourcePath = "$SDK_DIR/PlayerLauncher.kt",
        run = MissionRun.PLAYER,
    ),
    Mission(
        number = 2,
        titleRes = R.string.mission2_title,
        descriptionRes = R.string.mission2_desc,
        checkPointRes = R.string.mission2_check,
        sourcePath = "$SDK_DIR/DeepLinkRouter.kt",
        run = MissionRun.DEEP_LINK,
    ),
    Mission(
        number = 3,
        titleRes = R.string.mission3_title,
        descriptionRes = R.string.mission3_desc,
        checkPointRes = R.string.mission3_check,
        sourcePath = "$SDK_DIR/UserSetup.kt",
        run = MissionRun.AUTH,
    ),
    Mission(
        number = 4,
        titleRes = R.string.mission4_title,
        descriptionRes = R.string.mission4_desc,
        checkPointRes = R.string.mission4_check,
        sourcePath = "$UI_DIR/feed/FeedScreen.kt",
        run = MissionRun.FEED,
    ),
    Mission(
        number = 5,
        titleRes = R.string.mission5_title,
        descriptionRes = R.string.mission5_desc,
        checkPointRes = R.string.mission5_check,
        sourcePath = "$SDK_DIR/PipOptions.kt",
        run = MissionRun.PLAYER,
    ),
    Mission(
        number = 6,
        titleRes = R.string.mission6_title,
        descriptionRes = R.string.mission6_desc,
        checkPointRes = R.string.mission6_check,
        sourcePath = "$SDK_DIR/DemoPlayerDelegate.kt",
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.LOG,
    ),
    Mission(
        number = 7,
        titleRes = R.string.mission7_title,
        descriptionRes = R.string.mission7_desc,
        checkPointRes = R.string.mission7_check,
        sourcePath = "$SDK_DIR/PlayerConfigurationFactory.kt",
        run = MissionRun.PLAYER,
        openSheet = DevSheetTab.OPTIONS,
    ),
    Mission(
        number = 8,
        titleRes = R.string.mission8_title,
        descriptionRes = R.string.mission8_desc,
        checkPointRes = R.string.mission8_check,
        sourcePath = "$SDK_DIR/StudioLauncher.kt",
        run = MissionRun.STUDIO,
        needsStreamToken = true,
    ),
)

fun missionOf(number: Int): Mission = MISSIONS.first { it.number == number }
