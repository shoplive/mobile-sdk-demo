# Known Issues, Measured Behavior & Troubleshooting

[◀ Platform Differences](platform-differences.md) · [Docs home](../README.md)

> **Guide cross-reference:** [Troubleshooting & FAQ](https://sdk.shoplive.cloud/#faq) · [Error handling](https://sdk.shoplive.cloud/#errors) · [Types & states](https://sdk.shoplive.cloud/#types)

Everything on this page was **observed by running the demo apps**, not inferred from documentation. Each entry says when it was measured and on what build, because several of these will change as the SDK moves.

**Test environments:**

| | Build | Environment | Date |
|---|---|---|---|
| iOS | `3.0.0`, from `dev` commit `5f0ee781` | Simulator, Xcode 26.6 | 2026-07-30 |
| Android | `3.0.0` | `sdk_gphone16k_arm64` · API 37 · 16 KB page image | 2026-07-30 |

---

## Contents

- [What definitely works](#what-definitely-works)
- [Event delivery gaps](#event-delivery-gaps)
- [Rendering & layout](#rendering--layout)
- [PIP behavior](#pip-behavior)
- [Where the guide and the API disagree](#where-the-guide-and-the-api-disagree)
- [Config fields with unverified runtime behavior](#config-fields-with-unverified-runtime-behavior)
- [Not yet verified](#not-yet-verified)
- [Troubleshooting by symptom](#troubleshooting-by-symptom)

---

## What definitely works

Worth stating plainly, since the rest of this page is problems.

**iOS** — the full path was confirmed end to end: `initialize` → campaign resolution → overlay web view load → `playback` / `error` delegate delivery, visible live in the developer sheet.

On campaign `8f595bd943cc` (15:45, 2026-07-30): `initialize` → embed → `playback(REQUEST → AUDIO_LOADED → STARTED → RENDERING…)` plus `connectionStateChanged(.connecting → .connected)`, with **zero errors** and real video on screen.

**A notable detail from that session:** the campaign's WebRTC egress was returning 404 while LL-HLS was healthy, and the SDK **silently played over HLS with no error event at all.** That matches the design intent — failover is deliberately not announced through public events — but it means you cannot infer engine health from your event stream.

At 20:29–20:33 the full-screen/embedded split was confirmed visually: the embedded view showed video only; full screen showed the whole overlay (logo, LIVE badge, share, PIP, product banner, likes, chat). `playback` 218 events, `error` **0**.

**On the SDK 3.0.0 rebuild (22:09, 2026-07-30)** — re-verified on the current default campaign `faea28dd96c3`: `Shoplive.sdkVersion` returns `3.0.0` (read from the developer sheet), playback sustained with the playhead advancing 10 s → 80 s at 1920×1080/60 fps, and **zero non-2xx responses** (8× `200`, 56× `206`). The outbound request also carries `x-sl-player-sdk-version=3.0.0`, which confirms the version reaches the network layer rather than just the public API.

> ⚠️ **That campaign currently serves Apple's public BipBop sample HLS**, not live commerce content. Playback is a clean 1080p60 VOD, so it is a good smoke test — but chat, product banners, coupons and the LIVE badge only appear during a real broadcast and **cannot be exercised with it.** Use an on-air campaign to check those.

**Android** — install and launch clean, no crashes, no `dlopen` failures, no native alignment errors (including arm64-v8a on the 16 KB page image). Boots in English regardless of device language; all three languages switch correctly. `initialize` → `start` → `stateChanged(LOADING)` → `analytics` → `playback` all delivered. `Toast` confirmed to render **over the SDK-owned player Activity**.

---

## Event delivery gaps

### `stateChanged` never fires (iOS)

**Status:** open · measured across three builds

The design spec says `stateChanged(ShoplivePlayerState)` reports the playback lifecycle. **It does not arrive during healthy playback.**

| Event | 15:45 (`b8591bde`) | 18:37 (`8d66bcd6`) | 20:33 (`dev 5f0ee781`) |
|---|---|---|---|
| `stateChanged` | **0** | **0** | **0** — still absent |
| `campaignStatusChanged` | 0 | 1 ✅ recovered | 2 ✅ |
| `campaignInfoReceived` | 0 | 1 ✅ recovered | 2 ✅ |
| `playback` · `connectionStateChanged` · `analytics` | normal | normal | normal (`playback` 218, `error` 0) |

`campaignStatusChanged` and `campaignInfoReceived` were fixed by the `8d66bcd6` "embedded path wiring" change — the overlay web view was their source. `stateChanged` is still missing.

**Knock-on effects:** `player.state` stays `.idle` forever, and `analytics` reports `isPlaying: false` / `durationMs: 0` because the adapter derives those from state.

**What to do in your app:** judge playback from **`playback(STARTED / RENDERING)`**, which does arrive reliably. This is exactly what [`DemoPlayerDelegate.swift`](../iOS/ShopliveIntegration/DemoPlayerDelegate.swift) does:

```swift
case .playback(let playback):
    if playback.event == .started || playback.event == .rendering {
        onPlaybackReached?()
    }
```

Without that, the demo's "verified" badge would never appear. **Never gate your UI on `stateChanged` alone.**

The one thing `stateChanged` *is* reliable for on iOS: `.inAppPIP` entry.

### No error event when a stream doesn't exist (Android)

**Status:** open · reported to the SDK team

Playing a campaign that isn't broadcasting produces a black player. The app and emulator are fine — **there is no stream.** What arrives:

```
playback(requested) → playback(failed(code: 404, message: 404))   ← repeats every ~5s
playback(ended) → stateChanged(IDLE) → stateChanged(CLOSED)
```

> **On the campaign key:** this was measured on `faea28dd96c3` while it had no stream. That campaign has since been repointed and **now plays normally** — re-measured on iOS at 22:09, zero 404s (8× `200`, 56× `206`), playhead advancing 10 s → 80 s. To reproduce the failure below you now need a different campaign that genuinely has no stream. The observations still stand as recorded; they have not been re-confirmed since the repoint.

**Three observations reported to the SDK team:**

1. **`ShoplivePlayerEvent.Error` never fires — not once** — even though 404s repeat and the session ends. This contradicts the design contract ("deliver `error(isRecoverable = false)` when a session ends unrecoverably"). An app subscribing only to `error` can never learn the stream is missing, and shows a black screen indefinitely.
2. **`campaignInfoReceived` and `campaignStatusChanged` also never fired**, so the app has no way to determine READY / LIVE / ENDED. (`analytics` does arrive, carrying the campaign key.)
3. Overlay web view console: `Uncaught TypeError: window.__receiveAppEvent is not a function` × 3.

**Workaround in the demo** — count `playback(failed)` yourself: `onRepeatedPlaybackFailure()` in [`DemoPlayerDelegate.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt). Two details matter:

- **A one-shot latch per session**, reset on `stateChanged(LOADING)` — otherwise you nag the user every 5 seconds.
- **A `Toast`, not a Snackbar** — the SDK's player Activity is in front, so Compose UI from your app is invisible.

Once the SDK delivers `error` properly, this workaround can be deleted.

### Error semantics wrong when a stream is missing (iOS)

**Status:** open

The same underlying situation, different symptom. On a campaign whose `campaignStatus` is `"ONAIR"` but whose egress endpoints all 404:

- `error(code: .unexpectedError, isRecoverable: false)` repeats **twice per second**, with no HLS fallback.
- The original connection code (`connection Issue [34]`) survives only inside the `message` string — it is **not preserved as an `ErrorCode`**, so you can't branch on it.
- It reports `isRecoverable: false` **while still retrying**, which contradicts the spec.

**Demo behavior:** don't close the player; explain the reason **once per session**; keep the host-owned **‹ List** button as the escape route.

---

## Rendering & layout

### `.fill` looks like `.fit` in the embedded view (iOS)

**Status:** open · **requires an SDK fix — no app-side workaround**

In the embedded box, `resizeMode = .fill` renders with side letterboxing, i.e. like `.fit`.

The value itself is forwarded correctly (`ShoplivePlayerView.swift:161` → `:202` `.setResizeMode`). The problem is the next step: `Core/ShopLivePlayerView/View/View + VideoGravity.swift:182` computes the video frame from **`UIScreen.main.bounds`** instead of the host view's bounds. So a 210 pt container receives a screen-sized frame, producing horizontal gaps.

The demo leaves this visible rather than hiding it. **Don't design an iOS layout that depends on true `.fill` inside a small embedded box yet.**

### Black screen with no way out

**Status:** mitigated in the demo — worth copying

If the stream fails to resolve, the overlay web view never loads — and the SDK's own close button lives inside that overlay. The user is stranded on a black screen.

**Mitigation** ([`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift)): host the SDK player as a **child view controller** and add **‹ List** / **⌗ Developer** as sibling views. The host's subviews are ordered `[player.view, controls]`, so the controls always win hit-testing — whatever the SDK adds internally is inside `player.view` and can't beat that ordering.

**If you ship a full-screen player, give the user an app-owned exit.** Don't rely solely on the SDK's close button.

### Embedded view isn't forced to video-only (iOS)

**Status:** open · mitigated in the demo

Design spec §3.4 says the View approach is video-only with `overlayUI` pinned to `.hidden`, but **the SDK doesn't enforce it** — the setter accepts `.builtIn`. The result (measured) is a full-screen-sized overlay drawn shrunken inside a 210 pt box.

**Mitigation:** assign `player.overlayUI = .hidden` explicitly right after `play()`. Keep that line when you copy [`EmbeddedPlayerView.swift`](../iOS/ShopliveIntegration/EmbeddedPlayerView.swift).

> **Caveat on our own measurement:** because the demo sets *both* the `.preview` configuration (which includes `overlay.ui = .hidden`) and the runtime property, we have **not isolated** whether the embedded overlay is hidden by the configuration path or the runtime path. Both are set deliberately, so the outcome is correct, but the attribution is unconfirmed.

### Playback breaks on scroll in lazy containers

**Status:** by design — plan around it

`ShoplivePlayerView` releases resources on detach from the window. Lazy containers (`LazyColumn`, recycling collection views) dispose of off-screen items, so **scrolling alone interrupts playback.**

The demo feed uses `Column + verticalScroll` instead. There is no "stay alive while detached" option. See [Mission 4](mission-04-embed-in-your-screen.md#-do-not-put-the-player-in-a-lazycolumn--uicollectionview-cell).

---

## PIP behavior

### The full-screen host must step aside (iOS)

**Status:** mitigated in the demo — copy this

On promotion, the render surface moves to a floating container over the app window and **the original full-screen view is left empty.** Leave it visible and the user sees a black screen with a small PIP window on top. (This was a real user report.)

**Mitigation, four parts:**

1. Present the host `.overFullScreen`, **not** `.fullScreen` — `.fullScreen` detaches the presenter's view, so hiding your host reveals nothing.
2. On `stateChanged(.inAppPIP)`, call `PlayerHostViewController.setPipPresentation(true)` to hide the host. Now the list screen shows behind the floating window.
3. **Do not treat every non-`.inAppPIP` state as "returned from PIP"** — see the next entry. `.closed` means the session ended, and restoring the host on it is a bug.
4. **Poll `isInPictureInPicture` every 0.5 s as a safety net**, and have the poll bail out once the session is closed.

### Closing the PIP window flashes the host (iOS)

**Status:** fixed in the demo — the fix is in the copy-target layer, so copy it

**Symptom:** with the player in PIP, tapping the PIP window's close button covered the whole screen in black for a moment before it slid away.

**Cause:** `stateChanged(.closed)` is what arrives when the PIP window is closed — the session ends, it is *not* a PIP-exit. A delegate that collapses the state into a boolean (`onPipStateChanged(state == .inAppPIP)`) reports `false`, the stepped-aside host un-hides itself over a player that no longer has a render surface, and the host's own black background covers the screen until the dismissal finishes.

Measured at the moment of close: `inPip=false state=closed hostDismissing=true` — **the SDK dismisses the host itself**, so the host only needed to stay out of the way.

**Fix:** route session end and PIP-exit apart. `ShopliveIntegration/DemoPlayerDelegate.swift` now sends `.closed` to a separate `onSessionClosed` hook, and the host latches it so no in-flight restore can un-hide it. Deliberately it does **not** change `isHidden` — closing from full screen must keep the normal slide-down animation, and in both paths the visibility is already correct.

Verified: closing from PIP produces **no un-hide at all**, while tapping the PIP window to return still restores the host.

### What `stateChanged` actually delivers (iOS)

Correcting an earlier claim on this page that it fires "only on `.inAppPIP` entry". Observed states, PIP session:

| State | Fires? |
|---|---|
| `.inAppPIP` | ✅ on promotion |
| `.playing` | ✅ on returning from PIP to full screen |
| `.closed` | ✅ on session end, including closing the PIP window |

What still does **not** arrive is `stateChanged` during the initial playback ramp-up — see [above](#statechanged-never-fires-ios). So `stateChanged` is usable for PIP and teardown transitions, but not as a "playback has started" signal.

### PIP padding default clips the window

**Status:** cosmetic, easily avoided

`pip.padding = 0` (the spec default) pins the PIP window flush to the right and bottom edges, overlapping the home indicator so it looks clipped. The iOS demo raises its own default to `12`. Set it back to 0 in the Options tab to see the difference.

---

## Where the guide and the API disagree

These integration-guide examples **do not compile** against the current binaries. The demo is written against the real API.

| Guide says | Reality |
|---|---|
| `Shoplive.setUser(nil)` to log out | `setUser` is **non-optional**. Use `Shoplive.logout()` |
| `.profile(..., custom: ["grade": "vip"])` | **No `custom` parameter on iOS.** `rank: Int?` exists instead |
| `ShoplivePlayerView()` | `init(configuration:)` is **required** (no-arg and storyboard paths are sealed) |
| `respond(.success)` | Construct the full `ShopliveCouponResult(couponId:success:message:status:alertType:)` |
| Compare `playback(let pb)` with `pb != .rebuffering` | `PlaybackEvent` is a **class**; read state from `pb.event` (`PlaybackEventType`) |
| `ShopLiveAnalyticsInfo` / `ShopLivePlayerCampaign` | `ShopliveAnalyticsInfo` / `ShopliveCampaign` (lowercase `l`) |
| `playerView.expandToFullScreen()` | **Does not exist on iOS** (Android only) |
| `appearance.allowScreenCapture` default `false` | Implementation default is **`true`** — the guide is the item to correct |
| Mission 8 locked only in own-account mode | **Locked whenever no stream token is present** — you can't broadcast without one |

Also removed from the iOS public surface (referencing them is a compile error): `PipOptions.keepWindowStyleOnReturnFromOSPip`, `PipOptions.autoEnterOnLeaveScreen`, `AppearanceOptions.isStatusBarVisible`, and the Streamer's `ShopliveAppearanceOptions`.

---

## Config fields with unverified runtime behavior

On the earlier `8d66bcd6` build, six configuration fields stored a value but had **no consumer**. On `dev 5f0ee781` all six are now wired — here is the code evidence:

| Field | Wiring point |
|---|---|
| `overlay.ui` | `PublicSurface/ShoplivePlayerView.swift:160` → `_overlayUI` |
| `pip.isOSPipEnabled` | `Core/Adapter/ConfigurationBridge.swift:43` (implemented 2026-07-30) |
| `navigation.shareScheme` | `ShoplivePlayerView.swift:157` → `engine.action(.setShareScheme)` |
| `appearance.allowScreenCapture` | `ConfigurationBridge.swift:38` → `ScreenCaptureGuard` (implemented 2026-07-30) |
| `ShoplivePlayOptions.referrer` | `ShoplivePlayerView.swift:156` → `engine.action(.setReferrer)` |
| `ShoplivePlayOptions.keepWindowStateOnPlayExecuted` | `ShoplivePlayerView.swift:92` |

> ⚠️ **This evidence is static — code reading only.** Whether each field actually produces the intended behavior has **not been measured**. `allowScreenCapture` (capture blanking) and `isOSPipEnabled` (skipping OS PIP registration) are especially hard to check in a simulator and need real-device verification.

The demo's Options tab flags fields in this state inline, rather than presenting them as fully working.

---

## Not yet verified

Honest gaps. Real-device verification is required before these can be called done.

**Both platforms**

- Broadcast start (Mission 8) and the camera/microphone permission flow — emulator camera limitations block this
- `allowScreenCapture` actually blanking screenshots and mirroring
- `isOSPipEnabled = false` actually skipping OS PIP registration

**Android (needs a campaign that plays)**

- Real playback start (2–3 s), chat and LIVE badge
- in-app PIP staying **above** the product detail Activity
- `navigation(url)` → product detail routing
- Whether `sound.muteOnStart = true` reproduces the PIP bounce
- Perceived reload cost when promoting embedded → full screen

**iOS**

- Whether the embedded overlay is hidden by the configuration path or the runtime path (both are set — see above)

---

## Troubleshooting by symptom

| Symptom | Most likely cause |
|---|---|
| **Nothing happens on tap (Android)** | Context isn't an Activity. `ShoplivePlayer(context)` needs a `LifecycleOwner`; `applicationContext` is refused with only a logcat warning |
| **`notInitializedAccessKey` / `NOT_INITIALIZED_ACCESS_KEY` (9000)** | Playback called before `initialize`. Common on a deep-link cold start — move `initialize` into `AppDelegate` / `Application.onCreate()` ([Mission 2](mission-02-deep-link.md)) |
| **No events arrive at all** | Nothing owns the delegate. It's weakly held (iOS) / instance-owned (Android). Hold it strongly ([Mission 1](mission-01-open-the-player.md)) |
| **Black player, no error** | Very likely no stream. Verify the campaign is on air; count `playback(failed)` yourself ([above](#no-error-event-when-a-stream-doesnt-exist-android)) |
| **"Verified"/playback-started never triggers (iOS)** | You're gating on `stateChanged`. Use `playback(started/rendering)` ([above](#statechanged-never-fires-ios)) |
| **Playback stops when I scroll** | The player is in a lazy container. Use a non-recycling layout ([Mission 4](mission-04-embed-in-your-screen.md)) |
| **Screen goes black when PIP starts (iOS)** | The host is still visible. Present `.overFullScreen` and hide it on `.inAppPIP` ([above](#the-full-screen-host-must-step-aside-ios)) |
| **Overlay popup won't close** | You didn't call `respond`. Every `coupon` / `customWebAction` requires it ([Mission 6](mission-06-events-products-coupons.md)) |
| **Tapping a product does nothing** | The `navigation` request isn't handled — the one request that's genuinely mandatory |
| **Coupon works but nothing shows on Android** | You used a Snackbar. The SDK's Activity is in front; use `Toast` |
| **Configuration change has no effect** | Configuration is immutable after playback starts. Replay with a new one ([Mission 7](mission-07-ui-customization.md)) |
| **Overlay mode won't change on Android** | The runtime `overlayUI` setter isn't wired yet. Replay with an `overlay.ui` configuration |
| **Broadcast starts with no audio** | Missing `RECORD_AUDIO`. It is **not** in the AAR — declare it yourself ([Mission 8](mission-08-go-live.md)) |
| **Studio fails to open** | Missing stream token. `setUser` does not grant broadcast permission — they're separate paths |
| **Broadcast permission lost after logout** | `logout()` clears `streamToken` too. Call `setStreamToken` again |
| **Swift 6 build error switching on an SDK enum** | Missing `@unknown default`. The SDK's enums are resilient ([Architecture §3.6](03-architecture.md)) |
| **Compile error on an old type name** | Every public type gained a `Shoplive` prefix in v3. See the [rename table](api-reference.md#v3-renames-ios-breaking) |
| **iOS device build: "requires a development team"** | Set `DEVELOPMENT_TEAM` in `Project.swift` (or pick a team in Xcode) and change the bundle ID |
| **Android: SDK artifacts won't resolve** | Maven credentials missing. Fill in `shoplive.maven.username` / `password` in `local.properties` |

---

## Reporting something new

Please include:

1. Platform and SDK build (`Shoplive.sdkVersion`)
2. Device/emulator and OS version
3. **The developer sheet log for the whole session** — it's English-only for exactly this reason
4. The campaign key and whether it was on air
5. For errors: `code`, `rawCode`, `isRecoverable`, and the full `message`

That last item matters because some causes survive only in the `message` string and never reach `ErrorCode` — see the iOS `connection Issue [34]` case above.

---

[◀ Platform Differences](platform-differences.md) · [Docs home](../README.md)
