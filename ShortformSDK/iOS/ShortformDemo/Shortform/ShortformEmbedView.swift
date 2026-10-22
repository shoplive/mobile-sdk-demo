import UIKit
import ShopLiveShortformSDK

/// Hosts one of the SDK's embedded list views and applies a query and card options to it.
///
/// - `.horizontal` → `ShopLiveShortformHorizontalTypeView`
/// - `.card`       → `ShopLiveShortformCardTypeView`
/// - `.vertical`   → `ShopLiveShortformVerticalTypeView`
///
/// SDK 1.9.1 does not report how many items an embedded view loaded, so `onResult` is derived from the embedded
/// collection view's item count (public UIKit API): items appear → `.found`; still none after a few seconds → `.empty`.
final class ShortformEmbedView: UIView {
    enum Kind: Equatable {
        case horizontal
        case card
        case vertical
    }

    struct Style: Equatable {
        var cardType: Int = 1
        var showTitle = true
        var showViewCount = true
        var showProductCount = true
        var autoplay = true

        init() {}

        init(_ options: DetailOptions) {
            cardType = options.cardType
            showTitle = options.showTitle
            showViewCount = options.showViewCount
            showProductCount = options.showProductCount
            autoplay = options.autoplay
        }
    }

    enum LoadResult: Equatable {
        case found
        case empty
        case failed
    }

    var onResult: ((LoadResult) -> Void)?

    private(set) var kind: Kind?
    private(set) var query: ShortformQuery?
    private(set) var style = Style()

    private var sdkView: UIView?
    private var heightConstraint: NSLayoutConstraint!
    private var probeTimer: Timer?
    private var probeStart = Date()
    private var reported = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        probeTimer?.invalidate()
    }

    static func height(for kind: Kind, cardType: Int) -> CGFloat {
        switch kind {
        case .horizontal: return cardType == 2 ? 260 : 300
        case .card: return 520
        case .vertical: return 560
        }
    }

    /// Creates the SDK view when the kind changes, otherwise updates it in place, then reloads.
    func configure(kind: Kind, query: ShortformQuery, style: Style, height: CGFloat? = nil) {
        var created = false
        if kind != self.kind || sdkView == nil {
            created = true
            sdkView?.removeFromSuperview()
            let view = makeView(kind)
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            sdkView = view
            self.kind = kind
        }
        self.query = query
        self.style = style
        heightConstraint.constant = height ?? Self.height(for: kind, cardType: style.cardType)
        apply()
        reload()
        if created { submit() }
    }

    func notifyRotated() {
        switch sdkView {
        case let v as ShopLiveShortformHorizontalTypeView: v.notifyViewRotated()
        case let v as ShopLiveShortformCardTypeView: v.notifyViewRotated()
        case let v as ShopLiveShortformVerticalTypeView: v.notifyViewRotated()
        default: break
        }
    }

    func stopVideos() {
        switch sdkView {
        case let v as ShopLiveShortformHorizontalTypeView: v.disablePlayVideos()
        case let v as ShopLiveShortformCardTypeView: v.disablePlayVideos()
        case let v as ShopLiveShortformVerticalTypeView: v.disablePlayVideos()
        default: break
        }
    }

    // MARK: - SDK views

    private func makeView(_ kind: Kind) -> UIView {
        let bridge = ShortformBridge.shared
        switch kind {
        case .horizontal:
            return ShopLiveShortformHorizontalTypeView(cardViewType: cardViewType, playableType: .FIRST,
                                                       listViewDelegate: self, shortsCollectionDelegate: bridge)
        case .card:
            return ShopLiveShortformCardTypeView(cardViewType: cardViewType, listViewDelegate: self,
                                                 shortsCollectionDelegate: bridge)
        case .vertical:
            return ShopLiveShortformVerticalTypeView(cardViewType: cardViewType, listViewDelegate: self,
                                                     shortsCollectionDelegate: bridge)
        }
    }

    private var cardViewType: ShopLiveShortform.CardViewType {
        switch style.cardType {
        case 0: return .type0
        case 2: return .type2
        default: return .type1
        }
    }

    private var tagOperator: ShopLiveTagSearchOperator? { query?.tags == nil ? nil : .OR }

    /// Pushes the query and style into the SDK view. Every field is set, so a previous query never leaks into the next.
    private func apply() {
        let q = query ?? .all
        switch sdkView {
        case let v as ShopLiveShortformHorizontalTypeView:
            v.setCardViewType(type: cardViewType)
            v.setSkus(skus: q.skus)
            v.setHashTags(tags: q.tags, tagSearchOperator: tagOperator)
            v.setShortsCollectionId(shortsCollectionId: q.collectionId)
            v.setVisibleTitle(isVisible: style.showTitle)
            v.setVisibleViewCount(isVisible: style.showViewCount)
            v.setVisibleProductCount(isVisible: style.showProductCount)
            if style.autoplay { v.enablePlayVideos() } else { v.disablePlayVideos() }
        case let v as ShopLiveShortformCardTypeView:
            v.setCardViewType(type: cardViewType)
            v.setSkus(skus: q.skus)
            v.setHashTags(tags: q.tags, tagSearchOperator: tagOperator)
            v.setShortsCollectionId(shortsCollectionId: q.collectionId)
            v.setVisibleTitle(isVisible: style.showTitle)
            v.setVisibleViewCount(isVisible: style.showViewCount)
            v.setVisibleProductCount(isVisible: style.showProductCount)
            if style.autoplay { v.enablePlayVideos() } else { v.disablePlayVideos() }
        case let v as ShopLiveShortformVerticalTypeView:
            v.setCardViewType(type: cardViewType)
            v.setSkus(skus: q.skus)
            v.setHashTags(tags: q.tags, tagSearchOperator: tagOperator)
            v.setShortsCollectionId(shortsCollectionId: q.collectionId)
            v.setVisibleTitle(isVisible: style.showTitle)
            v.setVisibleViewCount(isVisible: style.showViewCount)
            v.setVisibleProductCount(isVisible: style.showProductCount)
            if style.autoplay { v.enablePlayVideos() } else { v.disablePlayVideos() }
        default:
            break
        }
    }

    /// First load of a new SDK view: fetches the list settings, then the list with the query set by `reload()`.
    private func submit() {
        switch sdkView {
        case let v as ShopLiveShortformHorizontalTypeView: v.submit()
        case let v as ShopLiveShortformCardTypeView: v.submit()
        case let v as ShopLiveShortformVerticalTypeView: v.submit()
        default: break
        }
    }

    private func reload() {
        switch sdkView {
        case let v as ShopLiveShortformHorizontalTypeView: v.reloadItems()
        case let v as ShopLiveShortformCardTypeView: v.reloadItems()
        case let v as ShopLiveShortformVerticalTypeView: v.reloadItems()
        default: break
        }
        startProbe()
    }

    // MARK: - Result probe

    private static let probeInterval: TimeInterval = 0.4
    private static let hiddenEmptyAfter: TimeInterval = 2.0
    private static let timeout: TimeInterval = 7.0

    private func startProbe() {
        probeTimer?.invalidate()
        reported = false
        probeStart = Date()
        let timer = Timer(timeInterval: Self.probeInterval, repeats: true) { [weak self] _ in self?.probe() }
        RunLoop.main.add(timer, forMode: .common)
        probeTimer = timer
    }

    private func probe() {
        guard !reported else { return }
        let elapsed = Date().timeIntervalSince(probeStart)
        let collection = sdkView.flatMap(Self.firstCollectionView)
        let count: Int = {
            guard let cv = collection, cv.numberOfSections > 0 else { return 0 }
            return cv.numberOfItems(inSection: 0)
        }()
        if count > 0 {
            report(.found)
        } else if elapsed >= Self.timeout || (elapsed >= Self.hiddenEmptyAfter && collection?.isHidden == true) {
            report(.empty)
        }
    }

    private func report(_ result: LoadResult) {
        guard !reported else { return }
        reported = true
        probeTimer?.invalidate()
        probeTimer = nil
        onResult?(result)
    }

    private static func firstCollectionView(in view: UIView) -> UICollectionView? {
        for sub in view.subviews {
            if let cv = sub as? UICollectionView { return cv }
            if let cv = firstCollectionView(in: sub) { return cv }
        }
        return nil
    }
}

extension ShortformEmbedView: ShopLiveShortformListViewDelegate {
    func onListViewError(error: Error) {
        EventLog.shared.add("onListViewError", error.localizedDescription)
        report(.failed)
    }

    func onShortsSettingsInitialized() {
        EventLog.shared.add("onShortsSettingsInitialized")
        // The SDK applies its server-side list settings here; re-apply the demo's choices on top.
        apply()
    }
}
