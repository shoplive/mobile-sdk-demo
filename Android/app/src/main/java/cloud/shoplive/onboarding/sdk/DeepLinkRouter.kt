package cloud.shoplive.onboarding.sdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import cloud.shoplive.onboarding.BuildConfig
import cloud.shoplive.onboarding.data.DemoLog

/**
 * Mission 2 — 딥링크로 띄우기.
 *
 * 푸시·문자·웹에서 온 링크를 재생으로 잇는다. 다루는 형태는
 *
 * ```
 * shoplivedemo://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
 * ```
 *
 * ## 콜드 스타트가 핵심이다
 * 링크를 탭하는 순간 앱이 죽어 있을 수 있다. 그때 순서는 반드시
 *
 * 1. `Shoplive.initialize(...)` — accessKey 설정 (보통 `Application.onCreate`)
 * 2. `Shoplive.setUser(...)` — 필요하면
 * 3. `ShoplivePlayer(activity).start(campaignKey, PlayOptions(referrer))`
 *
 * 이어야 한다. 초기화 전에 재생을 부르면 `NOT_INITIALIZED_ACCESS_KEY` 로 떨어진다.
 * 그래서 데모앱의 [cloud.shoplive.onboarding.SchemeActivity] 는 **파싱만 하고**
 * MainActivity 로 넘기고, 초기화가 끝난 뒤에 재생을 시작한다.
 *
 * ## ref 는 referrer 로 넘긴다
 * 유입 경로 추적값은 `ShoplivePlayOptions.referrer` 로 전달한다(최대 1024자로 절단된다).
 * 어느 푸시에서 들어와 얼마나 봤는지를 잇는 유일한 연결고리다.
 */
object DeepLinkRouter {

    /** `shoplivedemo` — build.gradle.kts 의 manifestPlaceholder 와 같은 값. */
    val scheme: String get() = BuildConfig.DEEP_LINK_SCHEME

    private const val HOST = "live"
    private const val PARAM_CAMPAIGN = "campaign"
    private const val PARAM_REF = "ref"

    data class Link(val campaignKey: String, val referrer: String?)

    /**
     * @return 우리가 다룰 수 있는 링크면 [Link], 아니면 null.
     */
    fun parse(uri: Uri?): Link? {
        if (uri == null) return null
        if (!uri.scheme.equals(scheme, ignoreCase = true)) return null
        if (!uri.host.equals(HOST, ignoreCase = true)) return null

        val campaignKey = uri.getQueryParameter(PARAM_CAMPAIGN)?.trim().orEmpty()
        if (campaignKey.isEmpty()) {
            DemoLog.error("Deep link has no campaign parameter: $uri")
            return null
        }

        val link = Link(campaignKey = campaignKey, referrer = uri.getQueryParameter(PARAM_REF))
        DemoLog.sdkCall("deep link received — $uri")
        DemoLog.sdkCall(
            "parsed → campaignKey: \"${link.campaignKey}\", referrer: ${link.referrer ?: "null"}"
        )
        return link
    }

    /** 데모앱이 스스로에게 보내는 가짜 푸시. **실제 딥링크 경로를 그대로 통과**한다. */
    fun fakePushUri(campaignKey: String, referrer: String = "push_demo"): Uri =
        Uri.parse("$scheme://$HOST?$PARAM_CAMPAIGN=$campaignKey&$PARAM_REF=$referrer")

    fun sendFakePush(context: Context, campaignKey: String, referrer: String = "push_demo") {
        val uri = fakePushUri(campaignKey, referrer)
        DemoLog.sdkCall("fake push fired — $uri")
        context.startActivity(
            Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }
}
