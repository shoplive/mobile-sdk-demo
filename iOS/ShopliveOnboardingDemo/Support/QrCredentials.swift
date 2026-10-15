//
//  QrCredentials.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Credentials read from a QR code — the same QR codes the native SDK test apps scan.
//
//  Format (from the native test apps): the QR holds a URL; only its query matters.
//
//      https://<any>?ak=<accessKey>&ck=<campaignKey>&title=<title>&userjwt=<JWT>&st=<streamToken>
//
//  | Key       | Field                    | Source                                                   |
//  | --------- | ------------------------ | -------------------------------------------------------- |
//  | ak        | accessKey                | Android CampaignListActivity, iOS SLQRReaderViewController |
//  | ck        | campaignKey              | same                                                     |
//  | title     | label only               | same (falls back to "Unknown Title (QR)")                |
//  | userjwt   | User JWT (Mission 3)     | iOS PlayerDemo2 SLQRReaderViewController                 |
//  | st        | stream token (Mission 8) | new in these demos — no native test app reads it         |
//
//  Rules — identical in the Android and Flutter demos:
//  - ak and ck are used together or not at all.
//  - userjwt and st may come alone.
//  - Blank values count as missing. Values are trimmed and percent-decoded.
//

import Foundation

struct QrCredentials: Equatable {
    static let keyAccessKey = "ak"
    static let keyCampaignKey = "ck"
    static let keyTitle = "title"
    static let keyUserJwt = "userjwt"
    static let keyStreamToken = "st"
    static let unknownTitle = "Unknown Title (QR)"

    var accessKey: String?
    var campaignKey: String?
    var title: String?
    var userJwt: String?
    var streamToken: String?

    var hasKeyPair: Bool { accessKey != nil && campaignKey != nil }

    /// The field names that were filled, for the confirmation message.
    var filledFields: [String] {
        var fields: [String] = []
        if accessKey != nil { fields.append("accessKey") }
        if campaignKey != nil { fields.append("campaignKey") }
        if streamToken != nil { fields.append("streamToken") }
        if userJwt != nil { fields.append("userJwt") }
        return fields
    }

    /// nil when the text is not a URL, or carries nothing this demo can use.
    static func parse(_ raw: String?) -> QrCredentials? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let items = URLComponents(string: text)?.queryItems, !items.isEmpty else { return nil }

        func value(_ name: String) -> String? {
            // First value wins, like the test apps' `first(where:)`.
            guard let v = items.first(where: { $0.name == name })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
            return v
        }

        let ak = value(keyAccessKey)
        let ck = value(keyCampaignKey)
        let pairOK = ak != nil && ck != nil
        let result = QrCredentials(
            accessKey: pairOK ? ak : nil,
            campaignKey: pairOK ? ck : nil,
            title: value(keyTitle),
            userJwt: value(keyUserJwt),
            streamToken: value(keyStreamToken))
        guard result.hasKeyPair || result.userJwt != nil || result.streamToken != nil else { return nil }
        return result
    }
}
