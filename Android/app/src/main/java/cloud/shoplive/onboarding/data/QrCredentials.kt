package cloud.shoplive.onboarding.data

import java.net.URI
import java.net.URISyntaxException
import java.net.URLDecoder

/**
 * Credentials read from a QR code — the same QR codes the native SDK test apps scan.
 *
 * ## Format (from the native test apps)
 * The QR holds a URL. Only its query parameters matter; scheme, host and path are
 * ignored:
 *
 * ```
 * https://<any>?ak=<accessKey>&ck=<campaignKey>&title=<title>&userjwt=<JWT>&st=<streamToken>
 * ```
 *
 * | Key | Field | Source |
 * | --- | --- | --- |
 * | `ak` | accessKey | Android `CampaignListActivity`, iOS `SLQRReaderViewController` |
 * | `ck` | campaignKey | same |
 * | `title` | label only | same (falls back to "Unknown Title (QR)") |
 * | `userjwt` | user JWT (Mission 3) | iOS PlayerDemo2 `SLQRReaderViewController` |
 * | `st` | stream token (Mission 8) | **new in these demos** — no native test app reads it |
 *
 * ## Rules — identical in the Flutter and iOS demos
 * - `ak` and `ck` are used together or not at all, so a half-filled pair never
 *   replaces a working one.
 * - `userjwt` and `st` may come alone.
 * - Blank values count as missing. Values are trimmed and percent-decoded.
 * - The test app's dev flag (`host.contains("dev")`) is ignored: this demo has no dev
 *   environment.
 *
 * Parsed with `java.net.URI` rather than `android.net.Uri` so plain JVM unit tests
 * can run it.
 */
data class QrCredentials(
    val accessKey: String? = null,
    val campaignKey: String? = null,
    val title: String? = null,
    val userJwt: String? = null,
    val streamToken: String? = null,
) {
    val hasKeyPair: Boolean get() = accessKey != null && campaignKey != null

    /** The field names that were filled, for the confirmation message. */
    val filledFields: List<String>
        get() = buildList {
            if (accessKey != null) add("accessKey")
            if (campaignKey != null) add("campaignKey")
            if (streamToken != null) add("streamToken")
            if (userJwt != null) add("userJwt")
        }

    companion object {
        const val KEY_ACCESS_KEY = "ak"
        const val KEY_CAMPAIGN_KEY = "ck"
        const val KEY_TITLE = "title"
        const val KEY_USER_JWT = "userjwt"
        const val KEY_STREAM_TOKEN = "st"

        const val UNKNOWN_TITLE = "Unknown Title (QR)"

        /** Null when the text is not a URL, or carries nothing this demo can use. */
        fun parse(raw: String?): QrCredentials? {
            val text = raw?.trim().orEmpty()
            if (text.isEmpty()) return null
            val query = try {
                URI(text).rawQuery
            } catch (e: URISyntaxException) {
                return null
            } ?: return null

            val params = mutableMapOf<String, String>()
            for (pair in query.split('&')) {
                if (pair.isEmpty()) continue
                val i = pair.indexOf('=')
                val key = decode(if (i < 0) pair else pair.substring(0, i)) ?: return null
                val value = decode(if (i < 0) "" else pair.substring(i + 1)) ?: return null
                params.putIfAbsent(key, value) // first value wins, like Uri.getQueryParameter
            }

            fun value(key: String): String? = params[key]?.trim()?.takeIf { it.isNotEmpty() }

            val ak = value(KEY_ACCESS_KEY)
            val ck = value(KEY_CAMPAIGN_KEY)
            val pairOk = ak != null && ck != null
            val result = QrCredentials(
                accessKey = if (pairOk) ak else null,
                campaignKey = if (pairOk) ck else null,
                title = value(KEY_TITLE),
                userJwt = value(KEY_USER_JWT),
                streamToken = value(KEY_STREAM_TOKEN),
            )
            if (!result.hasKeyPair && result.userJwt == null && result.streamToken == null) return null
            return result
        }

        private fun decode(s: String): String? = try {
            URLDecoder.decode(s, "UTF-8")
        } catch (e: IllegalArgumentException) {
            null // malformed percent-encoding
        }
    }
}
