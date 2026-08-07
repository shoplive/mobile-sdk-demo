# ShopLive onboarding demo app (Android)

An app for **checking the 8 features of the unified SDK v3 (Player · Streamer) with a single tap**.
It is built so that an integrator's developer can see each behavior with their own eyes, then **open the file printed
on the feature card and paste that code straight into their own app**.

- Integration guide: https://sdk.shoplive.cloud (한국어 / English / 日本語)
- Card number = the **Mission number** in the guide

---

## 1. Filling in credentials

Copy `local.properties.sample` to `local.properties` and fill in the values.
`local.properties` is git-ignored, so **it never gets committed.**

```
sdk.dir=/Users/<you>/Library/Android/sdk

# Private Maven (required) — values issued by your contact
shoplive.maven.username=
shoplive.maven.password=

# Demo keys for "take a tour" mode (optional)
shoplive.demo.accessKey=
shoplive.demo.campaignKey=
shoplive.demo.streamToken=
```

They can also be injected through the environment variables `SHOPLIVE_MAVEN_USERNAME` / `SHOPLIVE_MAVEN_PASSWORD` and
`SHOPLIVE_DEMO_ACCESS_KEY` / `SHOPLIVE_DEMO_CAMPAIGN_KEY` / `SHOPLIVE_DEMO_STREAM_TOKEN` (for CI).
Resolution order is `local.properties` → `gradle.properties` → environment.

**The demo keys may be left empty.** When empty they fall back to the demo account checked into the repo
([`demo/DemoDefaults.kt`](app/src/main/java/cloud/shoplive/onboarding/demo/DemoDefaults.kt)), so "take a tour" works
immediately after cloning. These are the same values as `DemoDefaults` in the iOS `DemoCredentials.swift`, so
**replacing a token on one side means replacing it on the other too**.

If `local.properties` (or the environment) has values, those win. To check things with your own account, put them in
`local.properties` or type them in on the start screen — do not edit `DemoDefaults.kt`.

> ⚠️ Treat every value in `DemoDefaults.kt` as **already public**. It is for a throwaway demo account only; customer or
> production credentials must never go there. Replacing a token does not remove it from git history, so invalidation has
> to happen in the Shoplive console. The stream token in particular is short-lived: when it expires Mission 8 stops
> working, and the fix is a new token from the console, entered on both Android and iOS.

The default repository is the development one (`repo.us1`). To use the customer-distribution one, add
`shoplive.maven.url=https://repo-mig.us1.shoplive.cloud/repository/shoplive/`.

## 2. Building

```bash
./gradlew :app:assembleDebug
```

---

## Building against local SDK sources (for SDK developers)

`matrix-sdk-android` can be wired in **by local path** instead of the private Maven AAR (a Gradle composite build).
Use it when you change the SDK and want to check it in this demo app right away.

- The default path is `../matrix-sdk-android`, next to this project. If that path exists it is enabled **automatically**;
  if not, it quietly falls back to the Maven AAR. When enabled, the configuration phase prints
  `[shoplive] using local SDK sources: ...`.
- **Do not change** the dependency declarations in `app/build.gradle.kts` (`libs.shoplive.player.sdk` and friends) —
  `dependencySubstitution` in `settings.gradle.kts` substitutes the `cloud.shoplive:shoplive-player-sdk` /
  `:shoplive-streamer-sdk` coordinates with the local projects.

Control it from `local.properties` (the environment variables `SHOPLIVE_SDK_LOCAL_PATH` / `SHOPLIVE_SDK_USE_LOCAL` work too):

```properties
# When cloned somewhere else
shoplive.sdk.localPath=/path/to/matrix-sdk-android
# When you want the Maven AAR again instead of local sources
shoplive.sdk.useLocal=false
```

Checking that the substitution actually took effect:

```bash
./gradlew :app:dependencyInsight --configuration debugCompileClasspath --dependency shoplive-player-sdk
```

> The SDK library modules have a `distribution` flavor dimension (develop/qa/qaUs/ebay). This app has no flavors, so
> `missingDimensionStrategy("distribution", "develop")` in `app/build.gradle.kts` picks develop. It is harmless on the
> AAR path.

---

## Gradle dependencies (the part integrators copy)

### Repository — `settings.gradle.kts`

The standard location for a new project.

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

The Groovy + older form (root `build.gradle`) works exactly the same way.

```groovy
allprojects {
    repositories {
        google()
        maven {
            url 'https://repo.us1.shoplive.cloud/repository/shoplive/'
            credentials {
                username = "<issued username>"
                password = "<issued password>"
            }
        }
        mavenCentral()
    }
}
```

**Do not hardcode the credentials.** This is what the demo actually does — read them from `local.properties`
(git-ignored), falling back to `gradle.properties` and then the environment, so nothing secret reaches the repository or
CI logs. Copy this block as-is; it is the version in [`settings.gradle.kts`](settings.gradle.kts).

```kotlin
import java.util.Properties

val localProps = Properties().apply {
    val file = File(rootDir, "local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun secret(key: String, env: String): String? =
    localProps.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty(key).orNull?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()
        maven {
            name = "shoplive"
            url = uri(
                secret("shoplive.maven.url", "SHOPLIVE_MAVEN_URL")
                    ?: "https://repo.us1.shoplive.cloud/repository/shoplive/"
            )
            credentials {
                username = secret("shoplive.maven.username", "SHOPLIVE_MAVEN_USERNAME")
                password = secret("shoplive.maven.password", "SHOPLIVE_MAVEN_PASSWORD")
            }
        }
        mavenCentral()
    }
}
```

```properties
# local.properties — never committed. Values are issued by your ShopLive contact.
shoplive.maven.username=
shoplive.maven.password=
# Only for customer-distribution builds; the default above is the development repo.
#shoplive.maven.url=https://repo-mig.us1.shoplive.cloud/repository/shoplive/
```

On CI, supply `SHOPLIVE_MAVEN_USERNAME` / `SHOPLIVE_MAVEN_PASSWORD` as secrets instead of a file.
Note that `FAIL_ON_PROJECT_REPOS` makes a repository declared in a module's build file an error — the repository belongs
in `settings.gradle.kts` only.

### Dependencies — app module

```groovy
def shoplive_sdk_version = "3.0.0"
implementation "cloud.shoplive:shoplive-player-sdk:$shoplive_sdk_version"
implementation "cloud.shoplive:shoplive-streamer-sdk:$shoplive_sdk_version"
implementation "cloud.shoplive:shoplive-core:$shoplive_sdk_version"
```

- **Watching only** → just `shoplive-player-sdk`
- **Broadcasting only** → just `shoplive-streamer-sdk`
- Both → declare both (exoplayer, webrtc, and android-webrtc are internal dependencies you never declare, and overlaps
  are de-duplicated by the SDK)
- **`shoplive-core` must be declared.** `Shoplive`, `ShopliveUser`, `ShopliveConfiguration`, and `ShopliveError`
  (= `cloud.shoplive.core.publicsurface`) live in that artifact, and the player/streamer modules consume it as
  `implementation`/`compileOnly`, so **it is not transitive on the compile classpath**. Without it you get
  `Unresolved reference 'core'`.
  (Measured 2026-07-30 against local SDK sources. Whether the published AAR behaves the same is unverified — see
  `TODO(verify)` in `gradle/libs.versions.toml`.)

**minSdk must be 23 or higher.** The documented floor is player 19 / streamer 21, but the transitive
`shoplive-android-webrtc` declares minSdk 23, so 21 fails manifest merging
(`minSdkVersion 21 cannot be smaller than version 23 declared in library [org.webrtc]`). Measured 2026-07-30.

This project manages the same declarations through the version catalog (`gradle/libs.versions.toml`).

> ⚠️ **The integration guide prints different coordinates.**
> <https://sdk.shoplive.cloud/shoplive-v3-integration-guide-ko.html> shows `cloud.shoplive:player-sdk:3.0.0` /
> `cloud.shoplive:streamer-sdk:3.0.0` (no `shoplive-` prefix) and says core comes along automatically. The coordinates
> above are the ones this project builds against, and they match the artifact names in the private Maven
> (`shoplive-player-sdk-3.0.0.aar`, `shoplive-streamer-sdk-3.0.0.aar`, `shoplive-core-3.0.0.aar`). Use these; the guide's
> form does not resolve. `NEEDS CHECK` — whether the guide or the repository is meant to change.

### Pulling the SDK from the private Maven in this demo

This demo currently consumes the SDK as **AARs committed under `app/src/main/libs/`**, so it builds with no credentials
at all. To switch it back to the private Maven, edit
[`app/build.gradle.kts`](app/build.gradle.kts) — the repository wiring in `settings.gradle.kts` is already in place:

```kotlin
dependencies {
    implementation(project(":integration"))

    // Remove the embedded AARs …
//  implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))

    // … and restore the private Maven coordinates.
    implementation(libs.shoplive.player.sdk)     // cloud.shoplive:shoplive-player-sdk:3.0.0
    implementation(libs.shoplive.streamer.sdk)   // cloud.shoplive:shoplive-streamer-sdk:3.0.0
    // core is declared by :integration with `api`, so the app inherits it.
}
```

Then fill in `shoplive.maven.username` / `shoplive.maven.password` in `local.properties` and build:

```bash
cp local.properties.sample local.properties   # then fill in the two credential lines
./gradlew :app:assembleDebug
```

Verifying that resolution actually goes to the private Maven (and which version it picked):

```bash
./gradlew :app:dependencyInsight --configuration debugCompileClasspath --dependency shoplive-player-sdk
```

The 7 AARs currently in `app/src/main/libs/` show what the Maven POMs resolve to transitively — useful if you ever have
to wire the SDK up without a repository at all:

| AAR | Declared |
|---|---|
| `shoplive-player-sdk-3.0.0.aar` | ✅ explicitly |
| `shoplive-streamer-sdk-3.0.0.aar` | ✅ explicitly |
| `shoplive-core-3.0.0.aar` | ✅ explicitly (not transitive — see above) |
| `shoplive-core-player-3.0.0.aar` | transitive |
| `shoplive-exoplayer-2.19.1.10.aar` | transitive (note the different version line) |
| `shoplive-webrtc-3.0.0.aar` | transitive |
| `shoplive-android-webrtc-3.0.0.aar` | transitive (this is what forces minSdk 23) |

> A `fileTree` of AARs carries **no dependency metadata**, which is why all 7 have to be present in that mode. On the
> Maven path you declare only the three marked ✅.

### Manifest

`INTERNET`, `ACCESS_NETWORK_STATE`, and `CAMERA` are already declared in the AAR and get merged, but
**`RECORD_AUDIO` is not in the AAR, so an app that broadcasts has to declare it itself.**

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<!-- Only when using advertising-ID based attribution -->
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

`ShopliveStreamer.start()` requests the runtime permissions for you (`intent()` does not).

---

## Composition

- **Jetpack Compose + Material 3**, single Activity + Navigation Compose, ViewModel + StateFlow
- compileSdk 35 / minSdk 24 (`:integration` is 23) / Java 17 / Kotlin 2.0.21 / AGP 8.7.3
- Two modules — `:app` (the demo harness) and `:integration` (**the integration code you copy verbatim**, see below)
- applicationId `cloud.shoplive.onboarding` — it can be installed alongside the SDK's internal demo app
  (`cloud.shoplive.demo`) on one device.

### Screens

| | Screen | Owner |
| --- | --- | --- |
| S1 | Start (take a tour / my account) | demo app |
| S2 | The 8 feature cards — **tapping a card runs it immediately** | demo app |
| S3 | Player · studio | **SDK** (Activity) |
| S3 | Home feed (Mission 4) | demo app (layout) + `:integration` (player creation and control) |
| V1 | Developer sheet (log / options) | demo app · ModalBottomSheet |
| V2 | Product detail | demo app · Activity |

### The copy-verbatim layer — `:integration`

**All integration code lives in `integration/` alone, and the files can be copied as-is into your own app.** To be
copyable it may only reference the SDK and standard frameworks, so this module **does not depend on** the demo app
(`:app`). The dependency direction is one-way, `:app → :integration`, and a single reference in the other direction
makes `:integration` fail to compile — the same condition as an integrator who copied only the files.

| # | Feature | File (`integration/src/main/java/cloud/shoplive/onboarding/integration/`) | Copy |
| --- | --- | --- | --- |
| 1 | Present the player | `ShoplivePlayerLauncher.kt` | ✅ |
| 2 | Open from a deep link | `ShopliveDeepLinkRouter.kt` | ✅ |
| 3 | Connect member info | `ShopliveUserSetup.kt` | ✅ |
| 4 | Embed in a screen | `ShopliveEmbeddedPlayer.kt` | ✅ |
| 5 | Keep watching in PIP | `ShoplivePipPresets.kt` | ✅ |
| 6 | Events · products · coupons | `ShoplivePlayerEventLogger.kt` | ✅ |
| 7 | UI customization | `ShoplivePlayerPresets.kt` | ✅ |
| 8 | Go live | `ShopliveStudioLauncher.kt` | ✅ |
| — | Initialization · logout · key format validation | `ShopliveInitializer.kt` | ✅ |
| — | Runtime control handle (`isMuted`, `resizeMode`, `reload`, PIP) | `ShoplivePlayerSession.kt` | ✅ |
| — | Log hook (no-op by default) · token masking | `ShopliveLog.kt` | ✅ |
| — | SDK enum → readable labels · error cause classification | `ShopliveEventLabels.kt` | ✅ |

These 12 files carry KDoc (in English) explaining **why it has to be written that way** — the Activity context
requirement, the immutable configuration contract, why a missing `respond` is a bug, and measured facts with dates.
Integrators have to be able to understand it from the comments alone, which is why every code comment in this project is
in English.

#### What copying involves

1. Copy the 12 files into your source tree and change only the `package` declaration to your own package.
   (Nothing else needs editing.)
2. Add the 3 SDK lines to `build.gradle` — `shoplive-player-sdk`, `shoplive-streamer-sdk`, `shoplive-core`.
   (`shoplive-core` holds `Shoplive`, `ShopliveUser`, and `ShopliveError`, and the two SDKs do not expose it transitively.)
3. If you want logs, one line in `Application.onCreate()`:
   `shopliveLog = { kind, message -> Log.d("Shoplive", "${kind.tag} $message") }`

#### There is exactly one injection point

Just `shopliveLog` (no-op by default). Every other app-specific decision — product URL routing, the wording shown to
users, progress recording, coupon copy — arrives through **constructor callbacks** on
`ShoplivePlayerEventLogger`. Because it is not global state, each instance can be given different ones.

The iOS edition has two more on its deep-link router (`configurationProvider`, `delegateProvider`), but the Android
edition **deliberately does not.** This app's deep-link path splits parsing (`SchemeActivity`) from playback
(`MainActivity`) for cold-start safety, and the router does not start playback itself. Putting configuration and
delegate injection points on an object that never starts playback would only add unused surface.

#### The harness (not a copy target)

| Location | What | Why it is harness |
| --- | --- | --- |
| `app/.../demo/DemoLogBridge.kt` | Wires `shopliveLog` → the demo event log | Integrators plug in their own logger |
| `app/.../demo/DemoConfigurationFactory.kt` | Assembles **every field** of the options tab into a configuration | Bound to demo screen state (the integrator-facing example is `ShoplivePlayerPresets`) |
| `app/.../demo/DemoLabels.kt` | SDK error-cause enum → `R.string` | Localization belongs to the app that owns the resources |
| `app/.../data/` | Mission progress · options tab state · credential storage · language setting | Demo-only state |
| `app/.../ui/` | All Compose screens | Demo UI |

`DemoConfigurationFactory` is the dividing line. "Assembling a configuration" looks like one thing but is really two —
the **example** an integrator copies (`branded()`, `overlayHidden()`, `embeddedPreview()`), and the **assembly** that
reflects the demo screen's mutable state across every field. In the iOS edition the latter had leaked into the copy
target, and the isolated compile target caught it.

### How the boundary is kept (not by human review)

Adding one log line is far too easy to be stopped by review. It is blocked in two layers.

| | What it catches |
| --- | --- |
| **Isolated compile** — `./gradlew :integration:assembleDebug` | Anything that breaks compilation: harness symbols, `R`, `BuildConfig`. The last line of defense, catching what a regex misses (enum extensions, factory functions) |
| **Boundary scanner** — `python3 scripts/integration_boundary_scanner.py` | Things that compile but hurt integrators: `android.util.Log`, Timber, `@Inject`, `@Composable`, ViewBinding, non-English comments |

The scanner **strips comments** before checking — an explanation like "this value flows into the demo's event log" is not
a violation. It looks at code only. It is wired into `./gradlew check`, and [CI](.github/workflows/ci.yml) runs both
layers (the scanner is separated so it can run without SDK credentials).

```bash
# Boundary check (no credentials needed)
python3 scripts/integration_boundary_scanner.py

# Prove copyability by compiling — build in an SDK-only environment
./gradlew :integration:assembleDebug
```

### Deep links (Mission 2)

```
shoplivedemo://live?campaign={CAMPAIGN_KEY}&ref={REFERRER}
```

The in-app "fake push" banner fires a real `ACTION_VIEW` intent and goes through the actual `SchemeActivity` →
`MainActivity` path. Parsing and playback are split so that playback starts after `initialize` even on a cold start.

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "shoplivedemo://live?campaign=<CAMPAIGN_KEY>&ref=push_test"
```

### Localization

- `values/` = **English** · `values-ko/` = 한국어 · `values-ja/` = 日本語
- All 159 string keys are defined in all three locales (zero missing, zero extra).

**The default language is English, and the app does not follow the device language.** On a Korean device the app still
opens in English. This build is handed to integrators in several countries, and if it followed the device language there
would be no way to check the English or Japanese screens on a Korean device.

Switching is done with the **`English / 한국어 / 日本語` segmented control at the top of the start screen**, and the
choice is stored on the device. The implementation is
[`data/LocaleSetting.kt`](app/src/main/java/cloud/shoplive/onboarding/data/LocaleSetting.kt) — it uses its own setting
plus each Activity's `attachBaseContext` rather than Android 13+'s per-app language setting (`LocaleManager`), because it
has to behave identically down to minSdk 24 and because it avoids the system setting and the app setting overwriting
each other.

To go back to following the device language, make `LocaleSetting.wrap()` return the original Context and delete the
`attachBaseContext` overrides in each Activity.

Two exceptions:

- **The language of SDK-drawn screens (player overlay, studio) is independent of this setting.** SDK Activities do not go
  through the demo app's `attachBaseContext`, and overlay copy is managed by the SDK and the server. The app UI may be in
  English while the player's chat UI appears in the device language.
- **The developer log (⌗ sheet) is deliberately English-only.** It mirrors SDK API calls verbatim as a technical log, and
  it gets pasted into bug reports.

---

## How confirmation happens automatically

The "confirmed" badge is not checked off by the user — it is **decided automatically from SDK events**
(`data/MissionProgress.kt`).

| Evidence | Mission |
| --- | --- |
| `Playback.Started` | 1 · 2 · 3 · 4 · 7 |
| `StateChanged(IN_APP_PIP)` | 5 |
| `Navigation` / `Coupon` request received | 6 |
| `StreamerEvent.StateChanged(LIVE)` | 8 |

---

## Where this differs from the prototype (reflecting real SDK constraints)

| Item | Prototype | Actual |
| --- | --- | --- |
| Log FAB and terminology-number toggle over the player screen | Shown over the player | **Not possible** — the player and studio are SDK-owned Activities. Logs accumulate and are read after returning to the app |
| `pip.autoEnterOnLeaveScreen` option | Present in options | **Not in the public surface** — on leaving the screen the app handles PIP itself via `enterPictureInPicture()` |
| Chat/product overlay on the embedded view | Shown | **Video only** — `overlayUI` is fixed at HIDDEN (the command channel stays) |
| Embedded view + OS PIP | Mentioned | **Full screen only** — embedded gets in-app PIP alone |
| `appearance.allowScreenCapture` default | `false` | The implemented default is **`true`** (a documentation correction) |
| Mission 8 lock | Only in my-account mode | **Always locked without a token** — a broadcast cannot start without one |
| Key pre-validation | "filtered by validation before playback" | The SDK has no pre-validation API → local format check only, plus translating error events into cause-specific sentences |
| Product detail | Modal sheet | **A separate Activity** — it has to be placed above the SDK player to be visible |
| Feed list | (unspecified) | `Column + verticalScroll` instead of `LazyColumn` — the embedded view releases resources on detach, so as a lazy item playback would break from scrolling alone |

## Verification status (measured on the emulator, 2026-07-30)

Confirmed on `sdk_gphone16k_arm64` · **API 37 · 16KB page image**.

Confirmed:

- Installs and runs correctly. No crashes, `dlopen` failures, or native alignment errors (arm64-v8a included)
- Launches in **English** by default (regardless of device language), and switching between the 3 languages works
- The feature list, developer sheet, and event log all render correctly
- The SDK integration path works: `initialize` → `start` → `stateChanged(LOADING)` → `analytics` → `playback` events received
- Toasts appear **above the SDK-owned player Activity**

### ⚠️ The earlier demo campaign does not play

The player stays black. This is not an app or emulator problem — **there is no stream**.

```
playback(requested) → playback(failed(code: 404, message: 404))   ← repeats every 5 seconds
playback(ended) → stateChanged(IDLE) → stateChanged(CLOSED)
```

This has to be re-checked with a campaignKey that is on air (or that has a VOD asset).

### Three observations to report to the SDK team

1. **`ShoplivePlayerEvent.Error` never arrives, even as the 404s repeat and the session ends.**
   This contradicts the design doc contract ("deliver `error(isRecoverable = false)` when the session ends
   unrecoverably"). An app that subscribes only to `error` can never learn that "there is no stream" and will just show a
   black screen.
2. **`campaignInfoReceived` and `campaignStatusChanged` did not fire either.** The app has no way to tell READY/LIVE/ENDED
   apart. (`analytics` does arrive, carrying the campaignKey.)
3. `Uncaught TypeError: window.__receiveAppEvent is not a function` ×3 in the overlay web view console.

Because of 1 and 2, the demo app counts `playback(failed)` itself and reports it —
`onRepeatedPlaybackFailure()` in
[`ShoplivePlayerEventLogger.kt`](integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerEventLogger.kt).
Once the SDK delivers `error` properly, this workaround can be deleted.

### Not yet confirmed (needs a campaign that plays)

- Actual playback start (2–3s) · chat and the LIVE badge
- Whether in-app PIP stays **above** the product detail Activity
- `navigation(url)` → product detail routing
- Whether `sound.muteOnStart = true` reproduces the PIP bounce
- Mission 8 broadcast start · camera/microphone permission flow (the emulator's camera limits apply too)
- How the re-fetch feels when promoting the embedded view to full screen

---

## Copyability verification status (2026-07-30)

Results for the `:integration` extraction refactor. Only things that were actually run are recorded here.

| Item | Result |
| --- | --- |
| Harness dependency count (before → after the refactor) | **88 → 0** (grep, command below) |
| Boundary scanner | PASS — 12 files, 0 violations |
| Isolated compile `:integration:assembleDebug` | ✅ succeeded (SDK only, no `:app` dependency) |
| App build `:app:assembleDebug` | ✅ succeeded |
| Copying it by hand | ✅ Into an empty project (`com.acme.shop`) with only the 3 SDK lines, copied the 12 files → changed one `package` line and assembled an APK successfully. Code calling all 12 public APIs **from a different package** compiled too |
| Korean in code comments | 0 (excluding localization resources such as `values-ko/` and the `한국어` label in the language picker) |
| Injection points | 1 — `shopliveLog` |
| **Emulator run** | ❌ **unverified** — this machine has no AVD or connected device (`adb devices` is empty, no system image installed). The app has to be run on a real device again after the refactor |
| AAR (private Maven) mode build | ❌ **unverified** — the Maven credentials in this machine's `local.properties` are empty, so verification used local SDK sources (composite build) only |

```bash
# To reproduce the pre-refactor number, run the same grep against app/.../sdk/ at the earlier commit.
grep -rn "DemoLog\|DemoContainer\|ProductRouter\|MissionProgress\|DemoOptions\|BuildConfig\|R\.string\.\|R\.drawable\.\|onboarding\.data\." \
  integration/src/main/java | wc -l   # → 0
```

### What the refactor actually caught (compilation, not the scanner)

1. **A `ShopliveError.cause` extension is silently defeated.** Because `ShopliveError` inherits `Throwable`, a `cause`
   extension property is shadowed by `Throwable.cause` at every call site — so callers get a `Throwable?` instead of the
   error cause classification. It was renamed to `causeGroup`.
2. **`shoplive-core` is not transitive.** See "Dependencies — app module" above.
3. **The effective minSdk floor is 23** (the docs say 19/21). See the same section above.
