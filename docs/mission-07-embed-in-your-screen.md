# Mission 7 — Add Inline Previews to a List Screen

[◀ Mission 6](mission-06-events-products-coupons.md) · [Docs home](../README.md) · Next: [Mission 8 — UI Customization & Placement ▶](mission-08-ui-customization.md)

> **Guide cross-reference:** [Mission 7 · Add Inline Previews to a List Screen](https://sdk.shoplive.cloud/#m7) · [Native vs. hybrid](https://sdk.shoplive.cloud/#m7-choose) · [Approach A · Native](https://sdk.shoplive.cloud/#m7-native) · [Approach B · Hybrid](https://sdk.shoplive.cloud/#m7-web) · [PlayerConfiguration fields](https://sdk.shoplive.cloud/#f-playerconfig)
>
> **Source — native:** [`ShopliveIntegration/EmbeddedPlayerView.swift`](../iOS/ShopliveIntegration/EmbeddedPlayerView.swift) · [`integration/…/ShopliveEmbeddedPlayer.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveEmbeddedPlayer.kt) (Compose glue: [`ui/feed/FeedScreen.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/ui/feed/FeedScreen.kt))
>
> **Source — hybrid:** [`ShopliveIntegration/WebBridge.swift`](../iOS/ShopliveIntegration/WebBridge.swift) + [`WebBridgeInput.swift`](../iOS/ShopliveIntegration/WebBridgeInput.swift) · [`integration/…/ShopliveWebBridge.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShopliveWebBridge.kt)
>
> **In the app:** card ⑦ — *"Add Inline Previews to a List Screen"*. The tap asks which way: **native** opens a home feed with a player sitting between the cards; **hybrid** opens a web list whose card opens the native player.

---

## What you're building

Live previews inside your own list or feed — a home feed, a product list, a tab — that invite the viewer in before they start watching. There are two ways, depending on what your list is made of:

| Your list is… | Approach | What crosses into the SDK |
|---|---|---|
| A native screen | **A · Native** — put `ShoplivePlayerView` in your layout. **Your app owns the layout; the SDK owns the video.** | The view itself |
| A WebView | **B · Hybrid** — keep the list on the web; a tap hands **one `campaignKey`** to the app, which opens the native player | One string |

**Checkpoint (native):** playback survives scrolling, and the player promotes to full screen on demand.
**Checkpoint (hybrid):** tapping a web card opens the native player full screen; an empty or non-string value opens nothing and the reason is in the log.

---

## Approach A · Native — a view in your own layout

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

    private let playerView: ShoplivePlayerView

    /// The embedded player, read-only — e.g. to tell its events apart from another player's
    /// (the same delegate object often serves several players). Control it through this wrapper.
    public var player: ShoplivePlayerControlling { playerView }

    /// ★ `configuration` is a REQUIRED argument.
    public init(configuration: ShoplivePlayerConfiguration) {
        self.playerView = ShoplivePlayerView(configuration: configuration)
        super.init(frame: .zero)

        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // Not supported — the SDK sealed off storyboard construction on purpose.
    required init?(coder: NSCoder) { fatalError("use init(configuration:)") }

    /// weak — the host must own the delegate strongly.
    public var delegate: ShoplivePlayerDelegate? {
        get { playerView.delegate }
        set { playerView.delegate = newValue }
    }

    /// The embedded view never starts playback on its own.
    public func play(campaignKey: String, options: ShoplivePlayOptions = .init()) {
        playerView.play(campaignKey: campaignKey, options: options)
        playerView.overlayUI = .hidden          // see "video only" below
    }

    /// Must be called when leaving the screen — skip it and audio keeps playing.
    public func stop() { playerView.stop() }
}
```

The read-only `player` accessor is how the demo's feed tells *its* embed apart from another session: the feed records `embeddedView.player` as the mission's player, and a playback signal from any other player — say, a deep-link player opened on top while the feed keeps playing underneath — is not credited to the inline mission. ⚠️ *Unverified:* that the delegate receives that same view object as its `player` ([Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) i2).

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

The SDK-facing part is plain View code in `:integration`, so an XML-based app can copy it as is. The comments are the load-bearing part:

```kotlin
fun createEmbeddedPlayer(
    activity: Activity,                       // Activity context, not application
    lifecycleOwner: LifecycleOwner,
    campaignKey: String,
    delegate: ShoplivePlayerDelegate,
    configuration: ShoplivePlayerConfiguration = ShoplivePlayerPresets.embeddedPreview(),
): ShoplivePlayerView = ShoplivePlayerView(activity).apply {
    this.delegate = delegate

    // Let the lifecycle release resources on destroy.
    bindLifecycle(lifecycleOwner)

    // configuration only applies BEFORE playback starts.
    this.configuration = configuration

    ShoplivePlayerSession.attach(this)
    play(campaignKey)
}

fun releaseEmbeddedPlayer(view: ShoplivePlayerView) {
    ShoplivePlayerSession.detach(view)
    view.stop()
}
```

The demo's Compose screen only places it: `AndroidView(factory = { createEmbeddedPlayer(…) }, onRelease = { releaseEmbeddedPlayer(it) })`.

Three things to copy:

1. **`bindLifecycle(lifecycleOwner)`** — ties resource release to the host lifecycle instead of making you track it.
2. **Assign `configuration` before `play()`.** After playback starts, assignments are ignored (a warning is logged). See [Mission 8](mission-08-ui-customization.md).
3. **`stop()` when the view goes away** — `releaseEmbeddedPlayer` in `onRelease`. Same rule as iOS — skip it and audio outlives the screen.

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
- Promote to PIP when the view scrolls off screen — see [Mission 3](mission-03-pip.md).
- Accept teardown and re-`play()` on re-attach, and budget for the reload delay in your UX.

There is no "keep the view alive while detached" option; that behavior is fixed in the SDK.

---

## Embedded is video only

The chat, product, and coupon overlays don't appear. `overlayUI` is pinned to `HIDDEN`, because a view sitting inside your layout that also drew a full overlay would collide with your own UI.

**But the command channel stays alive.** `hidden` means *not displayed*, not *torn down* — so `navigation`, `coupon`, and `customWebAction` requests keep arriving at your delegate. That's what makes "hide the SDK UI and draw your own" viable ([Mission 8](mission-08-ui-customization.md)).

> ⚠️ **iOS: the SDK doesn't enforce the pin.** The setter accepts `.builtIn`, and when it does, a full-screen-sized overlay gets drawn shrunken inside your embed box (measured). That's why `EmbeddedPlayerView.play()` assigns `player.overlayUI = .hidden` explicitly right after `play()`. Keep that line when you copy the file.

---

## Promoting to full screen

### Android

`expandToFullScreen()` on the view promotes it to the full-screen player (`expandEmbeddedToFullScreen()` in `:integration`). Measured 2026-07-30 on SDK 3.0.0: this **restarts the stream** rather than handing the running session over, so the viewer sees a brief reload.

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

| | `.default` (full screen, equals `.init()`) | `.preview` (embedded) |
|---|---|---|
| `pip.isInAppPipEnabled` / `isOSPipEnabled` | on (default) | **unsettled on 3.0.4** — see below |
| `overlay.ui` | `.builtIn` | **`.hidden`** |
| `sound.muteOnStart` | false | **true** |
| `appearance.resizeMode` | `.fill` | **unsettled on 3.0.4** — see below |

This prevents concrete problems: chat UI crammed into a small box, and audio starting without the user asking.

> **What changed with 3.0.4 — not yet re-measured.** On SDK 3.0.0, `.preview` measured as PIP fully off (in-App and OS) and changed **display policy only** — the stream that played was the same as live. The 3.0.4 guide describes `.preview` differently: it selects the **preview stream** (`type = preview`; iOS 3.0.4 now has `configuration.type`), and the nudge-style preview ([Mission 2](mission-02-nudge-preview.md)) treats in-App PIP as on. The 3.0.4 preset's PIP and `resizeMode` values are not visible in the SDK interface; [`NudgePreview.swift`](../iOS/ShopliveIntegration/NudgePreview.swift) logs the PIP value on every nudge. ⚠️ **Unverified** until a device run settles it ([Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) i8) — set the fields explicitly if your embedded slot depends on them.

### Android — `ShoplivePlayerType.PREVIEW`

```kotlin
configuration = ShoplivePlayerConfiguration(type = ShoplivePlayerType.PREVIEW)
```

On Android the equivalent is the `type` field, which drives the volume-key policy and the received stream resolution.

---

---

## Approach B · Hybrid — the list is a web page

If your list already lives in a WebView, keep it there. Only the tapped broadcast's **`campaignKey`** crosses into the app, and the app opens its native player exactly as in [Mission 1](mission-01-open-the-player.md). The app already holds the access key (`Shoplive.initialize`), so nothing else needs to cross.

The bridge is the WebView's own JS ↔ native channel, **not a Shoplive API**. The name both sides use is `ShopLiveAppInterface`.

## Step 1 · Web — send the key to whichever native interface exists

This is the guide's step-1 branching, as the demo's bundled page uses it (a real page gets the key from the Web SDK's `ON_CLICK_CAMPAIGN_LIST_ITEM` callback):

```js
var APP_INTERFACE = "ShopLiveAppInterface";
function sendToApp(value) {
  if (window[APP_INTERFACE]) {
    window[APP_INTERFACE].postMessage(value);                          // Android
  } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[APP_INTERFACE]) {
    window.webkit.messageHandlers[APP_INTERFACE].postMessage(value);   // iOS
  } else {
    // A plain browser — the Web SDK's modal player would open here.
  }
}
```

## Step 2 · Native — receive the key, and treat it as untrusted input

### iOS

Register the bridge on the configuration **before** creating the `WKWebView`, and remove it when the screen goes away:

```swift
let configuration = WKWebViewConfiguration()
configuration.allowsInlineMediaPlayback = true
let bridge = WebBridge(
    isOwnPage: { url in url.isFileURL /* your own pages only */ },
    onCampaignKey: { [weak self] key in self?.open(campaignKey: key) })   // weak — the content controller keeps the bridge alive
bridge.install(on: configuration)               // userContentController.add(_, name: "ShopLiveAppInterface")
let webView = WKWebView(frame: .zero, configuration: configuration)
webView.navigationDelegate = bridge             // keeps the web view on your own pages
webView.uiDelegate = bridge

deinit { WebBridge.uninstall(from: contentController) }   // removeScriptMessageHandler(forName:)
```

The message handler validates the body before anything opens — the rules live in `WebBridgeInput.swift` (Foundation only, so `iOS/scripts/logic_check.sh` can compile and check them on a Mac):

```swift
static func campaignKey(from body: Any?) -> Result {
    guard let body, !(body is NSNull) else {
        return .rejected(reason: "body is null")
    }
    guard let text = body as? String else {
        return .rejected(reason: "body is not a string (\(type(of: body)))")
    }
    let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else {
        return .rejected(reason: "campaignKey is empty")
    }
    return .accepted(key)
}
```

### Android

```kotlin
ShopliveWebBridge(activity) { host, campaignKey ->
    // main thread, live Activity, non-blank key
    ShoplivePlayerLauncher.start(host, campaignKey, delegate)
}.attachTo(
    webView = webView,
    ownPagePrefix = "file:///android_asset/hybrid/",   // anything else opens in the browser
    onPageError = { reason -> /* show it */ },
)
webView.loadUrl(pageUrl)                               // after attachTo

// when the WebView goes away
ShopliveWebBridge.detachFrom(webView)
webView.destroy()
```

```kotlin
@JavascriptInterface
fun postMessage(campaignKey: String?) {          // runs on the WebView's JavaBridge thread
    val key = campaignKeyFrom(campaignKey)       // raw?.trim()?.takeIf { it.isNotEmpty() }
    if (key == null) {
        logError("web bridge: postMessage(…) ignored — expected one non-blank campaignKey string")
        return
    }
    main.post { deliver(key) }                   // main thread; the Activity is a WeakReference,
}                                                // dropped if it is finishing or destroyed
```

## Step 3 · Native — play it

The key is all the full-screen player needs — the same call as [Mission 1](mission-01-open-the-player.md). For a signed-in viewer, call `setUser` right before playing ([Mission 5](mission-05-user-identity.md)).

## What the bridge has to defend against

| Input / situation | iOS | Android |
|---|---|---|
| `null`, empty, whitespace only | Ignored, reason logged | Ignored, reason logged |
| A non-blank string that is not a real campaign key | Passed to the SDK as is — no format rule exists. ⚠️ **Unverified** that it ends in the SDK's error path with nothing marked done (i7) | Same (a2) — see [Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) |
| Not a string (number, object, array) | Ignored, type logged (`body as? String`) | ⚠️ JS → Java conversion may deliver it as text (`"123"`, `"[object Object]"`) — it passes the check and goes to the SDK. **Unverified** that such a key ends in the SDK's error path with nothing credited |
| Thread | WebKit calls the handler on the main thread | `postMessage` runs on the JavaBridge thread → validated there, then posted to the main thread |
| Screen already gone | The bridge holds the screen only through a weak closure | The Activity is a `WeakReference`; a late message is dropped and logged |
| Another page inside the WebView | **Every page in the WebView can call the bridge.** Only your own pages load inside; anything else is cancelled and opened outside the app (`WKNavigationDelegate` / `createWebViewWith`) | Same — `shouldOverrideUrlLoading` keeps your prefix and sends the rest to `ACTION_VIEW` |
| Repeated taps | The screen remembers the player it opened and ignores taps while that player is not `.closed` | The screen's ViewModel holds the player it opened (weakly) and ignores taps while its state is ongoing — and while a start it requested has not left Idle yet. ⚠️ *Unverified (a5):* that this lock is released by Loading, Closed or an unrecoverable error ([Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code)) |

The guide's own Android example declares `postMessage(campaignKey: String)` (non-null) and does no validation; the demo takes `String?` and checks it, because the page is input you do not control.

---

## How the demo runs this mission

Tapping card ⑦ asks **native** or **hybrid**.

**Native** opens the home feed screen: two feed cards with a 220dp (Android) / 210pt (iOS) player box between them, plus a mute toggle and an **⤡ expand** button.

The screen is deliberately built to demonstrate the constraints rather than hide them:

- Scroll and playback keeps going — that's the `Column + verticalScroll` decision.
- Callout tips appear inline when the context is wrong (no Activity context, no campaign key).
- The **⤡** button is where an app would call `enterPictureInPicture()` itself, since there's no "auto-PIP when scrolled off screen" option in the public surface.

> ⚠️ **Measured on iOS:** in the embedded box, `resizeMode = .fill` renders like `.fit` — side letterboxing. The value *is* forwarded correctly; the problem is downstream, where the video frame is computed from `UIScreen.main.bounds` instead of the host view's bounds. An app can't work around it. Details in [Known Issues](known-issues.md#fill-looks-like-fit-in-the-embedded-view-ios).

**Hybrid** opens a web list loaded from the app bundle (`hybrid/index.html` — no hosting, no Web SDK, only the step-1 branching above). It has three cards: a live card that sends the demo's campaignKey, a card that sends an empty key, and one that sends a non-string — so the rejection paths can be seen in the Log tab — plus an external link that opens in the browser, not in the WebView. The key reaches the page escaped (iOS: a JSON string literal in a `WKUserScript`; Android: a URL-encoded query parameter read with `URLSearchParams`), never pasted into script text.

The "done" badge lights up when the player **this mission started** reaches playback — the feed's embed (native) or the player the web card opened (hybrid).

---

## Next

[Mission 8 — UI Customization & Placement ▶](mission-08-ui-customization.md) — colors, fonts, or hiding the built-in overlay and drawing your own. For "the view scrolled away" or "the user navigated elsewhere", see [Mission 3 — Keep Watching in PIP](mission-03-pip.md).

---

[◀ Mission 6](mission-06-events-products-coupons.md) · [Docs home](../README.md) · Next: [Mission 8 ▶](mission-08-ui-customization.md)
