import Foundation
@testable import ShortformDemo

enum Fixtures {
    static let catalogJSON = """
    {
      "version": 1,
      "home": { "collectionId": "home-collection" },
      "verticals": [
        { "id": "fashion", "title": { "en": "Fashion", "ko": "패션" },
          "productIds": ["P-1", "P-2"], "keywords": ["knit", "cardigan"], "tags": ["fall-look", "knitwear"] },
        { "id": "beauty", "title": { "en": "Beauty" },
          "productIds": ["P-3"], "keywords": ["serum"], "tags": ["skincare"] },
        { "id": "empty", "title": { "en": "Empty" } }
      ],
      "featuredProductIds": ["P-3", "P-1", "UNKNOWN"],
      "fallback": { "collectionId": "fallback-collection", "tags": ["picks"] },
      "products": [
        { "productId": "P-1", "sku": "SKU-1", "url": "https://shop.example/p1", "name": "Cashmere Knit",
          "brand": "Brand A", "currency": "KRW", "originalPrice": 89000, "discountPrice": 79000, "discountRate": 11,
          "keywords": ["knit"] },
        { "productId": "P-2", "name": "Round Cardigan", "brand": "Brand A", "currency": "KRW", "originalPrice": 59000 },
        { "productId": "P-3", "sku": "SKU-3", "name": "Daily Serum", "brand": "Brand B", "currency": "KRW",
          "originalPrice": 32000, "keywords": ["serum"] },
        { "productId": "P-4", "customerProductId": "C-4", "url": "https://shop.example/p4", "name": "Wool Knit Scarf",
          "brand": "Brand C", "currency": "USD", "originalPrice": 25 },
        { "productId": "P-5", "name": "Stoneware Mug", "brand": "Knit & Clay", "currency": "KRW", "originalPrice": 18000 }
      ]
    }
    """

    static var catalog: Catalog {
        try! Catalog.parse(Data(catalogJSON.utf8))
    }
}
