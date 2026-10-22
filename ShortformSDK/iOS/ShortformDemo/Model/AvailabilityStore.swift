import Foundation

/// Remembers which products were seen with their own shortform, for the ▶ badge.
/// Filled by the product page (when the product's own step returned shortform) and by the Home availability check.
final class AvailabilityStore {
    static let shared = AvailabilityStore()
    static let didChange = Notification.Name("ShortformDemo.AvailabilityStore.didChange")
    static let key = "shortformDemo.availability.v1"

    private let defaults: UserDefaults
    private let key: String
    private var values: [String: Bool]

    init(defaults: UserDefaults = .standard, key: String = AvailabilityStore.key) {
        self.defaults = defaults
        self.key = key
        self.values = (defaults.dictionary(forKey: key) as? [String: Bool]) ?? [:]
    }

    /// `nil` when not checked yet.
    func hasShortform(_ productId: String) -> Bool? {
        values[productId]
    }

    func set(_ productId: String, hasShortform: Bool) {
        guard values[productId] != hasShortform else { return }
        values[productId] = hasShortform
        defaults.set(values, forKey: key)
        NotificationCenter.default.post(name: AvailabilityStore.didChange, object: self)
    }

    func reset() {
        values = [:]
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: AvailabilityStore.didChange, object: self)
    }
}
