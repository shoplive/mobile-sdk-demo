package cloud.shoplive.onboarding.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Stores the access key, campaign key and stream token **on the device only**. None
 * of it is sent anywhere.
 *
 * [EncryptedSharedPreferences] by default (the file is encrypted through the Android
 * Keystore); on a device where the Keystore is unusable it falls back to plain
 * SharedPreferences, which beats the demo failing to start at all. Whether it fell
 * back is visible through [isEncrypted] and shown in the UI.
 */
class CredentialStore(context: Context) {

    private var encrypted = true

    private val prefs: SharedPreferences = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "shoplive_demo_credentials",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (t: Throwable) {
        // Fallback for a corrupt or unsupported Keystore. Log the cause, do not
        // swallow it.
        Log.w(TAG, "EncryptedSharedPreferences unavailable — falling back to plain SharedPreferences", t)
        encrypted = false
        context.getSharedPreferences("shoplive_demo_credentials_plain", Context.MODE_PRIVATE)
    }

    val isEncrypted: Boolean get() = encrypted

    var accessKey: String
        get() = prefs.getString(KEY_ACCESS, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_ACCESS, value.trim()).apply()

    var campaignKey: String
        get() = prefs.getString(KEY_CAMPAIGN, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_CAMPAIGN, value.trim()).apply()

    var streamToken: String
        get() = prefs.getString(KEY_STREAM_TOKEN, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_STREAM_TOKEN, value.trim()).apply()

    /** JWT for user authentication (Mission 3). Only used by the `token` method. */
    var userJwt: String
        get() = prefs.getString(KEY_USER_JWT, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_USER_JWT, value.trim()).apply()

    /** The last mode used, so a relaunch can skip the start screen. */
    var mode: DemoMode?
        get() = prefs.getString(KEY_MODE, null)?.let { saved ->
            DemoMode.entries.firstOrNull { it.name == saved }
        }
        set(value) = prefs.edit().putString(KEY_MODE, value?.name).apply()

    fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val TAG = "CredentialStore"
        const val KEY_ACCESS = "accessKey"
        const val KEY_CAMPAIGN = "campaignKey"
        const val KEY_STREAM_TOKEN = "streamToken"
        const val KEY_USER_JWT = "userJwt"
        const val KEY_MODE = "mode"
    }
}

/** Which credentials the app is running with. */
enum class DemoMode {
    /** Try it with the built-in demo keys, no input needed. */
    TOUR,

    /** Try it with the user's own keys. */
    OWN,
}
