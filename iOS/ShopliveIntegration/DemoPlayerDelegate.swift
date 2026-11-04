//
//  DemoPlayerDelegate.swift
//  ★ COPY THIS — mission 6 · events · products · coupons
//
//  The delegate has exactly two methods:
//    · didReceive event  — things you just listen to (notifications)
//    · didRequest request — things the app must answer. You must call respond.
//
//  Threading: both callbacks are expected on the main thread, but the SDK interface does not state it
//  (no @MainActor) — 요확인 (S55). publish() below moves an off-main callback to main. The respond
//  closure may be called from any thread.
//  Memory contract: `delegate` is weak — the host owns its lifetime. That is why this demo holds it
//  in a singleton.
//
//  One delegate serves every player in the app, so what the rest of the app needs is re-published on
//  **one** channel — `PlayerMilestone`, always together with the player that sent it. Each listener
//  subscribes to the player it cares about (`observeMilestones(of:)`), so no screen overwrites another
//  screen's callback and a late event from an old session cannot reach a new screen.
//

import UIKit
import ShoplivePlayerSDK
import ShopliveCore

/// What this delegate tells the rest of the app — one channel, one publish per fact (CG-4.2).
enum PlayerMilestone {
    /// Playback reached (first frame). Can repeat within one session (`rendering`).
    case playbackReached
    /// Sent on every state change except `.closed`; `true` only while in in-App PIP.
    case pipStateChanged(isActive: Bool)
    /// A request arrived. coupon/customWebAction are already answered here; navigation must be routed.
    case requestReceived(PlayerRequestKind)
    /// The session ended. `reason` is the player's `closeReason` at that moment (3.0.4+).
    case closed(reason: ShopliveCloseReason?)
    /// `.ready` / `.live` / `.ended` — e.g. close a preview that is not live (guide "Tip").
    case campaignStatusChanged(ShopliveCampaignStatus)
    /// An unrecoverable error (`isRecoverable == false`).
    case fatalError(ShopliveError)
}

enum PlayerRequestKind {
    /// Product landing — open `url` in your own screen.
    case navigation(URL)
    case coupon
    case customWebAction
}

final class DemoPlayerDelegate: NSObject, ShoplivePlayerDelegate {

    /// Because the delegate is weak, something must hold it strongly or events stop arriving.
    static let shared = DemoPlayerDelegate()

    // MARK: - Notifications (didReceive)

    func player(_ player: ShoplivePlayerControlling, didReceive event: ShoplivePlayerEvent) {
        switch event {

        case .stateChanged(let state):
            // Playback lifecycle. Entering/leaving .inAppPIP also arrives through this event.
            //
            // ★ `.closed` is session end, NOT a return from PIP — closing the PIP window lands here.
            //   Keep the two apart: after `.closed` the render surface is gone, so a host that un-hides
            //   on "PIP ended" covers the screen with its own background until it is dismissed.
            if state == .closed {
                // 3.0.4: the reason is a property of the player, not of the state — `.closed` has no
                // associated value in this build (the guide's `if case .closed(let reason)` does not
                // compile on iOS 3.0.4).
                let reason = player.closeReason
                // TODO(SDP-VERIFY): 요확인 — .closed 수신 시점에 closeReason 이 이미 채워져 있는지(nil 이면 아래 로그가 '이유 없음'), 실기기 3종(✕·앱 close·accessKey 변경) 확인 · 근거 SMV-1922 S16
                shopliveLog(.event, "stateChanged(.closed) — closeReason: \(reason.map { ".\($0.logLabel)" } ?? "nil (no reason)")")
                publish(.closed(reason: reason), from: player)
            } else {
                shopliveLog(.event, "stateChanged(.\(state.logLabel))")
                if state == .playing { publish(.playbackReached, from: player) }
                publish(.pipStateChanged(isActive: state == .inAppPIP), from: player)
            }

        case .campaignStatusChanged(let status):
            // .ready / .live / .ended — decide whether to show the LIVE badge from this value.
            shopliveLog(.event, "campaignStatusChanged(.\(status.logLabel))")
            publish(.campaignStatusChanged(status), from: player)

        case .campaignInfoReceived(let info):
            shopliveLog(.event,
                "campaignInfoReceived(campaignKey: \"\(info.campaignKey)\", title: \(info.title.map { "\"\($0)\"" } ?? "nil"), status: \(info.status.map { ".\($0.logLabel)" } ?? "nil"))")

        case .playback(let playback):
            // PlaybackEvent is a class — the state is in `.event`, extra details in `.datas`.
            shopliveLog(.event, "playback(\(playback.event.logLabel))")

            // ★ Measured (2026-07-30, SDK 3.0.0): across a healthy playback session the SDK never
            //   sends `stateChanged` even once. So gating "did playback start?" on stateChanged alone
            //   never becomes true. We decide it from playback(STARTED/RENDERING), which does arrive.
            if playback.event == .started || playback.event == .rendering {
                publish(.playbackReached, from: player)
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
            if !error.isRecoverable { publish(.fatalError(error), from: player) }

        case .webCommand(let name, let payload):
            // A custom command from the overlay web (e.g. a login request). The reverse direction is
            // send(command:payload:).
            shopliveLog(.event, "webCommand(name: \"\(name)\", payload: \(payload.map { "\($0.keys.sorted())" } ?? "nil"))")

        case .shareRequested(let info):
            // 3.0.4+: arrives only with navigation.isCustomShareEnabled = true, and then the SDK shows
            // no share sheet of its own — the app shows one (or nothing is shared).
            shopliveLog(.event,
                "shareRequested(url: \(info.url?.absoluteString ?? "nil"), campaignKey: \(info.campaignKey ?? "nil"), title: \(info.title ?? "nil"))")
            Self.presentShareSheet(for: info)

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
            publish(.requestReceived(.navigation(url)), from: player)
            shopliveLog(.request, "→ handed to the app's router")

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
            publish(.requestReceived(.coupon), from: player)

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
            publish(.requestReceived(.customWebAction), from: player)

        @unknown default:
            // A request that demands an answer, but we don't know how to handle it. Logging and
            // ignoring it can leave the overlay waiting forever, so check the SDK version.
            shopliveLog(.error, "Unknown ShoplivePlayerRequest — cannot call respond. Check your SDK version")
        }
    }
}

// MARK: - The milestone channel

extension DemoPlayerDelegate {

    static let milestoneNotification = Notification.Name("DemoPlayerDelegate.milestone")
    private static let milestoneKey = "milestone"

    /// Subscribes to milestones. `player` nil = every player; otherwise only that player's (identity,
    /// not equality — NotificationCenter matches `object` by `===`).
    ///
    /// Delivered on the main thread (moved there if a callback ever arrives off main). Keep the returned
    /// token and pass it to `NotificationCenter.default.removeObserver(_:)` when the listener goes away.
    static func observeMilestones(
        of player: ShoplivePlayerControlling?,
        _ handler: @escaping (ShoplivePlayerControlling, PlayerMilestone) -> Void
    ) -> NSObjectProtocol {
        // TODO(SDP-VERIFY): 요확인 — 콜백의 player 인자가 앱이 가진 그 객체인지(=== 필터·owner 비교의 전제): VC 세션은 ShoplivePlayerViewController 자신, 피드 임베드는 EmbeddedPlayerView.player 가 돌려주는 ShoplivePlayerView 자신. 3.0.4 디스어셈블상 VC.delegate.setter 가 VC 자체 weak 필드에 저장(0xdc2e0)해 VC 쪽 근거는 강하나 둘 다 실측 전 · 근거 SMV-1922 S50·S47
        NotificationCenter.default.addObserver(forName: milestoneNotification, object: player, queue: nil) { note in
            guard let sender = note.object as? ShoplivePlayerControlling,
                  let milestone = note.userInfo?[milestoneKey] as? PlayerMilestone else { return }
            handler(sender, milestone)
        }
    }

    private func publish(_ milestone: PlayerMilestone, from player: ShoplivePlayerControlling) {
        // TODO(SDP-VERIFY): 요확인 — SDK 가 delegate 를 항상 메인 스레드에서 부르는지(swiftinterface 에 @MainActor 근거 없음, P.si:318). 아니면 여기서 메인으로 넘기고 로그 · 근거 SMV-1922 S55
        guard Thread.isMainThread else {
            shopliveLog(.error, "delegate callback arrived off the main thread — milestone moved to main")
            DispatchQueue.main.async { self.publish(milestone, from: player) }
            return
        }
        NotificationCenter.default.post(name: Self.milestoneNotification, object: player,
                                        userInfo: [Self.milestoneKey: milestone])
    }
}

// MARK: - Sharing (3.0.4+)

extension DemoPlayerDelegate {

    /// `true` → the share button sends `shareRequested` instead of opening the SDK's share sheet.
    /// The SDK default is `false`.
    static func enableCustomShare(_ enabled: Bool, in configuration: inout ShoplivePlayerConfiguration) {
        configuration.navigation.isCustomShareEnabled = enabled
    }

    /// Shows the app's own share sheet for `info`. With nothing to share or nowhere to show it, nothing
    /// is shown and the reason is logged.
    static func presentShareSheet(for info: ShopliveShareInfo) {
        guard let url = info.url else {
            shopliveLog(.error, "shareRequested without a url — share sheet not shown")
            return
        }
        guard let presenter = DeepLinkRouter.topViewController() else {
            shopliveLog(.error, "shareRequested — no view controller to present the share sheet from")
            return
        }
        var items: [Any] = [url]
        if let title = info.title { items.insert(title, at: 0) }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad presents this as a popover, which needs an anchor or UIKit raises.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(sheet, animated: true)
        shopliveLog(.call, "UIActivityViewController(url: \"\(url.absoluteString)\") → present")
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
