package cloud.shoplive.onboarding

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.annotation.StringRes
import cloud.shoplive.onboarding.data.CredentialStore
import cloud.shoplive.onboarding.data.DemoMode
import cloud.shoplive.onboarding.data.LocaleSetting
import cloud.shoplive.onboarding.data.MissionProgress
import cloud.shoplive.onboarding.sdk.ShopliveInitializer
import java.lang.ref.WeakReference

/**
 * 앱 시작점.
 *
 * **SDK 초기화를 여기서 한다.** 딥링크로 콜드 스타트하는 경로(Mission 2)에서도 재생 전에
 * accessKey 가 설정돼 있어야 하기 때문이다. 마지막으로 쓴 모드의 키를 복구해 초기화하고,
 * 저장된 것이 없으면 시작 화면에서 사용자가 고를 때까지 초기화를 미룬다.
 */
class DemoApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // 표시 언어를 가장 먼저 확정한다 — 이후 만들어지는 컨텍스트가 이 값을 쓴다.
        LocaleSetting.install(this)

        DemoContainer.install(this)
        ProductRouter.install(this)

        // 재실행 시 시작 화면을 건너뛰고 마지막 모드로 들어간다.
        val credentials = DemoContainer.credentials
        val accessKey = when (credentials.mode) {
            DemoMode.OWN -> credentials.accessKey
            DemoMode.TOUR -> BuildConfig.DEMO_ACCESS_KEY
            null -> ""
        }
        ShopliveInitializer.initializeIfNeeded(this, accessKey)
    }
}

/**
 * 아주 작은 서비스 로케이터. 데모앱에 DI 프레임워크를 끌어들이지 않기 위한 선택이다 —
 * 고객사 앱에서는 Hilt·Koin 등 쓰던 방식으로 바꾸면 된다.
 */
object DemoContainer {

    lateinit var credentials: CredentialStore
        private set

    lateinit var progress: MissionProgress
        private set

    /** Compose 밖(ViewModel·delegate)에서 문자열 리소스를 읽기 위한 앱 컨텍스트. */
    lateinit var appContext: Context
        private set

    fun install(application: Application) {
        appContext = application
        credentials = CredentialStore(application)
        progress = MissionProgress(application)
    }

    /**
     * 리소스 문자열 조회 헬퍼.
     *
     * 앱 컨텍스트는 **기기 언어**를 들고 있으므로 그대로 쓰면 안 된다 —
     * [LocaleSetting] 이 고른 언어로 감싼 컨텍스트에서 읽는다(기본 영어).
     */
    fun string(@StringRes id: Int, vararg args: Any): String {
        val context = LocaleSetting.wrap(appContext)
        return if (args.isEmpty()) context.getString(id) else context.getString(id, *args)
    }

    /** 둘러보기 모드에 쓰는 내장 데모 키. local.properties 에서 주입된다. */
    val demoAccessKey: String get() = BuildConfig.DEMO_ACCESS_KEY
    val demoCampaignKey: String get() = BuildConfig.DEMO_CAMPAIGN_KEY
    val demoStreamToken: String get() = BuildConfig.DEMO_STREAM_TOKEN

    val hasDemoKeys: Boolean
        get() = demoAccessKey.isNotBlank() && demoCampaignKey.isNotBlank()
}

/**
 * `navigation(url)` 요청의 도착지를 연다.
 *
 * ## 왜 Activity 를 새로 띄우나
 * 요청이 도착하는 시점에는 **SDK 플레이어 Activity 가 화면 맨 앞**에 있다. 데모앱의
 * Compose 화면은 그 뒤에 있으므로, 상품 상세를 보여주려면 새 Activity 를 그 위에 올려야 한다.
 *
 * 또 `ShoplivePlayerRequest.Navigation` 은 url 만 준다(context 를 주지 않는다). 그래서
 * 앱이 자기 화면 컨텍스트를 알고 있어야 한다 — 여기서는 현재 떠 있는 Activity 를 추적한다.
 */
object ProductRouter {

    private var foreground: WeakReference<Activity> = WeakReference(null)
    private var application: Application? = null

    fun install(application: Application) {
        this.application = application
        application.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityResumed(activity: Activity) {
                    foreground = WeakReference(activity)
                }

                override fun onActivityPaused(activity: Activity) {
                    if (foreground.get() === activity) foreground = WeakReference(null)
                }

                override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
                override fun onActivityStarted(activity: Activity) = Unit
                override fun onActivityStopped(activity: Activity) = Unit
                override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
                override fun onActivityDestroyed(activity: Activity) = Unit
            }
        )
    }

    fun open(url: String) {
        val host = foreground.get()
        if (host != null) {
            host.startActivity(ProductDetailActivity.intent(host, url))
            return
        }
        // 화면이 하나도 떠 있지 않은 예외 상황(백그라운드) — 새 Task 로 올린다.
        application?.let { app ->
            app.startActivity(
                ProductDetailActivity.intent(app, url).apply {
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }
}
