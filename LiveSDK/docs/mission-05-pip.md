# Mission 5 — Keep Watching in PIP

[◀ Mission 4](mission-04-embed-in-your-screen.md) · [Docs home](../README.md) · Next: [Mission 6 — Events, products, coupons ▶](mission-06-events-products-coupons.md)

> **Guide cross-reference:** [Mission 5 · Applying PIP](https://sdk.shoplive.cloud/#m5) · [PlayerConfiguration fields](https://sdk.shoplive.cloud/#f-playerconfig)
>
> **Source:** [`ShopliveIntegration/PipOptions.swift`](../iOS/ShopliveIntegration/PipOptions.swift) · [`sdk/PipOptions.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PipOptions.kt)
>
> **In the app:** card ⑤ — *"Keep watching in PIP"*. During playback, tap a product and the stream continues in a small window.

---

## What you're building

Playback that survives the user going somewhere else — a product page, another screen, or another app. In live commerce this is the difference between "watched and bought" and "left and never came back".

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
PlayerSession.enterPictureInPicture()
PlayerSession.exitPictureInPicture()
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

With `.pip`, the SDK performs `enterPictureInPicture()` internally when a product tap navigates away. **That is the behavior card ⑤ demonstrates** — "tap a product → small window" is this one field, not app code.

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
// In your delegate:
case .stateChanged(let state):
    onPipStateChanged?(state == .inAppPIP)

// In the host:
func setPipPresentation(_ isPip: Bool) { /* hide/show the host */ }
```

Now the mission list is visible behind the floating PIP window — the correct UX.

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

Card ⑤ starts full-screen playback with the Options tab's PIP settings applied. Because `actionOnNavigation` defaults to PIP behavior in the demo config, tapping a product in the overlay both opens the product detail screen and shrinks the player.

The "done" badge lights up on `stateChanged(.inAppPIP)` / `IN_APP_PIP` — one of the two missions not gated on `playback(started)`.

**Worth trying:** in the Options tab, set `pipPadding` to 0 and replay to see the clipping problem, then set `scale` very small and replay. Both are one-field changes that visibly matter.

---

[◀ Mission 4](mission-04-embed-in-your-screen.md) · [Docs home](../README.md) · Next: [Mission 6 ▶](mission-06-events-products-coupons.md)
