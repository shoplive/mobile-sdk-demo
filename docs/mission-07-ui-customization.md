# Mission 7 — Customize the UI

[◀ Mission 6](mission-06-events-products-coupons.md) · [Docs home](../README.md) · Next: [Mission 8 — Go live ▶](mission-08-go-live.md)

> **Guide cross-reference:** [Mission 7 · UI customization & positioning](https://sdk.shoplive.cloud/#m7) · [PlayerConfiguration fields](https://sdk.shoplive.cloud/#f-playerconfig) · [PlayOptions fields](https://sdk.shoplive.cloud/#f-playoptions) · [Customer-configured items](https://sdk.shoplive.cloud/#customer-config)
>
> **Source:** [`ShopliveIntegration/PlayerConfigurationFactory.swift`](../iOS/ShopliveIntegration/PlayerConfigurationFactory.swift) · [`sdk/PlayerConfigurationFactory.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerConfigurationFactory.kt)
>
> **In the app:** card ⑦ — *"Customize the UI"*. Opens the Options tab automatically. Change colors and the overlay, then replay.

---

## What you're building

Making the player look like *your* product — brand colors, fonts, loading indicator — and, if you need to go further, hiding the built-in overlay entirely and drawing your own UI from delegate data.

**Checkpoint:** your color is applied, and events still arrive when the overlay is hidden.

---

## First: the three-lifetime rule

Before touching any field, get this straight. It explains almost every "I changed it and nothing happened" report.

| | `ShoplivePlayerConfiguration` | `ShoplivePlayOptions` | Runtime properties |
|---|---|---|---|
| What it is | Policy for a playback session | Values for one `play`/`start` call | Live handle properties |
| Set it | Before playback starts | At each play call | Any time during playback |
| Change it mid-playback? | **No — ignored** | n/a | **Yes** |
| Examples | PIP, sound, colors, overlay mode, navigation | `referrer`, `keepWindowStateOnPlayExecuted` | `isMuted`, `resizeMode`, `overlayUI` |

**Configuration is immutable once playback begins.** On Android every field is a `val` and post-start assignment is ignored with a warning in the log. To see a different configuration, you **replay** with a new one — which is exactly why the demo's Options tab has a **"Play again with these options"** button instead of pretending live edits work.

Progressive disclosure is the design principle here: every field has a working default, so `ShoplivePlayerConfiguration()` alone plays correctly and you override only what you care about.

---

## Approach ① — Standard appearance options

The 90% case. Swap in your brand color and fonts, keep everything else.

### iOS

```swift
static func branded(indicatorColor: UIColor,
                    chatInputFont: UIFont? = nil,
                    chatSendButtonFont: UIFont? = nil) -> ShoplivePlayerConfiguration {
    var config = ShoplivePlayerConfiguration()
    config.appearance.indicatorColor      = indicatorColor
    config.appearance.chatInputFont       = chatInputFont
    config.appearance.chatSendButtonFont  = chatSendButtonFont
    return config
}
```

### Android

```kotlin
appearance = ShoplivePlayerConfiguration.AppearanceOptions(
    indicatorColor = options.indicatorColor.argb,
    loadingAnimation = R.drawable.ic_demo_loading,   // null = SDK default
    isStatusBarVisible = true,
    chatInputTypeface = Typeface.DEFAULT_BOLD,       // null = SDK default
    // false makes the SDK apply FLAG_SECURE — screenshots and mirroring go black
    allowScreenCapture = true,
)
```

### `allowScreenCapture` deserves a closer look

Setting it to `false` blocks screen capture — on Android via `FLAG_SECURE`, on iOS via an internal capture guard.

> ⚠️ Two things to know: the **actual implementation default is `true`** (the guide documents `false` — the guide is the one that's wrong, and it's flagged for correction). And on iOS this field's runtime behavior **has not been verified on a real device yet** — the wiring is confirmed by code reading only. See [Known Issues](known-issues.md).

### Appearance fields differ by platform

| Field | iOS | Android |
|---|---|---|
| `indicatorColor` | ✅ | ✅ |
| `allowScreenCapture` | ✅ | ✅ |
| `chatInputFont` / `chatInputTypeface` | ✅ `UIFont` | ✅ `Typeface` |
| `chatSendButtonFont` | ✅ | ✗ |
| `resizeMode` | ✅ (under `appearance`) | ✅ (runtime property) |
| `loadingAnimation` | ✗ | ✅ (`@DrawableRes`) |
| `isStatusBarVisible` | ✗ **removed** | ✅ |

Full list: [Platform Differences](platform-differences.md).

---

## Approach ② — Hide the built-in overlay, draw your own

When the standard options aren't enough, you can turn off the SDK's chat/product/coupon UI and build your own from the data your delegate receives.

### iOS

```swift
static func overlayHidden() -> ShoplivePlayerConfiguration {
    var config = ShoplivePlayerConfiguration()
    config.overlay.ui = .hidden
    return config
}
```

### Android

```kotlin
overlay = ShoplivePlayerConfiguration.OverlayOptions(
    ui = ShopliveOverlayUIMode.HIDDEN,
)
```

### The critical detail: `hidden` ≠ torn down

**`.hidden` turns off display only.** The overlay web view stays alive internally, because **it is the command channel**. That's why `navigation`, `coupon`, and `customWebAction` requests keep arriving at your delegate while nothing is drawn.

This is what makes the whole approach viable: you hide the SDK's chat and render your own, and product taps still reach your app. There is **no public mode that destroys the web view** — that only happens when the session ends.

So the recipe is:

1. `overlay.ui = .hidden`
2. Handle every request in your delegate ([Mission 6](mission-06-events-products-coupons.md)) — this is now mandatory, not optional, since there's no built-in UI to fall back on
3. Draw your own chat/product/coupon UI from that data
4. Use `send(command:payload:)` to push state back to the overlay

### Toggling the overlay mid-playback

`overlayUI` is also a runtime property, so you can flip it during a session:

```swift
static func applyRuntimeOverlay(_ mode: ShopliveOverlayUIMode, to player: ShoplivePlayerControlling) {
    player.overlayUI = mode
}
```

Historically this was the *only* way to hide the overlay, because older iOS builds didn't consume the `overlay.ui` configuration field at all. On the current build the configuration path **is** wired (`ShoplivePlayerView` reads `configuration.overlay.ui` on play), so use configuration for the initial state and keep the runtime property for genuine mid-playback toggles.

> ⚠️ **Android:** the runtime `overlayUI` setter is **not yet wired** in the current version, and on the embedded view it's pinned to `HIDDEN` regardless. To be sure a mode is applied on Android, replay with an `overlay.ui` configuration. Noted in [`PlayerSession.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt).

---

## Named presets by usage (iOS)

Rather than assembling policy by hand, the iOS SDK provides two named presets. Using them keeps intent visible at the call site.

```swift
static func fullScreenLive() -> ShoplivePlayerConfiguration {
    ShoplivePlayerConfiguration.live       // equals .init() — everything on
}

static func embeddedPreview() -> ShoplivePlayerConfiguration {
    ShoplivePlayerConfiguration.preview    // PIP off, overlay hidden, muted, fill
}
```

`.live` has the same *value* as `.init()`, but `PlayerConfigurationFactory.fullScreenLive()` at a call site says something `.init()` doesn't. The demo picks between them on a `Usage` axis in [`DemoConfigBuilder.swift`](../iOS/ShopliveOnboardingDemo/Support/DemoConfigBuilder.swift):

- `MissionListViewController`, deep links, PIP promotion → `.fullScreenLive`
- `FeedDemoViewController` embed → `.embeddedPreview`

Full comparison table in [Mission 4](mission-04-embed-in-your-screen.md#choosing-a-preset-for-the-embedded-slot).

On Android the equivalent axis is `ShoplivePlayerType.LIVE` / `PREVIEW` in the `type` field, which drives volume-key policy and received stream resolution.

> **Design note worth borrowing:** when the demo uses `.preview`, it deliberately **does not** paint the Options tab's manual overrides on top — only color and `customParameters`. Overriding a preset field-by-field destroys the meaning of the preset. Pick a preset *or* configure manually, not both.

---

## The other configuration groups

Everything not covered above, for orientation. Field-level details are in the [API Reference](api-reference.md#shopliveplayerconfiguration).

**`sound`**

| Field | iOS | Android |
|---|---|---|
| `muteOnStart` | ✅ | ✅ |
| `mixWithOthers` | ✅ | ✅ |
| `autoResumeOnCallEnded` | ✅ | ✗ |
| `autoResumeOnFocusGained` | ✗ | ✅ |
| `isVolumeKeyEnabled` | ✗ | ✅ (`null` → follows `type`: LIVE=true, PREVIEW=false) |

**`navigation`**

| Field | Purpose |
|---|---|
| `actionOnNavigation` | What happens to the player when a product tap navigates away — close, or PIP ([Mission 5](mission-05-pip.md)) |
| `shareScheme` | Your app's URL scheme, used by the overlay's share button |
| `closeWhenAppDestroyed` | Android only |

**`customParameters`** — extra query parameters appended to the overlay URL. This is your hook for passing app-specific context (store ID, A/B bucket, membership tier) to your overlay web content.

**`ShoplivePlayOptions`** — the per-playback pair:

| Field | Purpose |
|---|---|
| `referrer` | Traffic source. Essential for deep links — [Mission 2](mission-02-deep-link.md) |
| `keepWindowStateOnPlayExecuted` | Preserve window state across a `play` call |

---

## How the demo runs this mission

Card ⑦ starts playback and **auto-opens the Options tab**, which has one control for **every public configuration field** — including the ones that don't fully work yet, which are marked with an inline warning rather than quietly omitted. That honesty is the point: you can see the whole surface and what part of it is real.

The build path is [`DemoConfigBuilder.makeConfiguration(_:from:)`](../iOS/ShopliveOnboardingDemo/Support/DemoConfigBuilder.swift) on iOS and [`PlayerConfigurationFactory.from(options)`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerConfigurationFactory.kt) on Android. Note that this assembly code lives in the **harness**, not the copy-target layer — it exists only because the demo needs one control per field, and your app doesn't. For copy-ready examples, use `branded()` / `overlayHidden()` in [`PlayerConfigurationFactory.swift`](../iOS/ShopliveIntegration/PlayerConfigurationFactory.swift).

The "done" badge lights up on `playback(started)` after a replay.

**Worth trying:** set `overlayUI` to hidden and replay. The video keeps playing, the chat disappears — and the Log tab still shows `navigation` and `coupon` requests arriving. That's the "hidden ≠ torn down" rule you can see with your own eyes.

---

[◀ Mission 6](mission-06-events-products-coupons.md) · [Docs home](../README.md) · Next: [Mission 8 ▶](mission-08-go-live.md)
