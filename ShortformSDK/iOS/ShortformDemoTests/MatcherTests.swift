import XCTest
@testable import ShortformDemo

final class MatcherTests: XCTestCase {
    private let catalog = Fixtures.catalog

    private func product(_ id: String, in c: Catalog? = nil) -> Product {
        (c ?? catalog).product(id: id)!
    }

    func testPlayerOrderIsProductIdThenTagsThenFallback() {
        let steps = ShortformMatcher.steps(for: product("P-1"), in: catalog, surface: .player)
        XCTAssertEqual(steps, [
            .product(ShortformQuery(productId: "P-1")),
            .verticalTags(["fall-look", "knitwear"]),
            .fallbackCollection("fallback-collection"),
        ])
        XCTAssertFalse(steps[0].isRelated)
        XCTAssertTrue(steps[1].isRelated)
        XCTAssertTrue(steps[2].isRelated)
    }

    func testEmbeddedUsesSkuForProductStep() {
        let steps = ShortformMatcher.steps(for: product("P-1"), in: catalog, surface: .embedded)
        if ShortformMatcher.listViewsAcceptProductConditions {
            XCTAssertEqual(steps.first, .product(ShortformQuery(productId: "P-1")))
        } else {
            XCTAssertEqual(steps.first, .product(ShortformQuery(skus: ["SKU-1"])))
            XCTAssertEqual(steps.last, .fallbackCollection("fallback-collection"))
        }
    }

    func testSurfaceCapabilities() {
        XCTAssertTrue(ShortformSurface.player.acceptsProductConditions)
        XCTAssertTrue(ShortformSurface.preview.acceptsProductConditions)
        XCTAssertEqual(ShortformSurface.embedded.acceptsProductConditions, ShortformMatcher.listViewsAcceptProductConditions)
        XCTAssertTrue(ShortformSurface.embedded.acceptsCollectionId)
        XCTAssertTrue(ShortformSurface.player.acceptsCollectionId)
        XCTAssertFalse(ShortformSurface.preview.acceptsCollectionId)
    }

    func testEmbeddedWithoutSkuStartsWithTags() throws {
        try XCTSkipIf(ShortformMatcher.listViewsAcceptProductConditions)
        let steps = ShortformMatcher.steps(for: product("P-2"), in: catalog, surface: .embedded)
        XCTAssertEqual(steps, [.verticalTags(["fall-look", "knitwear"]), .fallbackCollection("fallback-collection")])
    }

    func testUrlThenSkuWhenProductIdIsBlank() {
        var p = product("P-1")
        p.productId = " "
        XCTAssertEqual(ShortformMatcher.ownQuery(for: p, surface: .player), ShortformQuery(url: "https://shop.example/p1"))
        p.url = nil
        XCTAssertEqual(ShortformMatcher.ownQuery(for: p, surface: .player), ShortformQuery(skus: ["SKU-1"]))
        p.sku = nil
        XCTAssertNil(ShortformMatcher.ownQuery(for: p, surface: .player))
    }

    func testNameIsNeverUsed() {
        for surface in [ShortformSurface.embedded, .player, .preview] {
            for p in catalog.products {
                for step in ShortformMatcher.steps(for: p, in: catalog, surface: surface) {
                    let q = step.query
                    let values = [q.productId, q.url, q.collectionId].compactMap { $0 } + (q.skus ?? []) + (q.tags ?? [])
                    XCTAssertFalse(values.contains(p.name), "\(p.productId) matched by name on \(surface)")
                }
            }
        }
    }

    func testProductOutsideVerticalsGoesToFallback() throws {
        try XCTSkipIf(ShortformMatcher.listViewsAcceptProductConditions)
        let steps = ShortformMatcher.steps(for: product("P-5"), in: catalog, surface: .embedded)
        XCTAssertEqual(steps, [.fallbackCollection("fallback-collection")])
        XCTAssertTrue(steps[0].isRelated)
    }

    func testPreviewUsesFallbackTagsInsteadOfCollection() {
        let steps = ShortformMatcher.steps(for: product("P-5"), in: catalog, surface: .preview)
        XCTAssertEqual(steps, [.product(ShortformQuery(productId: "P-5")), .fallbackTags(["picks"])])
    }

    func testNoFallbackNoTagsNoSku() throws {
        try XCTSkipIf(ShortformMatcher.listViewsAcceptProductConditions)
        var c = catalog
        c.fallback = nil
        XCTAssertEqual(ShortformMatcher.steps(for: product("P-5", in: c), in: c, surface: .embedded), [])
    }

    func testTagsFromSeveralVerticalsAreMergedUniquely() {
        var c = catalog
        c.verticals[1].productIds.append("P-1")
        c.verticals[1].tags = ["skincare", "knitwear"]
        let steps = ShortformMatcher.steps(for: product("P-1", in: c), in: c, surface: .player)
        XCTAssertEqual(steps[1], .verticalTags(["fall-look", "knitwear", "skincare"]))
    }

    func testStepTranslationAcrossSurfaces() {
        let p = product("P-1")
        let embeddedOwn = MatchStep.product(ShortformQuery(skus: ["SKU-1"]))
        XCTAssertEqual(ShortformMatcher.step(embeddedOwn, on: .player, for: p, in: catalog), .product(ShortformQuery(productId: "P-1")))
        XCTAssertEqual(ShortformMatcher.step(.fallbackCollection("fallback-collection"), on: .preview, for: p, in: catalog),
                       .fallbackTags(["picks"]))
        XCTAssertEqual(ShortformMatcher.step(.fallbackTags(["picks"]), on: .player, for: p, in: catalog),
                       .fallbackCollection("fallback-collection"))
        XCTAssertEqual(ShortformMatcher.step(.verticalTags(["x"]), on: .player, for: p, in: catalog),
                       .verticalTags(["fall-look", "knitwear"]))
    }

    func testStepQueries() {
        XCTAssertEqual(MatchStep.verticalTags(["a"]).query, ShortformQuery(tags: ["a"]))
        XCTAssertEqual(MatchStep.fallbackCollection("c").query, ShortformQuery(collectionId: "c"))
        XCTAssertEqual(MatchStep.product(ShortformQuery(skus: ["s"])).matchedBy, "sku")
        XCTAssertEqual(MatchStep.product(ShortformQuery(productId: "p")).matchedBy, "productId")
    }

    func testResultsQueryPrefersSkusThenTags() {
        let all = catalog.products
        XCTAssertEqual(ShortformMatcher.resultsQuery(for: all, query: "", in: catalog), ShortformQuery(skus: ["SKU-1", "SKU-3"]))
        let noSku = [product("P-2")]
        XCTAssertEqual(ShortformMatcher.resultsQuery(for: noSku, query: "", in: catalog), ShortformQuery(tags: ["fall-look", "knitwear"]))
        XCTAssertNil(ShortformMatcher.resultsQuery(for: [product("P-5")], query: "", in: catalog))
    }
}
