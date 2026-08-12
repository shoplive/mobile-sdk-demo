# ShopLive SDK v3 — Mobile Onboarding Demo

Two demo apps — **iOS (UIKit)** and **Android (Jetpack Compose)** — that walk you through integrating the ShopLive SDK v3, one feature at a time. Each app shows 8 missions; tapping a card runs the real SDK feature and tells you which file produced it. These docs are the written companion to that walkthrough.

> **📘 Official integration guide: <https://sdk.shoplive.cloud/>**
>
> That entry point detects your browser language and redirects to the Korean, English, or Japanese guide automatically. Force one with `?lang=ko`, `?lang=en`, or `?lang=ja`. Every doc here links back to the matching guide section so you can cross-check code against the spec.
>
> *Note: the landing page's redirect currently drops URL fragments, so a link like `https://sdk.shoplive.cloud/#m6` lands at the top of the right-language guide rather than at Mission 6. See [A note on guide anchor links](#a-note-on-guide-anchor-links) below.*

---

## Start here

| | |
|---|---|
| 🚀 **[1. Getting Started](docs/01-getting-started.md)** | Install, credentials, run both apps, and the 3-line integration |
| 🧭 **[2. Demo App Tour](docs/02-demo-app-tour.md)** | The five screens, the developer sheet, how missions auto-verify |
| 🏗 **[3. Architecture & Copy Boundary](docs/03-architecture.md)** | Which files to copy, which to ignore, and the three mental models |

Then work through the missions in order. Each one is self-contained: what you're building, iOS and Android snippets, how the demo runs it, and the traps.

---

## The 8 missions

| # | Mission | What it covers | Source |
|---|---|---|---|
| **1** | [Open the player](docs/mission-01-open-the-player.md) | `initialize` + full-screen playback | `PlayerLauncher` |
| **2** | [Open from a deep link](docs/mission-02-deep-link.md) | Push/SMS/web → playback, and cold-start ordering | `DeepLinkRouter` |
| **3** | [Connect member info](docs/mission-03-user-identity.md) | Token / profile / guest, ID hashing, logout | `UserSetup` |
| **4** | [Embed in your screen](docs/mission-04-embed-in-your-screen.md) | `ShoplivePlayerView` inside your own layout | `EmbeddedPlayerView` · `FeedScreen` |
| **5** | [Keep watching in PIP](docs/mission-05-pip.md) | in-app PIP vs. OS PIP, host hand-off | `PipOptions` |
| **6** | [Events · products · coupons](docs/mission-06-events-products-coupons.md) | ⭐ The delegate — events vs. requests | `DemoPlayerDelegate` |
| **7** | [Customize the UI](docs/mission-07-ui-customization.md) | Colors, fonts, or replacing the overlay entirely | `PlayerConfigurationFactory` |
| **8** | [Go live](docs/mission-08-go-live.md) | Broadcasting from the SDK's studio | `StudioLauncher` |

**If you only read one, read Mission 6.** Everything else is configuration; the delegate is where your app actually participates.

---

## Reference

| | |
|---|---|
| 📖 **[API Reference](docs/api-reference.md)** | Every public type and field, iOS and Android side by side |
| 🔀 **[Platform Differences](docs/platform-differences.md)** | What exists on one platform and not the other, plus a cross-platform checklist |
| ⚠️ **[Known Issues & Troubleshooting](docs/known-issues.md)** | Measured behavior, guide-vs-reality gaps, symptom → cause table |

---

## The 60-second version

The whole integration is three calls.

**iOS**

```swift
// ① once per app launch
Shoplive.initialize(ShopliveConfiguration(accessKey: "{ACCESS_KEY}"))

// ② optional — identify the viewer
Shoplive.setUser(.guest)

// ③ play
present(ShoplivePlayerViewController(campaignKey: "{CAMPAIGN_KEY}"), animated: true)
```

**Android**

```kotlin
// ① once per app launch
Shoplive.initialize(context, ShopliveConfiguration(accessKey = "{ACCESS_KEY}"))

// ② optional — identify the viewer
Shoplive.setUser(ShopliveUser.Guest)

// ③ play
ShoplivePlayer(activity).start(campaignKey = "{CAMPAIGN_KEY}")
```

Everything after that is refinement. Guide: [Quick start](https://sdk.shoplive.cloud/#quickstart).

---

## Five things that save the most debugging time

Each of these has burned someone already. Details are in the linked docs.

1. **Initialize once per app, not per playback.** Playing before `initialize` fails with code 9000, and it bites hardest on a deep-link cold start. → [Mission 1](docs/mission-01-open-the-player.md), [Mission 2](docs/mission-02-deep-link.md)
2. **Android: the context must be an Activity.** `applicationContext` makes the SDK refuse to start with only a logcat warning — the button just looks dead. → [Mission 1](docs/mission-01-open-the-player.md)
3. **Something must own the delegate.** It's weakly held on iOS and instance-owned on Android; drop it and events stop silently. → [Mission 6](docs/mission-06-events-products-coupons.md)
4. **Configuration is immutable once playback starts.** Mid-session assignments are ignored. Runtime changes go through runtime properties (`isMuted`, `resizeMode`, `overlayUI`). → [Mission 7](docs/mission-07-ui-customization.md)
5. **Don't treat "no error event" as "everything is fine."** On iOS `stateChanged` never fires during healthy playback; on Android a missing stream produces 404 loops with no `error` at all. Judge playback from `playback(started/rendering)` and count failures yourself. → [Known Issues](docs/known-issues.md)

---

## Repository layout

```
mobile-sdk-demo/
├── README.md                    ← you are here
├── docs/                        ← this documentation set
├── iOS/
│   ├── ShopliveIntegration/     ★ COPY THIS — SDK calls only, zero harness deps
│   ├── ShopliveOnboardingDemo/    demo harness (Screens · Support · App)
│   ├── ShopliveOnboardingDemo.xcodeproj  SDK dependency (SPM), pinned to 3.0.0
│   └── scripts/                   boundary scanner
└── Android/
    └── app/src/main/java/cloud/shoplive/onboarding/
        ├── sdk/                 ★ COPY THIS — SDK calls, with KDoc on the "why"
        ├── ui/                    Compose screens, developer sheet, theme
        └── data/                  credentials, options, log, progress, locale
```

The `Integration` / `sdk` split is not just a convention — on iOS it's **enforced by the compiler**. A dedicated `IntegrationCopyPasteProof` target builds `ShopliveIntegration/**` and nothing else, so a single dependency on the demo harness breaks the build. → [Architecture](docs/03-architecture.md)

---

## Reading paths by role

**Integrating for the first time (~1 hour)**
[Getting Started](docs/01-getting-started.md) → [Demo App Tour](docs/02-demo-app-tour.md) → [Mission 1](docs/mission-01-open-the-player.md) → [Mission 6](docs/mission-06-events-products-coupons.md) → then whichever missions your product needs.

**Evaluating whether the SDK fits (~20 minutes)**
[Demo App Tour](docs/02-demo-app-tour.md) → [Platform Differences](docs/platform-differences.md) → [Known Issues](docs/known-issues.md).

**Migrating from v2**
[API Reference § v3 renames](docs/api-reference.md#v3-renames-ios-breaking) → [Known Issues § guide vs. API](docs/known-issues.md#where-the-guide-and-the-api-disagree) → [v2 → v3 migration guide](https://sdk.shoplive.cloud/#migration).

**Debugging something right now**
[Known Issues § Troubleshooting by symptom](docs/known-issues.md#troubleshooting-by-symptom).

---

## The two SDKs — what they are, where they live, how you pull them in

Both platforms ship **prebuilt binaries only, from public GitHub repositories**. There is no source to build, no
credential to request, and no artifact to commit into your project.

| | iOS | Android |
|---|---|---|
| **What it is** | 5 xcframeworks (`ios-arm64` + simulator slices), built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` | 8 AARs with POM metadata |
| **Distribution repo** | [shoplive/shoplive-sdk-ios](https://github.com/shoplive/shoplive-sdk-ios) — a `Package.swift` of binary targets, no source | [shoplive/shoplive-sdk-android](https://github.com/shoplive/shoplive-sdk-android) — AAR/POM only, no source |
| **Where the bytes are** | XCFramework zips attached to [release `3.0.0`](https://github.com/shoplive/shoplive-sdk-ios/releases/tag/3.0.0), checksum-pinned in `Package.swift` | The [`maven-repo`](https://github.com/shoplive/shoplive-sdk-android/tree/maven-repo) branch, served as a static Maven repository over `raw.githubusercontent.com`. Same artifacts also attached to [release `v3.0.0`](https://github.com/shoplive/shoplive-sdk-android/releases/tag/v3.0.0) |
| **How you integrate** | Swift Package Manager | Gradle |
| **You declare** | 2 products | 2 coordinates |
| **Auth** | none — public | none — public |
| **Minimum OS** | iOS 15.0 | API 23 |

### iOS — Swift Package Manager

Xcode → **File ▸ Add Package Dependencies…**, paste the repository URL, and pick **Exact 3.0.0**:

```
https://github.com/shoplive/shoplive-sdk-ios
```

Then add **`ShoplivePlayerSDK`** (watching) and/or **`ShopliveStreamerSDK`** (broadcasting) to your target.
Xcode downloads the xcframeworks into DerivedData and embeds them automatically — no Embed step, nothing in your repo.

For a package-based project:

```swift
dependencies: [
    .package(url: "https://github.com/shoplive/shoplive-sdk-ios", exact: "3.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "ShoplivePlayerSDK", package: "ShopliveSDK"),
        .product(name: "ShopliveStreamerSDK", package: "ShopliveSDK"),
    ])
]
```

`import ShoplivePlayerSDK` is enough — `ShopliveCore` is re-exported, so you never import it directly.

| xcframework | Download (zip) | You declare it |
|---|---|---|
| `ShoplivePlayerSDK` | 10.9 MB | ✅ watching |
| `ShopliveStreamerSDK` | 18.1 MB | ✅ broadcasting |
| `ShopliveCore` | 7.4 MB | no — part of both products |
| `ShopLiveWebRTCHelperSDK` | 2.0 MB | no — part of both products |
| `WebRTC` (`rtc-ios` 1.0.26) | 15.4 MB | no — part of both products |

### Android — Gradle

`settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        maven {
            url = uri("https://raw.githubusercontent.com/shoplive/shoplive-sdk-android/maven-repo")
            content { includeGroup("cloud.shoplive") }   // optional, keeps other lookups off GitHub
        }
        mavenCentral()   // required: the SDK's POMs depend on kotlin-stdlib, appcompat, material, gson…
    }
}
```

Your app module:

```kotlin
implementation("cloud.shoplive:shoplive-player-sdk:3.0.0")     // watching
implementation("cloud.shoplive:shoplive-streamer-sdk:3.0.0")   // broadcasting
```

Those two lines resolve eight artifacts. Note the `shoplive-` prefix — the coordinates without it do not exist.

| Artifact | Download (AAR) | You declare it |
|---|---|---|
| `shoplive-player-sdk:3.0.0` | 185 KB | ✅ watching |
| `shoplive-streamer-sdk:3.0.0` | 67 KB | ✅ broadcasting |
| `shoplive-core:3.0.0` | 1.1 MB | no — transitive from both |
| `shoplive-core-player:3.0.0` | 617 KB | no — transitive |
| `shoplive-exoplayer:2.19.1.11` | 73 KB | no — transitive (own version line) |
| `shoplive-webrtc:3.0.0` | 1.3 MB | no — transitive |
| `shoplive-android-webrtc:3.0.0` | 21.5 MB | no — transitive, and what forces API 23 |
| `shoplive-rtmp:3.0.0` | 6.6 MB | no — transitive (RTMP ingest, new in 3.0.0) |

**These are download sizes, not what your app grows by.** Both platforms strip and split at packaging time — for the
numbers that matter to your users, see the next section. This demo's own wiring:
[`Android/settings.gradle.kts`](Android/settings.gradle.kts) · [Android details](Android/README.md#gradle-dependencies-the-part-integrators-copy) ·
[iOS details](iOS/README.md#3-frameworks)

---

## Cost of integration — app size, minimum OS, build, dependencies

The four questions every team asks before committing to an SDK.

### How much does the app grow?

Size **added to your app** by the SDK. Pick the row that matches what you actually ship: if you only need watching, you don't pay for the studio.

**iOS**

| What you integrate | Added |
|---|---|
| Player + Streamer (both) | **17.0 MB** |
| Player only (watching) | **13.1 MB** |
| Streamer only (broadcasting) | **15.0 MB** |

**Android — AAB** (the format Play Store requires, and what your users actually download)

| What you integrate | Added |
|---|---|
| Player + Streamer (both) | **19.9 MB** |
| Player only | **13.5 MB** |
| Streamer only | **18.7 MB** |

**Android — universal APK** (direct distribution, sideloading, some enterprise channels)

| What you integrate | Added |
|---|---|
| Player + Streamer (both) | **53.8 MB** |
| Player only | **47.4 MB** |
| Streamer only | **52.6 MB** |

Two things worth reading off these numbers:

- **Both together costs far less than the sum.** iOS: 13.1 + 15.0 = 28.1 MB separately, but 17.0 MB together. Player and Streamer share `ShopliveCore` and the WebRTC binary, so the second one is close to free. Same effect on Android (13.5 + 18.7 → 19.9 MB).
- **Ship an AAB, not a universal APK.** The ~34 MB gap is almost entirely native WebRTC libraries: a universal APK carries every ABI (`arm64-v8a`, `armeabi-v7a`, …), while an AAB delivers only the one each device needs. If a 50 MB APK is a problem for you, that's a packaging choice, not an SDK cost.

### What is the minimum OS version?

| | SDK requires | Why |
|---|---|---|
| **iOS** | **15.0** | WebRTC OS PIP uses iOS 15+ APIs |
| **Android** | **API 23** (6.0 Marshmallow) | The transitive `shoplive-android-webrtc` declares `minSdk 23` |

> **Android: the documented per-artifact floors are lower than the real one.** Player says 19 and Streamer says 21, but a build with `minSdk 21` **fails at manifest merge**:
>
> ```
> minSdkVersion 21 cannot be smaller than version 23 declared in library [org.webrtc]
> ```
>
> So treat **23** as the floor regardless of which artifact you use. Measured 2026-07-30.

The demo app itself sets `minSdk 24` (its `:integration` module is 23) — that is the demo's own choice, not an SDK requirement.

### Build time

**Not measured** — no controlled before/after benchmark has been run, so no number is claimed here.

What can be said structurally is that both platforms ship **prebuilt binaries**, so the SDK is linked rather than compiled by your build:

- iOS distributes `.xcframework` bundles built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so they carry `.swiftinterface` and are not recompiled by your project.
- Android distributes AARs.

The expected cost is therefore in link and packaging time, not compilation. If build time matters to your decision, benchmark it on your own project — and tell us, because we'd like the number too.

### Are there dependency conflicts?

**Android — two real ones, both documented and both with known fixes:**

| Symptom | Cause | Fix |
|---|---|---|
| `minSdkVersion 21 cannot be smaller than version 23 declared in library [org.webrtc]` | Transitive `shoplive-android-webrtc` requires API 23 | Raise your `minSdk` to 23 |
| Coordinates don't resolve at all | The coordinates were written without the `shoplive-` prefix (`cloud.shoplive:player-sdk`), which is what the integration guide currently prints. Those artifacts do not exist in the distribution repository | Use `cloud.shoplive:shoplive-player-sdk` / `shoplive-streamer-sdk` |

You do **not** declare `core`, `core-player`, `exoplayer`, `webrtc`, `android-webrtc` or `rtmp` — all six are POM transitives, and overlaps between Player and Streamer are de-duplicated by version.

> A third one only bites SDK developers: the SDK's library modules declare a `distribution` flavor dimension
> (`develop`/`qa`/`qaUs`/`ebay`), so building against **local SDK sources** in a composite build needs
> `missingDimensionStrategy("distribution", "develop")` in the consuming module. Consuming the published AAR does not.
>
> `shoplive-core` used to be listed here as a required extra declaration. On the published channel it is **not**: the
> released POMs list it at compile scope, so it is already on your compile classpath. Verified 2026-08-12.

**iOS — none encountered.** Five xcframeworks link and embed directly with no conflicts in this project.

> ⚠️ **One untested risk:** the SDK embeds its own `WebRTC.xcframework` (`rtc-ios` 1.0.26). If your app already links a *different* WebRTC build — via another vendor SDK, for example — that is a plausible duplicate-binary clash. Nothing in this project exercises that case, so it is **unverified**, not cleared. Worth checking early if you ship another RTC SDK.

Full field-level platform differences: [Platform Differences](docs/platform-differences.md).

---

## Versions covered

Both platforms report **`Shoplive.sdkVersion` = `3.0.0`**.

| | Version | Built from | Delivery |
|---|---|---|---|
| iOS | `3.0.0` | `dev` commit `5f0ee781` | SPM (public) — `github.com/shoplive/shoplive-sdk-ios`, Exact 3.0.0 (`a1a168a6`) |
| Android | `3.0.0` | Published artifacts | Gradle (public) — `cloud.shoplive:shoplive-{player,streamer}-sdk:3.0.0` |

> **Same version number, not the same build.** The iOS binaries are packaged from a `dev` commit; Android consumes the published Maven artifacts. So a handful of fields still exist on one platform and not the other — all of them are listed in [Platform Differences](docs/platform-differences.md).

Behavioral notes in these docs were **measured by running the apps** on 2026-07-30 (iOS Simulator / Xcode 26.6; Android `sdk_gphone16k_arm64` API 37), not inferred from documentation. Where something is unverified, it says so.

---

## A note on guide anchor links

Guide links in these docs point at the language-branching entry `https://sdk.shoplive.cloud/` with a section anchor, e.g. `https://sdk.shoplive.cloud/#m6`.

The landing page redirects with `location.replace(target)`, which **does not carry the fragment**, so today those links land at the top of the correct-language guide instead of at the section. Adding the hash to the redirect fixes every link at once:

```js
location.replace(target + location.hash);
```

Until then, the per-language URLs work with anchors directly if you need to jump straight to a section:

- 한국어 — `https://sdk.shoplive.cloud/shoplive-v3-integration-guide-ko.html#m6`
- English — `https://sdk.shoplive.cloud/shoplive-v3-integration-guide-en.html#m6`
- 日本語 — `https://sdk.shoplive.cloud/shoplive-v3-integration-guide-ja.html#m6`

---

## Before handing a build to a customer

- **Credentials** — clear or replace the demo keys (`DemoDefaults` on iOS, `local.properties` on Android). Empty keys make the app prompt for input, which is usually what you want.
- **iOS signing** — pick your own team in Signing & Capabilities and replace the bundle ID `cloud.shoplive.onboarding.demo`.
- **iOS SDK version** — the Xcode project pins the package to **Exact 3.0.0**. Loosen it in Package Dependencies if you want minor updates automatically.

Details in [Getting Started](docs/01-getting-started.md).
