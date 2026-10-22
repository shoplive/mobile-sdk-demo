package cloud.shoplive.onboarding.integration

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Turning a link into playback.
 *
 * Handles links shaped like
 *
 * ```
 * {scheme}://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
 * ```
 *
 * The scheme and host are **parameters, not constants**: they belong to your app's
 * manifest (`<intent-filter>`), not to this file. Pass the same value you declared
 * there.
 *
 * ## Cold start is the whole problem
 * The app may be dead when the link is tapped. The order then has to be:
 *
 * 1. `Shoplive.initialize(...)` — set the access key (normally `Application.onCreate`)
 * 2. `Shoplive.setUser(...)` — if you need it
 * 3. `ShoplivePlayer(activity).start(campaignKey, PlayOptions(referrer))`
 *
 * Call playback before initialization and it fails with
 * `NOT_INITIALIZED_ACCESS_KEY`.
 *
 * ## Which is why this file does not start playback
 * It only parses. Deliberately.
 *
 * The Activity that receives the link is typically `noHistory=true` and finishes
 * immediately, and `ShoplivePlayer(context)` holds its constructor context weakly —
 * hand it an Activity that is about to disappear and later `play()` calls can be
 * refused. Only the host screen knows whether initialization has finished and which
 * Activity is alive, so it decides and it plays. That is also why there is no
 * `configurationProvider` here: the configuration belongs to whoever starts
 * playback, and that is not this object.
 *
 * See the demo's `SchemeActivity` -> `MainActivity` hand-off for the shape.
 */
object ShopliveDeepLinkRouter {

    private const val PARAM_CAMPAIGN = "campaign"
    private const val PARAM_REF = "ref"

    data class Link(
        val campaignKey: String,
        /**
         * Where the viewer came from. Forwarded as `ShoplivePlayOptions.referrer`
         * (truncated at 1024 characters) — the only link between "which push" and
         * "how long they watched".
         */
        val referrer: String?,
    )

    /**
     * @param scheme the scheme from your manifest's intent-filter, e.g. `myshop`.
     * @param host the host from the same filter. Defaults to `live`.
     * @return a [Link] when this is a link we can handle, otherwise null. Null means
     *   "not ours" — let the rest of your routing have it.
     */
    fun parse(uri: Uri?, scheme: String, host: String = "live"): Link? {
        if (uri == null) return null
        if (!uri.scheme.equals(scheme, ignoreCase = true)) return null
        if (!uri.host.equals(host, ignoreCase = true)) return null

        val campaignKey = uri.getQueryParameter(PARAM_CAMPAIGN)?.trim().orEmpty()
        if (campaignKey.isEmpty()) {
            logError("Deep link has no campaign parameter: $uri")
            return null
        }

        val link = Link(campaignKey = campaignKey, referrer = uri.getQueryParameter(PARAM_REF))
        logCall("deep link received — $uri")
        logCall(
            "parsed → campaignKey: \"${link.campaignKey}\", referrer: ${link.referrer ?: "null"}"
        )
        return link
    }

    /** Builds the link your backend or push payload should contain. */
    fun linkUri(scheme: String, campaignKey: String, referrer: String? = null, host: String = "live"): Uri =
        Uri.parse(
            buildString {
                append("$scheme://$host?$PARAM_CAMPAIGN=$campaignKey")
                if (!referrer.isNullOrBlank()) append("&$PARAM_REF=$referrer")
            }
        )

    /**
     * Fires the link at your own app, as a push would.
     *
     * Useful while integrating: it goes through the **real** intent-filter and the
     * real cold-start path, so it proves the wiring rather than simulating it. Set
     * up a test button with this before you go and configure a push provider.
     */
    fun sendTestLink(
        context: Context,
        scheme: String,
        campaignKey: String,
        referrer: String? = null,
        host: String = "live",
    ) {
        val uri = linkUri(scheme, campaignKey, referrer, host)
        logCall("test deep link fired — $uri")
        context.startActivity(
            Intent(Intent.ACTION_VIEW, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }
}
