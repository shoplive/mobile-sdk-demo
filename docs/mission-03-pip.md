# Mission 3 — Keep Watching in PIP

[◀ Mission 2](mission-02-nudge-preview.md) · [Docs home](../README.md) · Next: [Mission 4 — Launch via Deep Link ▶](mission-04-deep-link.md)

> **Guide cross-reference:** [Mission 3 · Keep Watching in PIP](https://sdk.shoplive.cloud/#m3) · [Starting directly in PIP](https://sdk.shoplive.cloud/#m3-pipstart) · [PIP buttons](https://sdk.shoplive.cloud/#m3-buttons) · [ButtonOptions](https://sdk.shoplive.cloud/#f-button) · [PlayerConfiguration fields](https://sdk.shoplive.cloud/#f-playerconfig)
>
> **Source:** [`ShopliveIntegration/PipOptions.swift`](../iOS/ShopliveIntegration/PipOptions.swift) · [`integration/…/ShoplivePipPresets.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePipPresets.kt)
>
> **In the app:** card ③ — *"Keep Watching in PIP"*. During playback, tap a product and the stream continues in a small window. The Options tab can also start the card straight in the small window and swap the window's buttons (3.0.4+).

---

## What you're building

Playback that survives the user going somewhere else — a product page, another screen, or another app. In live commerce this is the difference between "watched and bought" and "left and never came back".

**PIP is for a viewer who is already watching.** A small window that invites someone who has *not* started watching looks the same but is a different feature with different settings — that is [Mission 2 · Nudge-style preview](mission-02-nudge-preview.md).

**Checkpoint:** the small window persists, and tapping it returns you to full screen without interrupting playback.

---

## Two kinds of PIP, and they behave differently

| | **in-app PIP** | **OS PIP** |
|---|---|---|
| Who owns it | The SDK — a floating window above your app window | The system (`Activity.enterPictureInPictureMode()` on Android) |
| Triggered by | You: `enterPictureInPicture()` | Automatically when the app backgrounds, if `pip.isOSPipEnabled` |
| Works with full screen | Yes | Yes |
| Works with embedded view | Yes | **No** |
| Scope | Within your app | Over the home screen and other apps |

**Why OS PIP can't work with the embedded view:** OS PIP shrinks the *entire host Activity*. That has no meaning for a view sitting inside your layout. So on Android, setting `isOSPipEnabled = true` on an embedded view simply has no effect.

---

## Configuration

### iOS

```swift
static func configuration(position: ShoplivePipPosition = .bottomRight,
                          scale: CGFloat = 0.4,
                          enableOSPip: Bool = true) -> ShoplivePlayerConfiguration {
    var config = ShoplivePlayerConfiguration()
    config.pip.isInAppPipEnabled = true
    config.pip.defaultPosition   = position
    config.pip.scale             = scale        // fraction of window width, 0...1
    config.pip.isOSPipEnabled    = enableOSPip
    return config
}
```

### Android

```kotlin
ShoplivePlayerConfiguration.PipOptions(
    isInAppPipEnabled = true,
    isOSPipEnabled = true,
    enterOSPipOnBackPressed = true,          // Android only
    defaultPosition = ShoplivePipPosition.BOTTOM_RIGHT,
    scale = 0.4f,
    aspectRatio = …,                         // Android only
    padding = ShopliveInsets.all(12),        // or ShopliveInsets(left, top, right, bottom)
)
```

**The defaults already work.** `ShoplivePlayerConfiguration.PipOptions()` with nothing specified gives you in-app + OS PIP both on, bottom-right, 9:16, at 40% of the screen. You only touch this to change the look.

> **One default worth overriding:** `pip.padding = 0` (the spec default) pins the PIP window flush to the right and bottom edges, where it overlaps the home indicator and looks clipped. The iOS demo raises the default to `12` (you can set it back to 0 in the Options tab).

---

## Control — identical for full screen and embedded

```swift
// iOS — ShoplivePlayerControlling, so this works for both the VC and the View
static func enter(_ player: ShoplivePlayerControlling) { player.enterPictureInPicture() }
static func exit (_ player: ShoplivePlayerControlling) { player.exitPictureInPicture() }
static func toggle(_ player: ShoplivePlayerControlling) {
    player.isInPictureInPicture ? exit(player) : enter(player)
}
```

```kotlin
// Android — same idea, via the shared handle
ShoplivePlayerSession.enterPictureInPicture()
ShoplivePlayerSession.exitPictureInPicture()
```

### You do not designate a target view

`enterPictureInPicture()` promotes the SDK's own internal render surface. There is no view reference, container, or frame to pass. This surprises people who expect to hand the SDK a destination — you don't, and you can't.

### Promotion requires four conditions, and failure is silent

1. Playback is active (a render surface exists)
2. `pip.isInAppPipEnabled == true`
3. The window to attach to resolves successfully
4. **No other instance is already floating** — only one in-app PIP can exist at a time, and an existing one is not evicted for you (ownership is checked)

If any condition fails, the call is **ignored with no error**. Confirm success by reading `isInPictureInPicture` or by waiting for `stateChanged(.inAppPIP)`.

---

## Automatic PIP on navigation

The most common real trigger isn't a button — it's the user tapping a product.

```swift
config.navigation.actionOnNavigation = .pip
```

```kotlin
navigation = ShoplivePlayerConfiguration.NavigationOptions(
    actionOnNavigation = ShopliveNavigationAction.PIP,
)
```

With `.pip`, the SDK performs `enterPictureInPicture()` internally when a product tap navigates away. **That is the behavior card ③ demonstrates** — "tap a product → small window" is this one field, not app code.

---

## Starting directly in PIP (3.0.4+)

Everything above moves a stream that is already playing into the small window. You can also skip full screen and **start** in it — for a viewer who came to watch (a push, a [deep link](mission-04-deep-link.md)) but should stay on the screen they are on. The viewer came to watch, so the main stream, sound, and overlay play as usual. It is a per-playback option, not a configuration field:

```swift
// iOS — PipSetup.applyStartStyle(_:to:configuration:)
var options = ShoplivePlayOptions()
PipSetup.applyStartStyle(.pip, to: &options, configuration: configuration)   // options.presentationStyle = .pip
player.play(campaignKey: campaignKey, options: options)
```

```kotlin
// Android — ShoplivePipPresets.startInPip(base)
ShoplivePlayerLauncher.start(
    activity = activity,
    campaignKey = campaignKey,
    delegate = delegate,
    options = ShoplivePipPresets.startInPip(),   // presentationStyle = PIP (default FULLSCREEN)
)
```

| | iOS | Android |
|---|---|---|
| Field | `ShoplivePlayOptions.presentationStyle` — `.fullScreen` (default) / `.pip` | `ShoplivePlayOptions.presentationStyle` — `FULLSCREEN` (default) / `PIP` |
| Needs | `pip.isInAppPipEnabled == true` | `pip.isInAppPipEnabled == true`, and `ShoplivePlayer.start()` |
| If in-App PIP is off | **Silently plays full screen** (guide) — `applyStartStyle` logs that combination | Not documented — `ShoplivePlayerLauncher.start` logs it as an error; **unverified on a device** |
| `intent()` | — | An Intent from `ShoplivePlayer.intent()` always opens full screen and ignores this |

Both platforms start in **in-App PIP** — the floating window the SDK owns.

---

## PIP window buttons (3.0.4+)

The in-App PIP window has a close button and a restore (back to full screen) button. You can swap the close button's image and hide the restore button. Without these settings the SDK's default buttons appear.

```swift
// iOS — PipSetup.applyButtons(closeImage:hideRestoreButton:to:)
PipSetup.applyButtons(closeImage: UIImage(systemName: "xmark.circle.fill"),
                      hideRestoreButton: true,
                      to: &configuration)
// → configuration.pip.closeButton = .init(image: …), configuration.pip.restoreButton = .init(isHidden: true)
```

```kotlin
// Android — ShoplivePipPresets.withButtons(pip, closeImageResId, hideRestore)
val pip = ShoplivePipPresets.withButtons(
    pip = ShoplivePlayerConfiguration.PipOptions(),
    closeImageResId = R.drawable.ic_demo_pip_close,   // a drawable from your app; null keeps the SDK image
    hideRestore = true,
)
```

`ButtonOptions` is `image: UIImage?` + `isHidden: Bool` on iOS and `imageResId: Int?` + `isHidden: Boolean` on Android. The Android helper takes the drawable id as a plain `Int` on purpose — `:integration` must not reference any app's `R` class. The iOS demo has no asset catalog, so it uses an SF Symbol where your app would use its own image.

---

## ⚠️ There is no "auto-PIP when the view leaves the screen"

`pip.autoEnterOnLeaveScreen` was **removed from the public surface** (on iOS it's one of three deleted fields; on Android it never shipped). Referencing it on iOS is a compile error.

The reason is structural: by the time a view's window becomes `nil`, the window to attach the floating container to is gone too, so promotion can't succeed. It couldn't be made reliable.

**So if you want that behavior, your app implements it** — watch scroll position or lifecycle and call `enterPictureInPicture()` yourself. The demo feed's **⤡** button marks exactly the spot where that call belongs.

---

## ⚠️ iOS: the full-screen host must step out of the way

This one produces a dramatic-looking bug, and it's worth understanding before you ship.

**What happens:** on promotion to PIP, the render surface moves to a floating container over the app window. **The original full-screen view is left with nothing in it.** Leave that view visible and the user sees the entire screen covered in black with a small PIP window floating on top.

**The fix, as implemented in [`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift):**

1. **Present the host as `.overFullScreen`, not `.fullScreen`.** `.fullScreen` detaches the presenter's view from the hierarchy, so hiding your host reveals nothing behind it.
2. **Hide the host when PIP is entered:**

```swift
// In your delegate (DemoPlayerDelegate) — one channel, always with the player that sent it:
case .stateChanged(let state):
    publish(.pipStateChanged(isActive: state == .inAppPIP), from: player)

// In the host — subscribe to *its own* player only, so a late event from an old session
// cannot hide or show a newer host:
milestoneObserver = DemoPlayerDelegate.observeMilestones(of: player) { [weak self] _, milestone in
    if case .pipStateChanged(let isActive) = milestone { self?.setPipPresentation(isActive) }
}
func setPipPresentation(_ isPip: Bool) { /* hide/show the host */ }
```

Now the mission list is visible behind the floating PIP window — the correct UX. `.closed` is a separate milestone (`PlayerMilestone.closed(reason:)`): closing the PIP window ends the session, which is *not* a return to full screen, so the host must not show itself again.

3. **Add a polling safety net for the return trip.** `stateChanged` may not fire when PIP exits, so the demo polls `isInPictureInPicture` every 0.5 s.

**Measured:** on the tested build, `stateChanged` fires **only on `.inAppPIP` entry** — not for playing/loading transitions. So `stateChanged` is reliable enough for detecting PIP entry, and nothing else. See [Known Issues](known-issues.md#statechanged-never-fires-ios).

---

## Platform-specific fields

Some PIP fields exist on one platform only. Reaching for the wrong one is a compile error, so check here first.

| Field | iOS | Android |
|---|---|---|
| `isInAppPipEnabled`, `isOSPipEnabled`, `defaultPosition`, `scale` | ✅ | ✅ |
| `padding` | ✅ `UIEdgeInsets` | ✅ `ShopliveInsets` |
| `floatingOffset`, `fixedWidth` | ✅ | ✗ |
| `enterOSPipOnBackPressed`, `aspectRatio` | ✗ | ✅ |
| `autoEnterOnLeaveScreen` | ✗ removed | ✗ |
| `keepWindowStyleOnReturnFromOSPip` | ✗ removed | ✗ |

Full list: [Platform Differences](platform-differences.md).

---

## Platform notes

**iOS**

- OS PIP for WebRTC campaigns uses **iOS 15+ only** APIs. The demo's deployment target is 15.0, so it's covered — check yours if you support iOS 14.
- `pip.isOSPipEnabled` had no consumer in older builds. On the current build it is wired (the configuration bridge forwards it, and the engine skips registering the OS PIP controller when false). **Real-device runtime behavior has not been measured yet** — flagged in [Known Issues](known-issues.md).

**Android**

- `enterOSPipOnBackPressed` sends the player to OS PIP on back-press instead of closing it. Nice touch for retention, worth enabling deliberately rather than by accident.

---

## How the demo runs this mission

Card ③ starts full-screen playback with the Options tab's PIP settings applied. Because `actionOnNavigation` defaults to PIP behavior in the demo config, tapping a product in the overlay both opens the product detail screen and shrinks the player.

The "done" badge lights up on `stateChanged(.inAppPIP)` / `IN_APP_PIP_ENTERED` — one of the missions not gated on `playback(started)`. The one exception is the small window of a **nudge preview** (Mission 2): a nudge player entering in-App PIP never counts — not while Mission 2 runs, and not later either (an expanded nudge shrunk back into PIP while another mission runs) — because a nudge is not PIP.

The Options tab's PIP group carries the 3.0.4 items:

| Option | iOS | Android |
|---|---|---|
| Start in the small window | `ShoplivePlayOptions.presentationStyle` (`fullScreen` ↔ `pip`) | `PlayOptions.presentationStyle` (`FULLSCREEN` ↔ `PIP`) |
| Window buttons | `pip.closeButton · restoreButton` (SF Symbol close image + hidden restore) | `pip.closeButton.imageResId`, `pip.restoreButton.isHidden` |

With *start in the small window* on, the card itself opens in PIP, so the badge lights up as soon as the window appears.

**Worth trying:** in the Options tab, set `pipPadding` to 0 and replay to see the clipping problem, then set `scale` very small and replay. Both are one-field changes that visibly matter.

---

[◀ Mission 2](mission-02-nudge-preview.md) · [Docs home](../README.md) · Next: [Mission 4 ▶](mission-04-deep-link.md)
