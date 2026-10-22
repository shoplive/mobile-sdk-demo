import Foundation

/// The product-detail option bar. Raw values are stable: they are stored on the device and shared with the Android app.
struct DetailOptions: Codable, Equatable {
    enum Layout: String, Codable, CaseIterable {
        case horizontal
        case cardGrid
        case verticalFeed
        case floatingPreview
        case buttonOnly

        var titleKey: String {
            switch self {
            case .horizontal: return "option_layout_horizontal"
            case .cardGrid: return "option_layout_card"
            case .verticalFeed: return "option_layout_vertical"
            case .floatingPreview: return "option_layout_preview"
            case .buttonOnly: return "option_layout_button"
            }
        }

        var surface: ShortformSurface {
            switch self {
            case .horizontal, .cardGrid, .verticalFeed: return .embedded
            case .floatingPreview: return .preview
            case .buttonOnly: return .player
            }
        }
    }

    enum Position: String, Codable, CaseIterable {
        case aboveImages
        case belowImages
        case belowPrice
        case insideDescription
        case bottom

        var titleKey: String {
            switch self {
            case .aboveImages: return "option_position_above_images"
            case .belowImages: return "option_position_below_images"
            case .belowPrice: return "option_position_below_price"
            case .insideDescription: return "option_position_inside_description"
            case .bottom: return "option_position_bottom"
            }
        }
    }

    enum Corner: String, Codable, CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var titleKey: String {
            switch self {
            case .topLeft: return "option_preview_corner_top_left"
            case .topRight: return "option_preview_corner_top_right"
            case .bottomLeft: return "option_preview_corner_bottom_left"
            case .bottomRight: return "option_preview_corner_bottom_right"
            }
        }
    }

    enum PreviewSize: String, Codable, CaseIterable {
        case small
        case medium
        case large

        var titleKey: String { "option_preview_size_\(rawValue)" }

        /// Width of the floating preview, in points.
        var width: Double {
            switch self {
            case .small: return 100
            case .medium: return 130
            case .large: return 170
            }
        }
    }

    static let cardTypes = [0, 1, 2]
    static let columnChoices = [1, 2, 3]
    static let maxCountChoices = [1, 3, 5, 10]

    var layout: Layout = .horizontal
    var position: Position = .belowPrice
    var cardType: Int = 1
    var showTitle: Bool = true
    var showViewCount: Bool = true
    var showProductCount: Bool = true
    var columns: Int = 2
    var autoplay: Bool = true
    var previewCorner: Corner = .bottomRight
    var previewSize: PreviewSize = .medium
    var previewMaxCount: Int = 5
    /// Whether the option bar is collapsed.
    var barCollapsed: Bool = false

    static let `default` = DetailOptions()

    init() {}

    /// Tolerant decoding: a missing or unknown value keeps its default, and numbers are clamped to valid choices.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DetailOptions.default
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        layout = value(.layout, d.layout)
        position = value(.position, d.position)
        cardType = value(.cardType, d.cardType)
        showTitle = value(.showTitle, d.showTitle)
        showViewCount = value(.showViewCount, d.showViewCount)
        showProductCount = value(.showProductCount, d.showProductCount)
        columns = value(.columns, d.columns)
        autoplay = value(.autoplay, d.autoplay)
        previewCorner = value(.previewCorner, d.previewCorner)
        previewSize = value(.previewSize, d.previewSize)
        previewMaxCount = value(.previewMaxCount, d.previewMaxCount)
        barCollapsed = value(.barCollapsed, d.barCollapsed)
        if !Self.cardTypes.contains(cardType) { cardType = d.cardType }
        if !Self.columnChoices.contains(columns) { columns = d.columns }
        if previewMaxCount < 1 { previewMaxCount = d.previewMaxCount }
    }
}

/// Persists the option bar in `UserDefaults`.
final class OptionsStore {
    static let key = "shortformDemo.detailOptions.v1"
    static let didReset = Notification.Name("ShortformDemo.OptionsStore.didReset")

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = OptionsStore.key) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> DetailOptions {
        guard let data = defaults.data(forKey: key),
              let options = try? JSONDecoder().decode(DetailOptions.self, from: data) else { return .default }
        return options
    }

    func save(_ options: DetailOptions) {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: OptionsStore.didReset, object: self)
    }
}
