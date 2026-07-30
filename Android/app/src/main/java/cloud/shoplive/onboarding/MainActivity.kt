package cloud.shoplive.onboarding

import android.content.Intent
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.ui.DemoApp
import cloud.shoplive.onboarding.ui.theme.ShopliveOnboardingTheme

/**
 * 데모앱의 유일한 주 화면.
 *
 * 단일 Activity + Compose 구성이다. SDK 플레이어·스튜디오는 각자 Activity 로 이 위에 뜨고,
 * 이 화면은 그동안 살아 있으므로 delegate 가 계속 이벤트를 받는다.
 *
 * `launchMode="singleTask"` 라서 딥링크가 두 번째로 들어오면 [onNewIntent] 로 온다.
 */
class MainActivity : ComponentActivity() {
    /** 앱이 고른 표시 언어(기본 영어)를 이 화면의 리소스에 적용한다. */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleSetting.wrap(newBase))
    }


    private var deepLinkCampaignKey by mutableStateOf<String?>(null)
    private var deepLinkReferrer by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        readDeepLink(intent)

        setContent {
            ShopliveOnboardingTheme {
                DemoApp(
                    isEncryptedStorage = DemoContainer.credentials.isEncrypted,
                    deepLinkCampaignKey = deepLinkCampaignKey,
                    deepLinkReferrer = deepLinkReferrer,
                    onDeepLinkConsumed = {
                        deepLinkCampaignKey = null
                        deepLinkReferrer = null
                    },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readDeepLink(intent)
    }

    private fun readDeepLink(intent: Intent?) {
        val campaignKey = intent?.getStringExtra(EXTRA_DEEP_LINK_CAMPAIGN) ?: return
        deepLinkCampaignKey = campaignKey
        deepLinkReferrer = intent.getStringExtra(EXTRA_DEEP_LINK_REFERRER)
        // 화면 회전 등으로 같은 Intent 를 다시 읽어 중복 재생하지 않도록 비운다.
        intent.removeExtra(EXTRA_DEEP_LINK_CAMPAIGN)
        intent.removeExtra(EXTRA_DEEP_LINK_REFERRER)
    }

    companion object {
        const val EXTRA_DEEP_LINK_CAMPAIGN = "deepLinkCampaignKey"
        const val EXTRA_DEEP_LINK_REFERRER = "deepLinkReferrer"
    }
}
