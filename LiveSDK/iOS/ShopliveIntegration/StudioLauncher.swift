//
//  StudioLauncher.swift
//  ★ COPY THIS — mission 8 · broadcasting
//
//  The SDK provides the entire studio UI (camera preview, switching, zoom, chat, settings). There is
//  nothing for the app to draw.
//  Resolution and bitrate are server-driven, so no app code is needed for them.
//
//  Info.plist must contain NSCameraUsageDescription and NSMicrophoneUsageDescription.
//

import UIKit
import ShopliveCore
import ShopliveStreamerSDK

enum StudioLauncher {

    /// Presents the studio.
    ///
    /// - Important: The stream token (`Shoplive.setStreamToken`) is a **completely separate path from
    ///   viewer authentication**. Calling `setUser` does not enable broadcasting, and presenting
    ///   without a token fails to assemble with an authentication error.
    ///
    /// - Note: The caller does not pass whether this is a rehearsal — the SDK fetches the campaign
    ///         config and decides on its own. That is why the public entry point takes only
    ///         `campaignKey`.
    @discardableResult
    static func present(campaignKey: String,
                        streamToken: String,
                        from presenter: UIViewController,
                        delegate: ShopliveStreamerDelegate? = nil) -> ShopliveStreamerViewController {

        // 1) Stream token (required)
        Shoplive.setStreamToken(streamToken)
        shopliveLog(.call, "setStreamToken(\"\(shopliveMasked(streamToken))\")")

        // 2) Launch the studio
        let studio = ShopliveStreamerViewController(campaignKey: campaignKey)
        studio.streamerDelegate = delegate      // weak — the host owns its lifetime
        studio.modalPresentationStyle = .fullScreen

        shopliveLog(.call, "ShopliveStreamerViewController(campaignKey: \"\(campaignKey)\") → present")
        presenter.present(studio, animated: true)
        return studio
    }

    // NOTE: On dev (5f0ee781) the streamer's appearance options (AppearanceOptions / setFont) were
    //       **removed** from the public surface. `init(campaignKey:)` is the only entry point, and
    //       there is currently no public way to customize the studio's fonts or colors.
}

// MARK: - Receiving state

/// Streamer events come on two channels — state transitions (`stateChanged`) and errors (`error`).
/// Failures surface only as `.ended`, and `error` is emitted solely from the internal onError, so
/// there is no duplication.
final class DemoStreamerDelegate: NSObject, ShopliveStreamerDelegate {

    static let shared = DemoStreamerDelegate()

    /// Notifies the host so the demo UI can refresh on state changes (not part of the copy target).
    var onStateChanged: ((ShopliveBroadcastState) -> Void)?

    func streamer(_ streamer: ShopliveStreamerViewController, didReceive event: ShopliveStreamerEvent) {
        switch event {
        case .stateChanged(let state):
            shopliveLog(.event, "ShopliveStreamerEvent.stateChanged(.\(state.logLabel))")
            onStateChanged?(state)

        case .error(let error):
            shopliveLog(.error,
                "ShopliveStreamerEvent.error(code: .\(error.code.logLabel), isRecoverable: \(error.isRecoverable)) — \(error.message)")

        @unknown default:
            shopliveLog(.event, "Unknown ShopliveStreamerEvent — an SDK update added a new case")
        }
    }
}
