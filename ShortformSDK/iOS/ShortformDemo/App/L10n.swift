import Foundation

/// Localized string for a key in `Localizable.strings` (English base, Korean).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string with arguments.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}
