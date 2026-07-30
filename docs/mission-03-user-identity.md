# Mission 3 — Connect Member Info

[◀ Mission 2](mission-02-deep-link.md) · [Docs home](../README.md) · Next: [Mission 4 — Embed in your screen ▶](mission-04-embed-in-your-screen.md)

> **Guide cross-reference:** [Mission 3 · Connecting user info](https://sdk.shoplive.cloud/#m3) · [Queenie console setup](https://sdk.shoplive.cloud/#m3-queenie) · [ID hashing](https://sdk.shoplive.cloud/#m3-hash) · [ShopliveUser fields](https://sdk.shoplive.cloud/#f-user)
>
> **Source:** [`ShopliveIntegration/UserSetup.swift`](../iOS/ShopliveIntegration/UserSetup.swift) · [`sdk/UserSetup.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/UserSetup.kt)
>
> **In the app:** card ③ — *"Connect member info"*. Pick guest / profile / token, then play.

---

## What you're building

Making the viewer identifiable so chat shows their nickname, coupons can be tied to an account, and viewing history attaches to a member.

**Checkpoint:** the chat nickname shows the member name instead of a generated guest name.

---

## Three approaches — and you can mix them in one app

| Approach | Call | Use it when |
|---|---|---|
| **Token** ⭐ recommended | `setUser(.token(jwt:))` / `ShopliveUser.Token(jwt)` | Your server can sign a JWT. Safest. |
| **Profile** | `setUser(.profile(...))` / `ShopliveUser.Profile(...)` | Getting started with no server work |
| **Guest** | `setUser(.guest)` / `ShopliveUser.Guest` | Watching without a login |

All of them take effect **from the next playback onward**, so call them *before* `present`/`start`, not during.

**Token beats Profile.** If a token is set, any token derived from a profile is ignored. Don't try to layer both.

---

## ① Token — the recommended path

Your server signs a JWT and your app passes it through. Nothing sensitive is assembled on the client.

### iOS

```swift
static func applyToken(_ jwt: String) {
    Shoplive.setUser(.token(jwt: jwt))
}
```

### Android

```kotlin
Shoplive.setUser(ShopliveUser.Token(jwt))
```

Setting up the signing secret is a console task — see [Queenie console setup](https://sdk.shoplive.cloud/#m3-queenie) in the guide.

The demo falls back gracefully when the token field is empty, which is worth mirroring so you never send an empty token to the server:

```kotlin
val effective = if (method == Method.TOKEN && jwt.isBlank()) Method.GUEST else method
```

---

## ② Profile — client-supplied values

### iOS

```swift
static func applyProfile(rawUserId: String,
                         name: String? = nil,
                         age: Int? = nil,
                         gender: ShopliveGender = .undefined,
                         rank: Int? = nil) {

    let hashedId = hashUserId(rawUserId)   // never send the raw ID — see step ③

    Shoplive.setUser(.profile(
        id: hashedId,
        name: name,
        age: age,
        gender: gender,
        rank: rank
    ))
}
```

### Android

```kotlin
ShopliveUser.Profile(
    id = hashUserId("demo-user-0001"),
    name = "Demo User",
    age = 27,
    gender = ShopliveGender.UNDEFINED,
    rank = 1,
    custom = mapOf("grade" to "vip"),   // ← Android only, see below
)
```

### Field notes

**`gender` is not optional.** Two values look similar and mean opposite things:

| Value | Meaning | Sent to the server? |
|---|---|---|
| `.undefined` / `UNDEFINED` | "we didn't collect this" | **No** — the key is omitted from the payload entirely |
| `.neutral` / `NEUTRAL` | "explicitly a third gender" | **Yes** |

If you don't collect gender, use `.undefined`. Using `.neutral` as a stand-in sends incorrect data.

**`rank`** is the member tier score (this was `userScore` in v2). It feeds personalization queries.

> ⚠️ **Platform difference:** Android's `Profile` accepts a `custom: Map<String, String>` for arbitrary key-values. **iOS does not have a `custom` parameter** on the build this demo targets — only `rank: Int?`. The integration guide's example showing `.profile(..., custom: ["grade": "vip"])` does not compile on iOS. See [Platform Differences](platform-differences.md).

---

## ③ Hash the member ID

Don't put your raw member ID into the SDK. It travels to the overlay web view and to server logs, and once it's in a log you don't control it anymore.

### iOS

```swift
import CryptoKit

static func hashUserId(_ raw: String, salt: String = "SHOPLIVE_DEMO_SALT") -> String {
    let digest = SHA256.hash(data: Data((raw + salt).utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}
```

### Android

```kotlin
fun hashUserId(raw: String, salt: String = "SHOPLIVE_DEMO_SALT"): String =
    MessageDigest.getInstance("SHA-256")
        .digest((raw + salt).toByteArray())
        .joinToString("") { "%02x".format(it) }
```

> ⚠️ **A hardcoded salt can be extracted from your app binary.** For a demo that's fine; for production, fetch the salt from remote config — or better, use the **token** approach, where the server does the work and the client never handles member identity at all.

Guide reference: [ID hashing](https://sdk.shoplive.cloud/#m3-hash).

---

## ④ Guest — and the trap inside it

Here is the single most surprising thing in this mission:

> **`setUser(.guest)` does not log anyone out. It is a no-op.**

The guest identifier is issued by the server (via the `x-sl-guest-uid` header), so there is nothing for the client to set. It also **doesn't touch the existing auth slots** — call it while logged in and the user stays logged in.

To actually clear a session, use `logout()`:

### iOS

```swift
Shoplive.logout()   // clears authToken + user + streamToken, all three
```

### Android

```kotlin
Shoplive.logout()
Shoplive.setUser(ShopliveUser.Guest)   // then explicitly become a guest
```

That two-line Android sequence is exactly what [`UserSetup.apply(Method.GUEST)`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/UserSetup.kt) does, and the ordering is the point: logout first, then declare guest.

`logout()` clears **three slots at once** — `authToken`, `user`, and `streamToken`. If you're broadcasting, note that logging out a viewer also revokes broadcast permission; you'll need to call `setStreamToken` again ([Mission 8](mission-08-go-live.md)).

> ⚠️ **Migrating from v2?** `setUser` is **non-optional** in v3. `Shoplive.setUser(nil)` and `clearAuth` are gone; `logout()` replaces both. The integration guide still shows `setUser(nil)` in one place — that won't compile.

---

## Quick decision guide

```
Can your server sign a JWT?
├── Yes → Token.  Done. Stop reading.
└── No
    ├── Do you need the member's name in chat?
    │   └── Yes → Profile, with a hashed id
    └── No → Guest (and remember: it does not clear an existing login)
```

If you start with Profile and later add a signing endpoint, switching to Token is a one-line change at the call site — nothing else in your integration is affected.

---

## How the demo runs this mission

Tapping card ③ opens an action sheet with the three methods, applies the chosen one, and then plays. The result appears in the chat nickname on the SDK's overlay.

Android models the choice as an enum whose `label` is deliberately **not** translated — it's an API value, so `"guest"` / `"profile"` / `"token"` stay verbatim while only the human-readable description is localized:

```kotlin
enum class Method(val label: String, @StringRes val descriptionRes: Int) {
    GUEST("guest",     R.string.auth_guest_desc),
    PROFILE("profile", R.string.auth_profile_desc),
    TOKEN("token",     R.string.auth_token_desc),
}
```

Every applied method is logged as a `→SDK` line with the ID and token **masked to the first 8 characters** — the demo never prints a credential in full, because logs get pasted into tickets. See `shopliveMasked` in [`ShopliveLog.swift`](../iOS/ShopliveIntegration/ShopliveLog.swift) and `DemoLog.mask` on Android.

---

## Related

- The overlay can ask you to change the nickname via the `userNameUpdateRequested` event — [Mission 6](mission-06-events-products-coupons.md).
- Auth failures show up as a family of error codes (`AUTHENTICATION_FAILED`, `GUEST_LOGIN_NOT_ALLOWED`, `INVALID_SIGNATURE`, `DUPLICATE_SESSION`, `EXPIRED_SESSION`, …) — see the [error code table](api-reference.md#error-codes).

---

[◀ Mission 2](mission-02-deep-link.md) · [Docs home](../README.md) · Next: [Mission 4 ▶](mission-04-embed-in-your-screen.md)
