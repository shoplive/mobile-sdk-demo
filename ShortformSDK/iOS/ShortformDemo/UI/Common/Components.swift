import UIKit

extension UIViewController {
    /// The gear button shown on every screen.
    func installSettingsButton() {
        let item = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self,
                                   action: #selector(openSettings))
        item.accessibilityLabel = L("settings_title")
        navigationItem.rightBarButtonItems = [item] + (navigationItem.rightBarButtonItems ?? []).filter { $0 !== item }
    }

    @objc func openSettings() {
        let nav = AppNavigationController(rootViewController: SettingsViewController())
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
}

/// Bold section title with an optional trailing note.
final class SectionHeaderView: UIView {
    let titleLabel = UILabel()
    let noteLabel = UILabel()

    init(title: String, note: String? = nil) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        noteLabel.text = note
        noteLabel.font = .preferredFont(forTextStyle: .caption1)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0
        noteLabel.isHidden = note == nil
        let stack = UIStackView(arrangedSubviews: [titleLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setNote(_ note: String?) {
        noteLabel.text = note
        noteLabel.isHidden = note == nil
    }
}

/// A collection view that sizes to its content, for grids inside a scroll view.
final class SelfSizingCollectionView: UICollectionView {
    override var contentSize: CGSize {
        didSet { if oldValue != contentSize { invalidateIntrinsicContentSize() } }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: max(contentSize.height, 1))
    }
}

/// Product tile used by Home, Search and Results: image, ▶ badge, brand, name, price.
final class ProductCell: UICollectionViewCell {
    static let reuseId = "ProductCell"

    private let imageView = RemoteImageView()
    private let badge = UILabel()
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let discountLabel = UILabel()
    private let textStack = UIStackView()
    private var listConstraints: [NSLayoutConstraint] = []
    private var gridConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.layer.cornerRadius = 10
        imageView.translatesAutoresizingMaskIntoConstraints = false

        badge.text = "▶"
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        badge.layer.cornerRadius = 11
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.accessibilityLabel = L("home_has_shortform")

        brandLabel.font = .preferredFont(forTextStyle: .caption1)
        brandLabel.textColor = .secondaryLabel
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.numberOfLines = 2
        priceLabel.font = .preferredFont(forTextStyle: .subheadline).bold
        discountLabel.font = .preferredFont(forTextStyle: .subheadline).bold
        let priceRow = UIStackView(arrangedSubviews: [discountLabel, priceLabel, UIView()])
        priceRow.spacing = 4
        [brandLabel, nameLabel, priceLabel, discountLabel].forEach { $0.adjustsFontForContentSizeCategory = true }

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .fill
        [brandLabel, nameLabel, priceRow].forEach(textStack.addArrangedSubview)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageView)
        contentView.addSubview(badge)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            badge.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 6),
            badge.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -6),
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),
        ])
        gridConstraints = [
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            textStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ]
        listConstraints = [
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),
            textStack.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ]
        NSLayoutConstraint.activate(gridConstraints)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(_ product: Product, list: Bool = false) {
        NSLayoutConstraint.deactivate(list ? gridConstraints : listConstraints)
        NSLayoutConstraint.activate(list ? listConstraints : gridConstraints)
        imageView.setURL(product.imageUrls.first)
        brandLabel.text = product.brand
        brandLabel.isHidden = product.brand == nil
        nameLabel.text = product.name
        priceLabel.text = PriceFormatter.string(product.salePrice, currency: product.currency)
        discountLabel.text = PriceFormatter.discount(for: product)
        discountLabel.isHidden = discountLabel.text == nil
        discountLabel.textColor = tintColor
        badge.isHidden = AvailabilityStore.shared.hasShortform(product.productId) != true
        accessibilityLabel = [product.brand, product.name, priceLabel.text].compactMap { $0 }.joined(separator: ", ")
        isAccessibilityElement = true
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        discountLabel.textColor = tintColor
    }

    /// Height for a grid tile of the given width.
    static func gridHeight(width: CGFloat) -> CGFloat {
        let text = UIFont.preferredFont(forTextStyle: .caption1).lineHeight
            + UIFont.preferredFont(forTextStyle: .subheadline).lineHeight * 3 + 14
        return width + text
    }
}

extension UIFont {
    var bold: UIFont {
        guard let d = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: d, size: 0)
    }
}

/// Product grid layout helper: 2 · 3 columns or a list.
enum ProductGridLayout: Int, CaseIterable {
    case grid2
    case grid3
    case list

    var titleKey: String {
        switch self {
        case .grid2: return "results_layout_grid2"
        case .grid3: return "results_layout_grid3"
        case .list: return "results_layout_list"
        }
    }

    func itemSize(containerWidth: CGFloat, spacing: CGFloat, inset: CGFloat) -> CGSize {
        let available = max(containerWidth - inset * 2, 100)
        switch self {
        case .grid2, .grid3:
            let columns: CGFloat = self == .grid2 ? 2 : 3
            let width = floor((available - spacing * (columns - 1)) / columns)
            return CGSize(width: width, height: ProductCell.gridHeight(width: width))
        case .list:
            return CGSize(width: available, height: 96)
        }
    }
}
