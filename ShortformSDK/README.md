# Shortform SDK — Commerce Demo App

[◀ Repository home](../README.md) · Sibling: [Live SDK demo](../LiveSDK/README.md)

A small shopping app that shows **what shortform video looks like inside your own commerce app**. You search, open a
product, and the product page carries a shortform collection. A bar at the top of the page switches how that collection is
shown (horizontal strip, card grid, vertical feed, floating preview), and where it sits, while you watch.

It is built for one conversation: *"where should shortform go in our app, and what should it look like?"*

> **Status — in development.** The app targets **Shortform SDK 1.9.1** on both platforms. Until 1.9.1 is published,
> the iOS project resolves the SDK from its release branch; that switches to `exact: "1.9.1"` on release.

---

## The flow

```
Home ──▶ Search ──▶ Results ──▶ Product detail ──▶ Full-screen shortform
           │                        │                      │
           │ demo products first,   │ ★ shortform          └ tap a product in the video
           │ even for a query with  │   collection with a      → that product's detail page
           │ no shortform           │   live layout switcher
```

| Screen | What it shows | Shortform SDK |
|---|---|---|
| **Home** | Search bar, vertical chips, "Today's shortform" strip, featured products | `ShopLiveShortformHorizontalTypeView` + `ShopLiveShortformCollectionData` |
| **Search** | Suggested keywords; while typing, **demo products that have shortform are listed first**, then regular results | — |
| **Results** | Product grid (2 · 3 columns or list), optional shortform strip on top | `HorizontalTypeView` with the results' `skus` |
| **Product detail** ★ | Images, price, description, and **"Shortform for this product"** rendered in the layout chosen in the option bar | `HorizontalTypeView` · `CardTypeView` · `VerticalTypeView` with `setRelatedData(ShopLiveShortformRelatedData)`, or `ShopLiveShortform.showPreview` |
| **Full screen** | The SDK player; a product tap inside the video opens the app's own product page | `ShopLiveShortform.play`, `onProductClick` |

### The option bar (product detail)

| Option | Choices |
|---|---|
| Layout | Horizontal strip (`HorizontalTypeView`) · Large cards (`CardTypeView`, one card per row) · Grid (`VerticalTypeView`, 2–3 columns) · Floating preview (`showPreview`) · Button only (`play`) |
| Position | Above images · Below images · Below price · Inside description · Bottom |
| Card | `cardType` 0 · 1 · 2, title / view count / product count, columns, autoplay |
| Preview | Corner, size, max count |

The bar collapses for a clean "real app" look. The last choice is remembered on the device.

### Settings (⚙︎)

Environment and access key, branding (logo, brand color, corner radius, font), save/reset layout defaults, a catalog
check (shortform count per demo product), an SDK event log, and a demo reset.

---

## Run it

Both apps need two values that are **never committed**: a ShopLive **access key** and a **catalog URL**
(see [demo-config](demo-config/README.md)). Without them the app starts with the bundled sample catalog and asks for a key.

| | iOS | Android |
|---|---|---|
| Open | `ShortformSDK/iOS` in Xcode | `ShortformSDK/Android` in Android Studio |
| Local values | `Config/Local.xcconfig` (copy from `Local.xcconfig.sample`) | `local.properties` (copy from `local.properties.sample`) |
| SDK | SPM — [`shoplive/shortform-ios`](https://github.com/shoplive/shortform-ios) | Gradle — `cloud.shoplive:shoplive-short-form` from `https://sdk.shoplive.cloud/maven-repo` |
| Minimum OS | iOS 15 | API 24 |

Details: [iOS/README.md](iOS/README.md) · [Android/README.md](Android/README.md)

---

## Layout

```
ShortformSDK/
├── README.md            ← you are here
├── demo-config/         catalog format (schema), a sample catalog, how products are matched to shortform
├── iOS/                 UIKit app
└── Android/             Android Views app (Material 3, edge-to-edge)
```

Both apps share screen names, option names and string keys (English base, Korean when the device language is Korean),
so a change to one is easy to mirror in the other.

## How products are matched to shortform

The SDK finds the shortform for a product by **`productId`, `url` or `sku`**. A product's name is not used for matching,
so every catalog entry should carry at least one of those three. When a product has no shortform, the page falls back to
the vertical's tags, then to a fallback collection, and labels the result **"Related shortform"** so the demo never
claims a link that isn't there. Details: [demo-config/README.md](demo-config/README.md#matching).
