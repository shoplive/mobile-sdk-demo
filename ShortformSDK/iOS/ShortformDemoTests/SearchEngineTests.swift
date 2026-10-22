import XCTest
@testable import ShortformDemo

final class SearchEngineTests: XCTestCase {
    private let catalog = Fixtures.catalog

    func testDemoOrderIsFeaturedThenVerticals() {
        // Featured P-3, P-1 (UNKNOWN skipped), then fashion's P-2.
        XCTAssertEqual(SearchEngine.demoProductIds(in: catalog), ["P-3", "P-1", "P-2"])
    }

    func testMatchingVerticalComesFirstAfterFeatured() {
        let catalogWithMoreDemo: Catalog = {
            var c = catalog
            c.featuredProductIds = []
            return c
        }()
        XCTAssertEqual(SearchEngine.demoProductIds(in: catalogWithMoreDemo, query: "serum"), ["P-3", "P-1", "P-2"])
        XCTAssertEqual(SearchEngine.demoProductIds(in: catalogWithMoreDemo, query: "knit"), ["P-1", "P-2", "P-3"])
    }

    func testDemoProductsComeFirstThenOthers() {
        let result = SearchEngine.search("knit", in: catalog)
        XCTAssertFalse(result.demoIsPlaceholder)
        XCTAssertEqual(result.demo.map(\.productId), ["P-1"])
        // Name "Wool Knit Scarf" and brand "Knit & Clay" — catalog order.
        XCTAssertEqual(result.others.map(\.productId), ["P-4", "P-5"])
        XCTAssertEqual(result.allMatches.map(\.productId), ["P-1", "P-4", "P-5"])
    }

    func testMatchesNameBrandAndKeywordsCaseInsensitively() {
        XCTAssertEqual(SearchEngine.search("CASHMERE", in: catalog).demo.map(\.productId), ["P-1"])
        XCTAssertEqual(SearchEngine.search("brand a", in: catalog).demo.map(\.productId), ["P-1", "P-2"])
        XCTAssertEqual(SearchEngine.search("serum", in: catalog).demo.map(\.productId), ["P-3"])
    }

    func testIdsSkusAndUrlsAreNotSearched() {
        let result = SearchEngine.search("SKU-1", in: catalog)
        XCTAssertTrue(result.demoIsPlaceholder)
        XCTAssertTrue(result.others.isEmpty)
    }

    func testDemoSectionNeverDisappears() {
        let result = SearchEngine.search("no such thing", in: catalog)
        XCTAssertTrue(result.demoIsPlaceholder)
        XCTAssertEqual(result.demo.map(\.productId), ["P-3", "P-1"])
        XCTAssertTrue(result.others.isEmpty)
        XCTAssertTrue(result.allMatches.isEmpty)
    }

    func testOnlyOtherMatchesKeepsPlaceholderDemoSection() {
        let result = SearchEngine.search("mug", in: catalog)
        XCTAssertTrue(result.demoIsPlaceholder)
        XCTAssertEqual(result.demo.map(\.productId), ["P-3", "P-1"])
        XCTAssertEqual(result.others.map(\.productId), ["P-5"])
    }

    func testEmptyQueryShowsFeatured() {
        let result = SearchEngine.search("  ", in: catalog)
        XCTAssertTrue(result.demoIsPlaceholder)
        XCTAssertEqual(result.demo.map(\.productId), ["P-3", "P-1"])
    }

    func testPlaceholderUsesDemoIdsWhenNothingIsFeatured() {
        var c = catalog
        c.featuredProductIds = []
        XCTAssertEqual(SearchEngine.search("zzz", in: c, placeholderCount: 2).demo.map(\.productId), ["P-1", "P-2"])
    }

    func testSuggestedKeywordsAreUnique() {
        var c = catalog
        c.verticals[1].keywords = ["serum", "KNIT"]
        XCTAssertEqual(SearchEngine.suggestedKeywords(in: c), ["knit", "cardigan", "serum"])
    }

    func testVerticalProductsIncludeKeywordMatches() {
        let fashion = catalog.verticals[0]
        XCTAssertEqual(catalog.products(in: fashion).map(\.productId), ["P-1", "P-2"])
        var c = catalog
        c.products[4].keywords = ["cardigan"]
        XCTAssertEqual(c.products(in: fashion).map(\.productId), ["P-1", "P-2", "P-5"])
    }
}
