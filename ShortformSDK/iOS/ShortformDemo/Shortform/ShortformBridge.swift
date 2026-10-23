import UIKit
import ShopLiveShortformSDK
import ShopliveSDKCommon

/// The app's single `ShopLiveShortformDelegate` and the only place that calls the SDK's static API
/// (`ShopLiveCommon.setAccessKey`, `ShopLiveShortform.play`, `showPreview`, `close`).
///
/// A product tapped inside a video closes the SDK player and opens the app's own product page for the matching
/// catalog entry (`productId` → `customerProductId` → `sku` → `url`).
final class ShortformBridge: NSObject {
    static let shared = ShortformBridge()

    weak var navigationController: UINavigationController?

    var sdkVersion: String { ShopLiveShortform.sdkVersion }

    // MARK: - Setup

    func configure(accessKey: String?) {
        setAccessKey(accessKey)
    }

    /// Sent with every request so the demo's traffic is easy to tell apart.
    static let referrer = "shortform-demo-ios"

    func setAccessKey(_ key: String?) {
        ShopLiveCommon.setAccessKey(accessKey: key)
        EventLog.shared.add("setAccessKey", key == nil ? "cleared" : "set")
    }

    // MARK: - Full screen and preview

    /// `ShopLiveShortform.play`: a collection with `ShopLiveShortformCollectionData`; product conditions
    /// (productId → url → skus) or tags with `ShopLiveShortformRelatedData`.
    func play(_ query: ShortformQuery) {
        defer { EventLog.shared.add("play", describe(query)) }
        if let collectionId = query.collectionId {
            ShopLiveShortform.play(requestData: ShopLiveShortformCollectionData(referrer: Self.referrer,
                                                                                shortsCollectionId: collectionId,
                                                                                delegate: self))
            return
        }
        // The full-screen entry point that takes productId / url. The current 1.9.1 pre-release binaries mark it
        // deprecated; that mark is being removed in the SDK, so the app keeps using it.
        let data = ShopLiveShortformRelatedData(productId: query.productId,
                                                skus: query.skus,
                                                url: query.url,
                                                tags: query.tags,
                                                tagSearchOperator: query.tags == nil ? nil : .OR,
                                                referrer: Self.referrer,
                                                delegate: self)
        ShopLiveShortform.play(requestData: data)
    }

    struct PreviewStyle {
        var corner: DetailOptions.Corner
        var width: Double
        var maxCount: Int
    }

    /// `ShopLiveShortform.showPreview` — a floating preview in a corner of the screen.
    func showPreview(_ query: ShortformQuery, style: PreviewStyle) {
        let position: ShopLiveShortform.PreviewPosition
        switch style.corner {
        case .topLeft: position = .topLeft
        case .topRight: position = .topRight
        case .bottomLeft: position = .bottomLeft
        case .bottomRight: position = .bottomRight
        }
        // previewScale is the preview width relative to the screen's shorter side.
        let shortSide = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let scale = CGFloat(style.width) / max(shortSide, 1)
        let data = ShopLiveShortformPreviewData(productId: query.productId,
                                                skus: query.skus,
                                                url: query.url,
                                                tags: query.tags,
                                                tagSearchOperator: query.tags == nil ? nil : .OR,
                                                referrer: Self.referrer,
                                                isMuted: true,
                                                previewPosition: position,
                                                previewScale: scale,
                                                previewRadius: 12,
                                                useCloseButton: true,
                                                enableSwipeOut: true,
                                                maxCount: style.maxCount,
                                                delegate: self)
        ShopLiveShortform.showPreview(requestData: data)
        EventLog.shared.add("showPreview", describe(query) + " corner=\(style.corner.rawValue) max=\(style.maxCount)")
    }

    func close() {
        ShopLiveShortform.close()
    }

    // MARK: - Product routing

    private func openProduct(_ ref: ProductRef) {
        let catalog = AppEnvironment.shared.catalog
        ShopLiveShortform.close()
        // Let the SDK window go away before pushing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let nav = self?.navigationController else { return }
            nav.presentedViewController?.dismiss(animated: false)
            if let product = catalog.product(matching: ref) {
                nav.pushViewController(ProductDetailViewController(product: product), animated: true)
            } else {
                let alert = UIAlertController(title: nil, message: L("detail_not_in_catalog"), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L("settings_ok"), style: .default))
                nav.present(alert, animated: true)
            }
        }
    }

    private func describe(_ q: ShortformQuery) -> String {
        var parts: [String] = []
        if let v = q.productId { parts.append("productId=\(v)") }
        if let v = q.url { parts.append("url=\(v)") }
        if let v = q.skus { parts.append("skus=\(v.joined(separator: ","))") }
        if let v = q.tags { parts.append("tags=\(v.joined(separator: ","))") }
        if let v = q.collectionId { parts.append("collection=\(v)") }
        return parts.isEmpty ? "all" : parts.joined(separator: " ")
    }
}

extension ShortformBridge: ShopLiveShortformDelegate {
    func onProductClick(shortsId: String, shortsSrn: String, product: ProductData) {
        EventLog.shared.add("onProductClick", "shortsId=\(shortsId) productId=\(product.productId ?? "-") sku=\(product.sku ?? "-")")
        let ref = ProductRef(productId: product.productId, customerProductId: product.customerProductId,
                             sku: product.sku, url: product.url)
        DispatchQueue.main.async { self.openProduct(ref) }
    }

    func onBannerClick(shortsId: String, shortsSrn: String, url: String) {
        EventLog.shared.add("onBannerClick", "shortsId=\(shortsId)")
    }

    func onEvent(messenger: ShopLiveShortformMessenger?, command: String, payload: [String: Any]?) {
        let keys = payload.map { $0.keys.sorted().joined(separator: ",") } ?? ""
        EventLog.shared.add("onEvent", keys.isEmpty ? command : "\(command) [\(keys)]")
    }

    func onError(error: Error) {
        EventLog.shared.add("onError", error.localizedDescription)
    }

    func onDetailShown() {
        EventLog.shared.add("onDetailShown")
    }

    func onDetailHidden() {
        EventLog.shared.add("onDetailHidden")
    }

    func onShortsAttached(data: ShopLiveShortformData) {
        EventLog.shared.add("onShortsAttached", data.shortsId ?? "")
    }

    func onShortsDetached(data: ShopLiveShortformData) {
        EventLog.shared.add("onShortsDetached", data.shortsId ?? "")
    }
}
