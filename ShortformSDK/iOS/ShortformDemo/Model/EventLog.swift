import Foundation

/// In-memory log of SDK callbacks, shown in Settings → SDK event log.
final class EventLog {
    struct Entry: Equatable {
        let date: Date
        let name: String
        let detail: String
    }

    static let shared = EventLog()
    static let didChange = Notification.Name("ShortformDemo.EventLog.didChange")

    let capacity: Int
    private(set) var entries: [Entry] = []
    private let lock = NSLock()

    init(capacity: Int = 300) {
        self.capacity = capacity
    }

    func add(_ name: String, _ detail: String = "") {
        let entry = Entry(date: Date(), name: name, detail: String(detail.prefix(400)))
        lock.lock()
        entries.insert(entry, at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
        lock.unlock()
        DispatchQueue.main.async { NotificationCenter.default.post(name: EventLog.didChange, object: self) }
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        DispatchQueue.main.async { NotificationCenter.default.post(name: EventLog.didChange, object: self) }
    }

    var snapshot: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}
