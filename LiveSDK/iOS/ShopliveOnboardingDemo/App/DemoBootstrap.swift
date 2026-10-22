//
//  DemoBootstrap.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Does two things at app startup:
//   ① wires ShopliveIntegration/'s logging hook (shopliveLog) to the developer sheet's EventLog
//   ② initializes the SDK if stored credentials exist
//

import Foundation
import ShopliveCore

enum DemoBootstrap {

    static func start() {
        wireLogging()
        wireDeepLinkRouter()
        initializeIfCredentialsAvailable()
    }

    /// Plugs the demo's own configuration and delegate into the deep link router.
    private static func wireDeepLinkRouter() {
        DeepLinkRouter.shared.configurationProvider = { DemoConfigBuilder.makeConfiguration(.fullScreenLive) }
        DeepLinkRouter.shared.delegateProvider = { DemoPlayerDelegate.shared }
    }

    /// ShopLiveIntegration/ knows nothing about the harness — the wiring happens here, once.
    private static func wireLogging() {
        shopliveLog = { kind, message in
            let demoKind: EventLog.Kind
            switch kind {
            case .call:    demoKind = .sdk
            case .event:   demoKind = .event
            case .request: demoKind = .request
            case .error:   demoKind = .error
            }
            EventLog.shared.log(demoKind, message)
        }
    }

    private static func initializeIfCredentialsAvailable() {
        let credentials = DemoCredentials.shared
        guard !credentials.accessKey.isEmpty else { return }

        ShopliveBootstrap.initialize(
            accessKey: credentials.accessKey,
            // The demo leaves the whitelist empty, which disables validation. In a real app we
            // recommend listing your product landing and event page domains here.
            allowedWebViewDomains: [],
            attribution: ShopliveAttribution(utmSource: "onboarding_demo", utmMedium: "ios_app")
        )
    }
}
