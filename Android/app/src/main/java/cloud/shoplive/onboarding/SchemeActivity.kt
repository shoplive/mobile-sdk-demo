package cloud.shoplive.onboarding

import android.content.Intent
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.integration.ShopliveDeepLinkRouter

/**
 * Mission 2 — the deep-link entry point.
 *
 * ## This screen does not play anything
 * It parses and hands over to [MainActivity], for **cold-start safety**.
 *
 * If the app was dead when the link was tapped, `Shoplive.initialize` may not have
 * run yet, and calling playback in that state fails with
 * `NOT_INITIALIZED_ACCESS_KEY`. Only the main screen knows whether initialization
 * finished, so the decision and the playback belong there.
 *
 * This Activity is also `noHistory=true` and disappears at once.
 * `ShoplivePlayer(context)` holds its constructor context weakly, so handing it an
 * Activity that is about to finish can get later `play()` calls refused — starting
 * from a screen that stays alive (MainActivity) is safer.
 */
class SchemeActivity : ComponentActivity() {
    /** Applies the language chosen in the app (English by default) to this screen. */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleSetting.wrap(newBase))
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // The scheme comes from BuildConfig, which shares one value with the
        // manifest's intent-filter. The router takes it as a parameter so that
        // nothing in :integration depends on this app's BuildConfig.
        val link = ShopliveDeepLinkRouter.parse(intent?.data, BuildConfig.DEEP_LINK_SCHEME)

        startActivity(
            Intent(this, MainActivity::class.java).apply {
                // MainActivity is singleTask; if it is already up, this arrives at
                // onNewIntent.
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (link != null) {
                    putExtra(MainActivity.EXTRA_DEEP_LINK_CAMPAIGN, link.campaignKey)
                    putExtra(MainActivity.EXTRA_DEEP_LINK_REFERRER, link.referrer)
                }
            }
        )
        finish()
    }
}
