//
//  EventLog.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Data source for the "Event log" tab of the V1 developer sheet.
//  Prototype V1 rule: for a request, also record whether respond was called — this teaches that
//  failing to respond is itself a bug.
//

import Foundation

final class EventLog {

    static let shared = EventLog()

    static let didChange = Notification.Name("EventLog.didChange")

    enum Kind: String {
        case event = "EVENT"        // didReceive event
        case request = "REQUEST"    // didRequest — something the app must answer
        case error = "ERROR"
        case sdk = "→SDK"           // the app calling into the SDK
    }

    struct Entry {
        let kind: Kind
        let message: String
        let time: String
    }

    private(set) var entries: [Entry] = []
    private let limit = 200
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private init() {}

    func log(_ kind: Kind, _ message: String) {
        let entry = Entry(kind: kind, message: message, time: formatter.string(from: Date()))
        // Also mirror to the console so the flow is visible even when the sheet cannot be opened
        // (e.g. a black screen).
        print("[Shoplive] \(entry.time) \(kind.rawValue) \(message)")
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.limit { self.entries.removeLast() }
            NotificationCenter.default.post(name: EventLog.didChange, object: nil)
        }
    }

    func clear() {
        entries.removeAll()
        NotificationCenter.default.post(name: EventLog.didChange, object: nil)
    }

    var plainText: String {
        entries.map { "[\($0.time)] \($0.kind.rawValue) \($0.message)" }.joined(separator: "\n")
    }
}
