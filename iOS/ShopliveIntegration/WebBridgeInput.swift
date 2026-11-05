//
//  WebBridgeInput.swift
//  ★ COPY THIS — mission 7 · hybrid (the input rules for WebBridge.swift)
//
//  What the web page sends through `ShopLiveAppInterface` is untrusted input. These are the rules,
//  kept apart from WebKit so they can be checked on their own:
//    · the body must be a String (the guide's `message.body as? String`)
//    · empty or whitespace-only is ignored — nothing opens, the reason is logged
//
//  Foundation only — iOS/scripts/logic_check.sh compiles this file on the Mac to check the rules.
//

import Foundation

enum WebBridgeInput {

    enum Result: Equatable {
        /// A campaign key to play (surrounding whitespace removed).
        case accepted(String)
        /// Ignore the message. `reason` is for the log.
        case rejected(reason: String)
    }

    /// Validates `WKScriptMessage.body`.
    ///
    /// The web can post anything — a JS string arrives as `String`, a number as `NSNumber`, an object as
    /// `NSDictionary`, `null` as `NSNull`. Only a non-blank string is a campaign key.
    static func campaignKey(from body: Any?) -> Result {
        guard let body, !(body is NSNull) else {
            return .rejected(reason: "body is null")
        }
        guard let text = body as? String else {
            return .rejected(reason: "body is not a string (\(type(of: body)))")
        }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return .rejected(reason: "campaignKey is empty")
        }
        return .accepted(key)
    }

    /// Encodes `value` as a JavaScript string literal for a `WKUserScript` source.
    ///
    /// JSON string syntax is a subset of JS, so the JSON encoding of a String is a safe literal: quotes
    /// and backslashes are escaped, `/` becomes `\/` (so `</script>` cannot close a tag), and the two
    /// line terminators JSON allows raw (U+2028/U+2029) are escaped as well.
    /// Returns nil only if encoding fails — the caller logs and does not inject.
    static func javaScriptStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8) else { return nil }
        return literal
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
