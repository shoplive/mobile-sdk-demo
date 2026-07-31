package cloud.shoplive.onboarding.integration

import cloud.shoplive.player.ShopliveError
import cloud.shoplive.player.ShopliveErrorCode
import cloud.shoplive.player.ShoplivePlaybackEvent

/**
 * Human-readable labels for SDK enums.
 *
 * These are the smallest extensions that make SDK values readable in a log, and
 * you need them the moment you start reading logs — so they are part of the
 * copyable set, not the demo harness.
 *
 * The English text here is a *default*. If your app shows any of it to users,
 * map [ShopliveErrorCause] to your own localized resources instead of printing
 * [ShopliveErrorCause.defaultMessage]; log lines themselves stay English.
 */

/** Short label used in log lines. */
val ShoplivePlaybackEvent.logLabel: String
    get() = when (this) {
        is ShoplivePlaybackEvent.Requested -> "requested"
        is ShoplivePlaybackEvent.Started -> "started"
        is ShoplivePlaybackEvent.Rendering -> "rendering"
        is ShoplivePlaybackEvent.RebufferingStarted -> "rebufferingStarted"
        is ShoplivePlaybackEvent.RebufferingEnded -> "rebufferingEnded"
        is ShoplivePlaybackEvent.Buffering -> "buffering"
        is ShoplivePlaybackEvent.AudioLoaded -> "audioLoaded"
        is ShoplivePlaybackEvent.Ended -> "ended"
        is ShoplivePlaybackEvent.Failed -> "failed(code: $code, message: $message)"
    }

/**
 * Why playback failed, grouped by what the app should do about it.
 *
 * The SDK has no "is this key valid?" API — `Shoplive.initialize` only stores
 * the value. So a bad access key, a missing campaign, an auth problem and a dead
 * network are all told apart *after* a play attempt, from the error event. This
 * grouping is what turns that into a message worth showing.
 */
enum class ShopliveErrorCause(val defaultMessage: String) {
    /** initialize was never called, or the access key is wrong. */
    ACCESS_KEY("Invalid key — accessKey is not set. Call initialize first."),

    CAMPAIGN_NOT_FOUND("Campaign not found — check the campaignKey."),

    NOT_ON_AIR("The campaign is not on air. Check whether it is VOD and its scheduled time."),

    /** The viewer identity is missing, expired, or rejected. See ShopliveUserSetup. */
    AUTH_REQUIRED("Authentication required — check user authentication."),

    NETWORK("Network — check your connection. (The SDK is attempting automatic recovery.)"),

    SERVER("Server error — try again shortly."),

    OTHER("Other error"),
}

/**
 * Maps an SDK error code onto the cause groups above.
 *
 * Named `causeGroup`, not `cause`: `ShopliveError` extends `Throwable`, so an
 * extension called `cause` is silently shadowed by `Throwable.cause` at every call
 * site and you get a `Throwable?` where you expected a group. Measured 2026-07-30,
 * SDK 3.0.0.
 */
val ShopliveError.causeGroup: ShopliveErrorCause
    get() = when (code) {
        ShopliveErrorCode.NOT_INITIALIZED_ACCESS_KEY -> ShopliveErrorCause.ACCESS_KEY

        ShopliveErrorCode.CAMPAIGN_NOT_FOUND -> ShopliveErrorCause.CAMPAIGN_NOT_FOUND

        ShopliveErrorCode.CAMPAIGN_NOT_ON_AIR -> ShopliveErrorCause.NOT_ON_AIR

        ShopliveErrorCode.AUTHENTICATION_FAILED,
        ShopliveErrorCode.GUEST_LOGIN_NOT_ALLOWED,
        ShopliveErrorCode.CUSTOM_ACCOUNT_NOT_FOUND,
        ShopliveErrorCode.CUSTOM_ACCOUNT_EXPIRED,
        ShopliveErrorCode.INVALID_SIGNATURE,
        ShopliveErrorCode.DUPLICATE_SESSION,
        ShopliveErrorCode.EXPIRED_SESSION -> ShopliveErrorCause.AUTH_REQUIRED

        ShopliveErrorCode.CONNECTION_ISSUE,
        ShopliveErrorCode.FAILED_NETWORK -> ShopliveErrorCause.NETWORK

        ShopliveErrorCode.SERVER_ERROR -> ShopliveErrorCause.SERVER

        else -> ShopliveErrorCause.OTHER
    }

/**
 * One log line carrying everything needed to diagnose the error: the raw codes,
 * whether the SDK will keep trying, and the grouped cause.
 */
val ShopliveError.logLine: String
    get() = "error(code: $code, rawCode: $rawCode, isRecoverable: $isRecoverable) " +
        "${causeGroup.defaultMessage} · $message"
