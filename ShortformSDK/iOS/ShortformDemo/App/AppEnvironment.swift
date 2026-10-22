import UIKit

/// Local values (access key, catalog URL), branding and the loaded catalog.
///
/// Values come from `Config/Local.xcconfig` through Info.plist and can be overridden in Settings.
/// The access key is never logged or shown in full.
final class AppEnvironment {
    static let shared = AppEnvironment()

    static let catalogDidChange = Notification.Name("ShortformDemo.catalogDidChange")
    static let accessKeyDidChange = Notification.Name("ShortformDemo.accessKeyDidChange")
    static let brandDidChange = Notification.Name("ShortformDemo.brandDidChange")

    enum ValueSource { case settings, localConfig, none }

    private enum Keys {
        static let accessKey = "shortformDemo.accessKey"
        static let catalogURL = "shortformDemo.catalogURL"
        static let brandColor = "shortformDemo.brandColor"
    }

    private let defaults: UserDefaults
    private let info: [String: Any]
    let catalogStore: CatalogStore
    let optionsStore: OptionsStore

    private(set) var loaded: CatalogStore.Loaded
    var catalog: Catalog { loaded.catalog }

    init(defaults: UserDefaults = .standard, info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        self.defaults = defaults
        self.info = info
        self.catalogStore = CatalogStore(cacheURL: CatalogStore.defaultCacheURL, bundledURL: CatalogStore.bundledSampleURL)
        self.optionsStore = OptionsStore(defaults: defaults)
        self.loaded = CatalogStore.Loaded(catalog: Catalog(products: []), source: .bundled, remoteFailed: false)
    }

    // MARK: - Access key

    private var configAccessKey: String? { Self.plistValue(info["ShortformDemoAccessKey"]) }

    var accessKey: String? { defaults.string(forKey: Keys.accessKey).nonEmpty ?? configAccessKey }

    var accessKeySource: ValueSource {
        if defaults.string(forKey: Keys.accessKey).nonEmpty != nil { return .settings }
        return configAccessKey != nil ? .localConfig : .none
    }

    /// `nil` or empty clears the Settings value and returns to the local config value.
    func setAccessKeyOverride(_ key: String?) {
        if let key = key.nonEmpty { defaults.set(key, forKey: Keys.accessKey) } else { defaults.removeObject(forKey: Keys.accessKey) }
        ShortformBridge.shared.setAccessKey(accessKey)
        NotificationCenter.default.post(name: Self.accessKeyDidChange, object: self)
    }

    // MARK: - Catalog URL

    private var configCatalogURL: String? { Self.plistValue(info["ShortformDemoCatalogURL"]) }

    var catalogURLString: String? { defaults.string(forKey: Keys.catalogURL).nonEmpty ?? configCatalogURL }

    var catalogURL: URL? { catalogURLString.flatMap(URL.init(string:)) }

    var catalogURLSource: ValueSource {
        if defaults.string(forKey: Keys.catalogURL).nonEmpty != nil { return .settings }
        return configCatalogURL != nil ? .localConfig : .none
    }

    func setCatalogURLOverride(_ url: String?) {
        if let url = url.nonEmpty { defaults.set(url, forKey: Keys.catalogURL) } else { defaults.removeObject(forKey: Keys.catalogURL) }
    }

    @MainActor
    func reloadCatalog() async {
        loaded = await catalogStore.load(remoteURL: catalogURL)
        EventLog.shared.add("catalog", "source=\(loaded.source.rawValue) products=\(loaded.catalog.products.count)")
        NotificationCenter.default.post(name: Self.catalogDidChange, object: self)
    }

    // MARK: - Branding

    static let defaultBrandColor = UIColor.systemIndigo

    var brandColor: UIColor {
        guard let hex = defaults.string(forKey: Keys.brandColor), let color = UIColor(hex: hex) else { return Self.defaultBrandColor }
        return color
    }

    func setBrandColor(_ color: UIColor?) {
        if let color { defaults.set(color.hexString, forKey: Keys.brandColor) } else { defaults.removeObject(forKey: Keys.brandColor) }
        NotificationCenter.default.post(name: Self.brandDidChange, object: self)
    }

    // MARK: - Reset

    /// Clears everything the demo stored on the device: Settings values, layout choices, the cached catalog.
    @MainActor
    func resetDemo() async {
        for key in [Keys.accessKey, Keys.catalogURL, Keys.brandColor] { defaults.removeObject(forKey: key) }
        optionsStore.reset()
        AvailabilityStore.shared.reset()
        catalogStore.clearCache()
        EventLog.shared.clear()
        ShortformBridge.shared.setAccessKey(accessKey)
        NotificationCenter.default.post(name: Self.accessKeyDidChange, object: self)
        NotificationCenter.default.post(name: Self.brandDidChange, object: self)
        await reloadCatalog()
    }

    /// An Info.plist value from xcconfig: empty or unexpanded (`$(…)`) means not set.
    static func plistValue(_ value: Any?) -> String? {
        guard let s = (value as? String).nonEmpty, !s.hasPrefix("$(") else { return nil }
        return s
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}
