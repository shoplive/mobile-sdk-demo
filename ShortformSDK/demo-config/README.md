# Demo catalog

[◀ Shortform SDK demo](../README.md)

The demo app reads its products and its demo setup from **one JSON document** — the catalog. The app loads it from the
catalog URL in your local config and caches the last copy on the device, so a demo still starts on a bad network.
Without a URL it uses [`catalog.sample.json`](catalog.sample.json), which ships with the app.

| File | What it is |
|---|---|
| [`catalog.schema.json`](catalog.schema.json) | JSON Schema for the catalog (checked in CI) |
| [`catalog.sample.json`](catalog.sample.json) | A small sample catalog with placeholder products |

Keep real catalogs, access keys and hosted URLs **out of this repository.**

## Format

```jsonc
{
  "version": 1,
  "home":      { "collectionId": "…" },                   // "Today's shortform" strip
  "verticals": [                                          // chips on Home, groups in Search
    { "id": "fashion", "title": { "en": "Fashion", "ko": "패션" },
      "productIds": ["P-1001"], "keywords": ["knit"], "tags": ["fall-look"] }
  ],
  "featuredProductIds": ["P-1001"],                       // listed first in Search
  "fallback":  { "collectionId": "…", "tags": ["picks"] },
  "products":  [
    { "productId": "P-1001", "customerProductId": "…", "sku": "…", "url": "https://…",
      "name": "…", "brand": "…", "imageUrls": ["https://…"], "description": "…",
      "currency": "KRW", "originalPrice": 89000, "discountPrice": 79000, "discountRate": 11 }
  ]
}
```

Field names follow the product fields the Shortform SDK returns in its callbacks (`productId`, `customerProductId`,
`sku`, `url`, `brand`, `originalPrice`, `discountPrice`, `discountRate`, `currency`), so a product tapped inside a
video maps straight back to a catalog entry.

## Matching

| Step | Condition sent to the SDK | When |
|---|---|---|
| 1 | `productId`, else `url`, else `skus` | always — the product's own shortform |
| 2 | the vertical's `tags` (`tagSearchOperator` OR) | step 1 returned nothing |
| 3 | `fallback.collectionId` | step 2 returned nothing |

Steps 2 and 3 are labelled **"Related shortform"** on screen. `name` is never used for matching.

## Search order

1. Demo products (`featuredProductIds`, then the matching vertical's `productIds`) whose name, brand or keywords match
2. Every other matching product in `products`

The demo-product section stays visible even when nothing matches, showing a few featured products instead.
