package cloud.shoplive.onboarding.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * accessKey · campaignKey · 송출 토큰을 **기기에만** 저장한다. 서버로 보내지 않는다.
 *
 * 기본은 [EncryptedSharedPreferences](Android Keystore 로 파일을 암호화)이고, Keystore 를
 * 쓸 수 없는 기기에서는 일반 SharedPreferences 로 내려간다 — 데모앱이 아예 못 뜨는 것보다
 * 낫기 때문이다. 내려갔는지는 [isEncrypted] 로 확인할 수 있고 앱 화면에 그대로 노출한다.
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
        // Keystore 손상·미지원 기기 폴백. 원인을 삼키지 않고 로그로 남긴다.
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

    /** 사용자 인증(Mission 3)용 JWT. `token` 방식을 고를 때만 쓴다. */
    var userJwt: String
        get() = prefs.getString(KEY_USER_JWT, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_USER_JWT, value.trim()).apply()

    /** 마지막으로 쓴 모드. 재실행 시 시작 화면을 건너뛰기 위한 값. */
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

/** 앱이 어떤 자격증명으로 동작 중인지. */
enum class DemoMode {
    /** 내장 데모 키로 입력 없이 확인. */
    TOUR,

    /** 사용자가 입력한 자기 키로 확인. */
    OWN,
}
