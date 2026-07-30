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
import cloud.shoplive.onboarding.demo.DemoLogBridge
import cloud.shoplive.onboarding.integration.ShopliveInitializer
import java.lang.ref.WeakReference

/**
 * App entry point.
 *
 * **SDK initialization happens here.** A deep link can cold-start the app
 * (see `ShopliveDeepLinkRouter`), and the access key has to be set before playback
 * starts. The last used mode's key is restored and initialized; when nothing is
 * stored, initialization waits until the user chooses on the start screen.
 */
class DemoApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Pin the display language first — every context created later reads it.
        LocaleSetting.install(this)

        // Install the log sink before any SDK call, so nothing is lost. This is the
        // only wiring the copy-paste layer needs from the host app.
        DemoLogBridge.install()

        DemoContainer.install(this)
        ProductRouter.install(this)

        // On relaunch, skip the start screen and go straight in with the last mode.
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
 * A very small service locator, so the demo does not drag in a DI framework. In a
 * customer app, replace it with Hilt, Koin, or whatever you already use.
 *
 * Note that nothing in `:integration` knows this exists — it takes what it needs as
 * constructor and function parameters. That is the point: a DI choice made here
 * cannot leak into the files a customer copies.
 */
object DemoContainer {

    lateinit var credentials: CredentialStore
        private set

    lateinit var progress: MissionProgress
        private set

    /** App context for reading string resources outside Compose (ViewModel, delegate). */
    lateinit var appContext: Context
        private set

    fun install(application: Application) {
        appContext = application
        credentials = CredentialStore(application)
        progress = MissionProgress(application)
    }

    /**
     * String resource lookup helper.
     *
     * The app context carries the **device** language, so it cannot be used as-is —
     * read from the context [LocaleSetting] wrapped in the chosen language
     * (English by default).
     */
    fun string(@StringRes id: Int, vararg args: Any): String {
        val context = LocaleSetting.wrap(appContext)
        return if (args.isEmpty()) context.getString(id) else context.getString(id, *args)
    }

    /** Built-in demo keys for tour mode, injected from local.properties. */
    val demoAccessKey: String get() = BuildConfig.DEMO_ACCESS_KEY
    val demoCampaignKey: String get() = BuildConfig.DEMO_CAMPAIGN_KEY
    val demoStreamToken: String get() = BuildConfig.DEMO_STREAM_TOKEN

    val hasDemoKeys: Boolean
        get() = demoAccessKey.isNotBlank() && demoCampaignKey.isNotBlank()
}

/**
 * Opens the destination of a `navigation(url)` request.
 *
 * ## Why it launches an Activity
 * When the request arrives, the **SDK player Activity is front-most**. This app's
 * Compose screens are behind it, so showing a product detail means putting a new
 * Activity on top.
 *
 * `ShoplivePlayerRequest.Navigation` also only gives a url — no context. So the app
 * has to know its own screen context; here that means tracking the resumed Activity.
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
        // Nothing on screen at all (app in background) — start a new task.
        application?.let { app ->
            app.startActivity(
                ProductDetailActivity.intent(app, url).apply {
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }
}
