package cloud.shoplive.onboarding.demo

import androidx.annotation.StringRes
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.integration.ShopliveErrorCause
import cloud.shoplive.onboarding.integration.ShopliveInitializer
import cloud.shoplive.onboarding.integration.ShopliveUserSetup

/**
 * Localized text for the enums the copy-paste layer reports.
 *
 * `:integration` returns *reasons*, not sentences — [ShopliveErrorCause],
 * [ShopliveInitializer.Reason], [ShopliveUserSetup.Method] — each carrying an
 * English default for logs. Anything a user reads is looked up here instead, so
 * localization stays in the app that owns the resources.
 *
 * A customer app either does the same with its own strings, or prints the
 * `defaultMessage` and moves on.
 */
object DemoLabels {

    @StringRes
    fun messageRes(cause: ShopliveErrorCause): Int = when (cause) {
        ShopliveErrorCause.ACCESS_KEY -> R.string.err_access_key
        ShopliveErrorCause.CAMPAIGN_NOT_FOUND -> R.string.err_campaign_not_found
        ShopliveErrorCause.NOT_ON_AIR -> R.string.err_not_on_air
        ShopliveErrorCause.AUTH_REQUIRED -> R.string.err_auth_required
        ShopliveErrorCause.NETWORK -> R.string.err_network
        ShopliveErrorCause.SERVER -> R.string.err_server
        ShopliveErrorCause.OTHER -> R.string.err_other
    }

    @StringRes
    fun messageRes(reason: ShopliveInitializer.Reason): Int = when (reason) {
        ShopliveInitializer.Reason.KEYS_REQUIRED -> R.string.validate_keys_required
        ShopliveInitializer.Reason.ACCESS_KEY_WHITESPACE -> R.string.validate_access_key_whitespace
        ShopliveInitializer.Reason.CAMPAIGN_KEY_WHITESPACE -> R.string.validate_campaign_key_whitespace
    }

    /** The `guest` / `profile` / `token` labels are API values and stay untranslated. */
    @StringRes
    fun descriptionRes(method: ShopliveUserSetup.Method): Int = when (method) {
        ShopliveUserSetup.Method.GUEST -> R.string.auth_guest_desc
        ShopliveUserSetup.Method.PROFILE -> R.string.auth_profile_desc
        ShopliveUserSetup.Method.TOKEN -> R.string.auth_token_desc
    }
}
