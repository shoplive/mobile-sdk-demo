//
//  ShopliveLog.swift
//  ★ COPY THIS — the only "outward hole" in ShopliveIntegration/
//
//  Code inside ShopliveIntegration/ calls **only this function** to log.
//  The default implementation is a no-op, so copying this file along with the rest
//  compiles as-is with no further dependencies.
//
//  · Your app: leave it alone and nothing is printed. To plug in your own logger,
//    one line at startup:
//        shopliveLog = { kind, message in MyLogger.debug("[Shoplive] \(kind) \(message)") }
//    If you don't need logging at all, delete this file and its call sites
//    (every call site is a single line).
//
//  · Demo app: App/DemoBootstrap.swift wires this to EventLog at startup so the
//    output shows up in the developer sheet.
//
//  Why funnel logging through a single hole: if a copy-target file referenced the demo
//  harness (EventLog and friends) directly, it would fail to compile the moment you
//  copied it out. The boundary is enforced in CI by
//  scripts/integration_boundary_scanner.py.
//

import Foundation

/// Log kind — separates direction and nature. This distinction is the key to reading the flow.
public enum ShopliveLogKind: String {
    /// App → SDK call.
    case call = "→SDK"
    /// SDK → app notification (`didReceive event`).
    case event = "EVENT"
    /// SDK → app request (`didRequest`) — something the app must respond to.
    case request = "REQUEST"
    /// Error.
    case error = "ERROR"
}

/// Logging hook used only by Integration/. Defaults to a no-op.
public var shopliveLog: (ShopliveLogKind, String) -> Void = { _, _ in }

/// Exposes only the first 8 characters when writing a token or key to the log.
/// We don't know where logs end up, so credentials are never printed verbatim.
public func shopliveMasked(_ value: String) -> String {
    guard !value.isEmpty else { return "(none)" }
    return value.count <= 8 ? value : String(value.prefix(8)) + "…"
}
