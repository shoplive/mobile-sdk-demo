import XCTest
@testable import ShortformDemo

final class CatalogTests: XCTestCase {
    func testParsesFullCatalog() throws {
        let catalog = Fixtures.catalog
        XCTAssertEqual(catalog.version, 1)
        XCTAssertEqual(catalog.home?.collectionId, "home-collection")
        XCTAssertEqual(catalog.verticals.map(\.id), ["fashion", "beauty", "empty"])
        XCTAssertEqual(catalog.products.count, 5)
        XCTAssertEqual(catalog.fallback?.collectionId, "fallback-collection")
        XCTAssertEqual(catalog.fallback?.tags, ["picks"])
    }

    func testMissingOptionalArraysDecodeAsEmpty() throws {
        let json = #"{ "version": 1, "products": [ { "productId": "A", "name": "A", "currency": "KRW", "originalPrice": 1 } ] }"#
        let catalog = try Catalog.parse(Data(json.utf8))
        XCTAssertTrue(catalog.verticals.isEmpty)
        XCTAssertTrue(catalog.featuredProductIds.isEmpty)
        XCTAssertNil(catalog.fallback)
        XCTAssertEqual(catalog.products.first?.imageUrls, [])
        XCTAssertEqual(catalog.products.first?.keywords, [])
        XCTAssertEqual(Fixtures.catalog.verticals[2].productIds, [])
    }

    func testRejectsUnsupportedVersion() {
        let json = #"{ "version": 2, "products": [] }"#
        XCTAssertThrowsError(try Catalog.parse(Data(json.utf8))) { error in
            XCTAssertEqual(error as? Catalog.ParseError, .unsupportedVersion(2))
        }
    }

    func testRejectsDuplicateProductIds() {
        let p = #"{ "productId": "A", "name": "A", "currency": "KRW", "originalPrice": 1 }"#
        let json = #"{ "version": 1, "products": [\#(p), \#(p)] }"#
        XCTAssertThrowsError(try Catalog.parse(Data(json.utf8))) { error in
            XCTAssertEqual(error as? Catalog.ParseError, .duplicateProductId("A"))
        }
    }

    func testRejectsMissingRequiredField() {
        let json = #"{ "version": 1, "products": [ { "productId": "A", "currency": "KRW", "originalPrice": 1 } ] }"#
        XCTAssertThrowsError(try Catalog.parse(Data(json.utf8)))
    }

    func testBundledSampleCatalogParses() throws {
        let url = try XCTUnwrap(CatalogStore.bundledSampleURL, "catalog.sample.json is not in the app bundle")
        let catalog = try Catalog.parse(Data(contentsOf: url))
        XCTAssertFalse(catalog.products.isEmpty)
        for id in catalog.featuredProductIds {
            XCTAssertNotNil(catalog.product(id: id), "featured id \(id) is not a product")
        }
    }

    func testFeaturedProductsSkipUnknownIds() {
        XCTAssertEqual(Fixtures.catalog.featuredProducts.map(\.productId), ["P-3", "P-1"])
    }

    func testLocalizedTextFallsBackToEnglish() {
        let text = LocalizedText(["en": "Fashion", "ko": "패션"])
        XCTAssertEqual(text.resolved(for: "ko"), "패션")
        XCTAssertEqual(text.resolved(for: "ko-KR"), "패션")
        XCTAssertEqual(text.resolved(for: "ja"), "Fashion")
        XCTAssertEqual(text.resolved(for: nil), "Fashion")
    }

    func testSalePriceAndDiscount() {
        let catalog = Fixtures.catalog
        let knit = catalog.product(id: "P-1")!
        XCTAssertEqual(knit.salePrice, 79000)
        XCTAssertTrue(knit.hasDiscount)
        XCTAssertEqual(PriceFormatter.discount(for: knit), "11%")
        let mug = catalog.product(id: "P-5")!
        XCTAssertFalse(mug.hasDiscount)
        XCTAssertNil(PriceFormatter.discount(for: mug))
    }

    // MARK: - Mapping an SDK product back to the catalog

    func testProductRefMatchingOrder() {
        let catalog = Fixtures.catalog
        XCTAssertEqual(catalog.product(matching: ProductRef(productId: "P-3"))?.productId, "P-3")
        XCTAssertEqual(catalog.product(matching: ProductRef(customerProductId: "C-4"))?.productId, "P-4")
        XCTAssertEqual(catalog.product(matching: ProductRef(sku: "SKU-1"))?.productId, "P-1")
        XCTAssertEqual(catalog.product(matching: ProductRef(url: "https://shop.example/p4"))?.productId, "P-4")
        // An unknown productId falls through to the next identifier.
        XCTAssertEqual(catalog.product(matching: ProductRef(productId: "X", sku: "SKU-3"))?.productId, "P-3")
        XCTAssertNil(catalog.product(matching: ProductRef(productId: "  ")))
        XCTAssertNil(catalog.product(matching: ProductRef()))
    }

    // MARK: - Loading order: catalog URL → saved copy → bundled sample

    private func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).json")
    }

    private func bundledFixture() throws -> URL {
        let url = tempURL("bundled")
        let json = #"{ "version": 1, "products": [ { "productId": "B", "name": "Bundled", "currency": "KRW", "originalPrice": 1 } ] }"#
        try Data(json.utf8).write(to: url)
        return url
    }

    func testLoadUsesRemoteAndSavesCopy() async throws {
        let cache = tempURL("cache")
        let store = CatalogStore(cacheURL: cache, bundledURL: try bundledFixture()) { _ in Data(Fixtures.catalogJSON.utf8) }
        let loaded = await store.load(remoteURL: URL(string: "https://catalog.example/c.json"))
        XCTAssertEqual(loaded.source, .remote)
        XCTAssertEqual(loaded.catalog.products.count, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
    }

    func testLoadFallsBackToSavedCopyWhenRemoteFails() async throws {
        let cache = tempURL("cache")
        try Data(Fixtures.catalogJSON.utf8).write(to: cache)
        let store = CatalogStore(cacheURL: cache, bundledURL: try bundledFixture()) { _ in throw URLError(.notConnectedToInternet) }
        let loaded = await store.load(remoteURL: URL(string: "https://catalog.example/c.json"))
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertTrue(loaded.remoteFailed)
        XCTAssertEqual(loaded.catalog.products.count, 5)
    }

    func testInvalidRemoteDoesNotReplaceSavedCopy() async throws {
        let cache = tempURL("cache")
        try Data(Fixtures.catalogJSON.utf8).write(to: cache)
        let store = CatalogStore(cacheURL: cache, bundledURL: try bundledFixture()) { _ in Data("{ not json".utf8) }
        let loaded = await store.load(remoteURL: URL(string: "https://catalog.example/c.json"))
        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(try Data(contentsOf: cache), Data(Fixtures.catalogJSON.utf8))
    }

    func testLoadFallsBackToBundledSample() async throws {
        let store = CatalogStore(cacheURL: tempURL("missing"), bundledURL: try bundledFixture()) { _ in throw URLError(.timedOut) }
        let remote = await store.load(remoteURL: URL(string: "https://catalog.example/c.json"))
        XCTAssertEqual(remote.source, .bundled)
        XCTAssertEqual(remote.catalog.products.map(\.productId), ["B"])
        let none = await store.load(remoteURL: nil)
        XCTAssertEqual(none.source, .bundled)
        XCTAssertFalse(none.remoteFailed)
    }

    func testPlistValueTreatsEmptyAndUnexpandedAsUnset() {
        XCTAssertNil(AppEnvironment.plistValue(nil))
        XCTAssertNil(AppEnvironment.plistValue(""))
        XCTAssertNil(AppEnvironment.plistValue("  "))
        XCTAssertNil(AppEnvironment.plistValue("$(SHORTFORM_DEMO_ACCESS_KEY)"))
        XCTAssertEqual(AppEnvironment.plistValue("value"), "value")
    }
}
