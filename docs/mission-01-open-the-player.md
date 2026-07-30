# Mission 1 — Open the Player

[◀ Architecture](03-architecture.md) · [Docs home](../README.md) · Next: [Mission 2 — Deep links ▶](mission-02-deep-link.md)

> **Guide cross-reference:** [Mission 1 · Presenting the player directly](https://sdk.shoplive.cloud/#m1) · [Quick start](https://sdk.shoplive.cloud/#quickstart) · [ShopliveConfiguration fields](https://sdk.shoplive.cloud/#f-config)
>
> **Source:** [`ShopliveIntegration/PlayerLauncher.swift`](../iOS/ShopliveIntegration/PlayerLauncher.swift) · [`sdk/PlayerLauncher.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerLauncher.kt)
>
> **In the app:** card ① — *"Open the player"*. Tap it and a full-screen live stream opens.

---

## What you're building

One button that opens a full-screen live broadcast. This is the shortest path from nothing to playing video, and it's the foundation every other mission builds on.

**Checkpoint:** playback within 2–3 seconds; chat and the LIVE badge appear when the campaign is on air.

---

## Step 1 — Initialize, once per app

Initialization is an app-lifetime concern, not a per-playback one. It just registers your access key; nothing goes over the network yet.

### iOS

```swift
import ShopliveCore

// AppDelegate.application(_:didFinishLaunchingWithOptions:)
Shoplive.initialize(
    ShopliveConfiguration(
        accessKey: "{ACCESS_KEY}",
        allowedWebViewDomains: ["shop.example.com"],   // optional
        attribution: ShopliveAttribution(              // optional
            utmSource: "onboarding_demo",
            utmMedium: "ios_app"
        )
    )
)
```

`ShopliveConfiguration` is an **input-only value type** — every field is `let`. You can't read it back or mutate it later. To change something, build a new one and call `initialize` again.

### Android

```kotlin
// Application.onCreate()
Shoplive.initialize(
    context,
    ShopliveConfiguration(
        accessKey = "{ACCESS_KEY}",
        allowedWebViewDomains = listOf("shop.example.com"),  // optional
        attribution = ShopliveAttribution(                   // optional
            utmSource = "onboarding_demo",
            utmMedium = "android_app"
        )
    )
)
```

Only `accessKey` is required. Two notes on the optional fields:

- **`allowedWebViewDomains`** whitelists the domains the overlay web view may navigate to. Leaving it empty (`[]`, the default) **disables validation entirely**. The demo leaves it empty for convenience, but in production you should list your product-landing and event-page domains.
- **`attribution`** is a **full replace** on Android — you can't patch individual UTM fields. Omit it and the previous value is retained.

Switching accounts? Call `initialize` again (the last `accessKey` wins). But if you also need to change *identity*, call `Shoplive.logout()` first to clear the auth slots — see [Mission 3](mission-03-user-identity.md).

**Where the demo does this:** [`ShopliveBootstrap.swift`](../iOS/ShopliveIntegration/ShopliveBootstrap.swift) called from [`DemoBootstrap.swift`](../iOS/ShopliveOnboardingDemo/App/DemoBootstrap.swift); [`ShopliveInitializer.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/ShopliveInitializer.kt) called from [`DemoApplication.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/DemoApplication.kt).

> ⚠️ **Present or start before initializing and it fails** with `ShopliveErrorCode.notInitializedAccessKey` / `NOT_INITIALIZED_ACCESS_KEY` (9000). This is the single most common integration error, and it shows up most often on a cold start from a deep link — which is exactly why initialization belongs in `AppDelegate` / `Application.onCreate()`. See [Mission 2](mission-02-deep-link.md).

---

## Step 2 — Present the player

### iOS

```swift
import ShoplivePlayerSDK

let player = ShoplivePlayerViewController(
    campaignKey: "{CAMPAIGN_KEY}",
    options: ShoplivePlayOptions(),              // per-playback values
    configuration: ShoplivePlayerConfiguration() // policy — all fields defaulted
)

player.delegate = DemoPlayerDelegate.shared   // weak! see the warning below

present(player, animated: true)
```

Two behaviors to know:

- **`campaignKey` is required.** v3 deliberately does not expose a "create an empty VC now, play later" path, because a VC with nothing to play does nothing visible when presented and the cause is hard to trace.
- **You never call `play()` yourself.** The VC prepares playback on creation and starts automatically at `viewDidAppear`.

### Android

```kotlin
val player = ShoplivePlayer(activity)          // must be an Activity — see below
player.delegate = demoPlayerDelegate           // instance-owned! see below

player.start(
    campaignKey = "{CAMPAIGN_KEY}",
    options = ShoplivePlayOptions(),
    configuration = ShoplivePlayerConfiguration(),
)
```

Both `options` and `configuration` can be omitted — every field has a default and plain `start(campaignKey = …)` plays correctly.

**Want to control the transition yourself?** Use `intent()` instead of `start()` and call `startActivity` with the result. Do that when your app needs to own the transition animation or the Task/back-stack policy.

---

## The three things that silently break this

### ① Android: the context must be an Activity

`ShoplivePlayer(context)` requires a **`LifecycleOwner`**. Pass `applicationContext` and the SDK **refuses to start and only logs a warning** — from the user's perspective the button does nothing. This is the #1 false "the SDK is broken" report.

### ② You must hold onto the player instance and the delegate

The delegate is **weakly referenced on iOS** and **instance-owned on Android**. Either way, if you create the player in a local variable and let it go out of scope, events stop arriving — with no error to tell you why.

```kotlin
// ✗ Events will stop. The delegate is owned by the instance you just dropped.
fun play() {
    ShoplivePlayer(activity).apply { delegate = MyDelegate() }.start(campaignKey = key)
}
```

The demo keeps the handle in [`PlayerSession`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt) on Android and the delegate in a singleton (`DemoPlayerDelegate.shared`) on iOS. Both exist purely to guarantee lifetime.

### ③ Validate keys before you play — because the SDK can't

There is no "is this key valid?" API. `initialize` only stores the value. So the demo does two things:

1. **Local format check only** — non-empty, no whitespace. See `ShopliveInitializer.validate()`.
2. **Translate the resulting `error` event into a human sentence** per cause. See `describe(error)` in [`DemoPlayerDelegate.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt) and the [error code table](api-reference.md#error-codes).

That two-step pattern is worth copying — a bad key, a missing campaign, an auth failure, and a network problem all look identical until the error event arrives.

---

## How the demo runs this mission

Tapping card ① calls `PlayerLauncher`, which is a thin, deliberately boring wrapper:

- **iOS** — [`PlayerLauncher.present(campaignKey:from:options:configuration:delegate:)`](../iOS/ShopliveIntegration/PlayerLauncher.swift) creates the VC, assigns the delegate, logs the call, and presents. The demo then wraps it in `PlayerHostViewController` so it can put a **‹ List** escape button on top — see [Demo App Tour §2.5](02-demo-app-tour.md#25-the-ios-player-host).
- **Android** — [`PlayerLauncher.start(...)`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerLauncher.kt) creates the player, assigns the delegate, registers it with `PlayerSession`, and starts. `startWithOptions(...)` is the same thing but sourced from the Options tab, which is the path Missions 5 and 7 use.

The "done" badge lights up when `playback(started)` arrives — not when `present`/`start` returns.

---

## What to try in the app

1. Tap card ① and open the **⌗ Log** tab. Read the sequence top to bottom:
   `→SDK initialize` → `→SDK present/start` → `EVENT playback(requested → audioLoaded → started → rendering)` → `EVENT connectionStateChanged(.connecting → .connected)`.
2. Note what *doesn't* appear. On the measured iOS build, `stateChanged` never fires during a healthy session — see [Known Issues](known-issues.md#statechanged-never-fires-ios).
3. Try a campaign key that isn't on air and watch how the failure surfaces. It's less obvious than you'd expect, and [Known Issues](known-issues.md) covers what each platform actually does.

---

## Next

[Mission 2 — Open from a deep link ▶](mission-02-deep-link.md) takes the same playback call and triggers it from a push notification, where cold-start ordering becomes the whole problem.

---

[◀ Architecture](03-architecture.md) · [Docs home](../README.md) · Next: [Mission 2 ▶](mission-02-deep-link.md)
