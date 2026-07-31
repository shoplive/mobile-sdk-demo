package cloud.shoplive.onboarding.integration

/**
 * The single hole through which this package emits log lines.
 *
 * Files in this package never call `android.util.Log`, Timber, or the demo app's
 * event log directly. They call [shopliveLog], which does nothing by default.
 * That is what makes them copyable: an app that copies these files gets silence
 * until it opts in, and never a missing-symbol error.
 *
 * ## Wiring it up (one line, in Application.onCreate)
 * ```kotlin
 * shopliveLog = { kind, message -> Log.d("Shoplive", "${kind.tag} $message") }
 * ```
 *
 * If you do not want any of it, delete this file and the `shopliveLog(...)` /
 * `logCall(...)` calls in the other files. Nothing else depends on it.
 */
enum class ShopliveLogKind(val tag: String) {
    /** App -> SDK. An API call we made (initialize / setUser / start / play ...). */
    CALL("→SDK"),

    /** SDK -> app notification (`ShoplivePlayerDelegate.onEvent`). */
    EVENT("EVENT"),

    /** SDK -> app request (`onRequest`). The app has to answer these. */
    REQUEST("REQUEST"),

    /** The answer we sent back (`respond(...)`). */
    RESPOND("RESPOND"),

    /** Something failed. */
    ERROR("ERROR"),
}

/**
 * Log sink. No-op until the host app replaces it.
 *
 * Contract: set this once, early (`Application.onCreate`), before any Shoplive
 * call. It is a plain `var` — reassigning it while playback is running is not
 * synchronised, and the SDK delivers events on the main thread, so a late swap
 * from a background thread may drop or duplicate a line.
 *
 * Log text is intentionally NOT localized: it records SDK API names and event
 * payloads for developers, and translating those makes them harder to match
 * against the SDK reference.
 */
var shopliveLog: (ShopliveLogKind, String) -> Unit = { _, _ -> }

internal fun logCall(message: String) = shopliveLog(ShopliveLogKind.CALL, message)
internal fun logEvent(message: String) = shopliveLog(ShopliveLogKind.EVENT, message)
internal fun logRequest(message: String) = shopliveLog(ShopliveLogKind.REQUEST, message)
internal fun logRespond(message: String) = shopliveLog(ShopliveLogKind.RESPOND, message)
internal fun logError(message: String) = shopliveLog(ShopliveLogKind.ERROR, message)

/**
 * Shortens a secret to its first 8 characters for logging.
 *
 * Access keys, JWTs and stream tokens end up in log lines that get copied into
 * bug reports and crash reporters. Never log them whole — you do not control
 * where the log goes.
 */
fun shopliveMasked(value: String?): String = when {
    value.isNullOrBlank() -> "(none)"
    value.length <= 8 -> "$value…"
    else -> "${value.take(8)}…"
}
