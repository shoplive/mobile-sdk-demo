# Mission 8 — Go Live (Broadcasting)

[◀ Mission 7](mission-07-ui-customization.md) · [Docs home](../README.md) · Next: [API Reference ▶](api-reference.md)

> **Guide cross-reference:** [Mission 8 · Broadcasting](https://sdk.shoplive.cloud/#m8) · [Step 1 · Setting the stream token](https://sdk.shoplive.cloud/#m8-1) · [Studio screen](https://sdk.shoplive.cloud/#screens-streamer)
>
> **Source:** [`ShopliveIntegration/StudioLauncher.swift`](../iOS/ShopliveIntegration/StudioLauncher.swift) · [`sdk/StudioLauncher.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/StudioLauncher.kt)
>
> **In the app:** card ⑧ — *"Go live"*. Locked unless a stream token is present.

---

## What you're building

The broadcaster side. Camera preview, camera switching, zoom, chat, settings, the "Live in 3, 2, 1" countdown — **the SDK provides the entire studio UI.** There is nothing for you to draw.

**Checkpoint:** preview → LIVE transition, with automatic recovery on interruption.

Resolution and bitrate are **server-driven**, so no app code is needed for them either. Broadcasting is genuinely the smallest integration in this set — the complexity is all in the permissions and the token.

---

## The whole thing

### iOS

```swift
import ShopliveCore
import ShopliveStreamerSDK

// 1) Stream token — required
Shoplive.setStreamToken(streamToken)

// 2) Launch the studio
let studio = ShopliveStreamerViewController(campaignKey: campaignKey)
studio.streamerDelegate = DemoStreamerDelegate.shared   // weak — you own its lifetime
studio.modalPresentationStyle = .fullScreen
present(studio, animated: true)
```

### Android

```kotlin
// 1) Stream token — required
Shoplive.setStreamToken(streamToken)

// 2) Launch the studio
val streamer = ShopliveStreamer(activity)               // must be an Activity — see below
streamer.streamerDelegate = MyStreamerDelegate()
streamer.start(
    campaignKey = campaignKey,
    appearance = ShopliveAppearanceOptions(),           // Android only — countdown look
)
```

---

## ⚠️ The stream token is a completely separate path from viewer auth

This is the single most common misunderstanding in this mission.

| | Sets | Cleared by |
|---|---|---|
| `Shoplive.setUser(...)` | **Viewer** identity | `Shoplive.logout()` |
| `Shoplive.setStreamToken(...)` | **Broadcast** permission | `Shoplive.logout()` |

**Setting one does not fill the other.** A logged-in viewer cannot broadcast; calling `setUser` for your host account changes nothing about broadcast permission. Present the studio without a token and assembly fails with an authentication error.

Note that `logout()` clears **both** (plus `authToken`). So if your app logs the user out anywhere in the broadcast flow, you must call `setStreamToken` again before starting. See [Mission 3](mission-03-user-identity.md).

**In the demo:** the stream token is stored in the iOS **Keychain** (not `UserDefaults`, unlike the access/campaign keys) and card ⑧ is **locked whenever no token is present** — on both platforms, in both tour and own-account mode. There's no point offering a button that cannot work.

---

## Permissions

### iOS

`Info.plist` must contain both, or the app crashes when the studio requests the camera:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to broadcast live video.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to broadcast live audio.</string>
```

Both are already present in the demo's Info.plist.

### Android

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

`CAMERA` is declared in the AAR and merges in automatically. **`RECORD_AUDIO` is not** — you must declare it yourself. This is the easiest thing to forget, and the symptom is a broadcast with no audio.

> **Runtime prompts are handled for you — but only via `start()`.** `ShopliveStreamer.start()` requests camera and microphone permissions on your behalf, using the Activity's `lifecycleScope`. If you build the Intent yourself with `intent()`, **it does not** — you request them.
>
> This is also why **the context must be an Activity**: the permission request needs a lifecycle scope. Same rule as the player ([Mission 1](mission-01-open-the-player.md)).

---

## Receiving broadcast state

Streamer events come on exactly two channels: state transitions and errors.

### iOS

```swift
final class DemoStreamerDelegate: NSObject, ShopliveStreamerDelegate {

    static let shared = DemoStreamerDelegate()

    func streamer(_ streamer: ShopliveStreamerViewController,
                  didReceive event: ShopliveStreamerEvent) {
        switch event {
        case .stateChanged(let state):
            // ShopliveBroadcastState
            onStateChanged?(state)

        case .error(let error):
            // error.code, error.isRecoverable, error.message
            break

        @unknown default:
            break   // required — resilient enum
        }
    }
}
```

### Android

```kotlin
override fun onEvent(streamer: ShopliveStreamer, event: ShopliveStreamerEvent) {
    when (event) {
        is ShopliveStreamerEvent.StateChanged -> {
            // event.state, event.isRehearsal
            if (event.state == ShopliveBroadcastState.LIVE) progress.markBroadcastLive()
        }

        is ShopliveStreamerEvent.Error -> {
            if (!event.error.isRecoverable) onFatalError(event.error.message)
        }
    }
}
```

### Four rules about state

1. **States only advance by rank.** A late-arriving signal can't move a session backwards.
2. **`ENDED` is terminal.**
3. **Failures surface as `.ended`.** `error` is emitted only from the internal `onError` path, so there's no duplication — you won't get both for the same failure.
4. **Events before you attach the delegate are discarded, not replayed.** So read `state` once immediately after attaching to sync up:

```kotlin
streamer.streamerDelegate = MyStreamerDelegate()
DemoLog.event("StreamerEvent subscribed — current state: ${streamer.state}")
```

Skip that read and your UI can start out one state behind reality.

---

## One session at a time

Call `start()` again while a session is in progress (any state other than `IDLE` / `ENDED`) and it is **ignored**. If a new session does take the slot, the previous one receives an end notification.

The Android demo guards this by keeping the current streamer in a `@Volatile` field and exposing `state`:

```kotlin
object StudioLauncher {
    @Volatile private var current: ShopliveStreamer? = null

    val state: ShopliveBroadcastState
        get() = current?.state ?: ShopliveBroadcastState.IDLE
}
```

---

## Rehearsal mode is decided by the server

You don't pass a "this is a rehearsal" flag. The SDK fetches the campaign config and decides on its own — which is why the public entry point takes only `campaignKey`.

On Android you can *read* the answer: `ShopliveStreamerEvent.StateChanged` carries `isRehearsal`. Use it for a "REHEARSAL" badge, not for control flow.

---

## ⚠️ Studio appearance: iOS and Android diverge here

| | iOS (`3.0.0`, dev `5f0ee781`) | Android (`3.0.0`) |
|---|---|---|
| Appearance options | **Removed from the public surface** | `ShopliveAppearanceOptions()` |
| Constructor | `init(campaignKey:)` only | `start(campaignKey =, appearance =)` |
| Customizable | **Nothing** | Countdown progress, text, cancel button |

On the iOS build this demo targets, `ShopliveAppearanceOptions` and the `appearance:` parameter on `Shoplive.present(...)` were both **deleted**. There is currently **no public way to customize the studio's fonts or colors on iOS.** The demo's `StudioLauncher.swift` has a `NOTE` comment where the helper used to be, rather than dead code.

If studio branding matters to your iOS product, raise it with your ShopLive contact — it needs SDK work. Tracked in [Platform Differences](platform-differences.md).

---

## How the demo runs this mission

Card ⑧ sets the token, launches the studio, and returns. The "done" badge appears on `StreamerEvent.stateChanged(LIVE)` — actually going live, not merely opening the studio.

The token is masked to 8 characters in the log, like every other credential:

```
→SDK  setStreamToken("1-5QALAn…")
→SDK  ShopliveStreamer(activity).start(campaignKey: "faea28dd96c3")
```

> **Not yet verified:** broadcast start and the camera/microphone permission flow have **not** been confirmed on real hardware — emulators have camera limitations that make this specific mission hard to validate. This is on the manual real-device checklist. See [Known Issues](known-issues.md#not-yet-verified).

---

## Where to go from here

You've covered the whole feature set. Useful next stops:

| | |
|---|---|
| [API Reference](api-reference.md) | Every public type and field, both platforms, side by side |
| [Platform Differences](platform-differences.md) | What exists on one platform and not the other |
| [Known Issues](known-issues.md) | Measured behaviors, guide-vs-reality gaps, troubleshooting |
| [v2 → v3 migration](https://sdk.shoplive.cloud/#migration) | If you're upgrading an existing integration |

---

[◀ Mission 7](mission-07-ui-customization.md) · [Docs home](../README.md) · Next: [API Reference ▶](api-reference.md)
