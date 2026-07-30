//
//  DemoCredentials.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Keeps the accessKey / campaignKey / stream token entered in S1 on the device only — nothing is
//  sent to a server.
//  Prototype S1 rule: "input values go only into device secure storage; state explicitly that nothing
//  is sent to a server".
//

import Foundation
import Security

/// Built-in demo credentials (the "take a tour" path).
///
/// These are ShopLive's internal demo campaign values, included so all 8 missions can be exercised
/// without entering anything.
/// When handing the project to a customer, replace these three with the customer's keys or empty them
/// and let S1's "try with my own account" collect them instead.
enum DemoDefaults {
    static let accessKey = "uv9CGthPzlvsInZerCw0"
    static let campaignKey = "8f595bd943cc"

    /// For mission 8 (broadcasting) only. A completely separate path from viewer authentication.
    ///
    /// Deliberately left empty: a stream token grants **broadcast permission**, so it is not kept in
    /// source control. Mission 8 stays locked until a token is entered on S1, where it is stored in the
    /// Keychain on the device only. Missions 1–7 need no token and work as-is.
    static let streamToken = ""

    static var isAvailable: Bool { !accessKey.isEmpty && !campaignKey.isEmpty }
}

final class DemoCredentials {

    static let shared = DemoCredentials()

    enum Mode: String { case tour, own }

    private enum Key {
        static let mode = "demo.mode"
        static let accessKey = "demo.accessKey"
        static let campaignKey = "demo.campaignKey"
        static let streamToken = "demo.streamToken"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Stored values

    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .tour }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    /// accessKey and campaignKey are identifiers rather than secrets, so UserDefaults is enough.
    var accessKey: String {
        get { mode == .tour ? DemoDefaults.accessKey : (defaults.string(forKey: Key.accessKey) ?? "") }
        set { defaults.set(newValue, forKey: Key.accessKey) }
    }

    var campaignKey: String {
        get { mode == .tour ? DemoDefaults.campaignKey : (defaults.string(forKey: Key.campaignKey) ?? "") }
        set { defaults.set(newValue, forKey: Key.campaignKey) }
    }

    /// The stream token is a signed credential, so it goes in the Keychain (tour mode uses the
    /// built-in value).
    var streamToken: String {
        get { mode == .tour ? DemoDefaults.streamToken : (Keychain.read(Key.streamToken) ?? "") }
        set { Keychain.write(Key.streamToken, newValue) }
    }

    /// The stream token the user typed in — used to restore the S1 form.
    var enteredStreamToken: String { Keychain.read(Key.streamToken) ?? "" }

    /// Values the user typed in, regardless of mode — used to restore the S1 form.
    var enteredAccessKey: String { defaults.string(forKey: Key.accessKey) ?? "" }
    var enteredCampaignKey: String { defaults.string(forKey: Key.campaignKey) ?? "" }

    // MARK: - Readiness

    var isReadyForPlayback: Bool { !accessKey.isEmpty && !campaignKey.isEmpty }
    var isReadyForStreaming: Bool { isReadyForPlayback && !streamToken.isEmpty }

    /// Masking for logs and on-screen display (prototype V1 rule: "mask tokens and keys to the first
    /// 8 characters + …").
    static func masked(_ value: String) -> String {
        guard !value.isEmpty else { return "(not set)" }
        return value.count <= 8 ? value : String(value.prefix(8)) + "…"
    }

    func reset() {
        [Key.accessKey, Key.campaignKey, Key.mode].forEach { defaults.removeObject(forKey: $0) }
        Keychain.delete(Key.streamToken)
    }
}

// MARK: - Minimal Keychain wrapper

private enum Keychain {

    private static let service = "cloud.shoplive.onboarding.demo"

    static func write(_ account: String, _ value: String) {
        delete(account)
        guard !value.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
