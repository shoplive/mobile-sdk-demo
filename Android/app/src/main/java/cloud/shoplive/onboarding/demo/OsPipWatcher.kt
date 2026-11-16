package cloud.shoplive.onboarding.demo

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.activity.ComponentActivity
import cloud.shoplive.onboarding.data.DemoLog

/**
 * Tells the demo when the SDK player enters the system (OS) PIP window.
 *
 * ## Why the demo needs this
 * Since SDK 3.0.5 every PIP request from the full-screen player — the PIP button,
 * a product tap with `actionOnNavigation = PIP`, back press,
 * `enterPictureInPicture()` — opens **OS PIP**, and OS PIP is not reported through
 * `ShoplivePlayerState`: the state stays `Playing` / `Paused`, and `InAppPIP` is now
 * emitted only for the SDK's in-app floating window (`presentationStyle = PIP`). The public
 * surface has no OS PIP callback either, so mission 5 would never complete from
 * delegate events alone.
 *
 * ## How
 * The standard AndroidX signal: every `ComponentActivity` in this process gets an
 * `addOnPictureInPictureModeChangedListener`. The only Activity in this app that can
 * enter PIP is the SDK's player, so any entry is counted.
 *
 * **Demo harness only, not part of the copy-paste layer.** It relies on the SDK
 * player being a `ComponentActivity` that forwards `onPictureInPictureModeChanged`
 * to `super` — true for 3.0.5 (`AppCompatActivity`), but not a documented contract.
 */
object OsPipWatcher {

    fun install(application: Application, onEntered: () -> Unit) {
        application.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                    // Stored on the Activity it captures, so it is collected with that
                    // Activity — nothing to unregister.
                    (activity as? ComponentActivity)?.addOnPictureInPictureModeChangedListener { info ->
                        if (info.isInPictureInPictureMode) {
                            DemoLog.event("OS PIP entered (${activity.javaClass.simpleName})")
                            onEntered()
                        }
                    }
                }

                override fun onActivityStarted(activity: Activity) = Unit
                override fun onActivityResumed(activity: Activity) = Unit
                override fun onActivityPaused(activity: Activity) = Unit
                override fun onActivityStopped(activity: Activity) = Unit
                override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
                override fun onActivityDestroyed(activity: Activity) = Unit
            }
        )
    }
}
