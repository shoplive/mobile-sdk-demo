# 1. Getting Started

[◀ Docs home](../README.md) · Next: [Demo App Tour ▶](02-demo-app-tour.md)

> **Official integration guide:** [ShopLive SDK v3 Integration Guide](https://sdk.shoplive.cloud/)
> Relevant sections for this page: [Overview & requirements](https://sdk.shoplive.cloud/#overview) · [Install](https://sdk.shoplive.cloud/#install) · [Quick start](https://sdk.shoplive.cloud/#quickstart)

This page gets both demo apps running on your machine, then shows you the smallest possible integration — the three lines that produce a playing live stream.

---

## 1.1 What you need before you start

You need three values. All of them come from the ShopLive Queenie console or from your ShopLive contact.

| Value | Required for | Where it goes |
|---|---|---|
| **accessKey** | Everything | `Shoplive.initialize(...)`, once per app launch |
| **campaignKey** | Playing a specific broadcast | Every `start` / `play` call |
| **streamToken** | Broadcasting only (Mission 8) | `Shoplive.setStreamToken(...)` |

Android additionally needs **Maven repository credentials** (username + password) to download the SDK artifacts. iOS does not — the demo ships the binaries in-tree.

> **Tip:** You can complete Missions 1–7 with just `accessKey` + `campaignKey`. Mission 8 stays locked until a `streamToken` is present, because there is no way to start a broadcast without one.

---

## 1.2 Requirements

| | iOS | Android |
|---|---|---|
| Toolchain | Xcode 26+ (verified on 26.6) | AGP 8.7.3 · Kotlin 2.0.21 · Java 17 |
| Minimum OS | iOS 15.0 (WebRTC OS PIP uses iOS 15+ APIs) | minSdk 24 · compileSdk 35 |
| SDK delivery | 5 local `.xcframework` bundles in `iOS/Frameworks/` | Private Maven — `cloud.shoplive:shoplive-player-sdk` / `-streamer-sdk` `3.0.0` |
| UI framework in the demo | UIKit | Jetpack Compose + Material 3 |

> ⚠️ **The two demos are pinned to different SDK snapshots.** The iOS demo is built against a `dev` branch build (`5f0ee781`, rebuilt 2026-07-30); the Android demo consumes the published `3.0.0` artifacts. A handful of fields exist on one platform and not the other as a result — all of them are listed in [Platform Differences](platform-differences.md).

---

## 1.3 Run the iOS demo

```bash
cd iOS
open ShopliveOnboardingDemo.xcworkspace
```

Build and run. The `.xcodeproj` is committed, so **you do not need Tuist** just to open and run the app. You only need Tuist if you change the project structure (add files, change build settings):

```bash
tuist generate --no-open
```

**Credentials** live in [`iOS/ShopliveOnboardingDemo/Support/DemoCredentials.swift`](../iOS/ShopliveOnboardingDemo/Support/DemoCredentials.swift):

```swift
enum DemoDefaults {
    static let accessKey   = "…"   // your Queenie access key
    static let campaignKey = "…"   // a campaign that is currently on air
    static let streamToken = ""    // Mission 8 only — intentionally empty, see below
}
```

If these are filled in, the app skips the start screen and goes straight to the mission list. If you leave them empty, the app asks the user to type them in on the start screen — which is exactly what you want when handing the build to someone else. Values typed by the user stay on the device (access/campaign keys in `UserDefaults`, the stream token in the Keychain) and are never sent anywhere.

> **`streamToken` ships empty on purpose.** A stream token grants **broadcast permission**, so it is not kept in source control. Missions 1–7 need no token and run with no typing; Mission 8 stays locked until you enter one on the start screen. The access and campaign keys are identifiers rather than secrets, which is why they can live in source.

**Code signing:** `Project.swift` pins `DEVELOPMENT_TEAM = D237UGRPX6`. Simulator builds work on any machine (signing is disabled for the simulator SDK), but for a device build you must swap in your own team ID and bundle ID.

### What the SDK ships as

`iOS/Frameworks/` contains five xcframeworks that the app target links and embeds directly:

| xcframework | What it is |
|---|---|
| `ShopliveCore` | Shared layer — auth, configuration, user, errors |
| `ShoplivePlayerSDK` | Watching — HLS/WebRTC engines, automatic failover, PIP, overlay |
| `ShopliveStreamerSDK` | Broadcasting — the entire studio UI |
| `ShopLiveWebRTCHelperSDK` | Internal dependency of Player/Streamer |
| `WebRTC` | `rtc-ios` 1.0.26 binary |

In your own app you will use Swift Package Manager instead of local binaries:

```
https://github.com/shoplive/shoplive-ios-sdk
```

Add `ShoplivePlayerSDK` and/or `ShopliveStreamerSDK` — `ShopliveCore` comes along automatically.

---

## 1.4 Run the Android demo

Copy the sample properties file and fill it in:

```bash
cd Android
cp local.properties.sample local.properties
```

```properties
sdk.dir=/Users/<you>/Library/Android/sdk

# Private Maven — required, issued by your ShopLive contact
shoplive.maven.username=
shoplive.maven.password=

# Demo keys for "Take a tour" mode — optional
shoplive.demo.accessKey=
shoplive.demo.campaignKey=
shoplive.demo.streamToken=
```

Then build:

```bash
./gradlew :app:assembleDebug
```

`local.properties` is git-ignored, so nothing you put there gets committed. For CI, the same values can come from environment variables — `SHOPLIVE_MAVEN_USERNAME`, `SHOPLIVE_MAVEN_PASSWORD`, `SHOPLIVE_DEMO_ACCESS_KEY`, `SHOPLIVE_DEMO_CAMPAIGN_KEY`, `SHOPLIVE_DEMO_STREAM_TOKEN`. Resolution order is `local.properties` → `gradle.properties` → environment.

If the demo keys are blank, the "Take a tour" button is disabled and the user enters keys on the start screen instead.

### Gradle wiring you will copy into your own project

**Repository** — in `settings.gradle.kts` (the modern location):

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        maven {
            url = uri("https://repo.us1.shoplive.cloud/repository/shoplive/")
            credentials {
                username = "<issued username>"
                password = "<issued password>"
            }
        }
        mavenCentral()
    }
}
```

The older Groovy `allprojects { repositories { … } }` form in the root `build.gradle` works exactly the same way if that's what your project uses.

> The default repository above is the **development** one. For customer-facing builds use
> `https://repo-mig.us1.shoplive.cloud/repository/shoplive/`.

**Dependencies** — in your app module:

```groovy
def shoplive_sdk_version = "3.0.0"
implementation "cloud.shoplive:shoplive-player-sdk:$shoplive_sdk_version"
implementation "cloud.shoplive:shoplive-streamer-sdk:$shoplive_sdk_version"
```

- Watching only → `shoplive-player-sdk`
- Broadcasting only → `shoplive-streamer-sdk`
- Both → declare both

You never declare `core`, `exoplayer`, `webrtc`, or `android-webrtc` — they are transitive, and overlaps between Player and Streamer are de-duplicated by the SDK.

This demo manages the same declaration through a version catalog, [`Android/gradle/libs.versions.toml`](../Android/gradle/libs.versions.toml).

**Manifest permissions.** `INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE`, and `CAMERA` are already declared in the AAR and merge in automatically. **`RECORD_AUDIO` is not** — any app that broadcasts must declare it itself:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<!-- Only if you use advertising-ID based attribution -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

Runtime permission prompts are handled for you by `ShopliveStreamer.start()`. (If you build the Intent yourself with `intent()`, they are not — see [Mission 8](mission-08-go-live.md).)

---

## 1.5 The smallest working integration

This is the whole thing. Everything else in these docs is refinement.

### iOS

```swift
// ① Once per app launch — AppDelegate / App init
import ShopliveCore

Shoplive.initialize(ShopliveConfiguration(accessKey: "{ACCESS_KEY}"))

// ② Optional — identify the viewer
Shoplive.setUser(.guest)

// ③ Play
import ShoplivePlayerSDK

let player = ShoplivePlayerViewController(campaignKey: "{CAMPAIGN_KEY}")
present(player, animated: true)
```

### Android

```kotlin
// ① Once per app launch — Application.onCreate()
Shoplive.initialize(context, ShopliveConfiguration(accessKey = "{ACCESS_KEY}"))

// ② Optional — identify the viewer
Shoplive.setUser(ShopliveUser.Guest)

// ③ Play
ShoplivePlayer(activity).start(campaignKey = "{CAMPAIGN_KEY}")
```

Three things are worth internalizing right now, because they cause the majority of "nothing happens" reports:

1. **Initialization is once per app, not once per playback.** Calling `present`/`start` before `initialize` fails with `notInitializedAccessKey` / `NOT_INITIALIZED_ACCESS_KEY` (code 9000). Put it in `AppDelegate` / `Application.onCreate()` so that even a cold start from a deep link is covered — see [Mission 2](mission-02-deep-link.md).
2. **On Android the context must be an Activity.** `ShoplivePlayer(context)` requires a `LifecycleOwner`. Pass `applicationContext` and the SDK silently refuses to start, leaving only a warning in logcat.
3. **The delegate is weakly held on both platforms.** If nothing in your app owns it strongly, events stop arriving and you get no error telling you why. See [Mission 6](mission-06-events-products-coupons.md).

---

## 1.6 Where to go next

| If you want to… | Read |
|---|---|
| See what the demo app actually does, screen by screen | [Demo App Tour](02-demo-app-tour.md) |
| Understand which files to copy and which to ignore | [Architecture & Copy Boundary](03-architecture.md) |
| Start integrating feature by feature | [Mission 1 — Open the player](mission-01-open-the-player.md) |
| Look up a specific type or field | [API Reference](api-reference.md) |
| Check something that isn't behaving as documented | [Known Issues & Troubleshooting](known-issues.md) |

---

[◀ Docs home](../README.md) · Next: [Demo App Tour ▶](02-demo-app-tour.md)
