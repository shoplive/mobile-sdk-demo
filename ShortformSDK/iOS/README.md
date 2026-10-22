# Shortform SDK demo — iOS

[◀ Shortform SDK demo](../README.md) · Catalog format: [demo-config](../demo-config/README.md)

A UIKit app (programmatic, no storyboards) that shows shortform inside a small shopping flow:
**Home → Search → Results → Product detail → Full screen**. The product page has an option bar that switches how the
product's shortform is shown, and where, while you watch.

| | |
|---|---|
| Minimum iOS | 15.0 |
| Xcode | 16 or later (the project uses folder-synchronized groups, `objectVersion = 77`) |
| Bundle id | `cloud.shoplive.demo.shortform` |
| SDK | [`shoplive/shortform-ios`](https://github.com/shoplive/shortform-ios) via Swift Package Manager, product `ShopliveShortformSDK` (pulls `ShopliveSDKCommon` from `shoplive/common-ios`) |

## Run

1. Optional — local values. Copy the sample and fill it in:
   ```sh
   cp ShortformSDK/iOS/Config/Local.xcconfig.sample ShortformSDK/iOS/Config/Local.xcconfig
   ```
   | Key | What it is |
   |---|---|
   | `SHORTFORM_DEMO_ACCESS_KEY` | Your ShopLive access key |
   | `SHORTFORM_DEMO_CATALOG_URL` | A catalog JSON URL ([format](../demo-config/README.md)). Write `//` as `/$()/` — in `.xcconfig` files `//` starts a comment |

   `Config/Local.xcconfig` is ignored by git. Without it the project still builds: `Config/Base.xcconfig` includes it
   with `#include?`, the app starts with the bundled sample catalog and Settings asks for an access key.
   Both values can also be set (and overridden) in the app under **Settings**.
2. Open `ShortformSDK/iOS/ShortformDemo.xcodeproj` in Xcode, wait for the package to resolve, pick a simulator or a
   device (set your team under *Signing & Capabilities* for a device) and run the **ShortformDemo** scheme.

Command line (what CI runs):

```sh
cd ShortformSDK/iOS
xcodebuild -project ShortformDemo.xcodeproj -scheme ShortformDemo \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ShortformDemo.xcodeproj -scheme ShortformDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO
```

### SDK version

The app targets **Shortform SDK 1.9.1**. Until `1.9.1` is tagged, the package reference follows the release branch:

```
ShortformDemo.xcodeproj › Package Dependencies › shortform-ios — Branch: feature/common-ios-1.9.0
```

When 1.9.1 is published, switch it to an exact version: in Xcode select the project → *Package Dependencies* →
`shortform-ios` → *Dependency Rule: Exact Version* `1.9.1`; or in `project.pbxproj` replace the requirement with
`kind = exactVersion; version = 1.9.1;`. Then commit the generated
`ShortformDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Structure

```
ShortformSDK/iOS/
├── ShortformDemo.xcodeproj         project + shared scheme (ShortformDemo: app and unit tests)
├── Config/
│   ├── Base.xcconfig               empty defaults, then #include? "Local.xcconfig"
│   ├── Local.xcconfig.sample       copy to Local.xcconfig (ignored by git)
│   └── Info.plist                  ShortformDemoAccessKey / ShortformDemoCatalogURL ← xcconfig
├── ShortformDemo/
│   ├── App/                        AppDelegate, SceneDelegate, AppEnvironment (local values, branding, catalog), L()
│   ├── Model/                      no SDK imports — unit tested
│   │   ├── Catalog.swift           catalog types, parsing, SDK product → catalog entry
│   │   ├── CatalogStore.swift      catalog URL → saved copy → bundled sample
│   │   ├── SearchEngine.swift      search order (demo products first, section never disappears)
│   │   ├── ShortformMatcher.swift  matching steps per SDK surface
│   │   ├── DetailOptions.swift     option bar model + UserDefaults persistence
│   │   └── EventLog, AvailabilityStore, PriceFormatter
│   ├── Shortform/                  every SDK call lives here
│   ├── UI/                         Home, Search, Results, Detail (option bar, image pager), Settings, shared views
│   └── Resources/                  en.lproj (base), ko.lproj — identical keys
└── ShortformDemoTests/             catalog parsing, search order, matching fallback, option persistence
```

The bundled catalog is `../demo-config/catalog.sample.json`, referenced from the project (not copied).

## Where each SDK call lives

| SDK API | File | Used for |
|---|---|---|
| `ShopLiveCommon.setAccessKey(accessKey:)` | `Shortform/ShortformBridge.swift` | launch, Settings change, demo reset |
| `ShopLiveShortformHorizontalTypeView` | `Shortform/ShortformEmbedView.swift` | Home "Today's shortform", Results strip, detail *Horizontal strip* |
| `ShopLiveShortformCardTypeView` | `Shortform/ShortformEmbedView.swift` | detail *Card grid* |
| `ShopLiveShortformVerticalTypeView` | `Shortform/ShortformEmbedView.swift` | detail *Vertical feed* |
| `setSkus` · `setHashTags(…, .OR)` · `setShortsCollectionId` · `setCardViewType` · `setVisibleTitle/ViewCount/ProductCount` · `enable/disablePlayVideos` · `reloadItems` · `submit` | `Shortform/ShortformEmbedView.swift` | applying a match step and the card options in place |
| `ShopLiveShortform.play(requestData: ShopLiveShortformRelatedData / ShopLiveShortformCollectionData)` | `Shortform/ShortformBridge.swift` | detail *Button only* (the `RelatedData` overload is marked deprecated in 1.9.1 but is the only full-screen call that takes `productId` / `url`; it is the one expected build warning) |
| `ShopLiveShortform.showPreview(requestData: ShopLiveShortformPreviewData)` | `Shortform/ShortformBridge.swift` | detail *Floating preview* (corner, size, max count) |
| `ShopLiveShortform.close()` | `Shortform/ShortformBridge.swift` | before opening a product, leaving the page, switching layout |
| `ShopLiveShortformDelegate` (`onProductClick`, `onEvent`, `onError`, `onDetailShown/Hidden`, `onShortsAttached/Detached`, `onBannerClick`) | `Shortform/ShortformBridge.swift` | product routing, SDK event log |
| `ShopLiveShortformListViewDelegate` (`onListViewError`, `onShortsSettingsInitialized`) | `Shortform/ShortformEmbedView.swift` | errors, re-applying options |

Tapping a video opens the SDK's full-screen player. A product tapped inside the video (`onProductClick`) closes the
player and pushes the app's own product page for the matching catalog entry (`productId` → `customerProductId` →
`sku` → `url`).

## Matching on iOS

The order follows [demo-config](../demo-config/README.md#matching): the product's own shortform, then the vertical's
tags (OR), then the fallback collection — the last two labelled **"Related shortform"**. Names are never used.

What each SDK entry point accepts decides the product step:

| Layout | SDK surface | Product step | Fallback |
|---|---|---|---|
| Horizontal strip · Card grid · Vertical feed | embedded list views | `skus` (the list views take skus, tags or a collection) | tags → `fallback.collectionId` |
| Button only | `play` + `ShopLiveShortformRelatedData`; `ShopLiveShortformCollectionData` for the collection | `productId` → `url` → `skus` | tags → `fallback.collectionId` |
| Floating preview | `showPreview` + `ShopLiveShortformPreviewData` | `productId` → `url` → `skus` | tags → `fallback.tags` (preview data has no collection id) |

Which conditions each surface gets is decided in one place, `ShortformMatcher` (`Model/ShortformMatcher.swift`).
`ShortformMatcher.listViewsAcceptProductConditions` is the single switch for the list views: once they accept
related data (`productId` / `url`), turning it on makes the list views match exactly like the player and preview.

SDK 1.9.1 does not report how many items an embedded view loaded. The app reads the item count of the embedded
collection view (public UIKit API): items appear → that step is used; still none after a few seconds → next step.
The step found in an embedded layout is reused when you switch to *Floating preview* or *Button only*.
The same check, run invisibly on Home for featured products with a `sku`, drives the ▶ badge.

The option bar's **Columns** choice is stored (shared with Android) but disabled on iOS: the iOS list views pick
their column count from the screen width.

## Settings (⚙︎, on every screen)

Access key (stored on the device, shown only as "Set here" / "From local config"), catalog URL + source in use +
reload, brand color, reset layout defaults, SDK event log, reset demo.

## Verification status

| Check | Status |
|---|---|
| Build, iOS Simulator, Xcode 16 (`macos-15` runner) | passing in CI (`.github/workflows/shortform-ci.yml`, job **iOS demo**) |
| Unit tests (50: catalog parsing and loading order, search order, matching fallback, option persistence, string keys) | passing in CI on an iPhone simulator |
| Build warnings in app code | one expected: `play(requestData: ShopLiveShortformRelatedData)` is marked deprecated in 1.9.1 |
| Screens against a live account (shortform loading, empty-result fallback timing, preview size, product routing) | not yet checked by hand |
