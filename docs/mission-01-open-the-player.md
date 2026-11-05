# Mission 1 — Launch the Player Directly

[◀ Architecture](03-architecture.md) · [Docs home](../README.md) · Next: [Mission 2 — Nudge-Style Preview ▶](mission-02-nudge-preview.md)

> **Guide cross-reference:** [Mission 1 · Launch the Player Directly](https://sdk.shoplive.cloud/#m1) · [Quick start](https://sdk.shoplive.cloud/#quickstart) · [ShopliveConfiguration fields](https://sdk.shoplive.cloud/#f-config)
>
> **Source:** [`ShopliveIntegration/PlayerLauncher.swift`](../iOS/ShopliveIntegration/PlayerLauncher.swift) · [`integration/…/ShoplivePlayerLauncher.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerLauncher.kt)
>
> **In the app:** card ① — *"Launch the Player Directly"*. Tap it and a full-screen live stream opens.

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

Switching accounts? Call `initialize` again (the last `accessKey` wins). But if you also need to change *identity*, call `Shoplive.logout()` first to clear the auth slots — see [Mission 5](mission-05-user-identity.md).

**Where the demo does this:** [`ShopliveBootstrap.swift`](../iOS/ShopliveIntegration/ShopliveBootstrap.swift) called from [`DemoBootstrap.swift`](../iOS/ShopliveOnboardingDemo/App/DemoBootstrap.swift); [`ShopliveInitializer.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveInitializer.kt) called from [`DemoApplication.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/DemoApplication.kt).

> ⚠️ **Present or start before initializing and it fails** with `ShopliveErrorCode.notInitializedAccessKey` / `NOT_INITIALIZED_ACCESS_KEY` (9000). This is the single most common integration error, and it shows up most often on a cold start from a deep link — which is exactly why initialization belongs in `AppDelegate` / `Application.onCreate()`. See [Mission 4](mission-04-deep-link.md).

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

The demo keeps the handle in [`ShoplivePlayerSession`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerSession.kt) on Android and the delegate in a singleton (`DemoPlayerDelegate.shared`) on iOS. Both exist purely to guarantee lifetime.

### ③ Validate keys before you play — because the SDK can't

There is no "is this key valid?" API. `initialize` only stores the value. So the demo does two things:

1. **Local format check only** — non-empty, no whitespace. See `ShopliveInitializer.validate()`.
2. **Translate the resulting `error` event into a human sentence** per cause. See `causeGroup` in [`ShopliveEventLabels.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveEventLabels.kt) (code → cause), `DemoLabels.messageRes` in the app (cause → localized sentence), and the [error code table](api-reference.md#error-codes).

That two-step pattern is worth copying — a bad key, a missing campaign, an auth failure, and a network problem all look identical until the error event arrives.

---

## How the demo runs this mission

Tapping card ① calls the launcher, which is a thin, deliberately boring wrapper:

- **iOS** — [`PlayerLauncher.present(campaignKey:from:options:configuration:delegate:)`](../iOS/ShopliveIntegration/PlayerLauncher.swift) creates the VC, assigns the delegate, logs the call, and presents. The demo's cards present `DemoPlayerViewController` the same way — a subclass of the player that adds a **‹ List** escape button on top — see [Demo App Tour §2.5](02-demo-app-tour.md#25-the-ios-player-and-its-demo-controls).
- **Android** — [`ShoplivePlayerLauncher.start(...)`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerLauncher.kt) creates the player, assigns the delegate, registers it with `ShoplivePlayerSession`, starts, and returns the player. The demo passes a configuration and play options assembled from the Options tab (`DemoConfigurationFactory`) — every card uses that path; a customer app would pass one of the `ShoplivePlayerPresets` instead.

The "done" badge lights up when `playback(started)` arrives from **the player this card started** — not when `present`/`start` returns.

---

## What to try in the app

1. Tap card ① and open the **⌗ Log** tab. Read the sequence top to bottom:
   `→SDK initialize` → `→SDK present/start` → `EVENT playback(requested → audioLoaded → started → rendering)` → `EVENT connectionStateChanged(.connecting → .connected)`.
2. Note what *doesn't* appear. On the measured iOS build, `stateChanged` never fires during a healthy session — see [Known Issues](known-issues.md#statechanged-never-fires-ios).
3. Try a campaign key that isn't on air and watch how the failure surfaces. It's less obvious than you'd expect, and [Known Issues](known-issues.md) covers what each platform actually does.

---

## Next

[Mission 2 — Nudge-Style Preview ▶](mission-02-nudge-preview.md) starts the same player muted, in a small window over one of your screens — for a viewer who has not decided to watch yet.

Coming from a push notification instead? [Mission 4 — Launch via Deep Link](mission-04-deep-link.md) takes this same playback call and triggers it from a link, where cold-start ordering becomes the whole problem.

---

[◀ Architecture](03-architecture.md) · [Docs home](../README.md) · Next: [Mission 2 ▶](mission-02-nudge-preview.md)
