# Mission 2 — Open from a Deep Link

[◀ Mission 1](mission-01-open-the-player.md) · [Docs home](../README.md) · Next: [Mission 3 — Member info ▶](mission-03-user-identity.md)

> **Guide cross-reference:** [Mission 2 · Opening via deep link](https://sdk.shoplive.cloud/#m2) · [PlayOptions fields](https://sdk.shoplive.cloud/#f-playoptions)
>
> **Source:** [`ShopliveIntegration/DeepLinkRouter.swift`](../iOS/ShopliveIntegration/DeepLinkRouter.swift) + [`App/SceneDelegate.swift`](../iOS/ShopliveOnboardingDemo/App/SceneDelegate.swift) · [`sdk/DeepLinkRouter.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DeepLinkRouter.kt) + [`SchemeActivity.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/SchemeActivity.kt)
>
> **In the app:** card ② — *"Open from a deep link"*. It fires a mock push banner; tapping the banner plays straight from the link.

---

## What you're building

A push notification, SMS, or web link that opens straight into a live broadcast. This is how most real traffic reaches a live commerce stream, so it's worth getting right.

**Checkpoint:** tap the banner → playback starts, and the `ref` parameter arrives at the SDK as `referrer`.

The link shape used by the demo:

```
iOS      shopliveDemo://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
Android  shoplivedemo://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
```

---

## The one hard problem: cold start ordering

When someone taps a push notification, **your app may not be running**. `Shoplive.initialize` won't have executed yet. Call playback in that state and you get `NOT_INITIALIZED_ACCESS_KEY`.

The required order is always:

```
1. Shoplive.initialize(...)      ← accessKey (put this in AppDelegate / Application.onCreate)
2. Shoplive.setUser(...)         ← only if you need identity
3. play / start with the campaignKey and referrer from the link
```

So the design rule is: **parse in the entry point, play somewhere that knows initialization is done.** Both demos split those two responsibilities deliberately.

---

## iOS

### The two entry points — you need both

Wire only one and half your traffic silently fails.

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // … set up window …

        // App was NOT running and was launched by the link.
        if let url = connectionOptions.urlContexts.first?.url {
            DeepLinkRouter.shared.handle(url)
        }
    }

    // App WAS already running.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        DeepLinkRouter.shared.handle(url)
    }
}
```

Both funnel into the same `handle(_:)`.

### Parse, then play

```swift
@discardableResult
func handle(_ url: URL) -> Bool {

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let campaignKey = components.queryItems?.first(where: { $0.name == "campaign" })?.value,
          !campaignKey.isEmpty
    else {
        return false   // not our link — let another router try it
    }

    let referrer = components.queryItems?.first(where: { $0.name == "ref" })?.value

    // ShoplivePlayOptions applies to THIS ONE playback only —
    // as opposed to ShoplivePlayerConfiguration, which is policy.
    var options = ShoplivePlayOptions()
    options.referrer = referrer

    guard let presenter = Self.topViewController() else { return false }

    PlayerLauncher.present(
        campaignKey: campaignKey,
        from: presenter,
        options: options,
        configuration: configurationProvider(),
        delegate: delegateProvider()
    )
    return true
}
```

Returning `false` for links you don't recognize matters — it lets the caller hand the URL to another router instead of swallowing it.

### Finding a presenter

A deep link can arrive from any screen, so the router has to locate the top-most view controller itself:

```swift
static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

    guard var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                 ?? scene?.windows.first?.rootViewController else { return nil }

    while let presented = top.presentedViewController { top = presented }
    if let nav = top as? UINavigationController, let visible = nav.visibleViewController { top = visible }
    return top
}
```

### Injecting configuration and delegate

`DeepLinkRouter` presents playback itself, but *what* to present with is your app's decision. So it exposes two injection points with working defaults:

```swift
// In your app's startup code, once:
DeepLinkRouter.shared.configurationProvider = { MyPlayerConfig.fullScreen() }
DeepLinkRouter.shared.delegateProvider     = { MyPlayerDelegate.shared }
```

These are two of the three outward hooks described in [Architecture §3.2](03-architecture.md#the-integration-layer-has-exactly-three-outward-hooks). Leave them alone and you get `.init()` and `nil` — playback still works, you just receive no events.

---

## Android

### Manifest — the entry Activity

```xml
<activity
    android:name=".SchemeActivity"
    android:exported="true"
    android:noHistory="true"
    android:theme="@style/Theme.ShopliveOnboarding.Transparent">
    <intent-filter android:autoVerify="false">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:host="live" android:scheme="${deepLinkScheme}" />
    </intent-filter>
</activity>
```

`${deepLinkScheme}` comes from a `manifestPlaceholders` entry in `build.gradle.kts`, alongside a matching `BuildConfig.DEEP_LINK_SCHEME` — one source of truth for the scheme string in both the manifest and the code.

### The entry Activity parses but does not play

```kotlin
class SchemeActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val link = DeepLinkRouter.parse(intent?.data)

        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (link != null) {
                    putExtra(MainActivity.EXTRA_DEEP_LINK_CAMPAIGN, link.campaignKey)
                    putExtra(MainActivity.EXTRA_DEEP_LINK_REFERRER, link.referrer)
                }
            }
        )
        finish()
    }
}
```

**Two reasons this Activity doesn't start playback itself:**

1. **Cold-start safety.** Only the app's main screen knows whether `initialize` has completed, so the decision to play belongs there.
2. **Handle lifetime.** `SchemeActivity` is `noHistory=true` and disappears immediately. `ShoplivePlayer(context)` holds its constructor context weakly — hand it an Activity that's about to finish and later `play()` calls can be refused. Starting from a screen that stays alive is simply safer.

### Parsing

```kotlin
object DeepLinkRouter {
    val scheme: String get() = BuildConfig.DEEP_LINK_SCHEME
    private const val HOST = "live"

    data class Link(val campaignKey: String, val referrer: String?)

    fun parse(uri: Uri?): Link? {
        if (uri == null) return null
        if (!uri.scheme.equals(scheme, ignoreCase = true)) return null
        if (!uri.host.equals(HOST, ignoreCase = true)) return null

        val campaignKey = uri.getQueryParameter("campaign")?.trim().orEmpty()
        if (campaignKey.isEmpty()) return null

        return Link(campaignKey, uri.getQueryParameter("ref"))
    }
}
```

### MainActivity plays once it's ready

`MainActivity` is `launchMode="singleTask"`, so a second deep link arrives at `onNewIntent` rather than creating a new instance:

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    readDeepLink(intent)
}

private fun readDeepLink(intent: Intent?) {
    val campaignKey = intent?.getStringExtra(EXTRA_DEEP_LINK_CAMPAIGN) ?: return
    deepLinkCampaignKey = campaignKey
    deepLinkReferrer = intent.getStringExtra(EXTRA_DEEP_LINK_REFERRER)

    // Clear the extras so a config change (rotation) doesn't replay the same link.
    intent.removeExtra(EXTRA_DEEP_LINK_CAMPAIGN)
    intent.removeExtra(EXTRA_DEEP_LINK_REFERRER)
}
```

That last step is easy to forget and produces a real bug: rotate the device and the same link replays, restarting playback.

---

## `ref` → `referrer`: don't skip this

The tracking value goes into `ShoplivePlayOptions.referrer` (truncated at 1024 characters on Android):

```swift
var options = ShoplivePlayOptions()
options.referrer = referrer
```

```kotlin
ShoplivePlayOptions(referrer = link.referrer?.takeIf { it.isNotBlank() })
```

This is **the only link** between "which push did they come from" and "how long did they watch". If you leave it out, campaign attribution for live streams is gone — and there's no way to reconstruct it later. Note it belongs in `PlayOptions`, not configuration, precisely because it differs on every playback.

---

## How the demo runs this mission

The in-app **mock push banner is not a shortcut.** It fires a real `ACTION_VIEW` intent (Android) / opens the real URL scheme (iOS), so the link travels the exact path a production push would: `SchemeActivity` → `MainActivity` → playback.

```kotlin
fun sendFakePush(context: Context, campaignKey: String, referrer: String = "push_demo") {
    val uri = Uri.parse("$scheme://$HOST?campaign=$campaignKey&ref=$referrer")
    context.startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    })
}
```

The demo opens the **Log tab** automatically for this mission, so you can watch `deep link received` → `parsed → campaignKey/referrer` → `→SDK start` in order.

---

## Test it from the command line

Android — this also exercises the true cold start if you force-stop the app first:

```bash
adb shell am start -a android.intent.action.VIEW -d "shoplivedemo://live?campaign=<CAMPAIGN_KEY>&ref=push_test"
```

iOS simulator:

```bash
xcrun simctl openurl booted "shopliveDemo://live?campaign=<CAMPAIGN_KEY>&ref=push_test"
```

Try each one twice — once with the app killed, once with it running. Those are the two code paths, and they're the two that break independently.

---

## Next

[Mission 3 — Connect member info ▶](mission-03-user-identity.md) fills in step 2 of the ordering above: who the viewer is.

---

[◀ Mission 1](mission-01-open-the-player.md) · [Docs home](../README.md) · Next: [Mission 3 ▶](mission-03-user-identity.md)
