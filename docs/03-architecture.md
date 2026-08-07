# 3. Architecture & the Copy Boundary

[◀ Demo App Tour](02-demo-app-tour.md) · [Docs home](../README.md) · Next: [Mission 1 ▶](mission-01-open-the-player.md)

> **Guide cross-reference:** [Quick start](https://sdk.shoplive.cloud/#quickstart) · [Customer-configured items](https://sdk.shoplive.cloud/#customer-config)

Most demo apps leave you guessing which parts are the integration and which parts are scaffolding. This one draws that line explicitly — and on iOS, the compiler enforces it.

---

## 3.1 Two layers

| Layer | iOS | Android | Copy it? |
|---|---|---|---|
| **Integration** | `iOS/ShopliveIntegration/` | `Android/app/src/main/java/cloud/shoplive/onboarding/sdk/` | ★ **Yes** — SDK calls only |
| **Harness** | `Screens/` · `Support/` · `App/` | `ui/` · `data/` | No — mission list, log sheet, options, theme, localization |

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

### The integration layer has exactly three outward hooks

Which means: after you copy it, these are the only places you need to touch.

| Hook | Default | Purpose |
|---|---|---|
| `shopliveLog(_:_:)` | no-op | Logging. Plug in your own logger, or delete the call sites (each is one line). |
| `DeepLinkRouter.configurationProvider` | `{ .init() }` | Which configuration deep-link playback should use |
| `DeepLinkRouter.delegateProvider` | `{ nil }` | Which delegate receives deep-link playback events |

The demo wires all three in one place — [`App/DemoBootstrap.swift`](../iOS/ShopliveOnboardingDemo/App/DemoBootstrap.swift) — as a worked example of what your app has to connect:

```swift
// Route the integration layer's log hook into the developer sheet.
shopliveLog = { kind, message in EventLog.shared.log(kind.demoKind, message) }

// Tell the deep-link router which configuration and delegate to use.
DeepLinkRouter.shared.configurationProvider = { DemoConfigBuilder.makeConfiguration(.fullScreenLive) }
DeepLinkRouter.shared.delegateProvider     = { DemoPlayerDelegate.shared }
```

Why funnel logging through a single function? Because if a copy-target file referenced `EventLog` directly, it would stop compiling the moment someone copied it out. One indirection buys a guarantee.

---

## 3.3 Android: same split, package-based

The Android app separates by package rather than by build target:

| Package | Role |
|---|---|
| `sdk/` | ★ The integration layer. KDoc on each file explains the *why*. |
| `ui/` | Compose screens, the developer sheet, theme |
| `data/` | Credential storage, options state, log buffer, mission progress, locale |

`sdk/` files do reference two demo helpers — `DemoLog` for logging and `DemoContainer`/`MissionProgress` for demo bookkeeping. When you copy a file, replace `DemoLog.*` calls with your own logging (or delete them) and drop the progress-tracking lines. Everything else is pure SDK API.

The demo also avoids a DI framework on purpose: `DemoContainer` in [`DemoApplication.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/DemoApplication.kt) is a ten-line service locator, so nothing here presumes you use Hilt or Koin.

---

## 3.4 Mission → file map

The 📄 path printed on each card in the app is this table. Use it in both directions: tap a card to see the behavior, then open the file to see what produced it.

| # | Mission | iOS | Android |
|---|---|---|---|
| — | Initialize (once per app) | [`ShopliveBootstrap.swift`](../iOS/ShopliveIntegration/ShopliveBootstrap.swift) | [`ShopliveInitializer.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/ShopliveInitializer.kt) |
| 1 | [Open the player](mission-01-open-the-player.md) | [`PlayerLauncher.swift`](../iOS/ShopliveIntegration/PlayerLauncher.swift) | [`PlayerLauncher.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerLauncher.kt) |
| 2 | [Open from a deep link](mission-02-deep-link.md) | [`DeepLinkRouter.swift`](../iOS/ShopliveIntegration/DeepLinkRouter.swift) + [`SceneDelegate.swift`](../iOS/ShopliveOnboardingDemo/App/SceneDelegate.swift) | [`DeepLinkRouter.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DeepLinkRouter.kt) + [`SchemeActivity.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/SchemeActivity.kt) |
| 3 | [Connect member info](mission-03-user-identity.md) | [`UserSetup.swift`](../iOS/ShopliveIntegration/UserSetup.swift) | [`UserSetup.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/UserSetup.kt) |
| 4 | [Embed in your screen](mission-04-embed-in-your-screen.md) | [`EmbeddedPlayerView.swift`](../iOS/ShopliveIntegration/EmbeddedPlayerView.swift) | [`FeedScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/feed/FeedScreen.kt) |
| 5 | [Keep watching in PIP](mission-05-pip.md) | [`PipOptions.swift`](../iOS/ShopliveIntegration/PipOptions.swift) | [`PipOptions.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PipOptions.kt) |
| 6 | [Events · products · coupons](mission-06-events-products-coupons.md) | [`DemoPlayerDelegate.swift`](../iOS/ShopliveIntegration/DemoPlayerDelegate.swift) | [`DemoPlayerDelegate.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt) |
| 7 | [Customize the UI](mission-07-ui-customization.md) | [`PlayerConfigurationFactory.swift`](../iOS/ShopliveIntegration/PlayerConfigurationFactory.swift) | [`PlayerConfigurationFactory.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerConfigurationFactory.kt) |
| 8 | [Go live](mission-08-go-live.md) | [`StudioLauncher.swift`](../iOS/ShopliveIntegration/StudioLauncher.swift) | [`StudioLauncher.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/StudioLauncher.kt) |
| — | Runtime control handle | (`ShoplivePlayerControlling` directly) | [`PlayerSession.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt) |
| — | Log hook / enum labels | [`ShopliveLog.swift`](../iOS/ShopliveIntegration/ShopliveLog.swift) · [`ShopliveLabels.swift`](../iOS/ShopliveIntegration/ShopliveLabels.swift) | [`DemoLog.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/DemoLog.kt) |

---

## 3.5 Three mental models to carry into the missions

Almost every "why doesn't this work" question resolves to one of these three.

### ① Configuration vs. play options vs. runtime properties

Three different lifetimes, three different places to set things.

| | `ShoplivePlayerConfiguration` | `ShoplivePlayOptions` | Runtime properties |
|---|---|---|---|
| Scope | Policy for a playback session | One single `play` / `start` call | Right now, mid-playback |
| Mutable after playback starts? | **No** — assignments are ignored | n/a | Yes, that's the point |
| Examples | PIP policy, sound policy, colors, overlay mode, navigation behavior | `referrer`, `keepWindowStateOnPlayExecuted` | `isMuted`, `resizeMode`, `overlayUI` |

Putting a per-playback value like `referrer` in configuration, or expecting a configuration change to take effect mid-session, are the two most common mistakes. That's why the demo's Options tab has a **"Play again with these options"** button instead of pretending live edits work.

### ② Events vs. requests

The delegate has exactly two methods and the distinction is load-bearing:

- **Event** (`didReceive` / `onEvent`) — a notification. Handle what you care about, ignore the rest.
- **Request** (`didRequest` / `onRequest`) — the SDK is **asking you something**. `coupon` and `customWebAction` hand you a `respond` callback, and if you don't call it the overlay popup never closes. **Not responding is a bug**, not a no-op.

Only one request is genuinely mandatory: `navigation`. Skip it and tapping a product does nothing at all.

### ③ Full-screen and embedded share one control contract

`ShoplivePlayerViewController` / `ShoplivePlayer` (full screen) and `ShoplivePlayerView` (embedded) both implement `ShoplivePlayerControlling`. Mute, resize, reload, `send()`, and PIP enter/exit are **identical code** on either path. Only present/dismiss/close differ.

This is why you can write your player-control code once, and why [`PlayerSession.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt) stores the handle as the shared interface type rather than a concrete class.

---

## 3.6 One more thing: `@unknown default` on iOS

The iOS SDK is built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so its public enums are **resilient**. Switching over `ShoplivePlayerEvent`, `ShoplivePlayerRequest`, `ShopliveStreamerEvent`, or `ShoplivePlayerState` without `@unknown default` produces a warning today and an **error** under the Swift 6 language mode — even if you list every case that currently exists.

Every switch in `ShopliveIntegration/` includes it. For `ShoplivePlayerRequest` this matters beyond compilation: silently ignoring an unknown request means never calling `respond`, which leaves the overlay waiting.

Kotlin's `sealed` hierarchies don't have this problem — `when` over a sealed class is exhaustive at compile time, and adding a case is a source-breaking change you'll be told about.

---

[◀ Demo App Tour](02-demo-app-tour.md) · [Docs home](../README.md) · Next: [Mission 1 ▶](mission-01-open-the-player.md)
