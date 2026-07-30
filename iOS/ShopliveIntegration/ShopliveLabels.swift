//
//  ShopliveLabels.swift
//  ★ COPY THIS — short labels for printing SDK enums in logs and UI
//
//  The SDK's public enums do not conform to `CustomStringConvertible`, so interpolating them
//  directly reads poorly. These are the minimum extensions needed to make logs human-readable, which
//  is why they belong to the copy target.
//  The enums are resilient, so every switch carries an `@unknown default` (the SDK ships with library
//  evolution enabled).
//

import Foundation
import ShoplivePlayerSDK
import ShopliveStreamerSDK
import ShopliveCore

extension ShoplivePipPosition {
    var logLabel: String {
        switch self {
        case .topLeft: return "topLeft";           case .topCenter: return "topCenter"
        case .topRight: return "topRight";         case .middleLeft: return "middleLeft"
        case .middleCenter: return "middleCenter"; case .middleRight: return "middleRight"
        case .bottomLeft: return "bottomLeft";     case .bottomCenter: return "bottomCenter"
        case .bottomRight: return "bottomRight"
        @unknown default: return "unknown"
        }
    }
}

extension ShopliveNavigationAction {
    var logLabel: String {
        switch self {
        case .pip: return "pip"; case .keep: return "keep"; case .close: return "close"
        @unknown default: return "unknown"
        }
    }
    var next: ShopliveNavigationAction {
        switch self {
        case .pip: return .keep; case .keep: return .close; case .close: return .pip
        @unknown default: return .pip
        }
    }
}

extension ShopliveOverlayUIMode {
    var logLabel: String { self == .builtIn ? "builtIn" : "hidden" }
    var toggled: ShopliveOverlayUIMode { self == .builtIn ? .hidden : .builtIn }
}

extension ShopliveResizeMode {
    var logLabel: String { self == .fill ? "fill" : "fit" }
    var toggled: ShopliveResizeMode { self == .fill ? .fit : .fill }
}

extension ShoplivePlayerState {
    var logLabel: String {
        switch self {
        case .idle: return "idle";       case .loading: return "loading"
        case .playing: return "playing"; case .paused: return "paused"
        case .inAppPIP: return "inAppPIP"; case .closed: return "closed"
        @unknown default: return "unknown"
        }
    }
}

extension ShopliveCampaignStatus {
    var logLabel: String {
        switch self {
        case .ready: return "ready"; case .live: return "live"; case .ended: return "ended"
        @unknown default: return "unknown"
        }
    }
}

extension ShopliveConnectionState {
    var logLabel: String {
        switch self {
        case .connecting: return "connecting"; case .connected: return "connected"
        case .reconnecting: return "reconnecting"; case .disconnected: return "disconnected"
        @unknown default: return "unknown"
        }
    }
}

// `ShopliveBroadcastState` comes from ShopliveStreamerSDK — its label is at the bottom of this file.

extension PlaybackEventType {
    var logLabel: String { stringValue }
}

extension ShopliveErrorCode {
    /// For log display. `.unknown(code)` preserves and shows the original code.
    var logLabel: String {
        if case .unknown(let raw) = self { return "unknown(\(raw))" }
        return "\(self)"
    }
}

extension ShopliveBroadcastState {
    var logLabel: String {
        switch self {
        case .idle: return "idle"
        case .preview: return "preview"
        case .connecting: return "connecting"
        case .live: return "live"
        case .reconnecting: return "reconnecting"
        case .ended: return "ended"
        @unknown default: return "unknown"
        }
    }
}
