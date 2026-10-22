package cloud.shoplive.onboarding

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.ui.product.ProductDetailScreen
import cloud.shoplive.onboarding.ui.theme.ShopliveOnboardingTheme

/**
 * The Activity that holds the product detail.
 *
 * ## Why an Activity and not a Compose route
 * A `navigation(url)` request arrives while the **SDK player Activity is front-most**.
 * The demo's Compose NavHost is behind it, so navigating one of its routes changes
 * nothing the user can see. A separate Activity is what can be put on top of the
 * player.
 *
 * Real apps land products on their own screen or modal anyway, so this is the natural
 * shape rather than a workaround.
 */
class ProductDetailActivity : ComponentActivity() {
    /** Applies the language chosen in the app (English by default) to this screen. */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleSetting.wrap(newBase))
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = intent?.getStringExtra(EXTRA_URL).orEmpty()

        setContent {
            ShopliveOnboardingTheme {
                ProductDetailScreen(
                    receivedUrl = url,
                    onClose = { finish() },
                )
            }
        }
    }

    companion object {
        private const val EXTRA_URL = "extra_url"

        fun intent(context: Context, url: String): Intent =
            Intent(context, ProductDetailActivity::class.java).putExtra(EXTRA_URL, url)
    }
}
