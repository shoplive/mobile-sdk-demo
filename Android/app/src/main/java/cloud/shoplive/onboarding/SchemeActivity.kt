package cloud.shoplive.onboarding

import android.content.Intent
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.sdk.DeepLinkRouter

/**
 * Mission 2 — 딥링크 진입점.
 *
 * ## 이 화면은 재생하지 않는다
 * 파싱만 하고 [MainActivity] 로 넘긴다. 이유는 **콜드 스타트 안전성**이다.
 *
 * 링크를 탭하는 순간 앱이 죽어 있으면 `Shoplive.initialize` 가 아직 실행되지 않았을 수 있다.
 * 그 상태에서 바로 재생을 부르면 `NOT_INITIALIZED_ACCESS_KEY` 로 떨어진다. 초기화 완료
 * 여부를 아는 곳은 앱의 메인 화면이므로, 판단과 재생을 그쪽에 위임한다.
 *
 * 또 이 Activity 는 `noHistory=true` 로 즉시 사라진다. `ShoplivePlayer(context)` 는 생성자
 * context 를 약참조로 들고 있어, 곧 finish 되는 Activity 를 넘기면 이후 `play()` 재호출이
 * 거부될 수 있다 — 살아 있는 화면(MainActivity)에서 기동하는 편이 안전하다.
 */
class SchemeActivity : ComponentActivity() {
    /** 앱이 고른 표시 언어(기본 영어)를 이 화면의 리소스에 적용한다. */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(LocaleSetting.wrap(newBase))
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val link = DeepLinkRouter.parse(intent?.data)

        startActivity(
            Intent(this, MainActivity::class.java).apply {
                // singleTask 인 MainActivity 가 이미 떠 있으면 onNewIntent 로 받는다.
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
