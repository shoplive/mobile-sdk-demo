# Mission 6 — Events · Products · Coupons

[◀ Mission 5](mission-05-pip.md) · [Docs home](../README.md) · Next: [Mission 7 — Customize the UI ▶](mission-07-ui-customization.md)

> **Guide cross-reference:** [Mission 6 · Events, products, coupons](https://sdk.shoplive.cloud/#m6) · [Types & states](https://sdk.shoplive.cloud/#types) · [Error handling](https://sdk.shoplive.cloud/#errors)
>
> **Source:** [`ShopliveIntegration/DemoPlayerDelegate.swift`](../iOS/ShopliveIntegration/DemoPlayerDelegate.swift) · [`sdk/DemoPlayerDelegate.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt)
>
> **In the app:** card ⑥ — *"Events · products · coupons"*. Opens the Log tab automatically. Tap products and coupons and watch what arrives.

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

Both callbacks are **guaranteed to arrive on the main thread**. The `respond` callback may be called from **any** thread — which is intentional, since responding after a server round-trip is the normal case.

**Memory:** the delegate is weakly held on iOS and instance-owned on Android. If nothing owns it, events stop arriving with no warning. That's why the demo holds it in a singleton / in `PlayerSession`.

---

## Part 1 — Events (notifications)

### iOS

```swift
func player(_ player: ShoplivePlayerControlling, didReceive event: ShoplivePlayerEvent) {
    switch event {

    case .stateChanged(let state):
        // Playback lifecycle. Entering/leaving .inAppPIP also arrives here.
        onPipStateChanged?(state == .inAppPIP)

    case .campaignStatusChanged(let status):
        // .ready / .live / .ended — drive your LIVE badge from this.
        break

    case .campaignInfoReceived(let info):
        // info.campaignKey, info.title, info.status
        break

    case .playback(let playback):
        // PlaybackEvent is a CLASS. The state is in `.event`, details in `.datas`.
        if playback.event == .started || playback.event == .rendering {
            onPlaybackReached?()
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
        if !error.isRecoverable { onFatalError?(error) }

    // Required: the SDK's enums are resilient (library evolution).
    @unknown default:
        break
    }
}
```

### Android

```kotlin
override fun onEvent(player: ShoplivePlayerControlling, event: ShoplivePlayerEvent) {
    when (event) {
        is ShoplivePlayerEvent.StateChanged -> when (event.state) {
            ShoplivePlayerState.LOADING    -> { /* new session — reset your counters here */ }
            ShoplivePlayerState.IN_APP_PIP -> progress.markPipEntered()
            // Session over — drop the control handle so you don't command a dead player.
            ShoplivePlayerState.CLOSED     -> PlayerSession.detach(player)
            else -> Unit
        }

        is ShoplivePlayerEvent.CampaignStatusChanged -> { /* READY / LIVE / ENDED */ }
        is ShoplivePlayerEvent.CampaignInfoReceived  -> { /* event.info.title, .status */ }

        is ShoplivePlayerEvent.Playback -> when (val pb = event.event) {
            is ShoplivePlaybackEvent.Started   -> progress.markPlaybackStarted()
            is ShoplivePlaybackEvent.Rendering -> { /* frames are on screen */ }
            is ShoplivePlaybackEvent.Failed    -> onRepeatedPlaybackFailure(pb.code)
            else -> Unit
        }

        is ShoplivePlayerEvent.ConnectionStateChanged -> { /* reconnecting banner */ }
        is ShoplivePlayerEvent.UserNameUpdateRequested -> { /* open profile */ }
        is ShoplivePlayerEvent.Analytics -> { /* forward to your analytics */ }

        is ShoplivePlayerEvent.Error -> {
            if (!event.error.isRecoverable) onFatalError(describe(event.error))
        }
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
    onNavigation?(url)
```

```kotlin
is ShoplivePlayerRequest.Navigation -> {
    ProductRouter.open(request.url)
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

On iOS the same problem is solved differently: the demo hosts the player as a child view controller, so it can present the product detail modal from a host it controls.

**Related:** `navigation.actionOnNavigation` decides what happens to the *player* on navigation — close it, or shrink to PIP. See [Mission 5](mission-05-pip.md).

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
PlayerSession.send("HIGHLIGHT_PRODUCT", mapOf("sku" to sku))
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

The iOS demo takes the equivalent approach: don't close the player, explain the reason **once per session**, and keep the host-owned **‹ List** button available as the escape hatch.

If and when the SDK delivers `error` correctly here, these workarounds can be deleted. Both are marked in the source.

---

## Translate error codes into sentences

There's no API to pre-validate a key, so a bad access key, a missing campaign, an auth problem, and a network failure are indistinguishable until the error event arrives. Map them once:

```kotlin
private fun describe(error: ShopliveError): String {
    val causeRes = when (error.code) {
        ShopliveErrorCode.NOT_INITIALIZED_ACCESS_KEY -> R.string.err_access_key
        ShopliveErrorCode.CAMPAIGN_NOT_FOUND         -> R.string.err_campaign_not_found
        ShopliveErrorCode.CAMPAIGN_NOT_ON_AIR        -> R.string.err_not_on_air

        ShopliveErrorCode.AUTHENTICATION_FAILED,
        ShopliveErrorCode.GUEST_LOGIN_NOT_ALLOWED,
        ShopliveErrorCode.CUSTOM_ACCOUNT_NOT_FOUND,
        ShopliveErrorCode.CUSTOM_ACCOUNT_EXPIRED,
        ShopliveErrorCode.INVALID_SIGNATURE,
        ShopliveErrorCode.DUPLICATE_SESSION,
        ShopliveErrorCode.EXPIRED_SESSION            -> R.string.err_auth_required

        ShopliveErrorCode.CONNECTION_ISSUE,
        ShopliveErrorCode.FAILED_NETWORK             -> R.string.err_network
        ShopliveErrorCode.SERVER_ERROR               -> R.string.err_server
        else                                         -> R.string.err_other
    }
    return "error(code: ${error.code}, rawCode: ${error.rawCode}, " +
           "isRecoverable: ${error.isRecoverable}) ${DemoContainer.string(causeRes)} · ${error.message}"
}
```

Note it keeps `rawCode` and `message` alongside the friendly sentence — the user reads the sentence, and your bug report needs the raw values. Full table: [API Reference § Error codes](api-reference.md#error-codes).

---

## How the demo runs this mission

Card ⑥ starts playback and **auto-opens the Log tab**, because reading the log *is* the mission. Every request is logged as a pair:

```
REQUEST  coupon(id: "CPN-1", respond:) received
REQUEST  → respond(success: true, status: .show, alertType: .toast) called
```

Pairing them makes a missing `respond` visible at a glance — which is the whole reason it's formatted that way.

The "done" badge appears as soon as **any** `navigation` or `coupon` request arrives, since receiving one proves the channel works.

---

## Next

[Mission 7 — Customize the UI ▶](mission-07-ui-customization.md) — including the "hide the built-in overlay and draw your own" mode, which depends entirely on the requests you just wired up.

---

[◀ Mission 5](mission-05-pip.md) · [Docs home](../README.md) · Next: [Mission 7 ▶](mission-07-ui-customization.md)
