# Mission 6 — Events · Products · Coupons

[◀ Mission 5](mission-05-user-identity.md) · [Docs home](../README.md) · Next: [Mission 7 — Add Inline Previews to a List Screen ▶](mission-07-embed-in-your-screen.md)

> **Guide cross-reference:** [Mission 6 · Events · Products · Coupons](https://sdk.shoplive.cloud/#m6) · [Event types](https://sdk.shoplive.cloud/#m6-events) · [Why the player closed](https://sdk.shoplive.cloud/#m6-closed) · [Share button](https://sdk.shoplive.cloud/#m6-share) · [ShopliveShareInfo](https://sdk.shoplive.cloud/#f-shareinfo) · [Types & states](https://sdk.shoplive.cloud/#types) · [Error handling](https://sdk.shoplive.cloud/#errors)
>
> **Source:** [`ShopliveIntegration/DemoPlayerDelegate.swift`](../iOS/ShopliveIntegration/DemoPlayerDelegate.swift) · [`integration/…/ShoplivePlayerEventLogger.kt`](../Android/integration/src/main/java/cloud/shoplive/onboarding/integration/ShoplivePlayerEventLogger.kt)
>
> **In the app:** card ⑥ — *"Events · Products · Coupons"*. Opens the Log tab automatically. Tap products and coupons and watch what arrives.

---

## What you're building

The connection between the SDK's overlay and your app's screens and APIs. This is **the most important mission in the set** — if you only read one, read this one. Everything else is configuration; this is where your app actually participates.

**Checkpoint:** `navigation` and `coupon` requests arrive, and `respond` is called for each.

---

## The delegate has exactly two methods

That's the whole surface. The distinction between them is the thing to internalize.

| | **Event** | **Request** |
|---|---|---|
| iOS | `player(_:didReceive event:)` | `player(_:didRequest request:)` |
| Android | `onEvent(player, event)` | `onRequest(player, request)` |
| Meaning | "here's what happened" | "**I need an answer**" |
| If you ignore it | Fine — handle only what you care about | **Bug.** The overlay waits, the popup never closes |

Both callbacks are meant to arrive **on the main thread**; the demo's delegate is written for that. The `respond` callback may be called from **any** thread — which is intentional, since responding after a server round-trip is the normal case.

> ⚠️ **Unverified on iOS:** the 3.0.4 interface does not declare the main thread (no `@MainActor`). `DemoPlayerDelegate` therefore moves a callback that arrives off the main thread onto it and logs that — [Known Issues](known-issues.md#open-sdp-verify-markers-in-the-code) i3.

**Memory:** the delegate is weakly held on iOS and instance-owned on Android. If nothing owns it, events stop arriving with no warning. That's why the iOS demo holds it in a singleton (`DemoPlayerDelegate.shared`); on Android the player keeps the delegate it was given, and the demo builds one `ShoplivePlayerEventLogger` in its ViewModel and reuses it.

**One delegate, many players.** A single delegate object usually serves every player in the app — a feed view, a full-screen player, a nudge. Every callback hands you the `player` that raised it, so anything you derive from an event should carry that player along. The demo does exactly that: iOS re-publishes what the rest of the app needs as one `PlayerMilestone` channel (`DemoPlayerDelegate.observeMilestones(of:)`), and Android reports `onMilestone(milestone, player)`. On iOS a view controller session needs one extra step: 3.0.4 names the inner `ShoplivePlayerView` as `player`, not the view controller (measured on the simulator), so comparing it with your controller never matches. The demo registers each controller with `DemoPlayerDelegate.adopt(_:)`, a relay that puts the controller back as the sender — [Known Issues](known-issues.md#the-delegates-player-is-not-your-view-controller-ios).

---

## Part 1 — Events (notifications)

### iOS

```swift
func player(_ player: ShoplivePlayerControlling, didReceive event: ShoplivePlayerEvent) {
    switch event {

    case .stateChanged(let state):
        // Playback lifecycle. Entering/leaving .inAppPIP also arrives here.
        // `.closed` is session end, NOT a return from PIP — keep the two apart.
        if state == .closed {
            publish(.closed(reason: player.closeReason), from: player)   // 3.0.4+ — see "Why the player closed"
        } else {
            publish(.pipStateChanged(isActive: state == .inAppPIP), from: player)
        }

    case .campaignStatusChanged(let status):
        // .ready / .live / .ended — drive your LIVE badge from this.
        break

    case .campaignInfoReceived(let info):
        // info.campaignKey, info.title, info.status
        break

    case .playback(let playback):
        // PlaybackEvent is a CLASS. The state is in `.event`, details in `.datas`.
        if playback.event == .started || playback.event == .rendering {
            publish(.playbackReached, from: player)
        }

    case .connectionStateChanged(let state):
        // Engine-independent connection state. Drive a network banner off `.reconnecting`.
        break

    case .userNameUpdateRequested(let payload):
        // The overlay asked to change the nickname — send the user to your profile screen.
        break

    case .analytics(let info):
        // Forward viewing stats to your own analytics.
        break

    case .error(let error):
        // ONLY unrecoverable errors arrive here.
        if !error.isRecoverable { publish(.fatalError(error), from: player) }

    case .shareRequested(let info):
        // 3.0.4+, only with navigation.isCustomShareEnabled — see "Share button" below.
        Self.presentShareSheet(for: info)

    // Required: the SDK's enums are resilient (library evolution).
    @unknown default:
        break
    }
}
```

`publish(_:from:)` posts the milestone together with the player; a screen subscribes to **its own** player with `DemoPlayerDelegate.observeMilestones(of: player)`, so it never reacts to another session's events (pass `nil` to hear every player — the mission list does that for product landings).

### Android

```kotlin
override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
    when (event) {
        is ShoplivePlayerEvent.StateChanged -> when (event.state) {
            ShoplivePlayerState.Loading     -> { /* new session — reset your counters here */ }
            ShoplivePlayerState.InAppPIP    -> onMilestone(ShopliveMilestone.IN_APP_PIP_ENTERED, player)
            // Session over — drop the control handle so you don't command a dead player.
            // 3.0.4+: the state carries why — see "Why the player closed".
            is ShoplivePlayerState.Closed   -> ShoplivePlayerSession.detach(player)
            else -> Unit
        }

        is ShoplivePlayerEvent.CampaignStatusChanged -> { /* READY / LIVE / ENDED */ }
        is ShoplivePlayerEvent.CampaignInfoReceived  -> { /* event.info.title, .status */ }

        is ShoplivePlayerEvent.Playback -> when (val pb = event.event) {
            is ShoplivePlaybackEvent.Started   -> onMilestone(ShopliveMilestone.PLAYBACK_STARTED, player)
            is ShoplivePlaybackEvent.Rendering -> { /* frames are on screen */ }
            is ShoplivePlaybackEvent.Failed    -> onRepeatedPlaybackFailure(pb.code)
            else -> Unit
        }

        is ShoplivePlayerEvent.ConnectionStateChanged -> { /* reconnecting banner */ }
        is ShoplivePlayerEvent.UserNameUpdateRequested -> { /* open profile */ }
        is ShoplivePlayerEvent.Analytics -> { /* forward to your analytics */ }
        is ShoplivePlayerEvent.WebCommandReceived -> { /* event.name, event.payload (null without data) */ }
        is ShoplivePlayerEvent.ShareRequested -> onShareRequested(event.info)   // 3.0.4+, see "Share button"

        is ShoplivePlayerEvent.Error -> onError(event.error)   // reports isRecoverable == false via onFailure
    }
}
```

`ShoplivePlaybackEvent` is a sealed hierarchy: `Requested`, `AudioLoaded`, `Started`, `Rendering`, `Buffering`, `RebufferingStarted`, `RebufferingEnded`, `Ended`, `Failed(code, message)`.

### Two things that never arrive as events

Know these up front so you don't go looking:

1. **Engine failover (HLS ↔ WebRTC) is not reported.** It's an SDK internal. Your only observable signal for network conditions is `Playback` rebuffering.
2. **Issues being auto-recovered do not produce an `error`.** `Error` is delivered only when a session ends unrecoverably (`isRecoverable = false`). So an `error` in your log is always meaningful — and its absence does *not* mean everything is fine.

That second point has a real consequence, covered below.

---

## Part 2 — Requests (you must answer)

### The one you cannot skip: `navigation`

```swift
case .navigation(let url):
    // Without this, tapping a product does NOTHING at all.
    publish(.requestReceived(.navigation(url)), from: player)
// The mission list subscribes to every player and routes it:
// case .requestReceived(.navigation(let url)): self?.presentProductDetail(url: url)
```

```kotlin
is ShoplivePlayerRequest.Navigation -> {
    onNavigation(request.url)   // the demo passes { url -> ProductRouter.open(url) }
}
```

The SDK hands you a URL and nothing else — **no context, no view controller.** Routing is entirely your app's job, which means your app needs to know where it can present from.

**On Android this is harder than it looks**, because when the request arrives the **SDK's player Activity is in front**. Your Compose screens are behind it, so a bottom sheet or dialog from your nav graph will not be visible. The demo solves it with a dedicated Activity plus a foreground-Activity tracker:

```kotlin
object ProductRouter {
    private var foreground: WeakReference<Activity> = WeakReference(null)

    fun install(application: Application) {
        application.registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) { foreground = WeakReference(activity) }
            override fun onActivityPaused(activity: Activity) {
                if (foreground.get() === activity) foreground = WeakReference(null)
            }
            /* … */
        })
    }

    fun open(url: String) {
        val host = foreground.get()
        if (host != null) {
            host.startActivity(ProductDetailActivity.intent(host, url))
            return
        }
        // Nothing in the foreground (backgrounded) — start a new task.
        application?.startActivity(
            ProductDetailActivity.intent(application, url)
                .apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        )
    }
}
```

On iOS the problem is smaller: the player is a view controller the app presented, so the demo presents the product detail modal from the top-most view controller (`DeepLinkRouter.topViewController()`).

**Related:** `navigation.actionOnNavigation` decides what happens to the *player* on navigation — close it, or shrink to PIP. See [Mission 3](mission-03-pip.md).

### `coupon` — respond or the popup hangs

```swift
case .coupon(let id, let respond):
    // In a real app: call your coupon API, then fill in success/message from its result.
    let result = ShopliveCouponResult(
        couponId: id,
        success: true,
        message: "Your coupon has been issued",
        status: .show,      // surface the result in the overlay
        alertType: .toast   // as a toast
    )
    respond(result)
```

```kotlin
is ShoplivePlayerRequest.Coupon -> {
    request.respond(
        ShopliveCouponResult(
            couponId = request.id,
            success = true,
            message = "Your coupon has been issued",
            status = ShopliveResultStatus.HIDE,
            alertType = ShopliveResultAlertType.TOAST,
        )
    )
}
```

- `status` — `SHOW` keeps the overlay's result view up; `HIDE` closes it.
- `alertType` — `TOAST` or `ALERT`.
- `success = false` is a legitimate answer. "Out of stock" or "already claimed" is a response, not a failure to respond.

> ⚠️ **v2 migration:** `respond(.success)` no longer exists. You construct the **full** `ShopliveCouponResult(couponId:success:message:status:alertType:)`. The integration guide's shorthand example doesn't compile.

### `customWebAction` — your overlay's custom hooks

```swift
case .customWebAction(let id, let type, let payload, let respond):
    // Branch on `type` to run an app feature.
    let result = ShopliveCustomActionResult(
        id: id,
        success: true,
        message: nil,
        status: .keep,      // leave the overlay's display state alone
        alertType: .alert
    )
    respond(result)
```

Use this for actions defined by your overlay web content — "add to cart", "share to KakaoTalk", "open the size guide". Branch on `type`.

### iOS: `@unknown default` matters more here than anywhere else

```swift
@unknown default:
    // A request that demands an answer, and we don't know how to answer it.
    // Logging and moving on can leave the overlay waiting forever.
    shopliveLog(.error, "Unknown ShoplivePlayerRequest — cannot respond. Check your SDK version")
```

For events, an unhandled case is harmless. For **requests**, silently ignoring one means never calling `respond` — and the overlay stalls. Log loudly so this is discoverable after an SDK upgrade.

---

## Part 3 — App → overlay commands

There's a send-only channel in the other direction:

```swift
player.send(command: "HIGHLIGHT_PRODUCT", payload: ["sku": sku])
```

```kotlin
ShoplivePlayerSession.send("HIGHLIGHT_PRODUCT", mapOf("sku" to sku))
```

Receiving is not exposed as a public event — this is one-way. The command names are agreed with whoever builds your overlay web content.

---

## ⚠️ The failure mode you have to design for

Both platforms measured the same class of gap: **a stream that doesn't exist doesn't reliably produce an error.**

**Android (emulator, API 37, 2026-07-30):** playing a campaign that is not on air produced `playback(failed(code: 404))` every ~5 seconds, and the session ended `ended → IDLE → CLOSED` — with **`ShoplivePlayerEvent.Error` never firing once**. `campaignInfoReceived` and `campaignStatusChanged` didn't fire either. An app that watches only `error` will show a black screen forever with no idea why.

**iOS (simulator, 2026-07-30):** a different shape — `error(code: .unexpectedError, isRecoverable: false)` repeating **twice per second** with no HLS fallback. The underlying connection code (`connection Issue [34]`) survives only in the `message` string, not in `ErrorCode`. And it reports `isRecoverable: false` while still retrying.

**So count failures yourself.** The Android demo's workaround:

```kotlin
private fun onRepeatedPlaybackFailure(code: Int?) {
    consecutiveFailures += 1
    if (failureNotified || consecutiveFailures < FAILURE_THRESHOLD) return   // threshold = 2
    failureNotified = true
    // … notify the user once per session …
}
```

Two details in there are the real lessons:

- **A one-shot latch per session.** Without it you'd nag the user every 5 seconds. Reset it on `stateChanged(LOADING)`, since the delegate is reused across sessions.
- **Use a `Toast`, not a Snackbar.** At this moment the SDK's player Activity is in front; a Compose Snackbar is behind it and invisible. `Toast` is the only thing that reliably draws over another Activity.

The iOS demo takes the equivalent approach: don't close the player, explain the reason **once per session**, and keep the app-owned **‹ List** button available as the escape hatch.

If and when the SDK delivers `error` correctly here, these workarounds can be deleted. Both are marked in the source.

---

## Translate error codes into sentences

There's no API to pre-validate a key, so a bad access key, a missing campaign, an auth problem, and a network failure are indistinguishable until the error event arrives. Map them once. The Android demo splits this in two: `:integration` groups the codes into causes, and the app turns each cause into its own localized sentence.

```kotlin
// :integration — ShopliveEventLabels.kt
val ShopliveError.causeGroup: ShopliveErrorCause
    get() = when (code) {
        ShopliveErrorCode.NOT_INITIALIZED_ACCESS_KEY -> ShopliveErrorCause.ACCESS_KEY
        ShopliveErrorCode.CAMPAIGN_NOT_FOUND         -> ShopliveErrorCause.CAMPAIGN_NOT_FOUND
        ShopliveErrorCode.CAMPAIGN_NOT_ON_AIR        -> ShopliveErrorCause.NOT_ON_AIR

        ShopliveErrorCode.AUTHENTICATION_FAILED,
        ShopliveErrorCode.GUEST_LOGIN_NOT_ALLOWED,
        ShopliveErrorCode.CUSTOM_ACCOUNT_NOT_FOUND,
        ShopliveErrorCode.CUSTOM_ACCOUNT_EXPIRED,
        ShopliveErrorCode.INVALID_SIGNATURE,
        ShopliveErrorCode.DUPLICATE_SESSION,
        ShopliveErrorCode.EXPIRED_SESSION            -> ShopliveErrorCause.AUTH_REQUIRED

        ShopliveErrorCode.CONNECTION_ISSUE,
        ShopliveErrorCode.FAILED_NETWORK             -> ShopliveErrorCause.NETWORK
        ShopliveErrorCode.SERVER_ERROR               -> ShopliveErrorCause.SERVER
        else                                         -> ShopliveErrorCause.OTHER
    }

val ShopliveError.logLine: String
    get() = "error(code: $code, rawCode: $rawCode, isRecoverable: $isRecoverable) " +
        "${causeGroup.defaultMessage} · $message"

// app — DemoLabels.kt: the sentence stays in the app's own resources
@StringRes
fun messageRes(cause: ShopliveErrorCause): Int = when (cause) {
    ShopliveErrorCause.ACCESS_KEY -> R.string.err_access_key
    /* … one string per cause … */
    ShopliveErrorCause.OTHER -> R.string.err_other
}
```

Note the log line keeps `rawCode` and `message` alongside the friendly sentence — the user reads the sentence, and your bug report needs the raw values. Full table: [API Reference § Error codes](api-reference.md#error-codes).

---

## Why the player closed (3.0.4+)

Since 3.0.4 a closed session says **why** it closed — `ShopliveCloseReason`:

| iOS | Android | Meaning |
|---|---|---|
| `.userAction` | `USER_ACTION` | The viewer closed it (✕, back) |
| `.appRequest` | `APP_REQUEST` | Your app closed it (`close()`, or another session started) |
| `.accessKeyChanged` | `ACCESS_KEY_CHANGED` | `Shoplive.initialize` ran again with a different access key, which closes players opened with the old key |

Use it to decide what to do next — most of all whether to show a small window again. The guide's recommendation, which the [nudge-style preview](mission-02-nudge-preview.md) follows: if the viewer closed it (`userAction`), do not show it again right away on the same screen.

```swift
// iOS — DemoPlayerDelegate.swift. The reason is a property of the player, not of the state.
case .stateChanged(let state):
    if state == .closed {
        let reason = player.closeReason          // ShopliveCloseReason? — nil = no reason given
        publish(.closed(reason: reason), from: player)
    }
```

```kotlin
// Android — ShoplivePlayerEventLogger.kt. The state carries the reason.
fun stateLabel(state: ShoplivePlayerState): String = when (state) {
    is ShoplivePlayerState.Closed -> "closed(reason: ${state.reason})"   // USER_ACTION / APP_REQUEST / ACCESS_KEY_CHANGED
    else -> state.toString()
}
```

> ⚠️ **iOS differs from the guide.** The guide's iOS example reads the reason from the state (`if case .closed(let reason) = s`). In the 3.0.4 binary `.closed` has **no associated value** (`case idle, loading, playing, paused, inAppPIP, closed`) — the reason is `closeReason: ShopliveCloseReason?` on the player (`ShoplivePlayerControlling`, the view controller, and the view). The guide's form does not compile against 3.0.4; read `player.closeReason` when `.closed` arrives. Android matches the guide: `ShoplivePlayerState.Closed(reason)`.
>
> ⚠️ **Unverified:** whether `closeReason` is already set at the moment `.closed` arrives on iOS. If it is nil there, the log says "no reason"; the nudge screen reads it again later, when it decides whether to show itself, so its decision does not depend on that timing.

After an access-key change, a token-signed-in viewer must be set again with `Shoplive.setUser` ([Mission 5](mission-05-user-identity.md)).

---

## Share button — handle it in your app (optional · 3.0.4+)

By default the SDK shows its own share sheet. Set `navigation.isCustomShareEnabled = true` and the share button sends a `shareRequested` event **instead** — the SDK shows nothing, and your app shows its own share screen from `ShopliveShareInfo` (`url`, `campaignKey`, `title`, `descriptionText`, `thumbnailUrl`, all optional). With `navigation.shareScheme` set, that is used as the share URL before the overlay URL.

```swift
// iOS — DemoPlayerDelegate.swift
static func enableCustomShare(_ enabled: Bool, in configuration: inout ShoplivePlayerConfiguration) {
    configuration.navigation.isCustomShareEnabled = enabled      // default false — SDK share sheet
}

static func presentShareSheet(for info: ShopliveShareInfo) {
    guard let url = info.url else {
        shopliveLog(.error, "shareRequested without a url — share sheet not shown")
        return
    }
    guard let presenter = DeepLinkRouter.topViewController() else {
        shopliveLog(.error, "shareRequested — no view controller to present the share sheet from")
        return
    }
    let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    // iPad: anchor the popover (see the source)
    presenter.present(sheet, animated: true)
}
```

```kotlin
// Android — ShoplivePlayerEventLogger.kt
fun ShoplivePlayerConfiguration.NavigationOptions.withCustomShare(
    enabled: Boolean = true,
): ShoplivePlayerConfiguration.NavigationOptions = copy(isCustomShareEnabled = enabled)

private fun onShareRequested(info: ShopliveShareInfo) {
    val url = info.url
    if (url.isNullOrBlank()) {
        logError("shareRequested without a url — no share sheet shown")
        return
    }
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, url)
        info.title?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
    }
    onShare(Intent.createChooser(send, null))   // the app starts it from the Activity in front
}
```

| | iOS | Android |
|---|---|---|
| `isCustomShareEnabled = false` (default) | SDK share sheet, no event — the app's share code never runs | same |
| `true`, url present | `UIActivityViewController` from the top view controller | `ACTION_SEND` chooser, started by the demo's `ProductRouter.share` from the resumed Activity (the SDK player is in front) |
| `true`, no url | Nothing shown, logged | same |

---

## How the demo runs this mission

Card ⑥ starts playback and **auto-opens the Log tab**, because reading the log *is* the mission. Every request is logged as a pair:

```
REQUEST  coupon(id: "CPN-1", respond:) received
REQUEST  → respond(success: true, status: .show, alertType: .toast) called
```

Pairing them makes a missing `respond` visible at a glance — which is the whole reason it's formatted that way.

The "done" badge appears as soon as **any** `navigation`, `coupon` or `customWebAction` request arrives, from any player, since receiving one proves the channel works.

The 3.0.4 items show up in the same log: every close is logged with its reason (`stateChanged(.closed) — closeReason: .userAction` / `stateChanged(closed(reason: USER_ACTION))`), and the Options tab's `navigation.isCustomShareEnabled` switch (off by default, like the SDK) routes the share button to the app's own share sheet.

---

## Next

[Mission 7 — Add Inline Previews to a List Screen ▶](mission-07-embed-in-your-screen.md) — put live previews inside your own list or feed, natively or from a web page. And for the "hide the built-in overlay and draw your own" mode, which depends entirely on the requests you just wired up, see [Mission 8](mission-08-ui-customization.md).

---

[◀ Mission 5](mission-05-user-identity.md) · [Docs home](../README.md) · Next: [Mission 7 ▶](mission-07-embed-in-your-screen.md)
