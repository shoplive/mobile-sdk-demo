# ShopLive unified SDK v3 — iOS onboarding demo app

A UIKit demo app built so that integrators can finish their integration by **following the missions and pasting the code from `Integration/` straight into their own app**.

- Integration guide: <https://sdk.shoplive.cloud> (mission numbers 1–8 match the card numbers in this app)
- Screen design rationale: `shoplive-onboarding-demo-prototype.html` (3 screens · 2 overlays · 8 features)

---

## 1. Running it

```bash
open ShopliveOnboardingDemo.xcodeproj
```

**Xcode is the only thing you need.** There is no project generator, package manager, or CLI tool to install.
The SDK arrives through Xcode's built-in SPM on the first build (so network access is needed once), and the
revision it fetches is pinned by
`ShopliveOnboardingDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

It runs on both the simulator and a device. Built-in demo campaign keys are included, so you can walk through
missions 1–7 with **no input at all** via "take a tour · start now".
Mission 8 (broadcasting) needs a stream token, and **tokens are not kept in source**, so it stays locked until you
type one in on S1 (what you type is stored in the Keychain only).

Add files and change build settings **directly in Xcode** — there is no regeneration step.

> To change the SDK version, edit the version in Xcode's Package Dependencies and commit the updated
> `Package.resolved` together with the `.xcodeproj`.

---

## 2. Code structure — two layers, enforced by the compiler

| Directory | What it is |
|---|---|
| **`Integration/`** | ★ **The copy target.** SDK calls only. **Zero** harness dependencies — copy the folder wholesale and it compiles. |
| `Screens/` · `Support/` · `App/` | The demo harness (mission list, log sheet, options, theme, localization). **Not** a copy target. |

The boundary is enforced by **two mechanisms**, not by documentation.

**① Boundary scanner** — fails if a harness symbol (`EventLog`, `DemoTheme`, `L("…")`, …) shows up in `Integration/`.
```bash
python3 scripts/integration_boundary_scanner.py
```

**② The copy-paste proof target `IntegrationCopyPasteProof`** — a framework target whose **only** sources are `Integration/**`.
It reproduces exactly the condition of an integrator dropping `Integration/` into an empty project, so a single harness
dependency breaks the build.
```bash
xcodebuild -project ShopliveOnboardingDemo.xcodeproj -scheme IntegrationCopyPasteProof \
  -destination 'generic/platform=iOS' build
```
> This target catches what the scanner cannot. During refactoring it actually caught dependencies on `demoLabel`
> (a harness extension) and `PlayerConfigurationFactory.make()` (options-tab only).

### `Integration/` has exactly three outward hooks

Which means these are the only places you touch after copying it.

| Hook | Default | Purpose |
|---|---|---|
| `shopliveLog(_:_:)` | no-op | Logging. Plug in your own logger, or delete the call sites. |
| `DeepLinkRouter.configurationProvider` | `.init()` | Which configuration deep-link playback should use |
| `DeepLinkRouter.delegateProvider` | `nil` | Which delegate receives deep-link playback events |

The demo wires all three in one place, `App/DemoBootstrap.swift` — a worked example of what an integrator's app has to connect.

### Mission ↔ file map

The 📄 path printed on each card in the app is this table.

| Mission | What it covers | File |
|---|---|---|
| — | Initialization (once per app) | `Integration/ShopliveBootstrap.swift` |
| 1 | Present the player | `Integration/PlayerLauncher.swift` |
| 2 | Open from a deep link | `Integration/DeepLinkRouter.swift` + `App/SceneDelegate.swift` |
| 3 | Connect member info | `Integration/UserSetup.swift` |
| 4 | Embed in a screen | `Integration/EmbeddedPlayerView.swift` |
| 5 | Apply PIP | `Integration/PipOptions.swift` |
| 6 | Events · products · coupons | `Integration/DemoPlayerDelegate.swift` |
| 7 | UI customization | `Integration/PlayerConfigurationFactory.swift` |
| 8 | Broadcasting | `Integration/StudioLauncher.swift` |
| Shared | Log hook / enum labels | `Integration/ShopliveLog.swift` · `ShopliveLabels.swift` |

---

## 3. Frameworks

The SDK comes in through **Xcode's built-in SPM** — exactly the way an integrator gets it.
The package is registered in the project itself (Xcode → Package Dependencies), so there is no separate manifest file.

```
https://github.com/shoplive/shoplive-sdk-ios     Exact 3.0.0

The two libraries linked by the app target and the copy-paste proof target:
  ShoplivePlayerSDK
  ShopliveStreamerSDK
```

**You declare only two**, and the other three ride along inside them.

| xcframework | What it is | Declared directly |
|---|---|---|
| `ShoplivePlayerSDK` | Watching — HLS/WebRTC engines built in · automatic failover · PIP · overlay | ✅ |
| `ShopliveStreamerSDK` | Broadcasting — the entire studio UI (WebRTC · RTMP) | ✅ |
| `ShopliveCore` | Shared — auth · configuration · user · errors | automatic |
| `ShopLiveWebRTCHelperSDK` | Internal dependency of Player/Streamer | automatic |
| `WebRTC` | `rtc-ios` 1.0.26 binary (~34MB dynamic framework) | automatic |

Slices in each: `ios-arm64` (device) + `ios-arm64_x86_64-simulator`. Built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`,
so they carry `.swiftinterface`.

You do not need to `import ShopliveCore` either. The Player and Streamer modules re-export it via
`@_exported import ShopliveCore`, so `import ShoplivePlayerSDK` alone puts `Shoplive.*` in scope.

Xcode downloads the binaries into DerivedData, so they never enter the repository. The revision is pinned by
`ShopliveOnboardingDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
(currently `3.0.0` = `a1a168a6`). **Xcode embeds the five xcframeworks into the app bundle automatically** — there is
no separate Embed step.

### Reproducing the build (from SDK source)

Extracted from **`matrix-sdk-ios`, branch `chore/sdk-version-3.0.0`, `36a7157a`** (rebuilt 2026-07-30).
That commit is `dev` (`5f0ee781`) plus **five version constants bumped to `3.0.0`** and nothing else, so there is no
behavioral change — it exists to align the version string with Android (`3.0.0`).
That `Shoplive.sdkVersion` returns `3.0.0` was verified by measurement, via the developer sheet log on the simulator.
(The build before that was based on `feature/SMV-1446-repack-player` `8d66bcd6` — the API differences are in §7.)

Procedure (this uses the **SDK repository's own** tooling, not this demo's):

```bash
cd matrix-sdk-ios            # use-international.sh is unnecessary if the line symlink is already international
git switch chore/sdk-version-3.0.0

bash scripts/run-tuist.sh generate --no-open
# ① archive the 4 schemes (ShopliveCore · ShopLiveWebRTCHelperSDK · ShoplivePlayerSDK · ShopliveStreamerSDK)
#    for iphoneos / iphonesimulator (BUILD_LIBRARY_FOR_DISTRIBUTION=YES)
#    → xcodebuild -create-xcframework
# ② WebRTC is not rebuilt — the existing binary is reused
#    (copy .build/checkouts/rtc-ios/Frameworks/WebRTC.xcframework if needed)
```

> **The version constants only physically exist inside `ShopliveCore`.** They are `package`-scoped, so dependent
> modules do not inline them but read them at runtime — meaning the only binary that materially changes on a rebuild
> is `ShopliveCore`.
>
> ⚠️ **You cannot verify the version in the binary with `strings`.** Both `"3.0.0"` and `"2.0.20.1"` are 15 bytes or
> fewer, so Swift's small-string optimization inlines them into code as immediates (no string literal remains).
> Always check at runtime (`Shoplive.sdkVersion`).

> The dead module references in `ShopLiveTestApp/Project.swift` (`Modules/CorePlayer`, `Modules/WebRTCPlayer`) have
> been fixed, so the SDK repo's `tuist generate` now passes as-is. The old `TUIST_GENTYPE=SDKONLY` workaround is
> unnecessary.

> ⚠️ **`scripts/use-international.sh` quits any running Xcode.** Do not use it while working.
> This dev build was done in a separate worktree (`git worktree add --detach … origin/dev`) with the root symlinks
> created by hand (`ln -sfn lines/international/<name> <name>`), leaving the user's checkout and Xcode untouched.

---

## 4. Credentials

`DemoDefaults` in `Support/DemoCredentials.swift` holds the internal demo campaign values.

```swift
enum DemoDefaults {
    static let accessKey = "<demo accessKey>"
    static let campaignKey = "<demo campaignKey>"
    static let streamToken = "<demo stream token>"     // mission 8 only
}
```

**The values themselves are not copied into this document** — look at that one file for the real ones.

- When handing the project to a customer, **empty these three or replace them with the customer's keys**. Emptied, the app asks for input on S1.
- What the user types stays on the device (accessKey/campaignKey → `UserDefaults`, stream token → Keychain). Nothing is sent to a server.
- Logs and on-screen display keep only the first 8 characters and mask the rest (`DemoCredentials.masked(_:)`).

> **The defaults belong to a throwaway internal demo account** and are committed so that missions up to 8 run with no setup.
> **Do not copy this pattern in your own app** — a stream token grants **permission to start a broadcast** on that
> campaign to anyone who can read it. Keep yours out of source: inject it at build time or collect it at runtime
> (S1 input goes to the Keychain only).

> **The built-in demo campaign currently points at Apple's public sample HLS (BipBop)** (measured 2026-07-30 22:09).
> Playback is fine as 1920x1080@60fps VOD, but it is not real live-commerce content, so elements that only appear
> during a live broadcast — chat, products, the LIVE badge — cannot be checked on this campaign.

---

## 5. Localization (en default / ko / ja)

- Strings: `ShopliveOnboardingDemo/Resources/{en,ko,ja}.lproj/Localizable.strings` (108 keys each; zero missing and zero extra across the three)
- Lookup: `L("key")` / `L("key", args...)` in `Support/DemoStrings.swift`
- **The base (development) language is `en`** — a device set to ko/ja gets that language, anything else falls back to en.
  (`CFBundleDevelopmentRegion = en`, `CFBundleLocalizations = [en, ko, ja]`)
- **EventLog messages are not localized** — they are a record of SDK calls and events for developers, so showing the API names verbatim is more accurate.
- **All source comments are in English** (switched 2026-07-30). `ShopliveIntegration/` is teaching material that
  integrators copy and read, so an English-speaking integrator must be able to understand it from the comments alone.
  The harness (`Screens/`, `Support/`, `App/`) and the boundary scanner were aligned to English too, so that one
  project never mixes languages.
  Verification: `grep -rn '[가-힣]' ShopliveIntegration ShopliveOnboardingDemo` → 0 hits outside `Resources/*.lproj`.

Checking a specific language:

```bash
xcrun simctl launch <UDID> cloud.shoplive.onboarding.demo -AppleLanguages "(ja)"
```

`en.lproj` is the base language, and the other two are its translations — when you add a new string, add it to all three files.

---

## 6. SDK behavior confirmed by measurement (2026-07-30, SDK 3.0.0 — `dev` `5f0ee781` code)

Facts established by actually running the demo app on the simulator. They correspond to the `⚠️`/`Warning` comments
throughout the app code.

### Confirmed working
`initialize` → campaign resolution → overlay web view load → `playback` / `error` delivered to the delegate, end to
end. Visible live in the developer sheet log.

### Where configuration fields are consumed — all 6 wired up in dev ✅ (correcting an earlier record)

At the `8d66bcd6` build these six were "value stored but no effect".
**In dev (`5f0ee781`) all of them have a consumer** — code evidence:

| Field | Wiring point |
|---|---|
| `overlay.ui` | `PublicSurface/ShoplivePlayerView.swift:160` → `_overlayUI` |
| `pip.isOSPipEnabled` | `Core/Adapter/ConfigurationBridge.swift:43` (implemented 2026-07-30) |
| `navigation.shareScheme` | `ShoplivePlayerView.swift:157` `engine.action(.setShareScheme)` |
| `appearance.allowScreenCapture` | `ConfigurationBridge.swift:38` → `ScreenCaptureGuard` (implemented 2026-07-30) |
| `ShoplivePlayOptions.referrer` | `ShoplivePlayerView.swift:156` `engine.action(.setReferrer)` |
| `ShoplivePlayOptions.keepWindowStateOnPlayExecuted` | `ShoplivePlayerView.swift:92` |

> This evidence is **static (code reading)**. Whether each field actually produces the intended behavior has **not been
> measured** yet — `NEEDS CHECK`.
> `allowScreenCapture` (capture-detection masking) and `isOSPipEnabled` (OS PIP registration) in particular are hard to
> check on the simulator and are device-verification items.

The demo **still also** sets the runtime property `player.overlayUI = .hidden` in `EmbeddedPlayerView` (to keep design
doc §3.4 explicit at the call site). So this measurement did **not separate** whether the overlay is hidden in the
embedded case because of the config path or the runtime path.

(`autoEnterOnLeaveScreen` and `isStatusBarVisible` were **removed** from the public surface — §7.)

### Healthy playback path (campaign `8f595bd943cc`, measured 2026-07-30 15:45)
`initialize` → embed → `playback(REQUEST → AUDIO_LOADED → STARTED → RENDERING…)` plus
`connectionStateChanged(.connecting → .connected)`, with **zero errors** and real video playing.
On this campaign the WebRTC egress 404s while LL-HLS is alive, and the SDK **silently played over HLS with no error
event** — consistent with design doc §5, "failover is not announced through public events".

### Presets by usage — full screen = `.live`, embedded = `.preview`

dev provides **two named presets** on `ShoplivePlayerConfiguration`
(`Modules/PlayerSDK/Sources/PublicSurface/PlayerConfiguration.swift:79-105`).
The demo wraps them as `PlayerConfigurationFactory.fullScreenLive()` / `.embeddedPreview()` and selects between them at
the call site along the `DemoConfigBuilder.Usage` axis.

| | `.live` (full screen) | `.preview` (embedded) |
|---|---|---|
| Values | Same as `.init()` — everything on | Only the 5 below differ |
| `pip.isInAppPipEnabled` / `isOSPipEnabled` | default (on) | **false / false** |
| `overlay.ui` | `.builtIn` (default) | **`.hidden`** |
| `appearance.resizeMode` | `.fill` | `.fill` |
| `sound.muteOnStart` | false | **true** |

- Where they are used: `MissionListViewController`, `DemoBootstrap` deep links, and after promotion → `.fullScreenLive`;
  `FeedDemoViewController` embedded → `.embeddedPreview`.
- `.preview` changes **display policy only**. The preview-specific stream switch that v2's `ShopLive.preview()` also did
  (`previewLiveUrl`, `previewEgressProtocols`) is not included, because the embedded path has no wiring for it — the
  stream that plays is the same as live (stated in the SDK comments).
- When `.preview` is used, manual overrides from the options tab are not applied (to preserve the preset's meaning).
  Only colors and `customParameters` are painted on top.

**Measured result (2026-07-30 20:29–20:33)**: embedded shows video only with no overlay; full screen shows the entire
overlay (logo, LIVE, share, PIP, product banner, likes/chat). Confirmed visually. Zero errors.

**However, `.fill` looks like `.fit` on screen in the embedded case** ⚠️
`resizeMode` itself is delivered correctly to the embedded path (`ShoplivePlayerView.swift:161` → `:202`
`.setResizeMode`). The problem is the frame computation that follows —
`Core/ShopLivePlayerView/View/View + VideoGravity.swift:182` derives the video frame from **`UIScreen.main.bounds`**
rather than the host view's bounds. So a screen-sized frame lands in a 210pt-tall container and leaves margins on the
sides. This is not something the app can work around; it **requires an SDK fix** (the demo leaves it visible as is).

### Events that never arrive during healthy playback ⚠️

| Event | 15:45 (b8591bde) | 18:37 (8d66bcd6) | 20:33 (dev `5f0ee781`) |
|---|---|---|---|
| `stateChanged` | **0** | **0** | **0** (still absent) |
| `campaignStatusChanged` | 0 | **1** ✅ recovered | 2 ✅ |
| `campaignInfoReceived` | 0 | **1** ✅ recovered (title "Kio V5 new") | 2 ✅ |
| `playback` · `connectionStateChanged` · `analytics` | fine | fine | fine (playback 218 · error **0**) |

The "restore the incomplete embedded-path wiring" change in `8d66bcd6` brought the overlay web view up, which
**fixed** `campaignStatusChanged` and `campaignInfoReceived` (the overlay web was the source of those two events).
`stateChanged` still does not arrive.

Design doc §3.6 defines `stateChanged(ShoplivePlayerState)` as notifying the playback lifecycle, but in practice it
does not fire. As a result `player.state` stays `.idle`, and `analytics` arrives with `isPlaying: false` and
`durationMs: 0` (because the adapter derives them from state).

**What the app does about it**: it decides "playback reached" from **`playback(STARTED/RENDERING)`** rather than
`stateChanged` (`DemoPlayerDelegate`). Without this the "confirmed" badge would never appear.
An integrator's app must likewise not depend on `stateChanged` alone for playback state.

### When a campaign has no stream
On a campaign whose `campaignStatus` is `"ONAIR"` but whose egress all 404s (for example the earlier demo campaign):

- `error(code: .unexpectedError, isRecoverable: false)` **repeats endlessly, twice per second**, with no HLS fallback.
- The original connection code (`connection Issue [34]`) survives only inside the `message` string and is not preserved as an `ErrorCode`.
- It arrives as `isRecoverable: false` even though it is retrying — which contradicts §5.

**What the app does about it**: it does not close the player, and explains the reason once per session. Exit is `‹ list`.

### Preventing a trapped (black screen) state
If there is no stream the overlay cannot come up, and the SDK's own close button disappears with it, leaving no way out.
So the demo uses a **host that holds the SDK player as a child VC** (`PlayerHostViewController` in
`Screens/PlayerHostOverlay.swift`) and puts `‹ list` / `⌗ developer` on top of it as sibling views.
The host view's subviews are ordered `[player.view, controls]`, so controls always hit-test first; whatever the SDK
puts up internally lives inside `player.view` and cannot beat that ordering.

### In-app PIP — the host has to step aside ⚠️
On promotion to PIP the render surface moves to a **floating container above the app window**, and nothing is left in
the original full-screen view. Left alone, the whole screen goes black with just the small PIP window on top (the
symptom users reported).

What the demo does:
- Presents the host as `.overFullScreen` (`.fullScreen` detaches the presenter's view from the hierarchy, so hiding the host leaves nothing behind it).
- On `stateChanged(.inAppPIP)`, hides the host via `PlayerHostViewController.setPipPresentation(true)` → the mission
  list shows behind and only the PIP floats: correct UX.
- Return may not arrive via `stateChanged`, so there is a safety net that polls `isInPictureInPicture` every 0.5s
  (polling stops immediately when the session closes — see below).

### The screen briefly went black when closing from the PIP window (fixed) ⚠️

**Symptom**: tapping close (X) on the PIP window covered the whole screen in black for a moment before dismissing.

**Cause**: closing the PIP window does not deliver a PIP exit but **`stateChanged(.closed)` (session end)**.
If the delegate folds state into a boolean and forwards `onPipStateChanged(state == .inAppPIP)`, `.closed` arrives as
`false`, and the host that had stepped aside **becomes visible again over a player whose render surface is already
gone**. At that moment the host's black background covers the screen, and the dismiss animation runs behind it.

Measured values at the moment of closing: `inPip=false state=closed hostDismissing=true`
— **the SDK dismisses the host itself**, so the host should simply have stayed out of the way.

**Fix**: session end and PIP exit are now separate. `ShopliveIntegration/DemoPlayerDelegate.swift` sends `.closed`
through a distinct `onSessionClosed` hook, and the host latches it so that an in-flight return request cannot make it
visible again.
**`isHidden` is deliberately left alone** — closing from full screen must keep the existing slide-down animation, and
in both paths the visibility state at that point is already correct.

Verification: closing from PIP produces **no return call at all**, and tapping the PIP window to go back to full screen
still works.

### When `stateChanged` actually does arrive (correction)

This corrects an earlier record in this document ("it only arrives on entering `.inAppPIP`"). Measured over a PIP session:

| State | Arrives |
|---|---|
| `.inAppPIP` | ✅ on PIP promotion |
| `.playing` | ✅ on PIP → full screen return |
| `.closed` | ✅ on session end (including closing the PIP window) |

What still never arrives is **`stateChanged` around the initial playback start** (see the "events that never arrive"
table above). So `stateChanged` is usable for PIP and termination transitions, but not as a "playback started" signal.

With `pip.padding = 0` (the spec default) the PIP window sits flush against the right and bottom edges and gets clipped
by the home indicator. The demo raises the default to `12` (the options tab can set it back to 0).

### The embedded view has to be forced to video-only ⚠️
Design doc §3.4 specifies the View approach as "video only, `overlayUI` fixed at `.hidden`", but the SDK does not
enforce it (the setter accepts `.builtIn`). The result is a full-screen overlay drawn shrunken inside a 210pt embed box
(measured). The demo explicitly assigns `overlayUI = .hidden` right after `play()`.

### Resilient enums — `@unknown default` is mandatory
The SDK ships with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, so its public enums are **resilient**. When you `switch` over
`PlayerEvent`, `PlayerRequest`, `StreamerEvent`, `PlayerState` and friends, listing every case is not enough: **without
`@unknown default` you get a warning**, and in Swift 6 language mode an **error**.
Every switch in `Integration/` has one. `PlayerRequest` matters most, because it demands a response (`respond`) —
silently ignoring an unknown case can leave the overlay waiting forever.

### APIs that iOS does not have
There is no equivalent of Android's `expandToFullScreen()` (handing an embedded session over to full screen). Mission 4
tears the embedded session down and presents a fresh full-screen VC, so there is one extra short reload.

---

## 7. Public type names — `Shoplive` prefix throughout (breaking)

On this branch every v3 public type was **renamed with a `Shoplive` prefix**. Code written against the old names does
not compile.

| Before | Now |
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
| `Attribution` (Core) | `ShopliveAttribution` |
| `Gender` (Core) | `ShopliveGender` |
| `ErrorCode` (Core) | `ShopliveErrorCode` |
| `AppearanceOptions` (Streamer) | `ShopliveAppearanceOptions` |
| `BroadcastState` / `StreamerEvent` | `ShopliveBroadcastState` / `ShopliveStreamerEvent` |

The nested option types (`PipOptions`, `SoundOptions`, `AppearanceOptions`, `NavigationOptions`, `OverlayOptions`) stay
inside `ShoplivePlayerConfiguration` and were not renamed.

**Three removed fields** — referencing them is a compile error.

- `PipOptions.keepWindowStyleOnReturnFromOSPip`
- `PipOptions.autoEnterOnLeaveScreen` (auto-promotion on leaving the screen — only manual `enterPictureInPicture()` remains)
- `AppearanceOptions.isStatusBarVisible`

### Additional differences as of dev (`5f0ee781`) — what changed from `8d66bcd6`

| Item | `8d66bcd6` | dev `5f0ee781` |
|---|---|---|
| `ShoplivePlayerConfiguration.live` / `.preview` | absent | **added** (two named presets — §6) |
| `AppearanceOptions.resizeMode` | absent | **added** (`.fill` / `.fit`, default `.fill`) |
| `AppearanceOptions.allowScreenCapture` | no consumer | **behavior implemented** via `ScreenCaptureGuard` (default `true`) |
| Streamer `ShopliveAppearanceOptions` | present | **removed** — the `AppearanceOptions (Streamer)` row in the table above does not exist in dev |
| `ShopliveStreamerViewController` initializer | `init(campaignKey:appearance:)` | **`init(campaignKey:)` only** |
| `Shoplive.present(campaignKey:streamToken:from:delegate:)` | has an `appearance:` parameter | **does not** |

→ So the `appearance(fontFamily:)` helper in `StudioLauncher.swift` was **removed**, with a NOTE comment left in its
   place. There is currently no way to customize the studio screen's font or colors through dev's public surface.

---

## 8. Where the guide and the actual API disagree

These are examples in <https://sdk.shoplive.cloud> that **do not compile against the current binary**. This demo is
written against the actual API.

| Guide | Actual |
|---|---|
| Log out with `Shoplive.setUser(nil)` | `setUser` is **non-optional**. Log out with `Shoplive.logout()` |
| `.profile(..., custom: ["grade": "vip"])` | There is **no** `custom` parameter. There is `rank: Int?` |
| `ShoplivePlayerView()` | `init(configuration:)` is **required** (no-argument and storyboard paths are sealed off) |
| `respond(.success)` | Construct the whole `ShopliveCouponResult(couponId:success:message:status:alertType:)` |
| Comparing `playback(let pb)` with `pb != .rebuffering` | `PlaybackEvent` is a **class**. The state is `pb.event` (`PlaybackEventType`) |
| `ShopLiveAnalyticsInfo` / `ShopLivePlayerCampaign` | `ShopliveAnalyticsInfo` / `ShopliveCampaign` (lowercase l) |
| `playerView.expandToFullScreen()` | Does not exist on iOS (Android only) |

---

## 9. App composition (mapped to the prototype)

| Prototype | File |
|---|---|
| **S1** start | `Screens/StartViewController.swift` |
| **S2** mission list | `Screens/MissionListViewController.swift` |
| **S3** playback screen | drawn by the SDK + `Screens/PlayerHostOverlay.swift` (demo controls) · `Screens/FeedDemoViewController.swift` (feed variant) |
| **V1** developer sheet | `Screens/DevSheetViewController.swift` (log / options tabs) |
| **V2** product detail | `Screens/ProductDetailViewController.swift` |

The options tab puts one control on **every public field** of `PlayerConfiguration` and flags the ones that do nothing
with a warning.

---

## 10. Code signing

Signing settings live in the app target's build settings (Xcode → ShopliveOnboardingDemo target → Build Settings).

```
CODE_SIGN_STYLE    = Automatic
DEVELOPMENT_TEAM   = <team ID>          // needed for device builds only
CODE_SIGN_IDENTITY = Apple Development
// The simulator needs no signing — simulator builds pass on a machine with no team configured
CODE_SIGNING_ALLOWED[sdk=iphonesimulator*] = NO
```

If `DEVELOPMENT_TEAM` is empty, device-target builds fail with the following (the simulator is unaffected).

```
error: Signing for "ShopliveOnboardingDemo" requires a development team.
```

To run on a device, pick **your own team** in Signing & Capabilities. The bundle ID
(`cloud.shoplive.onboarding.demo`) also has to be replaced to match your provisioning.

---

## 11. Requirements

- Xcode 26 or later (verified on 26.6)
- iOS 15.0 or later — WebRTC OS PIP uses iOS 15+ only APIs
- Mission 8 (broadcasting) needs `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` (both are in Info.plist)
- Deep link scheme: `shopliveDemo://live?campaign=<KEY>&ref=<REFERRER>`
