import UIKit

/// A non-scrolling product grid for use inside a scroll view.
final class ProductGrid: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let collectionView: SelfSizingCollectionView
    var onSelect: ((Product) -> Void)?

    var products: [Product] = [] {
        didSet { reload() }
    }

    var layout: ProductGridLayout = .grid2 {
        didSet { reload() }
    }

    /// When set, `.grid2` becomes three columns on wide screens.
    var adaptsToWidth = true

    private let spacing: CGFloat = 12
    private let inset: CGFloat = 16
    private var observer: NSObjectProtocol?

    override init() {
        let flow = UICollectionViewFlowLayout()
        flow.minimumInteritemSpacing = 12
        flow.minimumLineSpacing = 16
        collectionView = SelfSizingCollectionView(frame: .zero, collectionViewLayout: flow)
        super.init()
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.contentInset = .zero
        collectionView.register(ProductCell.self, forCellWithReuseIdentifier: ProductCell.reuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
        observer = NotificationCenter.default.addObserver(forName: AvailabilityStore.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.collectionView.reloadData()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        collectionView.invalidateIntrinsicContentSize()
    }

    private var lastWidth: CGFloat = 0

    /// Call from `viewDidLayoutSubviews`: re-lays out the tiles after rotation or a size change.
    func layoutIfWidthChanged() {
        let width = collectionView.bounds.width
        guard width != lastWidth else { return }
        lastWidth = width
        reload()
    }

    private var effectiveLayout: ProductGridLayout {
        if adaptsToWidth, layout == .grid2, collectionView.bounds.width > 600 { return .grid3 }
        return layout
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        products.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProductCell.reuseId, for: indexPath) as! ProductCell
        cell.configure(products[indexPath.item], list: effectiveLayout == .list)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        effectiveLayout.itemSize(containerWidth: collectionView.bounds.width, spacing: spacing, inset: inset)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 4, left: inset, bottom: 16, right: inset)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(products[indexPath.item])
    }
}
