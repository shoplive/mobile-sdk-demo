//
//  ShopliveBootstrap.swift
//  ★ COPY THIS — step 1 of the integration guide's "Quick start"
//
//  Exactly once for the whole app: Shoplive.initialize.
//  Presenting the player or studio before this call fails with
//  ShopliveErrorCode.notInitializedAccessKey (9000).
//

import Foundation
import ShopliveCore

enum ShopliveBootstrap {

    /// Call once at app startup. Only `accessKey` is required; the rest have defaults.
    ///
    /// - Parameters:
    ///   - accessKey: The value issued in the Queenie console.
    ///   - allowedWebViewDomains: Whitelist of domains the overlay web view may navigate to.
    ///                            Leaving it empty (the default `[]`) disables validation.
    ///   - attribution: Acquisition tracking (4 UTM fields + ad identifier). The app collects
    ///                  these and passes them in.
    static func initialize(accessKey: String,
                           allowedWebViewDomains: [String] = [],
                           attribution: ShopliveAttribution? = nil) {

        // ShopliveConfiguration is an input-only value type — every field is `let`, so there is
        // no reading back or mutating it after initialization. To change it, build a new one and
        // call initialize again.
        let configuration = ShopliveConfiguration(
            accessKey: accessKey,
            allowedWebViewDomains: allowedWebViewDomains,
            attribution: attribution
        )

        Shoplive.initialize(configuration)

        shopliveLog(.call, "initialize(accessKey: \"\(shopliveMasked(accessKey))\") · SDK \(Shoplive.sdkVersion)")
    }
}
