package cloud.shoplive.onboarding.integration

import android.content.Context
import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.core.publicsurface.ShopliveAttribution
import cloud.shoplive.core.publicsurface.ShopliveConfiguration

/**
 * SDK initialization — done **once** for the whole app.
 *
 * ```kotlin
 * Shoplive.initialize(context, ShopliveConfiguration(accessKey = "{ACCESS_KEY}"))
 * ```
 *
 * Put it in `Application.onCreate()`. A deep link can cold-start the app
 * (see [ShopliveDeepLinkRouter]), and initialization has to be finished before
 * the player starts, otherwise playback fails with `NOT_INITIALIZED_ACCESS_KEY`.
 *
 * To switch accounts, call [initialize] again — the last access key wins. To also
 * change *who* the viewer is, call [logout] first: that is what clears the
 * authentication slots.
 */
object ShopliveInitializer {

    @Volatile
    private var initializedAccessKey: String? = null

    val isInitialized: Boolean get() = initializedAccessKey != null

    val currentAccessKey: String? get() = initializedAccessKey

    /**
     * @param allowedWebViewDomains restricts the domains the overlay WebView may
     *   open. Empty means no restriction.
     * @param attribution UTM parameters. This is a **full replace** — you cannot
     *   change one field, and passing null keeps whatever was set before.
     */
    fun initialize(
        context: Context,
        accessKey: String,
        allowedWebViewDomains: List<String> = emptyList(),
        attribution: ShopliveAttribution? = null,
    ) {
        Shoplive.initialize(
            context,
            ShopliveConfiguration(
                accessKey = accessKey,
                allowedWebViewDomains = allowedWebViewDomains,
                attribution = attribution,
            ),
        )
        initializedAccessKey = accessKey
        logCall("Shoplive.initialize(accessKey: \"${shopliveMasked(accessKey)}\")")
        logCall("SDK version ${Shoplive.sdkVersion}")
    }

    /**
     * Initializes only if it has not happened yet, or the access key changed.
     * Calling initialize repeatedly with the same key is harmless; this guard
     * exists to keep the log readable.
     */
    fun initializeIfNeeded(context: Context, accessKey: String) {
        if (accessKey.isBlank()) return
        if (initializedAccessKey == accessKey) return
        initialize(context, accessKey)
    }

    /**
     * Releases the authenticated identity — user, auth token and stream token, all
     * three slots at once. The access key and UTM values survive.
     *
     * `setUser(Guest)` does **not** do this (it is a no-op on the auth slots).
     */
    fun logout() {
        Shoplive.logout()
        logCall("Shoplive.logout() — cleared user/authToken/streamToken")
    }

    // ── Key format pre-check ─────────────────────────────────────────────────
    //
    // There is no API to ask the SDK whether a key is valid (initialize just
    // stores it). So the only thing worth doing locally is catching malformed
    // input — real validity shows up as an error event on the first play attempt,
    // which ShopliveErrorCause turns into a message.

    sealed interface Validation {
        data object Valid : Validation

        /** Use [Reason] to pick your own localized text; the enum is stable. */
        data class Invalid(val reason: Reason) : Validation
    }

    enum class Reason(val defaultMessage: String) {
        KEYS_REQUIRED("accessKey and campaignKey are required."),

        /** Copy-paste from a console usually gains a trailing space or newline. */
        ACCESS_KEY_WHITESPACE(
            "accessKey contains whitespace. Check whether it was truncated when copied."
        ),

        CAMPAIGN_KEY_WHITESPACE("campaignKey contains whitespace."),
    }

    fun validate(accessKey: String, campaignKey: String): Validation = when {
        accessKey.isBlank() || campaignKey.isBlank() ->
            Validation.Invalid(Reason.KEYS_REQUIRED)

        accessKey.any(Char::isWhitespace) ->
            Validation.Invalid(Reason.ACCESS_KEY_WHITESPACE)

        campaignKey.any(Char::isWhitespace) ->
            Validation.Invalid(Reason.CAMPAIGN_KEY_WHITESPACE)

        else -> Validation.Valid
    }
}
