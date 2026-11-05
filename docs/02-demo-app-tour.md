# 2. Demo App Tour

[◀ Getting Started](01-getting-started.md) · [Docs home](../README.md) · Next: [Architecture & Copy Boundary ▶](03-architecture.md)

> **Guide cross-reference:** [Screen terminology](https://sdk.shoplive.cloud/#screens) · [Player screen](https://sdk.shoplive.cloud/#screens-player) · [Studio screen](https://sdk.shoplive.cloud/#screens-streamer) · [Checking things with the demo app](https://sdk.shoplive.cloud/#demo)

The demo app is not a showcase — it's a **worksheet**. Each of the nine cards runs one real SDK feature and tells you which file produced it. This page explains the screens so that when you tap something, you know what you're looking at.

---

## 2.1 The five screens

Both platforms implement the same five surfaces. The prototype codenames (S1, S2, S3, V1, V2) appear in source comments, so they're worth knowing.

| | Screen | Who draws it | iOS | Android |
|---|---|---|---|---|
| **S1** | Start — pick a mode, enter keys | Demo app | [`StartViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/StartViewController.swift) | [`StartScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/start/StartScreen.kt) |
| **S2** | Mission list — 9 cards | Demo app | [`MissionListViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/MissionListViewController.swift) | [`MissionListScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/missions/MissionListScreen.kt) |
| **S3** | Player / studio | **The SDK** | The SDK player, subclassed for two demo controls — [`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift) | SDK Activity |
| **S3′** | Home feed (embedded player) — Mission 7, native | Demo app | [`FeedDemoViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/FeedDemoViewController.swift) | [`FeedScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/feed/FeedScreen.kt) |
| — | Web list (WebView + bridge) — Mission 7, hybrid | Demo app | [`HybridListViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/HybridListViewController.swift) | [`HybridListScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/hybrid/HybridListScreen.kt) |
| — | Product page with a nudge-style preview — Mission 2 | Demo app (the small window is the SDK) | [`NudgeProductViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/NudgeProductViewController.swift) | [`NudgeProductScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/nudge/NudgeProductScreen.kt) |
| **V1** | Developer sheet — Log / Options | Demo app | [`DevSheetViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/DevSheetViewController.swift) | [`DevSheet.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/devtools/DevSheet.kt) |
| **V2** | Product detail | Demo app | [`ProductDetailViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/ProductDetailViewController.swift) | [`ProductDetailScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/product/ProductDetailScreen.kt) |

**The important line is between S2 and S3.** Everything up to the mission list is your app. The moment playback starts, the screen belongs to the SDK — it renders the video, the chat, the LIVE badge, the product banner, the share and PIP buttons, and the close button. You do not build any of that.

---

## 2.2 S1 — two modes

| Mode | What it does |
|---|---|
| **Take a tour** | Uses the demo keys baked into the build. No typing. Enabled only when those keys are present. |
| **Use my account** | You type — or scan from a QR code — your own `accessKey` + `campaignKey` (and optionally a stream token and a User JWT). |

On relaunch the app skips S1 and re-enters the last mode used, so you don't retype keys every run.

The start screen's header carries the **English / 한국어 / 日本語** language selector on all three apps. It sits above the collapsible form so it never moves when the form opens — see [§2.6](#26-localization).

### QR code input

"Use my account" → **Scan a QR code** fills the form from the QR codes the native SDK test apps already use. The QR holds
a URL; only its query is read, and the rules are identical on iOS, Android and Flutter:

```
https://<any host>/<any path>?ak=<accessKey>&ck=<campaignKey>&title=<label>&st=<streamToken>&userjwt=<JWT>
```

| Key | Fills | Taken from |
|---|---|---|
| `ak` + `ck` | accessKey + campaignKey — **only as a pair** | test apps: Android `CampaignListActivity`, iOS `SLQRReaderViewController` |
| `title` | the confirmation message only | same |
| `userjwt` | User JWT (Mission 5) | iOS PlayerDemo2 |
| `st` | Stream token (Mission 9) | **new in these demos** — no test app reads a stream token from QR; add it to your QR generator |

Nothing is saved or initialized until "Validate and start". A QR without usable values keeps the camera open and says
why. Parsers: [`QrCredentials.swift`](../iOS/ShopliveOnboardingDemo/Support/QrCredentials.swift) ·
[`QrCredentials.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/QrCredentials.kt) ·
[`qr_credentials.dart`](../Flutter/lib/demo/data/qr_credentials.dart), each with the same 7 test cases. QR input is a
tester convenience, so it lives in the demo harness, never in the copy-paste layer.

---

## 2.3 S2 — the mission list

Each card shows four things:

```
┌────────────────────────────────────────────────┐
│ ①  Launch the Player Directly         ✔ done   │
│     Tap to open a full-screen live stream.     │
│     ✅ Plays within 2–3s · chat and LIVE badge │
│     📄 ShopliveIntegration/PlayerLauncher.swift│
└────────────────────────────────────────────────┘
```

1. **Number and title** — the same number and title as the [integration guide's mission map](https://sdk.shoplive.cloud/#mission-map) and these docs. The number is the card's position in the catalog and is not stored anywhere else, so reordering the catalog renumbers every screen at once. The header shows progress as `done / total`, with the total taken from the same catalog.
2. **What it does.**
3. **Checkpoint** — what you should see if it worked.
4. **📄 Source path** — the file that produced the behavior. This path is the only bridge between the running app and the code, and it is kept in sync with the real file location deliberately ([`MissionCatalog.swift`](../iOS/ShopliveOnboardingDemo/Support/MissionCatalog.swift), [`Missions.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/Missions.kt)). Mission 7 lists two files — one per approach.

**Tapping a card runs the mission immediately.** There is no detail screen in between — except Mission 7, which first asks *native* or *hybrid*, and Mission 5, which asks for the authentication method.

Like every card, Mission 2 replaces the session on screen when you tap it. Coming **back** to its product page is different: if another session is still going (a PIP you are watching, say), the nudge is not started again — only logged — so returning to the page never closes something you are watching. Same rule on iOS and Android.

### The "done" badge is not a checkbox

You cannot mark a mission complete yourself. The badge appears only when an SDK event proves the feature worked:

| Proof | Marks complete |
|---|---|
| Playback reached first frame — **from the player the running mission started** | Missions 1, 2, 4, 5, 7, 8 (whichever is running) |
| `stateChanged(.inAppPIP)` / `IN_APP_PIP_ENTERED` — any player **except a nudge's**: never from a nudge player (even after another mission started), nor while Mission 2 is still starting its nudge | Mission 3 |
| A `navigation`, `coupon` or `customWebAction` **request** arrived — any player | Mission 6 |
| `StreamerEvent.stateChanged(LIVE)` | Mission 9 |

The rules are the same on both platforms, and they live in one place: `MissionProgress` knows **which mission is running** and **which player that mission started**. Every start path — card, deep link, nudge, hybrid list, feed — registers its player. That is why a feed embed still playing underneath a deep-link player cannot complete the deep-link mission, and why a nudge's small window does not count as "keep watching in PIP". A start path that registered no player completes nothing (and says so in the log) — better not done than done wrongly.

> All of this rests on the sender being the object the app holds. On iOS, view controller sessions get that from `DemoPlayerDelegate.adopt(_:)`, because the SDK names its inner view as `player` ([Known Issues](known-issues.md#the-delegates-player-is-not-your-view-controller-ios), measured on the simulator). ⚠️ **Unverified on a device:** for the feed, that `player` is the view `EmbeddedPlayerView.player` returns — it is on the 3.0.4 simulator ([Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) i2). Android rests on the same premise for the player `ShoplivePlayerLauncher.start` returns (a4).

Implementation: [`MissionProgress`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/MissionProgress.kt) on Android, the `MissionProgress` class in [`MissionCatalog.swift`](../iOS/ShopliveOnboardingDemo/Support/MissionCatalog.swift) on iOS. The player signals come from the delegate together with the player that sent them — `onMilestone(milestone, player)` on Android, `DemoPlayerDelegate.observeMilestones(of:)` on iOS ([Mission 6](mission-06-events-products-coupons.md)).

### Progress survives the renumbering

Progress is stored as **mission identifiers**, not numbers — `player`, `nudge`, `pip`, `deeplink`, `user`, `events`, `inline`, `ui`, `studio` — under the same key on both platforms, `demo.completedMissionIds` (iOS `UserDefaults`, Android `SharedPreferences` file `shoplive_demo_progress`). A record from the 8-mission version (numbers 1–8) is migrated once on first launch — 1→player, 2→deeplink, 3→user, 4→inline, 5→pip, 6→events, 7→ui, 8→studio — and the old key is removed. A value that names no mission is dropped and logged. The nudge-style preview is new, so it starts not done.

> **Why this matters to you:** on iOS, "playback reached" is judged from `playback(STARTED/RENDERING)` and **not** from `stateChanged(.playing)` — because on the measured build `stateChanged` never fires during a healthy session. If your own app gates its UI on `stateChanged` alone, it will wait forever. Details in [Known Issues](known-issues.md#statechanged-never-fires-ios).

---

## 2.4 V1 — the developer sheet

Open it with the **⌗** button. Two tabs:

**Log tab.** Every SDK interaction, in order, tagged by direction:

| Tag | Meaning |
|---|---|
| `→SDK` | Your app called the SDK |
| `EVENT` | The SDK notified you (`didReceive` / `onEvent`) |
| `REQUEST` | The SDK asked you something and **needs a response** |
| `ERROR` | An error |

Reading a session top-to-bottom in this tab is the fastest way to understand the SDK's event model. The log is intentionally **English-only on both platforms** — it mirrors API names, and it gets pasted into bug reports.

**Options tab.** One control for **every public field** of `ShoplivePlayerConfiguration`, plus the runtime-only controls. Because configuration is immutable once playback starts, the tab has a **"Play again with these options"** button — that's the honest way to apply a configuration change. Fields whose behavior isn't yet wired end-to-end are flagged with a warning right in the UI.

Runtime controls (`isMuted`, `resizeMode`, `overlayUI`, `reload()`, `send()`, PIP enter/exit) act on the **live player handle**, not on configuration. Android keeps that handle in [`ShoplivePlayerSession.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerSession.kt) — a small object worth reading, because it demonstrates that full-screen and embedded players implement the *same* `ShoplivePlayerControlling` contract.

> ⚠️ **The sheet cannot appear over the SDK's player.** On Android the player is an SDK-owned Activity, so a Compose bottom sheet from the demo app sits behind it. Logs keep accumulating; you read them after coming back. On iOS the player is a view controller the demo subclasses, so **⌗ Developer** sits on top of it and opens the sheet from the player — see [§2.5](#25-the-ios-player-and-its-demo-controls).

---

## 2.5 The iOS player and its demo controls

On iOS the demo's cards present `DemoPlayerViewController`, a subclass of `ShoplivePlayerViewController` ([`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift)), **directly**, with two extra buttons on top: **‹ List** and **⌗ Developer**.

There are two concrete reasons, and both are worth copying if your app has similar needs:

1. **Escape hatch.** If a stream fails to resolve, the overlay web view never loads — and the SDK's own close button lives *in* that overlay. Without an app-owned button the user is trapped on a black screen. The view's subviews are ordered `[SDK player view, controls]`, so the controls always win hit-testing no matter what the SDK puts inside its own view.
2. **A subclass, not a child.** The SDK takes its modal down on in-App PIP only when the player is itself the presented modal. Embedded as a child it leaves a black full-screen modal that swallows every touch. Presented directly, the modal goes down on PIP — the mission list behind it is usable — and comes back on return, controls included. See [Mission 3](mission-03-pip.md) and [Known Issues](known-issues.md#embedding-the-player-as-a-child-breaks-in-app-pip-ios). ⚠️ *Unverified on a real device.*

With *start in PIP* on, the card presents nothing and the demo holds the player itself until `.closed` (`keepAliveUntilClosed()`) — with `pip.isInAppPipEnabled` off it presents normally. The developer sheet's PIP toggle closes the sheet first, then enters PIP, and its `reload()` is skipped during PIP.

---

## 2.6 Localization

Both apps ship **English (default) · 한국어 · 日本語**.

| | iOS | Android |
|---|---|---|
| Files | `Resources/{en,ko,ja}.lproj/Localizable.strings` (134 keys each, 2026-11-04) | `values/`, `values-ko/`, `values-ja/` (184 keys each, 2026-11-04) |
| Lookup | `L("key")` — [`DemoStrings.swift`](../iOS/ShopliveOnboardingDemo/Support/DemoStrings.swift) | `stringResource(R.string.…)` |
| Mission numbers in text | `%d`, filled from the catalog position (`MissionCatalog.number(of:)`) | `%d`, filled from `MissionId.displayNumber` |
| Language selection | **Does not follow the device** — an in-app segmented control, persisted; see [`DemoStrings.swift`](../iOS/ShopliveOnboardingDemo/Support/DemoStrings.swift) | **Does not follow the device** — an in-app segmented control, persisted; see [`LocaleSetting.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/LocaleSetting.kt) |

No string carries a mission number or the total count as text — those are `%d` arguments, so renumbering the catalog cannot leave a stale number behind. `python3 scripts/format_args_check.py` checks that every language has the same keys and placeholders and that every call site passes as many arguments as the string has placeholders.

Both apps (and the Flutter demo) deliberately ignore the device language so that one build can be demoed in all three languages from a single device. On Android it uses its own setting plus `attachBaseContext` rather than Android 13+ per-app languages, so behavior is identical down to minSdk 24.

**Two things localization does not reach:**

- **Anything the SDK draws.** The player overlay and studio don't pass through your app's context; their copy comes from the SDK and the server. Your app UI can be in English while the chat UI shows the device language.
- **The developer log**, as noted above — English by design.

---

## 2.7 Suggested walkthrough order

If you're evaluating the SDK for the first time, this order builds understanding fastest:

1. **Mission 1** — see that playback works at all, and how few lines it took.
2. **Mission 6** with the Log tab open — this is the one that teaches you the event model. Everything else is easier afterwards.
3. **Mission 5** — decide which authentication approach your app will use.
4. **Mission 7** — decide whether you need inline previews (native or hybrid), which changes your layout work substantially.
5. **Missions 2, 3, 4, 8** — polish: inviting viewers in, background viewing, entry points, branding.
6. **Mission 9** — only if your product broadcasts.

---

[◀ Getting Started](01-getting-started.md) · [Docs home](../README.md) · Next: [Architecture & Copy Boundary ▶](03-architecture.md)
