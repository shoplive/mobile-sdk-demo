# Mission 2 — Nudge-Style Preview

[◀ Mission 1](mission-01-open-the-player.md) · [Docs home](../README.md) · Next: [Mission 3 — Keep Watching in PIP ▶](mission-03-pip.md)

> **Guide cross-reference:** [Mission 2 · Nudge-Style Preview](https://sdk.shoplive.cloud/#m2) · [Step 1 · Start with the preview preset](https://sdk.shoplive.cloud/#m2-preview) · [Step 2 · Pass configuration and start options as a pair](https://sdk.shoplive.cloud/#m2-pair) · [Preview and PIP](https://sdk.shoplive.cloud/#screens-preview-pip)
>
> **Source:** [`ShopliveIntegration/NudgePreview.swift`](../iOS/ShopliveIntegration/NudgePreview.swift) · [`integration/…/ShopliveNudgePreview.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveNudgePreview.kt)
>
> **In the app:** card ② — *"Nudge-Style Preview"*. A stand-in product page opens, and a muted small window floats over it. Tap the window and it grows to full screen.

---

## What you're building

A small, muted window over a screen the viewer is already using — a product page, the home screen — that invites them into a live they have **not** started watching. The screen underneath stays usable. Tapping the window grows the same session to full screen.

**A nudge is not PIP.** Both use the SDK's small floating window, but the purpose and the settings differ:

| | Nudge-style preview (this mission) | PIP ([Mission 3](mission-03-pip.md)) |
|---|---|---|
| Who it is for | A viewer who has not started watching | A viewer who is already watching |
| Stream | Preview stream (lower resolution) | Main stream |
| Sound · overlay | Muted · hidden | As the viewer had them |
| How it starts | In the small window, from the start | From full screen, or [started in PIP](mission-03-pip.md#starting-directly-in-pip-304) |

**Checkpoint:** the small window appears muted and without the overlay, the page underneath still scrolls, and tapping the window expands it to full screen (iOS 3.0.4+ also unmutes it).

---

## Two presets, passed as a pair

"Small window + muted + overlay hidden" is common enough that both SDKs ship it as constants. It takes **two** of them, because configuration and start options are separate:

| | iOS | Android | Decides |
|---|---|---|---|
| Configuration | `ShoplivePlayerConfiguration.preview` | `ShoplivePlayerConfiguration.PREVIEW` | preview stream · muted · overlay hidden |
| Start options | `ShoplivePlayOptions.preview` | `ShoplivePlayOptions.PREVIEW` | `presentationStyle = .pip` / `PIP` — start in the small window |

Pass only one and you get something else: the configuration alone plays a muted preview **full screen**; the options alone open a small window with the main stream, sound, and overlay.

### iOS

```swift
/// `ShoplivePlayerConfiguration.preview` with in-App PIP switched on explicitly.
static func presetConfiguration() -> ShoplivePlayerConfiguration {
    var configuration = ShoplivePlayerConfiguration.preview
    shopliveLog(.call, "ShoplivePlayerConfiguration.preview — preset pip.isInAppPipEnabled = \(configuration.pip.isInAppPipEnabled)")
    configuration.pip.isInAppPipEnabled = true
    return configuration
}

/// - beforePlay: runs with the new player right before `play` — register listeners and keep the
///   player here, or the first events (e.g. entering the small window) can arrive unobserved.
@discardableResult
static func start(campaignKey: String,
                  over presenter: UIViewController,
                  configuration: ShoplivePlayerConfiguration = presetConfiguration(),
                  delegate: ShoplivePlayerDelegate?,
                  beforePlay: (ShoplivePlayerViewController) -> Void = { _ in }) -> ShoplivePlayerViewController {
    let player = ShoplivePlayerViewController(campaignKey: campaignKey,
                                              options: .preview,
                                              configuration: configuration)
    player.delegate = delegate      // weak — the caller owns the delegate's lifetime
    beforePlay(player)
    player.play(campaignKey: campaignKey, options: .preview)
    return player
}
```

**Register your observers in `beforePlay`, before `play` runs** — a nudge reports its first events (entering the small window, playback) as soon as it starts, and a listener attached after `start` returns can miss them. The demo does its setup there: it registers the controller with `DemoPlayerDelegate.adopt(_:)` ([why](known-issues.md#the-delegates-player-is-not-your-view-controller-ios)), keeps the player, and subscribes to its milestones.

### Android

```kotlin
fun configuration(
    base: ShoplivePlayerConfiguration = ShoplivePlayerConfiguration.PREVIEW,
): ShoplivePlayerConfiguration = base.copy(pip = base.pip.copy(isInAppPipEnabled = true))

fun start(
    activity: Activity,
    campaignKey: String,
    session: Session,
    configuration: ShoplivePlayerConfiguration = configuration(),
): ShoplivePlayer {
    val player = ShoplivePlayerLauncher.start(
        activity = activity,
        campaignKey = campaignKey,
        delegate = session,
        configuration = configuration,
        options = ShoplivePlayOptions.PREVIEW,
    )
    session.adopt(player)
    return player
}

// usage — a new Session per start; it is the player's delegate and forwards everything to yours
val session = ShopliveNudgePreview.Session(myDelegate)
ShopliveNudgePreview.start(activity, campaignKey, session)
```

Android goes through `ShoplivePlayerLauncher`, so the nudge becomes the current `ShoplivePlayerSession` like any other session — and, as with any `start()`, closes another full-screen or PIP session that is open. The `Session` passed in is the nudge's delegate: it records what the nudge reports about itself and keeps the player (see below).

### Why `isInAppPipEnabled = true` is written out

The guide's prerequisite for this mission is `pip.isInAppPipEnabled = true`. If it were false, iOS would play **full screen instead of in the small window, without an error** (guide, Mission 3). On Android the 3.0.4 preset enables it already; on iOS the preset's value is not visible in the SDK interface, so `presetConfiguration()` logs it and then sets it. Start from the preset and change only what you need.

---

## Tapping the window — nothing for you to call

Expanding to full screen is the SDK's job. On iOS 3.0.4+ the expanded nudge also unmutes, and turns on OS PIP if `pip.isOSPipEnabled` is on. Do **not** call `isMuted = false`, `exitPictureInPicture()`, or start a second player on tap — the window you already have *is* the viewing session now.

---

## When to show it, and when to take it away

The SDK shows the window; your screen decides when. The demo follows the guide's recommendations ([Implementation Tip](https://sdk.shoplive.cloud/#tip-flow)):

| Situation | What the demo does | Reads |
|---|---|---|
| The host screen becomes visible | Start a nudge — unless this screen's nudge is still up | iOS `viewDidAppear` · Android `ON_RESUME` |
| Another session is playing (a PIP the viewer is watching, say) | **First visit** (the viewer just tapped the card): replace that session and start the nudge, like any card. **Later visits** (back from another screen, rotation): do not start the nudge — it would close a session the viewer is still watching — and only log it. Same rule on both platforms | iOS `MissionID.nudgeMayStart(isFirstAppearance:otherSessionInProgress:)` · Android `onHostVisible(…, isFirstVisit)` → `OTHER_SESSION_ONGOING` |
| The viewer closed it on this screen | **Do not show it again** on this screen instance | the close reason is `userAction` / `USER_ACTION` |
| It closed for another reason | Show it again | `appRequest`, `accessKeyChanged`, or no reason |
| The viewer leaves the screen, window still small | `close()` it — a preview the viewer never opened should not follow them around | close reason becomes `appRequest` / `APP_REQUEST` |
| The viewer leaves after expanding it | Leave it alone — it is a viewing session now. ⚠️ **Unverified on iOS:** who keeps the expanded player once the host screen is released (if nothing does, the session ends with it) — see [Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) | — |
| The campaign is not live | The guide recommends closing it. The demo makes that an Options-tab switch, `closeNudgeWhenNotLive`, **off by default** so upcoming and VOD campaigns can still be tried; a window the viewer expanded is never closed | `campaignStatusChanged` |

Android packages the decisions with the SDK calls: `ShopliveNudgePreview.onHostVisible(isShowing, lastCloseReason, otherSessionOngoing, isFirstVisit)` returns `START` / `ALREADY_SHOWING` / `OTHER_SESSION_ONGOING` / `CLOSED_BY_VIEWER`, and `onHostLeft(session)` closes a nudge that was never expanded. Both read `ShopliveNudgePreview.Session`, the delegate wrapper that records the facts they need — close reason, *was expanded*, campaign status — and **holds the player strongly until it reports `Closed`**: a weak reference could be cleared while the window is still up, and the page would then fail to close it on leaving. The window's lifetime is already the SDK's (and `ShoplivePlayerSession`'s) to hold, so this adds no longer-lived reference; after `Closed` only plain facts remain.

```kotlin
fun onHostVisible(
    isShowing: Boolean,
    lastCloseReason: ShopliveCloseReason?,
    otherSessionOngoing: Boolean,        // e.g. ShoplivePlayerSession.current is someone else
    isFirstVisit: Boolean,               // the viewer just opened the page from its card
): HostVisit = when {
    isShowing -> HostVisit.ALREADY_SHOWING
    otherSessionOngoing && !isFirstVisit -> HostVisit.OTHER_SESSION_ONGOING
    lastCloseReason == ShopliveCloseReason.USER_ACTION -> HostVisit.CLOSED_BY_VIEWER
    else -> HostVisit.START
}

fun onHostLeft(session: Session) {
    val player = session.player          // null once the session reported Closed
    when {
        player == null -> logEvent("nudge host left — the nudge had already closed")
        session.wasExpanded -> logEvent("nudge host left — the viewer expanded it, so it keeps playing")
        else -> player.close()           // APP_REQUEST
    }
}
```

On iOS the screen reads the same facts straight from its nudge (`closeReason`, `state`, `isInPictureInPicture`) — see [`NudgeProductViewController.swift`](../iOS/ShopliveOnboardingDemo/Screens/NudgeProductViewController.swift). Why a nudge closed is the 3.0.4 close reason described in [Mission 6](mission-06-events-products-coupons.md#why-the-player-closed-304).

---

## Platform notes

**iOS**

- **Hold the returned player strongly** while the host screen lives. A small window that is not presented has no other owner.
- The demo starts a nudge through the same "close the current session first" step as every other start path: iOS does not guarantee one session at a time, and a second floating window is refused (see [Mission 3](mission-03-pip.md)).
- ⚠️ **Unverified (i9):** whether a `.pip`-style player must also be `present`ed is not documented. `NudgePreview.start` only calls `play(campaignKey:options:)` and carries a `TODO(SDP-VERIFY)`; if a device run shows `present` is needed, that one function changes.
- ⚠️ **Unverified (i8):** the preset's own `pip.isInAppPipEnabled` value — read it from the `ShoplivePlayerConfiguration.preview — preset …` log line on a device.

**Android**

- The host decides *left for good* from the navigation entry's ViewModel being cleared (a pop), not from `onDispose` / `ON_STOP` — those also fire on rotation and when the SDK's full-screen Activity covers the page.
- The nudge's delegate is a fresh `ShopliveNudgePreview.Session` per nudge. The SDK holds its delegate strongly, so a per-session object keeps one nudge's facts from leaking into the next. The page keeps only the `Session` (in its navigation entry's ViewModel), and the `Session` keeps the player only until `Closed`.
- ⚠️ **Unverified (i5 · a3):** what the small window shows for a campaign that is not live (a waiting screen, or closing at once with which reason) is SDK behavior — measure it on both platforms. All markers: [Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code).

---

## How the demo runs this mission

Card ② opens a demo product page (a dedicated screen — not the product-detail screen that Mission 6's product taps land on) and starts the nudge over it with the two presets. The Options tab is **not** applied: a nudge is defined by its presets.

The "done" badge lights up when the **nudge's own player reaches playback** (`playback(started)`). Its small window entering in-App PIP is *not* credited to Mission 3.

**Worth trying:** close the window with ✕, go back, and open card ② again — a new screen instance shows it again. Then expand it, press back, and check the log: the expanded session keeps playing. Turn on `closeNudgeWhenNotLive` in the Options tab and open a campaign that is not live.

---

[◀ Mission 1](mission-01-open-the-player.md) · [Docs home](../README.md) · Next: [Mission 3 ▶](mission-03-pip.md)
