package cloud.shoplive.onboarding.sdk

import androidx.annotation.StringRes
import cloud.shoplive.core.publicsurface.Shoplive
import cloud.shoplive.core.publicsurface.ShopliveGender
import cloud.shoplive.core.publicsurface.ShopliveUser
import cloud.shoplive.onboarding.DemoContainer
import cloud.shoplive.onboarding.R
import cloud.shoplive.onboarding.data.DemoLog
import java.security.MessageDigest

/**
 * Mission 3 — 회원 정보 연결.
 *
 * 세 가지 방식이 있고 **한 앱에서 섞어 쓸 수 있다**. 적용 시점은 "다음 재생부터"다.
 *
 * | 방식 | 호출 | 언제 쓰나 |
 * | --- | --- | --- |
 * | guest | `Shoplive.setUser(ShopliveUser.Guest)` | 미로그인 시청 |
 * | profile | `Shoplive.setUser(ShopliveUser.Profile(...))` | 서버 작업 없이 회원 표시 |
 * | token | `Shoplive.setUser(ShopliveUser.Token(jwt))` | 서버가 서명한 JWT (권장) |
 *
 * ## 주의 — Guest 는 "해제"가 아니다
 * `ShopliveUser.Guest` 는 **no-op** 이다. 기존 인증 슬롯을 그대로 둔다(게스트 식별자는
 * 서버가 발급한다). 로그아웃하려면 [Shoplive.logout] 을 불러야 한다.
 *
 * ## Token 이 Profile 을 이긴다
 * Token 을 설정해 두면, Profile 로 생성된 토큰은 무시된다.
 */
object UserSetup {

    /** [label] 은 API 값이라 번역하지 않는다. 설명만 로케일에 따라 바뀐다. */
    enum class Method(val label: String, @StringRes val descriptionRes: Int) {
        GUEST("guest", R.string.auth_guest_desc),
        PROFILE("profile", R.string.auth_profile_desc),
        TOKEN("token", R.string.auth_token_desc),
    }

    /**
     * @param jwt [Method.TOKEN] 일 때 필수. 비어 있으면 guest 로 내려간다.
     * @return 실제로 적용된 방식.
     */
    fun apply(method: Method, jwt: String = ""): Method {
        val effective = if (method == Method.TOKEN && jwt.isBlank()) Method.GUEST else method

        when (effective) {
            Method.GUEST -> {
                // 이미 로그인 상태였다면 Guest 만으로는 풀리지 않는다 — 명시적으로 해제한다.
                Shoplive.logout()
                Shoplive.setUser(ShopliveUser.Guest)
                DemoLog.sdkCall("Shoplive.logout() → setUser(ShopliveUser.Guest)")
            }

            Method.PROFILE -> {
                Shoplive.setUser(demoProfile())
                DemoLog.sdkCall(
                    "Shoplive.setUser(ShopliveUser.Profile(id: \"${DemoLog.mask(demoProfile().id)}\"))"
                )
            }

            Method.TOKEN -> {
                Shoplive.setUser(ShopliveUser.Token(jwt))
                DemoLog.sdkCall("Shoplive.setUser(ShopliveUser.Token(\"${DemoLog.mask(jwt)}\"))")
            }
        }

        if (method == Method.TOKEN && effective == Method.GUEST) {
            DemoLog.error("token method selected but the JWT is empty — falling back to guest.")
        }
        return effective
    }

    /**
     * 데모용 프로필. 실제 앱에서는 로그인 세션의 값을 넣는다.
     *
     * `id` 는 **해싱해서 넣는 것을 권장**한다 — 원문 회원 ID 를 SDK·서버에 남기지 않기 위해서다.
     * [ShopliveGender.UNDEFINED] 는 "수집하지 않음"이라 서버로 전송되지 않고,
     * [ShopliveGender.NEUTRAL] 은 제3의 성별로 **전송된다**.
     */
    private fun demoProfile() = ShopliveUser.Profile(
        id = hashUserId("demo-user-0001"),
        name = DemoContainer.string(R.string.demo_user_name),
        age = 27,
        gender = ShopliveGender.UNDEFINED,
        rank = 1,
        custom = mapOf("grade" to "vip"),
    )

    /** SHA-256(원문 + 앱 고유 salt). salt 는 앱마다 다르게 둔다. */
    fun hashUserId(raw: String, salt: String = "SHOPLIVE_DEMO_SALT"): String =
        MessageDigest.getInstance("SHA-256")
            .digest((raw + salt).toByteArray())
            .joinToString("") { "%02x".format(it) }
}
