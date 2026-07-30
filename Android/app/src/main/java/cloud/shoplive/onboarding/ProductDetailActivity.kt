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
 * V2 — 상품 상세를 담는 Activity.
 *
 * ## 왜 Compose 화면이 아니라 Activity 인가
 * `navigation(url)` 요청은 **SDK 플레이어 Activity 가 화면 맨 앞에 있을 때** 도착한다.
 * 데모앱의 Compose NavHost 는 그 뒤에 있으므로, 그쪽 라우트로 이동시켜도 사용자 눈에는
 * 아무 일도 일어나지 않는다. 그래서 상품 상세는 플레이어 위에 올릴 수 있는 별도 Activity 다.
 *
 * 실제 앱에서도 상품 랜딩은 보통 별도 화면·모달이라 이 구조가 자연스럽다.
 */
class ProductDetailActivity : ComponentActivity() {
    /** 앱이 고른 표시 언어(기본 영어)를 이 화면의 리소스에 적용한다. */
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
