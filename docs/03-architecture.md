# 3. Architecture & the Copy Boundary

[◀ Demo App Tour](02-demo-app-tour.md) · [Docs home](../README.md) · Next: [Mission 1 ▶](mission-01-open-the-player.md)

> **Guide cross-reference:** [Quick start](https://sdk.shoplive.cloud/#quickstart) · [Customer-configured items](https://sdk.shoplive.cloud/#customer-config)

Most demo apps leave you guessing which parts are the integration and which parts are scaffolding. This one draws that line explicitly — and on iOS, the compiler enforces it.

---

## 3.1 Two layers

| Layer | iOS | Android | Copy it? |
|---|---|---|---|
| **Integration** | `iOS/ShopliveIntegration/` | `Android/integration/` (the `:integration` module) | ★ **Yes** — SDK calls only |
| **Harness** | `Screens/` · `Support/` · `App/` | `Android/app/` — `ui/` · `data/` · `demo/` | No — mission list, log sheet, options, theme, localization |

The integration layer is written to be **read as teaching material and copied verbatim**. Every non-obvious call carries a comment explaining *why* it has to be that way — why the context must be an Activity, why configuration is immutable, why a missing `respond` is a bug.

---

## 3.2 iOS: the boundary is compiled, not documented

`ShopliveIntegration/` has **zero** dependencies on the demo harness. Copy the folder into an empty project and it builds. That claim is checked two ways:

**① Boundary scanner** — fails if a harness symbol (`EventLog`, `DemoTheme`, `L("…")`, …) appears anywhere under `ShopliveIntegration/`:

```bash
python3 iOS/scripts/integration_boundary_scanner.py
```

**② A copy-paste proof target** — `IntegrationCopyPasteProof` is a framework target whose *only* sources are `ShopliveIntegration/**`. That's the same condition as a customer dropping the folder into a blank project, so a single harness dependency breaks the build:

```bash
cd iOS
xcodebuild -project ShopliveOnboardingDemo.xcodeproj -scheme IntegrationCopyPasteProof \
  -destination 'generic/platform=iOS' build
```

This is not theoretical — during refactoring the proof target caught two real leaks the scanner missed (a harness extension `demoLabel`, and an options-tab-only factory method).

### The integration layer has exactly five outward hooks

Which means: after you copy it, these are the only places you need to touch.

| Hook | Default | Purpose |
|---|---|---|
| `shopliveLog(_:_:)` | no-op | Logging. Plug in your own logger, or delete the call sites (each is one line). |
| `DeepLinkRouter.configurationProvider` | `{ .init() }` | Which configuration deep-link playback should use |
| `DeepLinkRouter.delegateProvider` | `{ nil }` | Which delegate receives deep-link playback events |
| `DeepLinkRouter.beforePresent` | proceed at once | Close whatever player is on screen before the link's player is presented |
| `DeepLinkRouter.onPresented` | nothing | Receive the player the link opened |

The demo wires all five in one place — [`App/DemoBootstrap.swift`](../iOS/ShopliveOnboardingDemo/App/DemoBootstrap.swift) — as a worked example of what your app has to connect:

```swift
// Route the integration layer's log hook into the developer sheet.
shopliveLog = { kind, message in EventLog.shared.log(kind.demoKind, message) }

// Tell the deep-link router which configuration and delegate to use, and how to hand over the screen.
let router = DeepLinkRouter.shared
router.configurationProvider = { DemoConfigBuilder.makeConfiguration(.fullScreenLive) }
router.delegateProvider = { DemoPlayerDelegate.shared }
router.beforePresent = { proceed in DevSheetViewController.replaceCurrentSession(then: proceed) }
router.onPresented = { player in
    DemoPlayerDelegate.adopt(player)
    DevSheetViewController.recordSession(player, presentedAs: player, for: .deeplink)
}
```

Events reach the rest of your app through **one channel to listen on**, not a hook to set: `DemoPlayerDelegate` re-publishes what the app needs as `PlayerMilestone`, always with the player that sent it, and any screen subscribes with `DemoPlayerDelegate.observeMilestones(of:)` — to its own player, or to every player with `nil`. View controller sessions go through `DemoPlayerDelegate.adopt(_:)`, because the SDK names its inner view as `player` ([Known Issues](known-issues.md#the-delegates-player-is-not-your-view-controller-ios)). See [Mission 6](mission-06-events-products-coupons.md).

Why funnel logging through a single function? Because if a copy-target file referenced `EventLog` directly, it would stop compiling the moment someone copied it out. One indirection buys a guarantee.

---

## 3.3 Android: same split, a separate module

The Android project separates by Gradle module, so the boundary is compiled here too:

| Module / package | Role |
|---|---|
| `:integration` — `integration/src/main/java/cloud/shoplive/onboarding/integration/` | ★ The integration layer. KDoc on each file explains the *why*. Depends on the SDK only. |
| `:app` — `ui/` | Compose screens, the developer sheet, theme |
| `:app` — `data/` | Credential storage, options state, log buffer, mission progress, locale |
| `:app` — `demo/` | Wiring between the two: log bridge, options → configuration, error cause → string resource |

The dependency runs one way, `:app → :integration`; a reference in the other direction does not compile, which is the same condition as an integrator who copied only the files. `./gradlew :integration:assembleDebug` and `python3 Android/scripts/integration_boundary_scanner.py` check it. App-specific decisions — product routing, user-facing text, progress tracking — arrive through constructor callbacks on `ShoplivePlayerEventLogger`, and logging through the one `shopliveLog` hook. Details: [Android/README.md](../Android/README.md#the-copy-verbatim-layer--integration).

The demo also avoids a DI framework on purpose: `DemoContainer` in [`DemoApplication.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/DemoApplication.kt) is a ten-line service locator, so nothing here presumes you use Hilt or Koin.

---

## 3.4 Mission → file map

The 📄 path printed on each card in the app is this table. Use it in both directions: tap a card to see the behavior, then open the file to see what produced it.

The order is the integration guide's mission map; the card number is the position in the app's catalog (`MissionCatalog.swift` / `Missions.kt`) and nothing else.

| # | Mission | iOS | Android (`integration/…/integration/`) |
|---|---|---|---|
| — | Initialize (once per app) | [`ShopliveBootstrap.swift`](../iOS/ShopliveIntegration/ShopliveBootstrap.swift) | [`ShopliveInitializer.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveInitializer.kt) |
| 1 | [Launch the Player Directly](mission-01-open-the-player.md) | [`PlayerLauncher.swift`](../iOS/ShopliveIntegration/PlayerLauncher.swift) | [`ShoplivePlayerLauncher.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerLauncher.kt) |
| 2 | [Nudge-Style Preview](mission-02-nudge-preview.md) | [`NudgePreview.swift`](../iOS/ShopliveIntegration/NudgePreview.swift) | [`ShopliveNudgePreview.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveNudgePreview.kt) |
| 3 | [Keep Watching in PIP](mission-03-pip.md) | [`PipOptions.swift`](../iOS/ShopliveIntegration/PipOptions.swift) | [`ShoplivePipPresets.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePipPresets.kt) |
| 4 | [Launch via Deep Link](mission-04-deep-link.md) | [`DeepLinkRouter.swift`](../iOS/ShopliveIntegration/DeepLinkRouter.swift) + [`SceneDelegate.swift`](../iOS/ShopliveOnboardingDemo/App/SceneDelegate.swift) | [`ShopliveDeepLinkRouter.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveDeepLinkRouter.kt) + [`SchemeActivity.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/SchemeActivity.kt) |
| 5 | [Connect User Information](mission-05-user-identity.md) | [`UserSetup.swift`](../iOS/ShopliveIntegration/UserSetup.swift) | [`ShopliveUserSetup.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveUserSetup.kt) |
| 6 | [Events · Products · Coupons](mission-06-events-products-coupons.md) | [`DemoPlayerDelegate.swift`](../iOS/ShopliveIntegration/DemoPlayerDelegate.swift) | [`ShoplivePlayerEventLogger.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerEventLogger.kt) |
| 7 | [Add Inline Previews to a List Screen](mission-07-embed-in-your-screen.md) | [`EmbeddedPlayerView.swift`](../iOS/ShopliveIntegration/EmbeddedPlayerView.swift) · [`WebBridge.swift`](../iOS/ShopliveIntegration/WebBridge.swift) | [`ShopliveEmbeddedPlayer.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveEmbeddedPlayer.kt) · [`ShopliveWebBridge.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveWebBridge.kt) |
| 8 | [UI Customization & Placement](mission-08-ui-customization.md) | [`PlayerConfigurationFactory.swift`](../iOS/ShopliveIntegration/PlayerConfigurationFactory.swift) | [`ShoplivePlayerPresets.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerPresets.kt) |
| 9 | [Broadcasting](mission-09-go-live.md) | [`StudioLauncher.swift`](../iOS/ShopliveIntegration/StudioLauncher.swift) | [`ShopliveStudioLauncher.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveStudioLauncher.kt) |
| — | Runtime control handle | (`ShoplivePlayerControlling` directly) | [`ShoplivePlayerSession.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerSession.kt) |
| — | Log hook / enum labels | [`ShopliveLog.swift`](../iOS/ShopliveIntegration/ShopliveLog.swift) · [`ShopliveLabels.swift`](../iOS/ShopliveIntegration/ShopliveLabels.swift) | [`ShopliveLog.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveLog.kt) · [`ShopliveEventLabels.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveEventLabels.kt) |

---

## 3.5 Three mental models to carry into the missions

Almost every "why doesn't this work" question resolves to one of these three.

### ① Configuration vs. play options vs. runtime properties

Three different lifetimes, three different places to set things.

| | `ShoplivePlayerConfiguration` | `ShoplivePlayOptions` | Runtime properties |
|---|---|---|---|
| Scope | Policy for a playback session | One single `play` / `start` call | Right now, mid-playback |
| Mutable after playback starts? | **No** — assignments are ignored | n/a | Yes, that's the point |
| Examples | PIP policy, sound policy, colors, overlay mode, navigation behavior | `referrer`, `keepWindowStateOnPlayExecuted`, `presentationStyle` (3.0.4+) | `isMuted`, `resizeMode`, `overlayUI` |

Putting a per-playback value like `referrer` in configuration, or expecting a configuration change to take effect mid-session, are the two most common mistakes. That's why the demo's Options tab has a **"Play again with these options"** button instead of pretending live edits work.

### ② Events vs. requests

The delegate has exactly two methods and the distinction is load-bearing:

- **Event** (`didReceive` / `onEvent`) — a notification. Handle what you care about, ignore the rest.
- **Request** (`didRequest` / `onRequest`) — the SDK is **asking you something**. `coupon` and `customWebAction` hand you a `respond` callback, and if you don't call it the overlay popup never closes. **Not responding is a bug**, not a no-op.

Only one request is genuinely mandatory: `navigation`. Skip it and tapping a product does nothing at all.

### ③ Full-screen and embedded share one control contract

`ShoplivePlayerViewController` / `ShoplivePlayer` (full screen) and `ShoplivePlayerView` (embedded) both implement `ShoplivePlayerControlling`. Mute, resize, reload, `send()`, and PIP enter/exit are **identical code** on either path. Only present/dismiss/close differ.

This is why you can write your player-control code once, and why [`ShoplivePlayerSession.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerSession.kt) stores the handle as the shared interface type rather than a concrete class.

---

## 3.6 One more thing: `@unknown default` on iOS

The iOS SDK is built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so its public enums are **resilient**. Switching over `ShoplivePlayerEvent`, `ShoplivePlayerRequest`, `ShopliveStreamerEvent`, or `ShoplivePlayerState` without `@unknown default` produces a warning today and an **error** under the Swift 6 language mode — even if you list every case that currently exists.

Every switch in `ShopliveIntegration/` includes it. For `ShoplivePlayerRequest` this matters beyond compilation: silently ignoring an unknown request means never calling `respond`, which leaves the overlay waiting.

Kotlin's `sealed` hierarchies don't have this problem — `when` over a sealed class is exhaustive at compile time, and adding a case is a source-breaking change you'll be told about.

---

[◀ Demo App Tour](02-demo-app-tour.md) · [Docs home](../README.md) · Next: [Mission 1 ▶](mission-01-open-the-player.md)
