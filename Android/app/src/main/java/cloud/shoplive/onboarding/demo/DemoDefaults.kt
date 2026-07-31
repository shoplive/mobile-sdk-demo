package cloud.shoplive.onboarding.demo

/**
 * Built-in credentials for tour mode.
 *
 * These are checked in on purpose, so that cloning the repo and pressing "look
 * around" works with no setup — the same choice the iOS demo makes in
 * `DemoCredentials.swift` (`DemoDefaults`). Keep the two in sync: they are the same
 * demo account, and a token rotated on one side has to be rotated on the other.
 *
 * ## What this means
 * These are real values in a public-facing repository. They are a **throwaway demo
 * account** and nothing else may ever be put here. Anything belonging to a customer
 * or to production goes in `local.properties` (git-ignored) or the environment,
 * both of which override the values below — see
 * [cloud.shoplive.onboarding.DemoContainer].
 *
 * ## Rotation
 * Rotating a token here does not remove the old one from git history. Treat every
 * value in this file as already public, and rotate on the Shoplive console when it
 * needs to stop working.
 *
 * The stream token in particular is short-lived: broadcasting (Mission 8) stops
 * working when it expires, and the fix is a new token from the console, pasted here
 * and into the iOS file.
 */
object DemoDefaults {

    /** Demo account access key. */
    const val ACCESS_KEY = "ZJZBkloYuh5zXsH7wuUi"

    /** Demo campaign. */
    const val CAMPAIGN_KEY = "9c83384b5c93"

    /** Broadcast token for Mission 8. Expires; see the rotation note above. */
    const val STREAM_TOKEN =
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMDAzODI2IiwiYWNjZXNzS2V5IjoiWkpaQmtsb1l1aDV6WHNIN3d1VWkiLCJzb3VyY2UiOiJTVFJFQU1fQVBQIiwiZXhwIjoxODE2OTk4MjcxLCJpYXQiOjE3ODU0NjIyNzF9.77ZUK-ztmLR0Ow4N3vllxwU9-s-ziAtqGezvzvaZHhw"
}
