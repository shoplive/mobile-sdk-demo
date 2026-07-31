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
 * The demo's one main screen.
 *
 * Single Activity plus Compose. The SDK's player and studio come up as their own
 * Activities on top of this one, which stays alive underneath — which is why the
 * delegate keeps receiving events the whole time.
 *
 * `launchMode="singleTask"`, so a second deep link arrives at [onNewIntent].
 */
class MainActivity : ComponentActivity() {
    /** Applies the language chosen in the app (English by default) to this screen. */
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
        // Clear it so a rotation does not re-read the same Intent and play twice.
        intent.removeExtra(EXTRA_DEEP_LINK_CAMPAIGN)
        intent.removeExtra(EXTRA_DEEP_LINK_REFERRER)
    }

    companion object {
        const val EXTRA_DEEP_LINK_CAMPAIGN = "deepLinkCampaignKey"
        const val EXTRA_DEEP_LINK_REFERRER = "deepLinkReferrer"
    }
}
