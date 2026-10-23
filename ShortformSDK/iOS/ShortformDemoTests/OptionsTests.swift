import XCTest
@testable import ShortformDemo

final class OptionsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ShortformDemoTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsWhenNothingStored() {
        XCTAssertEqual(OptionsStore(defaults: defaults).load(), .default)
    }

    func testRoundTrip() {
        let store = OptionsStore(defaults: defaults)
        var options = DetailOptions()
        options.layout = .grid
        options.position = .insideDescription
        options.cardType = 2
        options.showTitle = false
        options.showViewCount = false
        options.showProductCount = false
        options.columns = 3
        options.autoplay = false
        options.previewCorner = .topLeft
        options.previewSize = .large
        options.previewMaxCount = 10
        options.barCollapsed = true
        store.save(options)
        XCTAssertEqual(OptionsStore(defaults: defaults).load(), options)
    }

    func testReset() {
        let store = OptionsStore(defaults: defaults)
        var options = DetailOptions()
        options.layout = .buttonOnly
        store.save(options)
        store.reset()
        XCTAssertEqual(store.load(), .default)
    }

    func testCorruptDataFallsBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: OptionsStore.key)
        XCTAssertEqual(OptionsStore(defaults: defaults).load(), .default)
    }

    func testPartialAndUnknownValuesKeepDefaults() throws {
        let json = #"{ "layout": "largeCards", "position": "sideways", "cardType": 7, "columns": 0, "previewMaxCount": -1 }"#
        defaults.set(Data(json.utf8), forKey: OptionsStore.key)
        let options = OptionsStore(defaults: defaults).load()
        XCTAssertEqual(options.layout, .largeCards)
        XCTAssertEqual(options.position, DetailOptions.default.position)
        XCTAssertEqual(options.cardType, DetailOptions.default.cardType)
        XCTAssertEqual(options.columns, DetailOptions.default.columns)
        XCTAssertEqual(options.previewMaxCount, DetailOptions.default.previewMaxCount)
        XCTAssertEqual(options.showTitle, true)
    }

    func testLegacyLayoutValuesMigrate() {
        let cases: [(String, DetailOptions.Layout)] = [
            ("horizontal", .strip), ("cardGrid", .largeCards), ("verticalFeed", .grid),
            ("floatingPreview", .floatingPreview), ("buttonOnly", .buttonOnly),
        ]
        for (stored, expected) in cases {
            let json = #"{ "layout": "\#(stored)", "position": "bottom", "cardType": 2 }"#
            defaults.set(Data(json.utf8), forKey: OptionsStore.key)
            let options = OptionsStore(defaults: defaults).load()
            XCTAssertEqual(options.layout, expected, stored)
            // The other stored choices survive the migration.
            XCTAssertEqual(options.position, .bottom, stored)
            XCTAssertEqual(options.cardType, 2, stored)
        }
    }

    func testMigratedLayoutIsSavedWithTheNewValue() throws {
        defaults.set(Data(#"{ "layout": "cardGrid" }"#.utf8), forKey: OptionsStore.key)
        let store = OptionsStore(defaults: defaults)
        store.save(store.load())
        let data = try XCTUnwrap(defaults.data(forKey: OptionsStore.key))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["layout"] as? String, "largeCards")
    }

    func testUnknownLayoutKeepsDefault() {
        defaults.set(Data(#"{ "layout": "carousel", "position": "bottom" }"#.utf8), forKey: OptionsStore.key)
        let options = OptionsStore(defaults: defaults).load()
        XCTAssertEqual(options.layout, DetailOptions.default.layout)
        XCTAssertEqual(options.position, .bottom)
    }

    func testLayoutTitleKeys() {
        XCTAssertEqual(DetailOptions.Layout.allCases.map(\.titleKey), [
            "option_layout_strip", "option_layout_large_cards", "option_layout_grid",
            "option_layout_preview", "option_layout_button",
        ])
    }

    func testStoredRawValuesAreStable() throws {
        var options = DetailOptions()
        options.layout = .floatingPreview
        options.position = .belowImages
        let data = try JSONEncoder().encode(options)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["layout"] as? String, "floatingPreview")
        XCTAssertEqual(DetailOptions.Layout.allCases.map(\.rawValue),
                       ["strip", "largeCards", "grid", "floatingPreview", "buttonOnly"])
        XCTAssertEqual(dict["position"] as? String, "belowImages")
        XCTAssertEqual(dict["previewCorner"] as? String, "bottomRight")
    }

    func testLayoutSurfaces() {
        XCTAssertEqual(DetailOptions.Layout.strip.surface, .embedded)
        XCTAssertEqual(DetailOptions.Layout.largeCards.surface, .embedded)
        XCTAssertEqual(DetailOptions.Layout.grid.surface, .embedded)
        XCTAssertEqual(DetailOptions.Layout.floatingPreview.surface, .preview)
        XCTAssertEqual(DetailOptions.Layout.buttonOnly.surface, .player)
    }

    func testDescriptionSplitForInsidePosition() {
        XCTAssertTrue(ProductDetailViewController.splitDescription(nil) == (nil, nil))
        XCTAssertTrue(ProductDetailViewController.splitDescription("One.") == ("One.", nil))
        XCTAssertTrue(ProductDetailViewController.splitDescription("One.\n\nTwo.\nThree.") == ("One.", "Two.\n\nThree."))
    }

    func testAvailabilityStorePersists() {
        let store = AvailabilityStore(defaults: defaults, key: "availability")
        XCTAssertNil(store.hasShortform("P-1"))
        store.set("P-1", hasShortform: true)
        store.set("P-2", hasShortform: false)
        let reloaded = AvailabilityStore(defaults: defaults, key: "availability")
        XCTAssertEqual(reloaded.hasShortform("P-1"), true)
        XCTAssertEqual(reloaded.hasShortform("P-2"), false)
        reloaded.reset()
        XCTAssertNil(AvailabilityStore(defaults: defaults, key: "availability").hasShortform("P-1"))
    }

    func testEventLogKeepsNewestWithinCapacity() {
        let log = EventLog(capacity: 3)
        for i in 1...5 { log.add("e\(i)") }
        XCTAssertEqual(log.snapshot.map(\.name), ["e5", "e4", "e3"])
        log.clear()
        XCTAssertTrue(log.snapshot.isEmpty)
    }

    func testLocalizationsHaveIdenticalKeys() throws {
        func keys(_ lang: String) throws -> Set<String> {
            let bundle = Bundle(for: ProductDetailViewController.self)
            let path = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
                                     "missing \(lang) strings")
            let dict = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            return Set(dict.keys)
        }
        let en = try keys("en")
        let ko = try keys("ko")
        XCTAssertFalse(en.isEmpty)
        XCTAssertEqual(en.subtracting(ko), [], "missing in ko")
        XCTAssertEqual(ko.subtracting(en), [], "missing in en")
        let prefixes = ["home_", "search_", "results_", "detail_", "option_", "settings_"]
        for key in en {
            XCTAssertTrue(prefixes.contains { key.hasPrefix($0) }, "unexpected key prefix: \(key)")
        }
    }
}
