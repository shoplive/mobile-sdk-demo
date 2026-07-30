# Platform Differences (iOS ↔ Android)

[◀ API Reference](api-reference.md) · [Docs home](../README.md) · Next: [Known Issues ▶](known-issues.md)

> **Guide cross-reference:** [Types & states](https://sdk.shoplive.cloud/#types) · [PlayerConfiguration](https://sdk.shoplive.cloud/#f-playerconfig) · [Troubleshooting & FAQ](https://sdk.shoplive.cloud/#faq)

If you're integrating both platforms, read this page before you write shared design docs — several fields exist on one side only, and one capability is genuinely missing on iOS.

**Snapshots compared:**

| | Version | Built from | Delivery |
|---|---|---|---|
| iOS | `3.0.0` | `dev` commit `5f0ee781` | Local xcframeworks in `iOS/Frameworks/` |
| Android | `3.0.0` | Published artifacts | Private Maven |

Both report the same version number, but they are **not the same build** — which is why the differences below exist at all.

Some of the differences below are **snapshot skew** (one platform is simply ahead) rather than deliberate design. Those are marked, since they may resolve on their own.

---

## 1. The big one: no session hand-off on iOS

| | Android | iOS |
|---|---|---|
| Embedded → full screen | `expandToFullScreen()` hands the live session over | **No equivalent API** |
| Cost | None | Tear down + re-present = one extra reload |

The iOS demo works around it by stopping the embedded session and presenting a fresh full-screen VC, which re-resolves the stream:

```swift
public func expandToFullScreen(from presenter: UIViewController, …) -> ShoplivePlayerViewController? {
    guard let campaignKey else { return nil }
    stop()
    return PlayerLauncher.present(campaignKey: campaignKey, from: presenter, …)
}
```

**Design impact:** if your product treats "tap the inline preview to go full screen" as a core flow, budget for a visible reload on iOS, or raise it with your ShopLive contact — it's SDK-side work an app can't paper over.

Details: [Mission 4](mission-04-embed-in-your-screen.md#promoting-to-full-screen).

---

## 2. Studio customization

| | Android | iOS |
|---|---|---|
| Appearance options | `ShopliveAppearanceOptions()` — countdown progress, text, cancel button | **Removed from the public surface** |
| Constructor | `start(campaignKey =, appearance =)` | `init(campaignKey:)` only |

On the iOS build this demo targets, both `ShopliveAppearanceOptions` and the `appearance:` parameter on `Shoplive.present(...)` were **deleted**. There is currently **no public way to customize the studio's fonts or colors on iOS.** The demo's `StudioLauncher.swift` carries a `NOTE` comment where the helper used to be.

Details: [Mission 8](mission-08-go-live.md#-studio-appearance-ios-and-android-diverge-here).

---

## 3. User profile: `custom`

| | Android | iOS |
|---|---|---|
| Arbitrary key-values | `custom: Map<String, String>` | **Not available** |
| Tier score | `rank: Int?` | `rank: Int?` |

The integration guide shows `.profile(..., custom: ["grade": "vip"])` for iOS. **That does not compile** on this build — iOS has `rank` only. If you need extra attributes on iOS today, encode them into a server-signed JWT (the token approach) instead.

Details: [Mission 3](mission-03-user-identity.md#field-notes).

---

## 4. Field-by-field configuration matrix

Legend: ✅ available · ✗ not available · ⚠️ available but see the note

### `pip`

| Field | iOS | Android |
|---|---|---|
| `isInAppPipEnabled` | ✅ | ✅ |
| `isOSPipEnabled` | ⚠️ wired, real-device behavior unverified | ✅ (full screen only) |
| `defaultPosition` | ✅ | ✅ |
| `scale` | ✅ | ✅ |
| `padding` | ✅ `UIEdgeInsets` | ✅ `ShopliveInsets` |
| `floatingOffset` | ✅ | ✗ |
| `fixedWidth` | ✅ | ✗ |
| `enterOSPipOnBackPressed` | ✗ | ✅ |
| `aspectRatio` | ✗ | ✅ |
| `autoEnterOnLeaveScreen` | ✗ removed | ✗ never shipped |
| `keepWindowStyleOnReturnFromOSPip` | ✗ removed | ✗ |

### `sound`

| Field | iOS | Android |
|---|---|---|
| `muteOnStart` | ✅ | ✅ |
| `mixWithOthers` | ✅ | ✅ |
| `autoResumeOnCallEnded` | ✅ | ✗ |
| `autoResumeOnFocusGained` | ✗ | ✅ |
| `isVolumeKeyEnabled` | ✗ | ✅ |

The last two reflect real platform semantics rather than an oversight: Android has an audio-focus model and hardware volume keys the SDK can intercept; iOS has call interruption.

### `appearance`

| Field | iOS | Android |
|---|---|---|
| `indicatorColor` | ✅ `UIColor` | ✅ ARGB `Int` |
| `allowScreenCapture` | ⚠️ wired, unverified on device | ✅ (`FLAG_SECURE`) |
| `chatInputFont` / `chatInputTypeface` | ✅ | ✅ |
| `chatSendButtonFont` | ✅ | ✗ |
| `resizeMode` | ✅ under `appearance` | ✅ as a runtime property |
| `loadingAnimation` | ✗ | ✅ `@DrawableRes` |
| `isStatusBarVisible` | ✗ removed | ✅ |

### `navigation`

| Field | iOS | Android |
|---|---|---|
| `actionOnNavigation` | ✅ | ✅ |
| `shareScheme` | ✅ | ✅ |
| `closeWhenAppDestroyed` | ✗ | ✅ |

### Presets / type

| | iOS | Android |
|---|---|---|
| Named presets | `ShoplivePlayerConfiguration.live` / `.preview` | ✗ |
| Type field | ✗ | `type = ShoplivePlayerType.LIVE / PREVIEW` |

Same intent, different mechanism. On iOS the preset bundles five display-policy values; on Android `type` drives volume-key policy and received stream resolution. **They are not exact equivalents** — if you want identical behavior on both, set the individual fields explicitly rather than assuming the preset and the type match.

---

## 5. Runtime property support

| Property | iOS | Android |
|---|---|---|
| `isMuted` | ✅ | ✅ |
| `resizeMode` | ✅ | ✅ |
| `overlayUI` | ✅ configuration path wired; runtime toggle works | ⚠️ **runtime setter not yet wired**; pinned `HIDDEN` on the embedded view |
| `reload()` · `stop()` · `send()` | ✅ | ✅ |
| `enterPictureInPicture()` / `exit` | ✅ | ✅ |
| `isInPictureInPicture` | ✅ | ✅ |

**On Android, to be certain an overlay mode is applied, replay with an `overlay.ui` configuration** rather than assigning the runtime property. Noted in [`PlayerSession.kt`](../Android/app/src/main/java/cloud/shoplive/onboarding/sdk/PlayerSession.kt).

---

## 6. Language & enum exhaustiveness

| | iOS | Android |
|---|---|---|
| Public enums | **Resilient** (library evolution). `@unknown default` is **mandatory** — a warning today, an **error** under the Swift 6 language mode | Kotlin `sealed` — `when` is exhaustive at compile time |
| Playback event shape | `PlaybackEvent` is a **class**; state is in `.event` (`PlaybackEventType`), detail in `.datas` | `ShoplivePlaybackEvent` is a sealed hierarchy you destructure directly |
| Delegate methods | `player(_:didReceive:)` / `player(_:didRequest:)` | `onEvent(player, event)` / `onRequest(player, request)` |

The Swift consequence is worth repeating: for **requests**, an unhandled case means `respond` is never called, and the overlay stalls. Log loudly in `@unknown default` so an SDK upgrade doesn't fail quietly.

---

## 7. Structural / hosting differences

These come from the platforms themselves, but they change how much app code you write.

| | iOS | Android |
|---|---|---|
| Player hosting | A **ViewController** you present — so you can wrap it as a child VC and add sibling controls on top | An **SDK-owned Activity** — you cannot draw over it from your own composition |
| Showing something over the player | Add sibling views to your host VC ([`PlayerHostOverlay.swift`](../iOS/ShopliveOnboardingDemo/Screens/PlayerHostOverlay.swift)) | **`Toast` only.** A Compose Snackbar sits behind the SDK Activity and is invisible |
| Product detail destination | A modal presented from the host VC | **A separate Activity** — it has to be launched over the SDK Activity |
| Deep-link entry | `SceneDelegate` — **two** methods (`willConnectTo` + `openURLContexts`) | A dedicated `SchemeActivity` that parses and forwards |
| Getting a presenter | Walk the window/VC hierarchy yourself | Track the foreground Activity (`ActivityLifecycleCallbacks`) |
| Embedded in a list | `UICollectionView` cells recycle — same hazard | `LazyColumn` disposes off-screen items — **use `Column + verticalScroll`** |
| Credential storage in the demo | Keychain (stream token), `UserDefaults` (keys) | `EncryptedSharedPreferences` where available |

The Android "Toast only" constraint is a genuinely useful thing to know before you design your error UX — it's why the demo notifies repeated playback failure with a `Toast` and keeps the long-form text for the log.

---

## 8. Observed behavior differences

Same class of problem, different symptom. Both measured 2026-07-30 — full detail in [Known Issues](known-issues.md).

| | iOS | Android |
|---|---|---|
| `stateChanged` during healthy playback | **Never fires** (fires only on `.inAppPIP` entry) | Fires normally (`LOADING`, `IN_APP_PIP`, `CLOSED`, …) |
| Stream missing / 404 | `error(.unexpectedError, isRecoverable: false)` **twice per second**, no HLS fallback | `playback(failed(404))` every ~5s and **`Error` never fires at all** |
| `campaignInfoReceived` / `campaignStatusChanged` | Delivered on the current build | **Did not fire** in the 404 case |
| Silent HLS fallback | Confirmed — WebRTC egress 404 while LL-HLS played, with zero error events | — |

**The portable lesson:** judge "playback reached" from `playback(started/rendering)` on both platforms, and never treat "no error event" as "everything is fine". Both demos count failures themselves.

---

## 9. Localization behavior

| | iOS | Android |
|---|---|---|
| Follows device language | **Yes** (ko/ja recognized, else falls back to en) | **No** — explicit in-app selector, persisted |
| Mechanism | `.lproj` bundles + `CFBundleDevelopmentRegion = en` | Custom `LocaleSetting` + `attachBaseContext` (not Android 13+ per-app languages, so behavior is identical down to minSdk 24) |
| SDK-drawn screens | Not affected by your app's setting | Not affected by your app's setting |
| Developer log | English only, by design | English only, by design |

---

## 10. Checklist for cross-platform integrations

Concrete things to decide once, before either platform starts coding:

- [ ] **Embedded → full screen**: does your design depend on seamless hand-off? If yes, iOS needs a different UX or an SDK change.
- [ ] **Studio branding**: if you need it, iOS can't do it today.
- [ ] **Extra profile attributes**: don't build on `custom` unless you're Android-only, or use the token approach.
- [ ] **Playback-reached signal**: standardize on `playback(started/rendering)` for both.
- [ ] **Failure detection**: implement your own repeated-failure counter on both; don't rely on `error`.
- [ ] **Over-player UI**: on Android, plan for `Toast`-only. Don't design a Snackbar flow that can't render.
- [ ] **List embedding**: no lazy containers on either platform.
- [ ] **`resizeMode` in embeds**: on iOS it currently renders like `.fit` — don't build a design that requires true `.fill` in a small box yet.
- [ ] **Preset vs. explicit fields**: set fields explicitly if you need iOS and Android to behave identically.

---

[◀ API Reference](api-reference.md) · [Docs home](../README.md) · Next: [Known Issues ▶](known-issues.md)
