//
//  DemoPlayerDelegate.swift
//  ★ COPY THIS — mission 6 · events · products · coupons
//
//  The delegate has exactly two methods:
//    · didReceive event  — things you just listen to (notifications)
//    · didRequest request — things the app must answer. You must call respond.
//
//  Threading contract: the SDK **guarantees both callbacks are invoked on the main thread**. The
//  respond closure may be called from any thread.
//  Memory contract: `delegate` is weak — the host owns its lifetime. That is why this demo holds it
//  in a singleton.
//

import UIKit
import ShoplivePlayerSDK
import ShopliveCore

final class DemoPlayerDelegate: NSObject, ShoplivePlayerDelegate {

    /// Because the delegate is weak, something must hold it strongly or events stop arriving.
    static let shared = DemoPlayerDelegate()

    /// Routes product landings (navigation) to an app screen. In the demo this opens the V2 product
    /// detail modal.
    var onNavigation: ((URL) -> Void)?

    /// Called when an unrecoverable error arrives. The demo shows the reason.
    /// (If the error prevents the overlay from loading, the SDK's own close button is missing too and
    /// the user gets stuck.)
    var onFatalError: ((ShopliveError) -> Void)?

    /// in-App PIP enter/exit. `true` = promoted to PIP.
    ///
    /// Going to PIP moves the render surface into a floating container on the app window, so the
    /// full-screen host must step out of the way (otherwise a black screen covers everything).
    var onPipStateChanged: ((Bool) -> Void)?

    /// Playback reached (first frame rendered). The host uses this for its "verified" marker.
    ///
    /// - Note: Some SDK builds never deliver `stateChanged(.playing)` (measured), so
    ///   `playback(STARTED/RENDERING)` is used as the playback-reached signal.
    var onPlaybackReached: (() -> Void)?

    // MARK: - Notifications (didReceive)

    func player(_ player: ShoplivePlayerControlling, didReceive event: ShoplivePlayerEvent) {
        switch event {

        case .stateChanged(let state):
            // Playback lifecycle. Entering/leaving .inAppPIP also arrives through this event.
            shopliveLog(.event, "stateChanged(.\(state.logLabel))")
            if state == .playing { onPlaybackReached?() }
            // Tell the host about PIP promotion/return. Every state other than `.inAppPIP` counts as
            // "not in PIP".
            onPipStateChanged?(state == .inAppPIP)

        case .campaignStatusChanged(let status):
            // .ready / .live / .ended — decide whether to show the LIVE badge from this value.
            shopliveLog(.event, "campaignStatusChanged(.\(status.logLabel))")

        case .campaignInfoReceived(let info):
            shopliveLog(.event,
                "campaignInfoReceived(campaignKey: \"\(info.campaignKey)\", title: \(info.title.map { "\"\($0)\"" } ?? "nil"), status: \(info.status.map { ".\($0.logLabel)" } ?? "nil"))")

        case .playback(let playback):
            // PlaybackEvent is a class — the state is in `.event`, extra details in `.datas`.
            shopliveLog(.event, "playback(\(playback.event.logLabel))")

            // ★ Measured (2026-07-30, SDK 2.0.20.1): across a healthy playback session the SDK never
            //   sends `stateChanged` even once. So gating "did playback start?" on stateChanged alone
            //   never becomes true. We decide it from playback(STARTED/RENDERING), which does arrive.
            //   (`campaignStatusChanged` and `campaignInfoReceived` were also missing on older builds
            //   but are delivered again on the current one.)
            if playback.event == .started || playback.event == .rendering {
                onPlaybackReached?()
            }

        case .connectionStateChanged(let state):
            // Shared connection state, independent of engine (HLS/WebRTC). Drive a network banner off
            // `.reconnecting`.
            shopliveLog(.event, "connectionStateChanged(.\(state.logLabel))")

        case .userNameUpdateRequested(let payload):
            // The overlay asked to change the nickname — send the user to the app's profile screen.
            shopliveLog(.event, "userNameUpdateRequested(\(payload.keys.sorted()))")

        case .analytics(let info):
            // The hook for forwarding viewing statistics to your own analytics.
            shopliveLog(.event,
                "analytics(campaignKey: \"\(info.campaignKey)\", isPlaying: \(info.isPlaying), durationMs: \(info.durationMs), campaign: \(info.campaign?.title ?? "nil"), brand: \(info.brand?.name ?? "nil"))")

        case .error(let error):
            // Only unrecoverable errors arrive here. Issues being auto-recovered do not surface as
            // errors.
            shopliveLog(.error,
                "error(code: .\(error.code.logLabel), isRecoverable: \(error.isRecoverable)) — \(error.message)")
            if !error.isRecoverable { onFatalError?(error) }

        // The SDK ships with library evolution enabled, so its enums are resilient — always include
        // @unknown default so a newly added case cannot break this app.
        @unknown default:
            shopliveLog(.event, "Unknown ShoplivePlayerEvent — an SDK update added a new case")
        }
    }

    // MARK: - Requests that need an answer (didRequest)

    func player(_ player: ShoplivePlayerControlling, didRequest request: ShoplivePlayerRequest) {
        switch request {

        case .navigation(let url):
            // ★ The one request the app absolutely must handle. Without it, tapping a product does
            //   nothing at all.
            shopliveLog(.request, "navigation(url: \"\(url.absoluteString)\") received — the app must handle this")
            onNavigation?(url)
            shopliveLog(.request, "→ router.open(url) called")

        case .coupon(let id, let respond):
            // The app (i.e. your server) issues the coupon and returns the result to the overlay.
            shopliveLog(.request, "coupon(id: \"\(id)\", respond:) received")

            // In a real app you would call your coupon API here and fill in success/message from its
            // result.
            let result = ShopliveCouponResult(
                couponId: id,
                success: true,
                message: "Your coupon has been issued",
                status: .show,      // surface the result in the overlay
                alertType: .toast   // as a toast
            )
            respond(result)
            shopliveLog(.request, "→ respond(success: true, status: .show, alertType: .toast) called")

        case .customWebAction(let id, let type, let payload, let respond):
            // An arbitrary action defined by the overlay web. Branch on `type` to run an app feature.
            shopliveLog(.request,
                "customWebAction(id: \"\(id)\", type: \"\(type)\", payload: \(payload.map { "\($0)" } ?? "nil")) received")

            let result = ShopliveCustomActionResult(
                id: id,
                success: true,
                message: nil,
                status: .keep,      // leave the overlay's display state as it is
                alertType: .alert
            )
            respond(result)
            shopliveLog(.request, "→ respond(success: true, status: .keep) called")

        @unknown default:
            // A request that demands an answer, but we don't know how to handle it. Logging and
            // ignoring it can leave the overlay waiting forever, so check the SDK version.
            shopliveLog(.error, "Unknown ShoplivePlayerRequest — cannot call respond. Check your SDK version")
        }
    }
}

// MARK: - App → overlay commands

extension DemoPlayerDelegate {

    /// The app sends a command to the overlay web. (Receiving is not exposed as a public event — this
    /// is a send-only channel.)
    static func sendHighlightProduct(sku: String, to player: ShoplivePlayerControlling) {
        player.send(command: "HIGHLIGHT_PRODUCT", payload: ["sku": sku])
        shopliveLog(.call, "send(command: \"HIGHLIGHT_PRODUCT\", payload: [\"sku\": \"\(sku)\"])")
    }
}
