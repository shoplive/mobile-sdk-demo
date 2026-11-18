package cloud.shoplive.onboarding.integration

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import java.lang.ref.WeakReference

/**
 * Hybrid inline preview — the list lives in a WebView, and a tap hands one
 * campaignKey to the app, which plays it with the native player.
 *
 * The web page calls:
 *
 * ```js
 * if (window.ShopLiveAppInterface) window.ShopLiveAppInterface.postMessage(campaignKey);
 * ```
 *
 * This is the WebView's standard JS-to-native channel, not a Shoplive API. Only one
 * string crosses it; `accessKey` already lives in the app (`Shoplive.initialize`).
 *
 * ## Threading, and why the Activity is held weakly
 * [postMessage] runs on the WebView's **JavaBridge thread**, not the main thread. So
 * it only validates there, then posts to the main thread. By the time that runs the
 * screen may be gone, which is why the Activity is a [WeakReference] checked for
 * `isFinishing` / `isDestroyed` — a late tap from a dead page is dropped, never
 * played on a destroyed Activity.
 *
 * ## Every page inside the WebView can call the bridge
 * If the WebView may navigate to someone else's page, that page can call
 * `postMessage` too. [attachTo] keeps the WebView on your own pages and sends every
 * other URL to the external browser.
 *
 * @param onCampaignKey called on the main thread with a live Activity and a
 *   non-blank key. Start playback here (see [ShoplivePlayerLauncher]).
 */
class ShopliveWebBridge(
    activity: Activity,
    private val onCampaignKey: (activity: Activity, campaignKey: String) -> Unit,
) {
    private val activity = WeakReference(activity)
    private val main = Handler(Looper.getMainLooper())

    /** Set by [detachFrom]. A message already posted to the main thread is dropped. */
    @Volatile
    private var released = false

    /** Called by the page, on the JavaBridge thread. */
    @JavascriptInterface
    fun postMessage(campaignKey: String?) {
        val key = campaignKeyFrom(campaignKey)
        if (key == null) {
            val shown = if (campaignKey == null) "null" else "\"$campaignKey\""
            logError("web bridge: postMessage($shown) ignored — expected one non-blank campaignKey string")
            return
        }
        // TODO(SDP-VERIFY): needs verification — JS-to-Java conversion can turn a non-string (number, object) into text such as "123" or "[object Object]", which passes this check; confirm on a device that such a key ends in the SDK error path and nothing is credited · ref SMV-1922 S10
        main.post { deliver(key) }
    }

    private fun deliver(campaignKey: String) {
        if (released) {
            logError("web bridge: \"$campaignKey\" arrived after the bridge was released — ignored")
            return
        }
        val host = activity.get()
        if (host == null || host.isFinishing || host.isDestroyed) {
            logError("web bridge: \"$campaignKey\" arrived after the screen was gone — ignored")
            return
        }
        logEvent("web bridge: postMessage(\"$campaignKey\")")
        // This runs from a main-thread Handler: an exception here would crash the app
        // for one tap on a web card. Log it with the key instead.
        runCatching { onCampaignKey(host, campaignKey) }
            .onFailure { e -> logError("web bridge: playing \"$campaignKey\" failed — ${e::class.java.simpleName}: ${e.message}") }
    }

    /**
     * Registers this bridge on [webView] — call it **before** `loadUrl`, so the page
     * sees the interface on its first load — and keeps the WebView on your own pages.
     *
     * @param ownPagePrefix URLs starting with this stay in the WebView. Anything else
     *   opens in the external browser and the WebView stays where it is.
     * @param onPageError the main page failed to load, with the reason.
     */
    @SuppressLint("SetJavaScriptEnabled")
    fun attachTo(
        webView: WebView,
        ownPagePrefix: String,
        onPageError: (reason: String) -> Unit = {},
    ) {
        webView.settings.javaScriptEnabled = true
        webView.addJavascriptInterface(this, NAME)
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.url.toString().startsWith(ownPagePrefix)) return false
                openOutside(view.context, request.url)
                return true
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError,
            ) {
                if (!request.isForMainFrame) return
                val reason = "${error.description} (${error.errorCode})"
                logError("web page failed to load: ${request.url} — $reason")
                onPageError(reason)
            }
        }
    }

    /**
     * Undoes [attachTo]: removes the interface, and drops any tap that was already on
     * its way to the main thread. Call before destroying the WebView.
     */
    fun detachFrom(webView: WebView) {
        released = true
        webView.removeJavascriptInterface(NAME)
        logCall("web bridge: $NAME removed")
    }

    private fun openOutside(context: Context, url: Uri) {
        logCall("external link → browser: $url")
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, url))
        } catch (e: ActivityNotFoundException) {
            logError("no app can open $url (${e.message}) — staying on the page")
        }
    }

    companion object {
        /** The name the page calls. Must match the web side exactly. */
        const val NAME = "ShopLiveAppInterface"

        /**
         * The one input rule: a campaignKey is a non-blank string. Null, empty and
         * whitespace-only are not keys. Trimmed, because a key never has whitespace.
         */
        fun campaignKeyFrom(raw: String?): String? = raw?.trim()?.takeIf { it.isNotEmpty() }
    }
}
