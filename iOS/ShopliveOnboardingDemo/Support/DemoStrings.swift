//
//  DemoStrings.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Three locales: English / 한국어 / 日本語. The strings themselves live in
//  Resources/<lang>.lproj/Localizable.strings.
//  The language is an **app-level setting, English by default** — it does not follow the device,
//  the same rule as the Android and Flutter demos. The demo is handed to customers in several
//  countries, and each needs to see all three languages on one phone.
//
//  NOTE: EventLog messages coming from ShopliveIntegration/ are **not localized** — they are a
//    record of SDK calls and events meant for developers, so showing the API names verbatim is more
//    accurate than translating them.
//

import Foundation

/// The app's display language. Changing it takes effect for screens built afterwards; the start
/// screen rebuilds itself right away.
enum DemoLanguage: String, CaseIterable {
    case en, ko, ja

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        case .ja: return "日本語"
        }
    }

    private static let key = "demo.language"

    static var current: DemoLanguage {
        get { DemoLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .en }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            cachedBundle = nil
        }
    }

    private static var cachedBundle: Bundle?

    /// The `<lang>.lproj` bundle for the current language. Falls back to the main bundle.
    static var bundle: Bundle {
        if let b = cachedBundle { return b }
        let b = Bundle.main.path(forResource: current.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        cachedBundle = b
        return b
    }
}

/// Localized string lookup. Used as `L("start.tour")` or `L("list.title", 3)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: DemoLanguage.bundle, comment: "")
    guard !args.isEmpty else { return format }
    return String(format: format, arguments: args)
}
