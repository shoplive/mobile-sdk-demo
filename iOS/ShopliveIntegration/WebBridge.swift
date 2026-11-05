//
//  WebBridge.swift
//  ★ COPY THIS — mission 7 · inline preview in a list (hybrid — the list is a web page)
//
//  The list stays in a WKWebView; when a card is tapped the page sends one campaignKey to the app
//  through `ShopLiveAppInterface`, and the app opens its native player (guide mission 7, method B).
//  This bridge is plain WebKit, not an SDK feature.
//
//  Ownership: WKUserContentController holds a message handler **strongly**, so
//    · the bridge reaches back to your screen only through the closure you pass (capture it weakly);
//    · your screen removes the handler when it goes away — `uninstall(from:)` in deinit.
//
//  The bridge can be called by any page loaded in the web view, so it also keeps the web view on your
//  own pages and opens everything else outside the app (guide mission 7, "the bridge is callable from
//  any page").
//

import UIKit
import WebKit

final class WebBridge: NSObject {

    /// The name the web page calls: `window.webkit.messageHandlers.ShopLiveAppInterface.postMessage(key)`.
    static let interfaceName = "ShopLiveAppInterface"

    private let isOwnPage: (URL) -> Bool
    private let onCampaignKey: (String) -> Void

    /// - Parameters:
    ///   - isOwnPage: which URLs may load inside the web view. Everything else opens outside the app.
    ///   - onCampaignKey: called on the main thread with a validated key (WebBridgeInput). Capture your
    ///     screen weakly — the content controller keeps this bridge alive.
    init(isOwnPage: @escaping (URL) -> Bool, onCampaignKey: @escaping (String) -> Void) {
        self.isOwnPage = isOwnPage
        self.onCampaignKey = onCampaignKey
        super.init()
    }

    /// Registers the bridge. Call it **before** creating the WKWebView with this configuration.
    func install(on configuration: WKWebViewConfiguration) {
        configuration.userContentController.add(self, name: Self.interfaceName)
        shopliveLog(.call, "userContentController.add(_, name: \"\(Self.interfaceName)\")")
    }

    /// Removes the bridge. Call it from the hosting screen's deinit.
    static func uninstall(from controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: interfaceName)
        shopliveLog(.call, "userContentController.removeScriptMessageHandler(forName: \"\(interfaceName)\")")
    }

    private func openOutside(_ url: URL) {
        shopliveLog(.call, "external link → opened outside the web view: \(url.absoluteString)")
        UIApplication.shared.open(url) { opened in
            if !opened { shopliveLog(.error, "no app could open \(url.absoluteString) — staying on the page") }
        }
    }
}

// MARK: - Web → app

extension WebBridge: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.interfaceName else { return }

        switch WebBridgeInput.campaignKey(from: message.body) {
        case .accepted(let campaignKey):
            shopliveLog(.request, "\(Self.interfaceName).postMessage(\"\(campaignKey)\") received → open the player")
            // TODO(SDP-VERIFY): 요확인 — campaignKey 형식 규칙 근거가 없어 공백이 아닌 문자열은 그대로 SDK 에 넘긴다. 잘못된 키가 SDK error 경로(U03 · 실패 안내 1회)로 가는지 실측 · 근거 SMV-1922 S10
            onCampaignKey(campaignKey)
        case .rejected(let reason):
            // Nothing opens and nothing is marked done (AC-2) — the reason is all that is left.
            shopliveLog(.error, "\(Self.interfaceName).postMessage ignored — \(reason)")
        }
    }
}

// MARK: - Keep the web view on your own pages

extension WebBridge: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isOwnPage(url) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            openOutside(url)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        shopliveLog(.error, "web page failed to load — \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        shopliveLog(.error, "web page failed — \(error.localizedDescription)")
    }
}

extension WebBridge: WKUIDelegate {

    /// `target="_blank"` / `window.open`. External URLs were already sent outside by the policy above;
    /// one of your own pages loads in this web view instead of a new one.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url, isOwnPage(url) else { return nil }
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
