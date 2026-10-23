# Shortform SDK demo — Android

[◀ Shortform SDK demo](../README.md) · Catalog format: [demo-config](../demo-config/README.md)

A small Android Views shopping app (Material 3, DayNight, edge-to-edge) that shows shortform inside product pages.
Screens, option names and string keys match the iOS app.

| | |
|---|---|
| SDK | `cloud.shoplive:shoplive-short-form:1.9.1` + `shoplive-common` / `shoplive-network` `1.9.0` + `shoplive-media3` `1.10.1.3` |
| Repository | `https://sdk.shoplive.cloud/maven-repo` (public, no credentials) |
| Package | `cloud.shoplive.demo.shortform` |
| Minimum / target | API 24 / API 35 (compile 36) |
| Toolchain | Gradle 8.9 (wrapper), AGP 8.7.3, Kotlin 1.8.22, JDK 17 |

## Run it

1. Open `ShortformSDK/Android` in Android Studio, or use the command line:
   ```bash
   cd ShortformSDK/Android
   ./gradlew :app:assembleDebug test        # build + JVM unit tests
   ./gradlew :app:installDebug              # install on a device or emulator
   ```
2. Optional local values: copy `local.properties.sample` to `local.properties` (git-ignored) and fill in
   ```properties
   shortform.demo.accessKey=<your ShopLive access key>
   shortform.demo.catalogUrl=<URL of your catalog JSON>
   ```
   Both end up in `BuildConfig` and can be changed at runtime in **Settings (⚙︎)**, which wins over the build value.
   The same keys also work as `-P` Gradle properties or the `SHORTFORM_DEMO_ACCESS_KEY` / `SHORTFORM_DEMO_CATALOG_URL`
   environment variables.
3. Without values the app starts with the bundled sample catalog and shows an "Add an access key" prompt.

Never commit a real access key or a hosted catalog URL.

### Building against a locally installed SDK

To try an SDK build installed in `~/.m2` (for example before it is published), add `-PuseMavenLocal=true`:

```bash
./gradlew :app:assembleDebug test -PuseMavenLocal=true
```

Only `shoplive-short-form` is then taken from Maven Local; everything else resolves as usual. Without the flag the SDK
always comes from the public repository.

## Catalog

The catalog is loaded in this order (`catalog/CatalogRepository.kt`):

1. the catalog URL (Settings, else `local.properties`) — saved on the device after it parses,
2. the last good copy for that URL,
3. the bundled sample.

The sample is **not** duplicated in this module: `app/build.gradle.kts` copies
`ShortformSDK/demo-config/catalog.sample.json` into the app's assets at build time (`copySampleCatalog`), and the unit
tests read the same file.

## Structure

```
app/src/main/java/cloud/shoplive/demo/shortform/
├── DemoApp.kt                 Application: settings, options, catalog repository; sets the access key on start
├── catalog/                   Catalog model + parser, loading/caching, search order
├── data/                      Option bar state (DetailOptions) and its persistence, Settings values
├── shortform/
│   ├── ShortformSdk.kt        ← every Shortform SDK call
│   ├── ShortformMatcher.kt    matching steps (pure Kotlin, unit-tested)
│   ├── ShortformResolver.kt   walks the steps against the SDK; ▶ badge availability
│   └── EventLog.kt            SDK callbacks for Settings → SDK event log
└── ui/
    ├── BaseActivity.kt        brand color, edge-to-edge window, top bar with ⚙︎
    ├── Insets.kt              system bar / cutout / IME insets
    ├── home/  search/  results/  detail/  settings/
```

Strings: `res/values/strings.xml` (English) and `res/values-ko/strings.xml` (Korean) have the same keys. Prefixes:
`home_`, `search_`, `results_`, `detail_`, `option_`, `settings_`, plus `app_name` and `common_`.

## Where each SDK call lives

All in `shortform/ShortformSdk.kt`:

| What | SDK API | Used by |
|---|---|---|
| Access key | `ShopLiveCommon.setAccessKey` | `DemoApp`, Settings |
| Horizontal strip ("Today's shortform", Results, Product detail) | `ShopLiveShortformHorizontalTypeView` | Home, Results, Product detail |
| Large cards — one large card per row (two on tablets) | `ShopLiveShortformCardTypeView` | Product detail |
| Grid — 2 or 3 columns | `ShopLiveShortformVerticalTypeView.setSpanCount` | Product detail |
| Product condition on a list view | `setRelatedData(ShopLiveShortformRelatedData)` + `submit` | Product detail |
| Other conditions on a list view | `setShortsCollectionId` / `setHashTags` / `setSkus` + `submit` (`setRelatedData(null)`) | Home, Results, Product detail |
| Card options | `setViewType`, `setVisibleTitle` / `ViewCount` / `ProductCount`, `enablePlayVideos` / `disablePlayVideos` | all list views |
| Matching probe, ▶ badge | `ShopLiveShortform.get(context, relatedData, …)` / `get(context, collectionData, …)` | Product detail, product cards |
| Button only | `ShopLiveShortform.play(context, relatedData)` / `play(context, collectionData)` | Product detail |
| Floating preview | `ShopLiveShortform.showPreview` + `ShopLiveShortformPreviewData`, `hidePreview` | Product detail |
| Product tap in a video | `ShopLiveShortformListener.onProductClick` → `ShopLiveShortform.close()` → app's Product detail | `ShortformSdk.DemoListener` |
| Event log | `onEvent`, `onError`, `onShortsAttached` / `onShortsDetached`, `onDetailShown` / `onDetailHidden` | `ShortformSdk.DemoListener` |

The listener is passed to each view and request (`listener = DemoListener`); the deprecated global
`ShopLiveShortform.setHandler` is not used.

## Matching

The order in [demo-config](../demo-config/README.md#matching), the same for every layout (`ShortformMatcher.steps`):

| Step | Condition | SDK |
|---|---|---|
| 1 | `productId`, else `url`, else `skus` | `ShopLiveShortformRelatedData` (`setRelatedData`, `get`, `play`, preview fields) |
| 2 | the vertical's `tags` (OR) | collection setters / `ShopLiveShortformCollectionData` |
| 3 | `fallback.collectionId` (the floating preview, which has no collection field, uses `fallback.tags`) | same |

The app asks `ShopLiveShortform.get` for each step in turn and shows the first that returns shortform; steps 2 and 3 are
labelled **Related shortform**. The ▶ badge on product cards is step 1 alone. The product name is never used. A
product tapped inside a video is mapped back by `productId`, `customerProductId`, `sku`, then `url`.

## Verification status

| Check | Status |
|---|---|
| `./gradlew :app:assembleDebug test` | Passes locally, offline, with `-PuseMavenLocal=true` (Shortform 1.9.1 from Maven Local) |
| Unit tests (catalog parsing, search order, matching fallback, option persistence and migration, formatting) | 30 tests, all passing |
| CI (`.github/workflows/shortform-ci.yml`, job `android`) | Resolves the SDK from the public repository; needs 1.9.1 to be published there |
| On a device / emulator | Not run yet: layouts, insets, preview placement and full-screen product taps still need a manual pass |
