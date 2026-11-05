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
        MissionProgress.shared.startObserving()     // first touch migrates the record; subscribes before any player starts
        wireDeepLinkRouter()
        initializeIfCredentialsAvailable()
    }

    /// Plugs the demo's own configuration, delegate and session handling into the deep link router.
    /// The providers stay side-effect free; closing the session on screen happens in `beforePresent`,
    /// before the router picks its presenter (SMV-1922 N1).
    private static func wireDeepLinkRouter() {
        let router = DeepLinkRouter.shared
        router.configurationProvider = { DemoConfigBuilder.makeConfiguration(.fullScreenLive) }
        router.delegateProvider = { DemoPlayerDelegate.shared }
        router.beforePresent = { proceed in DevSheetViewController.replaceCurrentSession(then: proceed) }
        router.onPresented = { player in
            DemoPlayerDelegate.adopt(player)
            DevSheetViewController.recordSession(player, presentedAs: player, for: .deeplink)
        }
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
