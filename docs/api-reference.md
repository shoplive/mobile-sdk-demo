# API Reference

[◀ Mission 8](mission-08-go-live.md) · [Docs home](../README.md) · Next: [Platform Differences ▶](platform-differences.md)

> **Guide cross-reference:** [Data field dictionary](https://sdk.shoplive.cloud/#fields) · [ShopliveConfiguration](https://sdk.shoplive.cloud/#f-config) · [Attribution](https://sdk.shoplive.cloud/#f-attr) · [ShopliveUser](https://sdk.shoplive.cloud/#f-user) · [PlayerConfiguration](https://sdk.shoplive.cloud/#f-playerconfig) · [PlayOptions](https://sdk.shoplive.cloud/#f-playoptions) · [Types & states](https://sdk.shoplive.cloud/#types) · [Error handling](https://sdk.shoplive.cloud/#errors)

A lookup table for the public surface, both platforms side by side. This reflects what the demo apps actually compile against:

- **iOS** — `dev` build `5f0ee781` (rebuilt 2026-07-30), local xcframeworks
- **Android** — `cloud.shoplive:shoplive-{player,streamer}-sdk:3.0.0`

Where the two disagree, the difference is called out here and explained in [Platform Differences](platform-differences.md).

---

## Contents

- [Entry points — `Shoplive`](#entry-points--shoplive)
- [`ShopliveConfiguration`](#shopliveconfiguration)
- [`ShopliveUser`](#shopliveuser)
- [Player types](#player-types)
- [`ShoplivePlayerConfiguration`](#shopliveplayerconfiguration)
- [`ShoplivePlayOptions`](#shopliveplayoptions)
- [`ShoplivePlayerControlling` — runtime](#shopliveplayercontrolling--runtime)
- [Delegate: events](#delegate-events)
- [Delegate: requests](#delegate-requests)
- [Enums & states](#enums--states)
- [Error codes](#error-codes)
- [Streamer](#streamer)
- [v3 renames (iOS, breaking)](#v3-renames-ios-breaking)

---

## Entry points — `Shoplive`

| Purpose | iOS | Android |
|---|---|---|
| Initialize (once per app) | `Shoplive.initialize(_ config: ShopliveConfiguration)` | `Shoplive.initialize(context, config)` |
| SDK version | `Shoplive.sdkVersion` | `Shoplive.sdkVersion` |
| Set viewer identity | `Shoplive.setUser(_ user:)` | `Shoplive.setUser(user)` |
| Clear all auth | `Shoplive.logout()` | `Shoplive.logout()` |
| Set broadcast permission | `Shoplive.setStreamToken(_:)` | `Shoplive.setStreamToken(token)` |

`logout()` clears **three slots at once**: `authToken`, `user`, `streamToken`.

Related: [Mission 1](mission-01-open-the-player.md), [Mission 3](mission-03-user-identity.md), [Mission 8](mission-08-go-live.md).

---

## `ShopliveConfiguration`

App-level configuration. **Input-only** — every field is `let`/`val`, so there is no reading it back and no mutating it. To change it, build a new one and call `initialize` again.

| Field | Type | Default | Notes |
|---|---|---|---|
| `accessKey` | `String` | — | **Required.** From the Queenie console. |
| `allowedWebViewDomains` | `[String]` / `List<String>` | `[]` | Whitelist for overlay web view navigation. **Empty disables validation.** |
| `attribution` | `ShopliveAttribution?` | `nil` | 4 UTM fields + ad identifier. On Android this is a **full replace**, not a patch. |

`ShopliveAttribution(utmSource:utmMedium:…)` — see [Attribution](https://sdk.shoplive.cloud/#f-attr) in the guide for the full field list.

---

## `ShopliveUser`

Three variants. Takes effect **from the next playback onward**.

| Variant | iOS | Android |
|---|---|---|
| Token (recommended) | `.token(jwt: String)` | `ShopliveUser.Token(jwt)` |
| Profile | `.profile(id:name:age:gender:rank:)` | `ShopliveUser.Profile(id, name, age, gender, rank, custom)` |
| Guest | `.guest` | `ShopliveUser.Guest` |

### Profile fields

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | **Hash it.** Never pass a raw member ID. |
| `name` | `String?` | Shown as the chat nickname |
| `age` | `Int?` | |
| `gender` | `ShopliveGender` | **Not optional.** `undefined` = not collected (omitted from the payload); `neutral` = explicitly a third gender (sent) |
| `rank` | `Int?` | Member tier score — was `userScore` in v2 |
| `custom` | `Map<String, String>` | **Android only** |

> - **`setUser(.guest)` is a no-op** — it does not clear an existing login. Use `logout()`.
> - **Token beats Profile** — if a token is set, a profile-derived token is ignored.
> - `setUser` is **non-optional** in v3; `setUser(nil)` from v2 no longer compiles.

Details: [Mission 3](mission-03-user-identity.md).

---

## Player types

| | Full screen | Embedded |
|---|---|---|
| iOS | `ShoplivePlayerViewController(campaignKey:options:configuration:)` | `ShoplivePlayerView(configuration:)` |
| Android | `ShoplivePlayer(activity)` → `.start(campaignKey =, options =, configuration =)` | `ShoplivePlayerView(activity)` → `.configuration =` → `.play(campaignKey)` |
| Playback start | Automatic on present | **You call `play()`** |
| Overlay UI | Yes | No — video only |
| Control contract | `ShoplivePlayerControlling` | The same `ShoplivePlayerControlling` |

**Constraints:**

- **iOS:** `campaignKey` is required; there is no "create empty, play later" path. `ShoplivePlayerView()` with no argument and storyboard construction are sealed off — pass `.init()` explicitly for defaults.
- **Android:** the context must be an **Activity** (`LifecycleOwner`). `applicationContext` causes a silent refusal with only a logcat warning.
- **Both:** the delegate is weakly held / instance-owned. Hold it strongly or events stop.
- **Android extras:** `intent()` returns an Intent instead of starting (you own the transition); `bindLifecycle(owner)` on the embedded view ties resource release to a lifecycle; `expandToFullScreen()` hands the session over from embedded to full screen (**no iOS equivalent**).

Details: [Mission 1](mission-01-open-the-player.md), [Mission 4](mission-04-embed-in-your-screen.md).

---

## `ShoplivePlayerConfiguration`

Policy for a playback session. **Immutable once playback starts** — later assignments are ignored (Android logs a warning). Every field has a working default, so `ShoplivePlayerConfiguration()` alone plays correctly.

### Presets

| | iOS | Android |
|---|---|---|
| Full-screen live | `ShoplivePlayerConfiguration.live` | `type = ShoplivePlayerType.LIVE` |
| Embedded preview | `ShoplivePlayerConfiguration.preview` | `type = ShoplivePlayerType.PREVIEW` |

`.preview` differs from `.live` in exactly five values: `pip.isInAppPipEnabled = false`, `pip.isOSPipEnabled = false`, `overlay.ui = .hidden`, `sound.muteOnStart = true`, `appearance.resizeMode = .fill`. It changes **display policy only** — the stream that plays is the same as live.

### `pip`

| Field | iOS | Android | Notes |
|---|---|---|---|
| `isInAppPipEnabled` | ✅ | ✅ | SDK-drawn floating window |
| `isOSPipEnabled` | ✅ | ✅ | System PIP. **Full screen only** — no effect on the embedded view |
| `defaultPosition` | ✅ | ✅ | `ShoplivePipPosition` |
| `scale` | ✅ | ✅ | Fraction of window width, `0...1`. Default 0.4 |
| `padding` | ✅ `UIEdgeInsets` | ✅ `ShopliveInsets` | Default 0 pins to the edge and can look clipped |
| `floatingOffset` | ✅ | ✗ | |
| `fixedWidth` | ✅ | ✗ | |
| `enterOSPipOnBackPressed` | ✗ | ✅ | Back-press goes to OS PIP instead of closing |
| `aspectRatio` | ✗ | ✅ | Default 9:16 |
| `autoEnterOnLeaveScreen` | ✗ **removed** | ✗ | Your app calls `enterPictureInPicture()` instead |
| `keepWindowStyleOnReturnFromOSPip` | ✗ **removed** | ✗ | |

### `sound`

| Field | iOS | Android |
|---|---|---|
| `muteOnStart` | ✅ | ✅ |
| `mixWithOthers` | ✅ | ✅ |
| `autoResumeOnCallEnded` | ✅ | ✗ |
| `autoResumeOnFocusGained` | ✗ | ✅ |
| `isVolumeKeyEnabled` | ✗ | ✅ — `null` follows `type` (LIVE=true, PREVIEW=false) |

### `appearance`

| Field | iOS | Android | Notes |
|---|---|---|---|
| `indicatorColor` | ✅ `UIColor` | ✅ ARGB `Int` | Loading indicator / brand accent |
| `allowScreenCapture` | ✅ | ✅ | **Implementation default is `true`** (the guide says `false` — the guide is wrong). `false` applies `FLAG_SECURE` on Android |
| `chatInputFont` / `chatInputTypeface` | ✅ `UIFont?` | ✅ `Typeface?` | `nil` = SDK default |
| `chatSendButtonFont` | ✅ | ✗ | |
| `resizeMode` | ✅ `ShopliveResizeMode` | (runtime property) | `.fill` / `.fit`, default `.fill` |
| `loadingAnimation` | ✗ | ✅ `@DrawableRes Int?` | `null` = SDK default |
| `isStatusBarVisible` | ✗ **removed** | ✅ | |

### `navigation`

| Field | iOS | Android | Notes |
|---|---|---|---|
| `actionOnNavigation` | ✅ | ✅ | `ShopliveNavigationAction` — with `.pip`, the SDK enters PIP internally on navigation |
| `shareScheme` | ✅ | ✅ | Your app's URL scheme for the overlay share button |
| `closeWhenAppDestroyed` | ✗ | ✅ | |

### `overlay`

| Field | Notes |
|---|---|
| `ui` | `ShopliveOverlayUIMode` — `.builtIn` (default) / `.hidden`. **`hidden` hides display only; the web view stays alive as the command channel, so requests keep arriving.** No public mode destroys the web view. |

### `customParameters`

Extra query parameters appended to the overlay URL. Your hook for passing app context (store ID, A/B bucket, tier) to overlay web content.

Details: [Mission 7](mission-07-ui-customization.md).

---

## `ShoplivePlayOptions`

Per-`play`/`start` values. Distinct from configuration precisely because these differ every time.

| Field | Type | Notes |
|---|---|---|
| `referrer` | `String?` | Traffic source. **Truncated at 1024 chars on Android.** The only link between "which push" and "how long watched" |
| `keepWindowStateOnPlayExecuted` | `Bool` | Preserve window state across a `play` call |

Details: [Mission 2](mission-02-deep-link.md).

---

## `ShoplivePlayerControlling` — runtime

Implemented by **both** the full-screen player and the embedded view, so control code is identical on either path.

| Member | Type | Notes |
|---|---|---|
| `isMuted` | `Bool` get/set | |
| `resizeMode` | `ShopliveResizeMode` get/set | |
| `overlayUI` | `ShopliveOverlayUIMode` get/set | iOS: wired. **Android: not yet wired**, and pinned to `HIDDEN` on the embedded view |
| `state` | `ShoplivePlayerState` get | |
| `isInPictureInPicture` | `Bool` get | The reliable way to confirm PIP |
| `reload()` | | |
| `stop()` | | Required when leaving the screen, or audio keeps playing |
| `send(command:payload:)` | | App → overlay, **send only** (no public receive event) |
| `enterPictureInPicture()` | | Promotes the SDK's internal render surface — you pass no view |
| `exitPictureInPicture()` | | |

**PIP promotion requires all four:** playback active · `isInAppPipEnabled` · the attach window resolves · no other instance floating. **Failure is silent** — verify via `isInPictureInPicture` or `stateChanged(.inAppPIP)`.

Details: [Mission 5](mission-05-pip.md).

---

## Delegate: events

Notifications. Handle what you need, ignore the rest.

| iOS `ShoplivePlayerEvent` | Android `ShoplivePlayerEvent` | Payload / use |
|---|---|---|
| `.stateChanged(ShoplivePlayerState)` | `StateChanged(state)` | Lifecycle + PIP entry. ⚠️ See [Known Issues](known-issues.md#statechanged-never-fires-ios) |
| `.campaignStatusChanged(ShopliveCampaignStatus)` | `CampaignStatusChanged(status)` | ready / live / ended → your LIVE badge |
| `.campaignInfoReceived(ShopliveCampaignInfo)` | `CampaignInfoReceived(info)` | `campaignKey`, `title`, `status` |
| `.playback(PlaybackEvent)` | `Playback(event)` | The reliable playback signal |
| `.connectionStateChanged(ShopliveConnectionState)` | `ConnectionStateChanged(state)` | `.reconnecting` → network banner |
| `.userNameUpdateRequested([String: Any])` | `UserNameUpdateRequested(payload)` | Overlay asks to change the nickname |
| `.analytics(ShopliveAnalyticsInfo)` | `Analytics(info)` | `campaignKey`, `isPlaying`, `isMuted`, `durationMs`, `campaign`, `brand` |
| `.error(ShopliveError)` | `Error(error)` | **Only unrecoverable errors** |

**Threading:** both callbacks are guaranteed on the **main thread**. `respond` may be called from any thread.

**iOS:** `PlaybackEvent` is a **class**, not an enum. Read the state from `playback.event` (`PlaybackEventType`), extra detail from `playback.datas`. Comparing the event object directly (as one guide example does) doesn't work.

**Android:** `ShoplivePlaybackEvent` is a sealed hierarchy — `Requested`, `AudioLoaded`, `Started`, `Rendering`, `Buffering`, `RebufferingStarted`, `RebufferingEnded`, `Ended`, `Failed(code, message)`.

**Two things never arrive as events:** engine failover (HLS ↔ WebRTC) is an SDK internal, and issues being auto-recovered do not produce an `error`.

---

## Delegate: requests

The SDK is asking you something. **Not responding is a bug.**

| Request | iOS | Android | Must you? |
|---|---|---|---|
| Navigation | `.navigation(URL)` | `Navigation(url)` | **Yes.** Without it, product taps do nothing |
| Coupon | `.coupon(id, respond)` | `Coupon(id, respond)` | Respond, or the overlay popup never closes |
| Custom web action | `.customWebAction(id, type, payload, respond)` | `CustomWebAction(id, type, payload, respond)` | Same |

### Response types

```swift
ShopliveCouponResult(couponId: String, success: Bool, message: String?,
                     status: ShopliveResultStatus, alertType: ShopliveResultAlertType)

ShopliveCustomActionResult(id: String, success: Bool, message: String?,
                           status: ShopliveResultStatus, alertType: ShopliveResultAlertType)
```

| Type | Values |
|---|---|
| `ShopliveResultStatus` | `show` / `hide` / `keep` |
| `ShopliveResultAlertType` | `toast` / `alert` |

`success = false` is a valid answer — "out of stock" is a response, not a failure to respond.

> ⚠️ v2's `respond(.success)` shorthand is gone; construct the full result object.

Details: [Mission 6](mission-06-events-products-coupons.md).

---

## Enums & states

| Type | Values |
|---|---|
| `ShoplivePlayerState` | `idle` · `loading` · `playing` · `inAppPIP` · `closed` … |
| `ShopliveCampaignStatus` | `ready` · `live` · `ended` |
| `ShopliveConnectionState` | `connecting` · `connected` · `reconnecting` … |
| `ShopliveResizeMode` | `fill` (default) · `fit` |
| `ShoplivePipPosition` | `bottomRight` (default) · … |
| `ShopliveOverlayUIMode` | `builtIn` (default) · `hidden` |
| `ShopliveNavigationAction` | close · `pip` · … |
| `ShopliveGender` | `male` · `female` · `neutral` · `undefined` |
| `ShoplivePlayerType` (Android) | `LIVE` · `PREVIEW` |
| `ShopliveBroadcastState` | `IDLE` · `LIVE` · `ENDED` (advances by rank; `ENDED` is terminal) |

> ⚠️ **iOS: `@unknown default` is mandatory.** The SDK ships with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so public enums are **resilient**. Omitting `@unknown default` warns today and **errors** under the Swift 6 language mode — even if you list every existing case. For `ShoplivePlayerRequest` this matters doubly: silently ignoring an unknown request means never calling `respond`, which stalls the overlay.
>
> Kotlin `sealed` classes don't have this issue — `when` is exhaustive at compile time.

---

## Error codes

`ShopliveError` carries `code` (`ShopliveErrorCode`), `rawCode`, `isRecoverable`, and `message`. Keep `rawCode` and `message` in your logs even when you show the user a friendly sentence.

| Code | Cause | What to tell the user |
|---|---|---|
| `NOT_INITIALIZED_ACCESS_KEY` (9000) | `initialize` wasn't called, or the key is wrong | Setup problem — check the access key |
| `CAMPAIGN_NOT_FOUND` | No such campaign key | Wrong campaign key |
| `CAMPAIGN_NOT_ON_AIR` | Campaign exists but isn't broadcasting | Not live right now |
| `AUTHENTICATION_FAILED` | Auth rejected | Sign-in needed |
| `GUEST_LOGIN_NOT_ALLOWED` | Campaign requires a login | Sign-in needed |
| `CUSTOM_ACCOUNT_NOT_FOUND` · `CUSTOM_ACCOUNT_EXPIRED` | Account issue | Sign-in needed |
| `INVALID_SIGNATURE` | JWT signature mismatch | Sign-in needed (check your signing secret) |
| `DUPLICATE_SESSION` · `EXPIRED_SESSION` | Session conflict / expiry | Sign in again |
| `CONNECTION_ISSUE` · `FAILED_NETWORK` | Network | Check the connection |
| `SERVER_ERROR` | Server-side | Try again shortly |

There is **no API to pre-validate a key.** `initialize` only stores the value. So the practical pattern is: local format check → play → translate the error event per cause. See `describe(error)` in [`DemoPlayerDelegate.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/DemoPlayerDelegate.kt).

Guide: [Error handling](https://sdk.shoplive.cloud/#errors).

---

## Streamer

| | iOS | Android |
|---|---|---|
| Entry | `ShopliveStreamerViewController(campaignKey:)` | `ShopliveStreamer(activity)` → `.start(campaignKey =, appearance =)` |
| Delegate | `.streamerDelegate` (weak) | `.streamerDelegate` |
| Current state | — | `.state` |
| Appearance | **✗ removed from the public surface** | `ShopliveAppearanceOptions()` — countdown progress, text, cancel button |
| Token | `Shoplive.setStreamToken(_:)` — **required, separate from viewer auth** | same |

**Events** — two channels only:

| Event | Payload |
|---|---|
| `stateChanged` | `ShopliveBroadcastState` (+ `isRehearsal` on Android) |
| `error` | `code`, `rawCode`, `isRecoverable`, `message` |

Failures surface as `.ended`; `error` comes only from the internal `onError`, so there's no duplication. Events before you attach the delegate are **discarded, not replayed** — read `state` once after attaching.

**One session at a time.** `start()` during an active session (not `IDLE`/`ENDED`) is ignored.

Details: [Mission 8](mission-08-go-live.md).

---

## v3 renames (iOS, breaking)

Every public type gained a `Shoplive` prefix. Code written against the old names does not compile.

| v2 / earlier v3 | Current |
|---|---|
| `PlayerState` | `ShoplivePlayerState` |
| `CampaignStatus` | `ShopliveCampaignStatus` |
| `ConnectionState` | `ShopliveConnectionState` |
| `ResizeMode` | `ShopliveResizeMode` |
| `PipPosition` | `ShoplivePipPosition` |
| `OverlayUIMode` | `ShopliveOverlayUIMode` |
| `NavigationAction` | `ShopliveNavigationAction` |
| `CampaignInfo` | `ShopliveCampaignInfo` |
| `PlayerConfiguration` | `ShoplivePlayerConfiguration` |
| `PlayOptions` | `ShoplivePlayOptions` |
| `PlayerEvent` / `PlayerRequest` | `ShoplivePlayerEvent` / `ShoplivePlayerRequest` |
| `Attribution` | `ShopliveAttribution` |
| `Gender` | `ShopliveGender` |
| `ErrorCode` | `ShopliveErrorCode` |
| `BroadcastState` / `StreamerEvent` | `ShopliveBroadcastState` / `ShopliveStreamerEvent` |
| `ShopLiveAnalyticsInfo` | `ShopliveAnalyticsInfo` (lowercase `l`) |
| `ShopLivePlayerCampaign` | `ShopliveCampaign` (lowercase `l`) |

**Nested option types are unchanged** — `PipOptions`, `SoundOptions`, `AppearanceOptions`, `NavigationOptions`, `OverlayOptions` still live inside `ShoplivePlayerConfiguration` under their original names.

**Deleted fields** (referencing them is a compile error): `PipOptions.keepWindowStyleOnReturnFromOSPip`, `PipOptions.autoEnterOnLeaveScreen`, `AppearanceOptions.isStatusBarVisible`, and the Streamer's `ShopliveAppearanceOptions`.

Guide: [v2 → v3 migration](https://sdk.shoplive.cloud/#migration).

---

[◀ Mission 8](mission-08-go-live.md) · [Docs home](../README.md) · Next: [Platform Differences ▶](platform-differences.md)
