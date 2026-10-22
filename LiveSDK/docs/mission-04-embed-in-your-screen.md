# Mission 4 — Embed in Your Screen

[◀ Mission 3](mission-03-user-identity.md) · [Docs home](../README.md) · Next: [Mission 5 — PIP ▶](mission-05-pip.md)

> **Guide cross-reference:** [Mission 4 · Embedding in a screen (View)](https://sdk.shoplive.cloud/#m4) · [PlayerConfiguration fields](https://sdk.shoplive.cloud/#f-playerconfig)
>
> **Source:** [`ShopliveIntegration/EmbeddedPlayerView.swift`](../iOS/ShopliveIntegration/EmbeddedPlayerView.swift) · [`ui/feed/FeedScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/feed/FeedScreen.kt)
>
> **In the app:** card ④ — *"Embed in your screen"*. Opens a home feed with a player sitting between the cards.

---

## What you're building

A live player inside your own layout — a home feed, a product page, a tab. **Your app owns the layout; the SDK owns the video.**

**Checkpoint:** playback survives scrolling, and the player promotes to full screen on demand.

---

## Full-screen vs. embedded: what actually changes

| | Full screen (`ShoplivePlayerViewController` / `ShoplivePlayer`) | Embedded (`ShoplivePlayerView`) |
|---|---|---|
| Layout | SDK owns the whole screen | **You** own it |
| Overlay UI (chat, products, coupons) | Yes | **No — video only** |
| Controls, events, PIP | `ShoplivePlayerControlling` | **The same `ShoplivePlayerControlling`** |
| Playback start | Automatic on present | **You call `play()`** |
| in-app PIP | Yes | Yes |
| OS PIP | Yes | **No** (Android: full screen only) |

The third row is the good news: mute, resize, reload, `send()`, and PIP enter/exit are literally the same code on both paths. Only present/dismiss/close differ.

---

## iOS

The demo wraps `ShoplivePlayerView` in a thin `UIView` you can drop straight into your layout. Here's the essential shape:

```swift
public final class EmbeddedPlayerView: UIView {

    private let player: ShoplivePlayerView

    /// ★ `configuration` is a REQUIRED argument.
    public init(configuration: ShoplivePlayerConfiguration) {
        self.player = ShoplivePlayerView(configuration: configuration)
        super.init(frame: .zero)

        player.translatesAutoresizingMaskIntoConstraints = false
        addSubview(player)
        NSLayoutConstraint.activate([
            player.topAnchor.constraint(equalTo: topAnchor),
            player.bottomAnchor.constraint(equalTo: bottomAnchor),
            player.leadingAnchor.constraint(equalTo: leadingAnchor),
            player.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // Not supported — the SDK sealed off storyboard construction on purpose.
    required init?(coder: NSCoder) { fatalError("use init(configuration:)") }

    /// weak — the host must own the delegate strongly.
    public var delegate: ShoplivePlayerDelegate? {
        get { player.delegate }
        set { player.delegate = newValue }
    }

    /// The embedded view never starts playback on its own.
    public func play(campaignKey: String, options: ShoplivePlayOptions = .init()) {
        player.play(campaignKey: campaignKey, options: options)
        player.overlayUI = .hidden          // see "video only" below
    }

    /// Must be called when leaving the screen — skip it and audio keeps playing.
    public func stop() { player.stop() }
}
```

### Why `configuration` is a required argument

`ShoplivePlayerView()` with no arguments, and storyboard-based construction, are both **sealed off**. If the view could be created without the host supplying settings, the PIP host window, overlay mode, and sound policy would silently freeze at their defaults with no indication why. If you want defaults, pass `.init()` explicitly — the point is that it's a decision you made.

### The rest of the surface is the shared contract

```swift
public var isMuted: Bool { get set }
public var resizeMode: ShopliveResizeMode { get set }
public var state: ShoplivePlayerState { get }
public func reload()
public func send(command: String, payload: [String: Any]?)
public func enterPictureInPicture()
public func exitPictureInPicture()
public var isInPictureInPicture: Bool { get }
```

---

## Android

Embedding into Compose via `AndroidView`. The comments here are the load-bearing part:

```kotlin
AndroidView(
    modifier = Modifier.fillMaxSize(),
    factory = { _ ->
        ShoplivePlayerView(activity).apply {          // Activity context, not application
            this.delegate = delegate

            // Let the lifecycle release resources on destroy.
            bindLifecycle(lifecycleOwner)

            // configuration only applies BEFORE playback starts.
            // PREVIEW type: volume keys disabled, preview-resolution stream, less traffic.
            configuration = PlayerConfigurationFactory.from(
                DemoOptionsStore.current.copy(type = ShoplivePlayerType.PREVIEW)
            )

            PlayerSession.attach(this)
            play(campaignKey)
        }
    },
    onRelease = { view ->
        PlayerSession.detach(view)
        view.stop()
    },
)
```

Three things to copy:

1. **`bindLifecycle(lifecycleOwner)`** — ties resource release to the host lifecycle instead of making you track it.
2. **Assign `configuration` before `play()`.** After playback starts, assignments are ignored (a warning is logged). See [Mission 7](mission-07-ui-customization.md).
3. **`stop()` in `onRelease`.** Same rule as iOS — skip it and audio outlives the screen.

---

## ⚠️ Do not put the player in a `LazyColumn` / `UICollectionView` cell

This is the trap that costs the most debugging time.

`ShoplivePlayerView` **releases its resources when it detaches from the window** (`onDetachedFromWindow`). Lazy containers dispose of off-screen items by design. Put the player in a lazy item and **scrolling alone interrupts playback.**

So the demo feed uses `Column + verticalScroll` instead:

```kotlin
Column(
    modifier.fillMaxSize().verticalScroll(rememberScrollState())
) {
    FeedCard(…)
    Box(Modifier.fillMaxWidth().height(220.dp)) { AndroidView(…) }
    FeedCard(…)
}
```

For a feed of a handful of cards this is the correct trade — everything is composed, and scrolling doesn't touch playback.

**If you genuinely need a long list**, pick one of these:

- Pin the player outside the recycling area (a fixed header, a sticky region).
- Promote to PIP when the view scrolls off screen — see [Mission 5](mission-05-pip.md).
- Accept teardown and re-`play()` on re-attach, and budget for the reload delay in your UX.

There is no "keep the view alive while detached" option; that behavior is fixed in the SDK.

---

## Embedded is video only

The chat, product, and coupon overlays don't appear. `overlayUI` is pinned to `HIDDEN`, because a view sitting inside your layout that also drew a full overlay would collide with your own UI.

**But the command channel stays alive.** `hidden` means *not displayed*, not *torn down* — so `navigation`, `coupon`, and `customWebAction` requests keep arriving at your delegate. That's what makes "hide the SDK UI and draw your own" viable ([Mission 7](mission-07-ui-customization.md)).

> ⚠️ **iOS: the SDK doesn't enforce the pin.** The setter accepts `.builtIn`, and when it does, a full-screen-sized overlay gets drawn shrunken inside your embed box (measured). That's why `EmbeddedPlayerView.play()` assigns `player.overlayUI = .hidden` explicitly right after `play()`. Keep that line when you copy the file.

---

## Promoting to full screen

### Android

`expandToFullScreen()` hands the session over — no reload.

### iOS

**There is no equivalent API.** The demo tears down the embedded session and presents a fresh full-screen VC, which re-resolves the stream and costs one more brief loading pass:

```swift
@discardableResult
public func expandToFullScreen(from presenter: UIViewController,
                               options: ShoplivePlayOptions = .init(),
                               configuration: ShoplivePlayerConfiguration = .init(),
                               delegate: ShoplivePlayerDelegate? = nil) -> ShoplivePlayerViewController? {
    guard let campaignKey else { return nil }
    stop()
    return PlayerLauncher.present(campaignKey: campaignKey,
                                  from: presenter,
                                  options: options,
                                  configuration: configuration,
                                  delegate: delegate)
}
```

If seamless hand-off matters for your iOS product, raise it with your ShopLive contact — it's SDK-side work, not something an app can work around. Tracked in [Platform Differences](platform-differences.md).

---

## Choosing a preset for the embedded slot

An inline preview needs different defaults from a full-screen session, and the SDK provides both as named presets.

### iOS — `ShoplivePlayerConfiguration.preview`

```swift
let config = ShoplivePlayerConfiguration.preview
let view = EmbeddedPlayerView(configuration: config)
```

| | `.live` (full screen) | `.preview` (embedded) |
|---|---|---|
| `pip.isInAppPipEnabled` / `isOSPipEnabled` | on (default) | **false / false** |
| `overlay.ui` | `.builtIn` | **`.hidden`** |
| `sound.muteOnStart` | false | **true** |
| `appearance.resizeMode` | `.fill` | `.fill` |

Everything else equals `.init()`. This prevents three concrete problems: a PIP window popping out of a preview thumbnail, chat UI crammed into a small box, and audio starting without the user asking.

> `.preview` changes **display policy only.** v2's `ShopLive.preview()` also switched to a preview-only stream (`previewLiveUrl`); that part is *not* included, because the embedded path has no wiring for it. **The stream that plays is the same as live.**

### Android — `ShoplivePlayerType.PREVIEW`

```kotlin
configuration = ShoplivePlayerConfiguration(type = ShoplivePlayerType.PREVIEW)
```

On Android the equivalent is the `type` field, which drives the volume-key policy and the received stream resolution.

---

## How the demo runs this mission

Tapping card ④ opens the home feed screen: two feed cards with a 220dp (Android) / 210pt (iOS) player box between them, plus a mute toggle and an **⤡ expand** button.

The screen is deliberately built to demonstrate the constraints rather than hide them:

- Scroll and playback keeps going — that's the `Column + verticalScroll` decision.
- Callout tips appear inline when the context is wrong (no Activity context, no campaign key).
- The **⤡** button is where an app would call `enterPictureInPicture()` itself, since there's no "auto-PIP when scrolled off screen" option in the public surface.

> ⚠️ **Measured on iOS:** in the embedded box, `resizeMode = .fill` renders like `.fit` — side letterboxing. The value *is* forwarded correctly; the problem is downstream, where the video frame is computed from `UIScreen.main.bounds` instead of the host view's bounds. An app can't work around it. Details in [Known Issues](known-issues.md#fill-looks-like-fit-in-the-embedded-view-ios).

---

## Next

[Mission 5 — Keep watching in PIP ▶](mission-05-pip.md) — the natural follow-up, since "the view scrolled away" and "the user navigated elsewhere" both end in the same place.

---

[◀ Mission 3](mission-03-user-identity.md) · [Docs home](../README.md) · Next: [Mission 5 ▶](mission-05-pip.md)
