# ShopLive onboarding demo app (Flutter)

The Flutter version of the onboarding demo: **the same 8 missions, the same screens and the same verification rules as
the [Android](../Android/README.md) and [iOS](../iOS/README.md) demos**, built on the ShopLive Flutter SDK
**3.0.2** (`shoplive_player` / `shoplive_streamer` from pub.dev).

Tap a card, the real SDK feature runs, and the card names the file under `lib/shoplive_integration/` that did it.

- Integration guide: https://sdk.shoplive.cloud
- Flutter SDK release: https://github.com/shoplive/shoplive-sdk-flutter/releases/tag/3.0.2
- Card number = the **Mission number** in the guide

---

## 1. Run it

| | Minimum (SDK 3.0.2) | Used here |
|---|---|---|
| Flutter / Dart | 3.22 / 3.4 | 3.29.3 / 3.7.2 |
| Android | minSdk 23 · compileSdk 36 · AGP 8.7 · Gradle 8.9 · JDK 17 | minSdk 24 · AGP 8.7.3 · Gradle 8.11.1 · Kotlin 1.9.25 |
| iOS | 15.0 | 15.0 |

The demo's own `pubspec.yaml` asks for Dart ^3.7.2 (Flutter 3.29); the SDK itself works from Flutter 3.22.

```bash
cd Flutter
flutter pub get
flutter run
```

Nothing to fill in. Tour mode uses the same throwaway demo account as the native demos
([`lib/demo/data/demo_defaults.dart`](lib/demo/data/demo_defaults.dart)). To point tour mode at your own account
without editing that file:

```bash
flutter run --dart-define=SHOPLIVE_DEMO_ACCESS_KEY=... --dart-define=SHOPLIVE_DEMO_CAMPAIGN_KEY=... --dart-define=SHOPLIVE_DEMO_STREAM_TOKEN=...
```

What the SDK needs from the host projects, all already set here:

| Where | What | Why |
|---|---|---|
| `android/app/build.gradle.kts` | `compileSdk = 36`, `minSdk = 24`, Java 17 | Media3 1.10 needs 36; WebRTC needs ≥ 23 |
| `android/app/src/main/AndroidManifest.xml` | `supportsPictureInPicture="true"` on `MainActivity` | without it OS PIP reports `PIP_ACTIVITY_NOT_DECLARED` |
| `MainActivity.kt` | `FlutterFragmentActivity` | the SDK registers its OS-PIP listener only on a `ComponentActivity` |
| `AndroidManifest.xml` | `CAMERA`, `RECORD_AUDIO` | Mission 8 studio |
| `ios/Podfile` | `platform :ios, '15.0'` | `pod install` fails below 15 |
| `ios/Runner/Info.plist` | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` | iOS kills the app when the studio asks for the camera without them |
| both | URL scheme `shoplivedemoflutter://live` | Mission 2 deep link |

The Android Maven repository (`https://sdk.shoplive.cloud/maven-repo`, `exclusiveContent` for `cloud.shoplive`) is
added **by the Shoplive plugins themselves** — this project declares nothing. On iOS, `pod install` downloads and
checksum-verifies the SDK XCFrameworks; run it with a UTF-8 locale (`LANG=en_US.UTF-8`) if you run it by hand.

### QR code input

"Use my own account" → **Scan a QR code** fills the form from the same QR codes the native test apps scan.
The QR holds a URL; only its query is read:

```
https://<any host>/<any path>?ak=<accessKey>&ck=<campaignKey>&title=<label>&st=<streamToken>&userjwt=<JWT>
```

| Key | Fills | Taken from |
|---|---|---|
| `ak` + `ck` | accessKey + campaignKey (only as a pair) | Android `CampaignListActivity`, iOS `SLQRReaderViewController` |
| `title` | the confirmation message only | same |
| `userjwt` | User JWT (Mission 3) | iOS PlayerDemo2 |
| `st` | Stream token (Mission 8) | **new in these demos** (iOS · Android · Flutter) — no native test app reads a stream token from QR; add it to your QR generator |

Nothing is saved or initialized until you tap "Validate and start". Parser:
[`lib/demo/data/qr_credentials.dart`](lib/demo/data/qr_credentials.dart), tests: `test/qr_credentials_test.dart`.
QR input is a tester convenience, so it lives in the demo harness, not in `shoplive_integration/`.

---

## 2. The copy boundary

```
lib/
├── shoplive_integration/   ★ COPY THIS — SDK calls only. Imports: dart, flutter, shoplive_*, crypto
├── demo/                     demo harness: screens, developer sheet, options state, strings, progress
└── main.dart                 initialize before runApp, install the log sink
test/integration_boundary_test.dart   fails if shoplive_integration/ imports anything else
```

The boundary is enforced by a test, the Flutter form of the iOS `IntegrationCopyPasteProof` target:

```bash
flutter test
```

| # | Mission | File (`lib/shoplive_integration/`) | Verified when |
|---|---|---|---|
| 1 | Open the player | `shoplive_player_launcher.dart` | `playback(started)` |
| 2 | Open from a deep link | `shoplive_deep_link_router.dart` | `playback(started)` after a link |
| 3 | Connect member info | `shoplive_user_setup.dart` | `playback(started)` |
| 4 | Show it in your screen | `shoplive_feed_preview.dart` | `playback(started)` |
| 5 | Keep watching in PIP | `shoplive_pip_presets.dart` | `stateChanged(inAppPip)` |
| 6 | Events · products · coupons | `shoplive_player_event_logger.dart` | a navigation / coupon / custom request |
| 7 | Customize the UI | `shoplive_player_presets.dart` | `playback(started)` |
| 8 | Go live | `shoplive_studio_launcher.dart` | `StreamerEvent.stateChanged(live)` |

Shared helpers: `shoplive_log.dart` (the one log sink), `shoplive_event_labels.dart` (error grouping),
`shoplive_player_session.dart` (runtime commands), `shoplive_initializer.dart`.

---

## 3. Where Flutter differs from the native demos

Read these before porting native code. Each one changed how a mission is built.

| Topic | Native SDK | Flutter SDK 3.0.2 | What the demo does |
|---|---|---|---|
| **Embedding (Mission 4)** | `ShoplivePlayerView` inside your layout | **No embeddable widget** — the player is always a native screen over Flutter | Starts the player directly in in-app PIP (`presentationStyle: pip`, `type: preview`, muted) floating over the feed; full screen is `exitPictureInPicture()` |
| **Configuration** | a new immutable object per `start` | **merged** onto the current settings; null fields keep the last value | the options tab sends every field on every start |
| **Delegate** | one delegate object | four streams on `ShoplivePlayer.instance`: `events`, `navigationRequests`, `couponRequests`, `customWebActionRequests` | one logger subscribes once in `main()` and is never cancelled |
| **Coupon with no listener** | popup waits | answered at once with `success: false` | the listener is always attached |
| **Unanswered request** | popup stays | fallback `success: false` after the timeout (10 s, `setRequestTimeout` 1–120 s) | `respond` result is logged; `false` means "too late" |
| **Errors** | callbacks / logs | every call is a `Future` that throws `PlatformException(INVALID_ARGUMENT / NO_HOST_SCREEN / NOT_RUNNING / SDK_ERROR)` | wrapped and logged in `shoplive_player_session.dart` |
| **Context** | Android needs an `Activity` | nothing to pass; fails with `NO_HOST_SCREEN` before the first frame | deep-link playback waits for a post-frame callback |
| **Android-only options** | top-level fields | under `configuration.android` (ignored on iOS) | grouped as "android" in the options tab |
| **PIP padding** | dp / pt | **pixels** | labelled `(px)` |
| **Not exposed** | loading animation, chat fonts, iOS `allowScreenCapture` | — | no control in the options tab |

Full list: the [shoplive_player README](https://pub.dev/packages/shoplive_player), "iOS differences".

---

## 4. Verification status

Measured **2026-10-15**, Flutter 3.29.3, SDK 3.0.2, tour mode, on the iOS Simulator (iPhone 17 Pro, Xcode 26.6) and the
Android Emulator (Pixel 10 image, API 37, arm64). The demo campaign had **no live stream** at the time, so
`playback(started)` never arrived: Missions 1·2·3·4·7 ran but their cards could not turn green.

| Mission | iOS Simulator | Android Emulator |
|---|---|---|
| 1 Open the player | Player opens with overlay (title, LIVE badge, products) | Same |
| 2 Deep link | Banner → `launchUrl` → URL scheme → `app_links` → `start(referrer: push_demo)` | Same; plus **cold start** (app force-stopped): `initialize` → subscribe → link → `start(referrer: cold_start)`, link handled once |
| 3 Member info | Not run | `profile` → `setUser(profile(id: <sha256>))` → `start` |
| 4 In your screen | Preview floats in in-app PIP; Full screen → `exitPictureInPicture()` | Same; leaving the feed → `close()` → `stateChanged(closed)` |
| 5 · 6 PIP / requests | Product tap → `navigation(url)` → Flutter product route, player in in-app PIP; both cards verified | Same; Home while full screen → **OS PIP** |
| 7 Customize | Not run | Options tab renders; `send(...)`, `setOverlayUI(...)` reach the SDK |
| 8 Go live | Studio opens, `stateChanged(preview)`, Info.plist permission strings shown | SDK asks for camera/mic itself; `stateChanged(preview, isRehearsal: false)` on the emulator camera |

**Not verified:** going LIVE (it would broadcast to the shared demo campaign), playback of a real stream, coupons and
custom actions (the campaign had none), physical devices. Android release (R8) was built, not run.

Measured behavior worth knowing:

- **No-stream campaign.** iOS sends `error(code: UNEXPECTED_ERROR, recoverable: false)` on every retry (~5 s) while the
  session stays open, and `playback(failed)` with `code: null`. Android sends `playback(failed(code: 404))` and no
  error. The event logger reports a failure once per session on both.
- **Android: Back out of the host while the player is in PIP.** The SDK player Activity stays alive in its own task
  and comes back over the relaunched app; its later events (`closed`) did **not** reach the new Flutter engine.
  Close the player (`ShoplivePlayer.instance.close()`) before your app finishes its Activity if this matters to you.
- **Fixed during verification:** `MaterialApp(initialRoute: '/start')` stacks `'/'` under the start screen, so Back
  landed on the feature list with no mode chosen. The demo now builds exactly one initial route
  (`onGenerateInitialRoutes`). Measured on Android; the iOS first-launch symptom (tap on "Take a tour" without a
  screen change, once) was not reproduced and its cause is unconfirmed.
