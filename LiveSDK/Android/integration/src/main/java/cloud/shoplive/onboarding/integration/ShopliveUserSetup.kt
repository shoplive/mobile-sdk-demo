package cloud.shoplive.onboarding.integration

import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.core.publicsurface.ShopliveGender
import cloud.shoplive.core.publicsurface.ShopliveUser
import java.security.MessageDigest

/**
 * Connecting the viewer's identity.
 *
 * Three ways, and one app **may mix them**. They take effect from the next
 * playback onwards.
 *
 * | Method | Call | When |
 * | --- | --- | --- |
 * | guest | `Shoplive.setUser(ShopliveUser.Guest)` | watching without logging in |
 * | profile | `Shoplive.setUser(ShopliveUser.Profile(...))` | show a member without server work |
 * | token | `Shoplive.setUser(ShopliveUser.Token(jwt))` | server-signed JWT (recommended) |
 *
 * ## Careful — Guest is not "sign out"
 * `ShopliveUser.Guest` is a **no-op** on the authentication slots: it leaves an
 * existing identity in place (the guest identifier is issued by the server). To
 * sign out you must call [ShopliveInitializer.logout].
 *
 * ## Token beats Profile
 * Once a Token is set, tokens generated from a Profile are ignored.
 */
object ShopliveUserSetup {

    /** [label] is the API value, so it is never translated. */
    enum class Method(val label: String) {
        GUEST("guest"),
        PROFILE("profile"),
        TOKEN("token"),
    }

    /**
     * @param jwt required for [Method.TOKEN]. Blank falls back to guest.
     * @param profile used for [Method.PROFILE]. Defaults to [exampleProfile];
     *   pass the values of your own logged-in session instead.
     * @return the method that was actually applied.
     */
    fun apply(
        method: Method,
        jwt: String = "",
        profile: ShopliveUser.Profile = exampleProfile(),
    ): Method {
        val effective = if (method == Method.TOKEN && jwt.isBlank()) Method.GUEST else method

        when (effective) {
            Method.GUEST -> {
                // Guest alone will not release an existing login — clear it explicitly.
                Shoplive.logout()
                Shoplive.setUser(ShopliveUser.Guest)
                logCall("Shoplive.logout() → setUser(ShopliveUser.Guest)")
            }

            Method.PROFILE -> {
                Shoplive.setUser(profile)
                logCall("Shoplive.setUser(ShopliveUser.Profile(id: \"${shopliveMasked(profile.id)}\"))")
            }

            Method.TOKEN -> {
                Shoplive.setUser(ShopliveUser.Token(jwt))
                logCall("Shoplive.setUser(ShopliveUser.Token(\"${shopliveMasked(jwt)}\"))")
            }
        }

        if (method == Method.TOKEN && effective == Method.GUEST) {
            logError("token method selected but the JWT is empty — falling back to guest.")
        }
        return effective
    }

    /**
     * Example profile. Replace the values with your logged-in session's.
     *
     * Hashing `id` is **recommended** — it keeps the raw member ID out of the SDK
     * and off the Shoplive servers while staying stable per user.
     *
     * [ShopliveGender.UNDEFINED] means "not collected" and is not transmitted;
     * [ShopliveGender.NEUTRAL] is a third gender value and **is** transmitted.
     */
    fun exampleProfile(
        rawUserId: String = "demo-user-0001",
        name: String = "Demo user",
    ): ShopliveUser.Profile = ShopliveUser.Profile(
        id = hashUserId(rawUserId),
        name = name,
        age = 27,
        gender = ShopliveGender.UNDEFINED,
        rank = 1,
        custom = mapOf("grade" to "vip"),
    )

    /** SHA-256(raw + per-app salt). Use a salt of your own, not this one. */
    fun hashUserId(raw: String, salt: String = "SHOPLIVE_DEMO_SALT"): String =
        MessageDigest.getInstance("SHA-256")
            .digest((raw + salt).toByteArray())
            .joinToString("") { "%02x".format(it) }
}
