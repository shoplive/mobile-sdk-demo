# 2. Demo App Tour

[◀ Getting Started](01-getting-started.md) · [Docs home](../README.md) · Next: [Architecture & Copy Boundary ▶](03-architecture.md)

> **Guide cross-reference:** [Screen terminology](https://sdk.shoplive.cloud/#screens) · [Player screen](https://sdk.shoplive.cloud/#screens-player) · [Studio screen](https://sdk.shoplive.cloud/#screens-streamer) · [Checking things with the demo app](https://sdk.shoplive.cloud/#demo)

The demo app is not a showcase — it's a **worksheet**. Each of the eight cards runs one real SDK feature and tells you which file produced it. This page explains the screens so that when you tap something, you know what you're looking at.

---

## 2.1 The five screens

Both platforms implement the same five surfaces. The prototype codenames (S1, S2, S3, V1, V2) appear in source comments, so they're worth knowing.

| | Screen | Who draws it | iOS | Android |
|---|---|---|---|---|
| **S1** | Start — pick a mode, enter keys | Demo app | [`StartViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/StartViewController.swift) | [`StartScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/start/StartScreen.kt) |
| **S2** | Mission list — 8 cards | Demo app | [`MissionListViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/MissionListViewController.swift) | [`MissionListScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/missions/MissionListScreen.kt) |
| **S3** | Player / studio | **The SDK** | + [`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift) | SDK Activity |
| **S3′** | Home feed (embedded player) | Demo app | [`FeedDemoViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/FeedDemoViewController.swift) | [`FeedScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/feed/FeedScreen.kt) |
| **V1** | Developer sheet — Log / Options | Demo app | [`DevSheetViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/DevSheetViewController.swift) | [`DevSheet.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/devtools/DevSheet.kt) |
| **V2** | Product detail | Demo app | [`ProductDetailViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/ProductDetailViewController.swift) | [`ProductDetailScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/product/ProductDetailScreen.kt) |

**The important line is between S2 and S3.** Everything up to the mission list is your app. The moment playback starts, the screen belongs to the SDK — it renders the video, the chat, the LIVE badge, the product banner, the share and PIP buttons, and the close button. You do not build any of that.

---

## 2.2 S1 — two modes

| Mode | What it does |
|---|---|
| **Take a tour** | Uses the demo keys baked into the build. No typing. Enabled only when those keys are present. |
| **Use my account** | You type your own `accessKey` + `campaignKey` (and optionally a stream token). |

On relaunch the app skips S1 and re-enters the last mode used, so you don't retype keys every run.

Android's start screen also carries the **English / 한국어 / 日本語** language selector — see [§2.6](#26-localization).

---

## 2.3 S2 — the mission list

Each card shows four things:

```
┌────────────────────────────────────────────────┐
│ ①  Open the player                    ✔ done   │
│     Tap to open a full-screen live stream.     │
│     ✅ Plays within 2–3s · chat and LIVE badge │
│     📄 ShopliveIntegration/PlayerLauncher.swift│
└────────────────────────────────────────────────┘
```

1. **Number and title** — the number is the same Mission number used in [the integration guide](https://sdk.shoplive.cloud/#m1) and in these docs.
2. **What it does.**
3. **Checkpoint** — what you should see if it worked.
4. **📄 Source path** — the file that produced the behavior. This path is the only bridge between the running app and the code, and it is kept in sync with the real file location deliberately ([`MissionCatalog.swift`](../iOS/ShopliveOnboardingDemo/Support/MissionCatalog.swift), [`Missions.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/Missions.kt)).

**Tapping a card runs the mission immediately.** There is no detail screen in between.

### The "done" badge is not a checkbox

You cannot mark a mission complete yourself. The badge appears only when an SDK event proves the feature worked:

| Proof | Marks complete |
|---|---|
| `playback(started)` — playback actually reached first frame | Missions 1, 2, 3, 4, 7 |
| `stateChanged(.inAppPIP)` / `IN_APP_PIP` | Mission 5 |
| A `navigation` or `coupon` **request** arrived | Mission 6 |
| `StreamerEvent.stateChanged(LIVE)` | Mission 8 |

Implementation: [`MissionProgress`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/MissionProgress.kt) on Android, the `MissionProgress` class in [`MissionCatalog.swift`](../iOS/ShopliveOnboardingDemo/Support/MissionCatalog.swift) on iOS.

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

Runtime controls (`isMuted`, `resizeMode`, `overlayUI`, `reload()`, `send()`, PIP enter/exit) act on the **live player handle**, not on configuration. Android keeps that handle in [`PlayerSession.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt) — a small object worth reading, because it demonstrates that full-screen and embedded players implement the *same* `ShoplivePlayerControlling` contract.

> ⚠️ **The sheet cannot appear over the SDK's player.** On Android the player is an SDK-owned Activity, so a Compose bottom sheet from the demo app sits behind it. Logs keep accumulating; you read them after coming back. On iOS the demo works around this by hosting the player as a child view controller so it can put sibling controls on top — see [§2.5](#25-the-ios-player-host).

---

## 2.5 The iOS player host

On iOS the demo doesn't present `ShoplivePlayerViewController` directly. It wraps it in `PlayerHostViewController` ([`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift)) and adds two sibling buttons: **‹ List** and **⌗ Developer**.

There are two concrete reasons, and both are worth copying if your app has similar needs:

1. **Escape hatch.** If a stream fails to resolve, the overlay web view never loads — and the SDK's own close button lives *in* that overlay. Without a host-owned button the user is trapped on a black screen. The host's subviews are ordered `[player.view, controls]`, so the controls always win hit-testing no matter what the SDK puts inside `player.view`.
2. **PIP hand-off.** When the player promotes to in-app PIP, the render surface moves to a floating container over the app window and the original full-screen view is left empty. Leave the host visible and the user sees a black screen with a small PIP window on top of it. The host is presented `.overFullScreen` and hides itself on `stateChanged(.inAppPIP)`. See [Mission 5](mission-05-pip.md).

---

## 2.6 Localization

Both apps ship **English (default) · 한국어 · 日本語**.

| | iOS | Android |
|---|---|---|
| Files | `Resources/{en,ko,ja}.lproj/Localizable.strings` (107 keys each) | `values/`, `values-ko/`, `values-ja/` (159 keys each) |
| Lookup | `L("key")` — [`DemoStrings.swift`](../iOS/ShopliveOnboardingDemo/Support/DemoStrings.swift) | `stringResource(R.string.…)` |
| Language selection | Follows the device (ko/ja recognized, everything else falls back to en) | **Does not follow the device** — an in-app segmented control, persisted; see [`LocaleSetting.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/data/LocaleSetting.kt) |

Android deliberately ignores the device language so that one build can be demoed in all three languages from a single device. It uses its own setting plus `attachBaseContext` rather than Android 13+ per-app languages, so behavior is identical down to minSdk 24.

**Two things localization does not reach:**

- **Anything the SDK draws.** The player overlay and studio don't pass through your app's context; their copy comes from the SDK and the server. Your app UI can be in English while the chat UI shows the device language.
- **The developer log**, as noted above — English by design.

---

## 2.7 Suggested walkthrough order

If you're evaluating the SDK for the first time, this order builds understanding fastest:

1. **Mission 1** — see that playback works at all, and how few lines it took.
2. **Mission 6** with the Log tab open — this is the one that teaches you the event model. Everything else is easier afterwards.
3. **Mission 3** — decide which authentication approach your app will use.
4. **Mission 4** — decide whether you need the embedded player, which changes your layout work substantially.
5. **Missions 2, 5, 7** — polish: entry points, background viewing, branding.
6. **Mission 8** — only if your product broadcasts.

---

[◀ Getting Started](01-getting-started.md) · [Docs home](../README.md) · Next: [Architecture & Copy Boundary ▶](03-architecture.md)
