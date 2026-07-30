//
//  DeepLinkRouter.swift
//  ★ COPY THIS — mission 2 · opening the player from a deep link
//
//  The entry points are the two methods in App/SceneDelegate.swift:
//    · scene(_:willConnectTo:options:)  — the app was not running and was launched by the link
//    · scene(_:openURLContexts:)        — the app was already running
//  Both paths funnel into handle(_:) here. Wire up only one and half the cases won't open.
//
//  Link shape: shopliveDemo://live?campaign=<CAMPAIGN_KEY>&ref=<REFERRER>
//

import UIKit
import ShoplivePlayerSDK

final class DeepLinkRouter {

    static let shared = DeepLinkRouter()

    private init() {}

    // MARK: - Injection points
    //
    // A deep link can arrive from anywhere in the app, so this router presents playback itself.
    // The configuration and delegate it uses are the host's decision, so they are injected — the
    // defaults work on their own.

    /// The configuration to play with. Defaults to the SDK's default configuration.
    var configurationProvider: () -> ShoplivePlayerConfiguration = { .init() }

    /// The delegate that receives events. `delegate` is weak, so **the host must own it strongly**.
    var delegateProvider: () -> ShoplivePlayerDelegate? = { nil }

    /// Parses the deep link and presents the player. Returns false if it isn't our link, so the caller
    /// can hand it to another router.
    @discardableResult
    func handle(_ url: URL) -> Bool {

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let campaignKey = components.queryItems?
                  .first(where: { $0.name == "campaign" })?.value,
              !campaignKey.isEmpty
        else {
            shopliveLog(.error, "deep link parse failed — no campaign parameter: \(url.absoluteString)")
            return false
        }

        let referrer = components.queryItems?.first(where: { $0.name == "ref" })?.value

        shopliveLog(.call, "deep link received — \(url.absoluteString)")

        // ShoplivePlayOptions applies to **this single playback only** (as opposed to
        // ShoplivePlayerConfiguration, which is policy).
        var options = ShoplivePlayOptions()
        options.referrer = referrer

        shopliveLog(.call, "parsed → play(campaignKey: \"\(campaignKey)\", referrer: \(referrer.map { "\"\($0)\"" } ?? "nil"))")

        guard let presenter = Self.topViewController() else {
            shopliveLog(.error, "could not find a top-most ViewController to present from")
            return false
        }

        PlayerLauncher.present(
            campaignKey: campaignKey,
            from: presenter,
            options: options,
            configuration: configurationProvider(),
            delegate: delegateProvider()
        )
        return true
    }

    /// Deep links arrive from any screen, so we have to locate the presenter ourselves.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                     ?? scene?.windows.first?.rootViewController else { return nil }

        while let presented = top.presentedViewController { top = presented }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController { top = visible }
        return top
    }
}
