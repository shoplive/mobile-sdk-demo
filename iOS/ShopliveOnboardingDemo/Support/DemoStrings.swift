//
//  DemoStrings.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Three locales: English / 한국어 / 日本語. The strings themselves live in
//  Resources/<lang>.lproj/Localizable.strings.
//  Follows the device language and falls back to **en, the base language**, for anything else.
//
//  NOTE: EventLog messages coming from ShopliveIntegration/ are **not localized** — they are a
//    record of SDK calls and events meant for developers, so showing the API names verbatim is more
//    accurate than translating them.
//

import Foundation

/// Localized string lookup. Used as `L("start.tour")` or `L("list.title", 3)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    guard !args.isEmpty else { return format }
    return String(format: format, arguments: args)
}
