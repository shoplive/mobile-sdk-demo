import UIKit

/// Product detail ★ — images, brand, name, price, description, and the product's shortform rendered as the option bar
/// says (layout, position, card, preview). Changes re-render in place and are remembered on the device.
final class ProductDetailViewController: UIViewController {
    private(set) var product: Product

    private var options: DetailOptions
    private let optionBar: OptionBarView
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var pager: ImagePagerView
    private let infoStack = UIStackView()
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let discountLabel = UILabel()
    private let priceLabel = UILabel()
    private let originalPriceLabel = UILabel()
    private let descriptionTitle = UILabel()
    private let descriptionFirst = UILabel()
    private let descriptionRest = UILabel()
    private let section = ShortformSectionView()

    /// Steps for the embedded layouts and the one being tried.
    private var steps: [MatchStep] = []
    private var stepIndex = 0
    private var previewShown = false

    /// The step that returned shortform for a product in an embedded layout, so a layout switch keeps it.
    private static var resolved: [String: MatchStep] = [:]

    private var env: AppEnvironment { .shared }

    init(product: Product) {
        self.product = product
        self.options = AppEnvironment.shared.optionsStore.load()
        self.optionBar = OptionBarView(options: options)
        self.pager = ImagePagerView(urls: product.imageUrls)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.backButtonDisplayMode = .minimal
        title = product.brand ?? product.name
        installSettingsButton()

        optionBar.translatesAutoresizingMaskIntoConstraints = false
        optionBar.onChange = { [weak self] options in self?.optionsChanged(options) }
        view.addSubview(scrollView)
        view.addSubview(optionBar)

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            optionBar.topAnchor.constraint(equalTo: safe.topAnchor),
            optionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            optionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: optionBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
        ])
        optionBar.insetsLayoutMarginsFromSafeArea = true

        brandLabel.font = .preferredFont(forTextStyle: .subheadline)
        brandLabel.textColor = .secondaryLabel
        nameLabel.font = .preferredFont(forTextStyle: .title2).bold
        nameLabel.numberOfLines = 0
        discountLabel.font = .preferredFont(forTextStyle: .title3).bold
        priceLabel.font = .preferredFont(forTextStyle: .title3).bold
        originalPriceLabel.font = .preferredFont(forTextStyle: .subheadline)
        originalPriceLabel.textColor = .secondaryLabel
        let priceRow = UIStackView(arrangedSubviews: [discountLabel, priceLabel, originalPriceLabel, UIView()])
        priceRow.spacing = 6
        priceRow.alignment = .firstBaseline
        infoStack.axis = .vertical
        infoStack.spacing = 4
        [brandLabel, nameLabel, priceRow].forEach(infoStack.addArrangedSubview)

        descriptionTitle.text = L("detail_description")
        descriptionTitle.font = .preferredFont(forTextStyle: .headline)
        for label in [descriptionFirst, descriptionRest] {
            label.font = .preferredFont(forTextStyle: .body)
            label.numberOfLines = 0
        }
        [brandLabel, nameLabel, discountLabel, priceLabel, originalPriceLabel, descriptionTitle, descriptionFirst, descriptionRest]
            .forEach { $0.adjustsFontForContentSizeCategory = true }

        section.onAction = { [weak self] in self?.sectionAction() }

        NotificationCenter.default.addObserver(self, selector: #selector(catalogChanged), name: AppEnvironment.catalogDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(optionsReset), name: OptionsStore.didReset, object: nil)

        buildContent()
        render(restartMatching: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if options.layout == .floatingPreview, !previewShown { showPreview() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if previewShown {
            ShortformBridge.shared.close()
            previewShown = false
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.section.embed.notifyRotated() }
    }

    // MARK: - Content

    private func buildContent() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        pager = ImagePagerView(urls: product.imageUrls)
        pager.translatesAutoresizingMaskIntoConstraints = false
        let square = pager.heightAnchor.constraint(equalTo: pager.widthAnchor)
        square.priority = .defaultHigh
        NSLayoutConstraint.activate([square, pager.heightAnchor.constraint(lessThanOrEqualToConstant: 460)])

        brandLabel.text = product.brand
        brandLabel.isHidden = product.brand == nil
        nameLabel.text = product.name
        priceLabel.text = PriceFormatter.string(product.salePrice, currency: product.currency)
        discountLabel.text = PriceFormatter.discount(for: product)
        discountLabel.textColor = view.tintColor
        discountLabel.isHidden = discountLabel.text == nil
        if product.hasDiscount {
            let original = PriceFormatter.string(product.originalPrice, currency: product.currency)
            originalPriceLabel.attributedText = NSAttributedString(string: original, attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ])
            originalPriceLabel.isHidden = false
        } else {
            originalPriceLabel.isHidden = true
        }

        let (first, rest) = Self.splitDescription(product.description)
        descriptionTitle.isHidden = first == nil
        descriptionFirst.text = first
        descriptionFirst.isHidden = first == nil
        descriptionRest.text = rest
        descriptionRest.isHidden = rest == nil

        stack.addArrangedSubview(pager)
        for v in [infoStack, descriptionTitle, descriptionFirst, descriptionRest] {
            stack.addArrangedSubview(padded(v))
        }
    }

    /// Wraps a view with the readable side margins (the stack itself is full width for the SDK views).
    private func padded(_ content: UIView) -> UIView {
        let container = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.isHidden = content.isHidden
        return container
    }

    /// First paragraph and the rest, for the "Inside description" position.
    static func splitDescription(_ text: String?) -> (String?, String?) {
        guard let text = text.nonEmpty else { return (nil, nil) }
        let paragraphs = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let first = paragraphs.first else { return (nil, nil) }
        let rest = paragraphs.dropFirst().joined(separator: "\n\n")
        return (first, rest.isEmpty ? nil : rest)
    }

    private func container(of view: UIView) -> UIView? {
        stack.arrangedSubviews.first { $0 === view || $0.subviews.contains(view) }
    }

    // MARK: - Shortform section

    private func placeSection() {
        if section.superview != nil {
            stack.removeArrangedSubview(section)
            section.removeFromSuperview()
        }
        let views = stack.arrangedSubviews
        func after(_ v: UIView) -> Int {
            guard let c = container(of: v), let i = views.firstIndex(of: c) else { return views.count }
            return i + 1
        }
        let index: Int
        switch options.position {
        case .aboveImages: index = 0
        case .belowImages: index = after(pager)
        case .belowPrice: index = after(infoStack)
        case .insideDescription: index = descriptionFirst.isHidden ? after(infoStack) : after(descriptionFirst)
        case .bottom: index = views.count
        }
        stack.insertArrangedSubview(section, at: min(index, views.count))
    }

    private func render(restartMatching: Bool) {
        placeSection()
        let catalog = env.catalog
        if options.layout != .floatingPreview, previewShown {
            ShortformBridge.shared.close()
            previewShown = false
        }

        switch options.layout {
        case .horizontal, .cardGrid, .verticalFeed:
            let newSteps = ShortformMatcher.steps(for: product, in: catalog, surface: .embedded)
            if restartMatching || newSteps != steps {
                steps = newSteps
                stepIndex = Self.resolved[product.productId].flatMap { newSteps.firstIndex(of: $0) } ?? 0
            }
            runEmbeddedStep()

        case .floatingPreview:
            guard let step = playerStep(surface: .preview) else { return section.showMessage(L("detail_no_shortform")) }
            section.setTitle(related: step.isRelated, matchedBy: step.matchedBy)
            section.showButton(L("detail_preview_again"), note: L("detail_preview_note"))
            if view.window != nil { showPreview() }

        case .buttonOnly:
            guard let step = playerStep(surface: .player) else { return section.showMessage(L("detail_no_shortform")) }
            section.setTitle(related: step.isRelated, matchedBy: step.matchedBy)
            section.showButton(L("detail_play_button"))
        }
    }

    private var embedKind: ShortformEmbedView.Kind {
        switch options.layout {
        case .cardGrid: return .card
        case .verticalFeed: return .vertical
        default: return .horizontal
        }
    }

    private func runEmbeddedStep() {
        guard let step = steps[safe: stepIndex] else {
            section.showMessage(L("detail_no_shortform"))
            return
        }
        section.setTitle(related: step.isRelated, matchedBy: step.matchedBy)
        section.showEmbedded()
        section.embed.onResult = { [weak self] result in self?.embeddedResult(result, for: step) }
        section.embed.configure(kind: embedKind, query: step.query, style: ShortformEmbedView.Style(options))
        EventLog.shared.add("match", "\(product.productId) step=\(stepIndex + 1) by=\(step.matchedBy)")
    }

    private func embeddedResult(_ result: ShortformEmbedView.LoadResult, for step: MatchStep) {
        guard steps[safe: stepIndex] == step else { return }
        let isOwn = !step.isRelated
        switch result {
        case .found:
            Self.resolved[product.productId] = step
            if isOwn { AvailabilityStore.shared.set(product.productId, hasShortform: true) }
        case .empty:
            if isOwn { AvailabilityStore.shared.set(product.productId, hasShortform: false) }
            stepIndex += 1
            runEmbeddedStep()
        case .failed:
            break
        }
    }

    /// Step for the preview / button layouts: the step an embedded layout found, translated to that surface;
    /// otherwise the first step (the product's own `productId`).
    private func playerStep(surface: ShortformSurface) -> MatchStep? {
        let catalog = env.catalog
        if let found = Self.resolved[product.productId],
           !(found.isRelated && product.sku.nonEmpty == nil),
           let step = ShortformMatcher.step(found, on: surface, for: product, in: catalog) {
            return step
        }
        return ShortformMatcher.steps(for: product, in: catalog, surface: surface).first
    }

    private func showPreview() {
        guard options.layout == .floatingPreview, let step = playerStep(surface: .preview) else { return }
        let style = ShortformBridge.PreviewStyle(corner: options.previewCorner, width: options.previewSize.width,
                                                 maxCount: options.previewMaxCount)
        ShortformBridge.shared.showPreview(step.query, style: style)
        previewShown = true
    }

    private func sectionAction() {
        switch options.layout {
        case .floatingPreview:
            showPreview()
        case .buttonOnly:
            if let step = playerStep(surface: .player) { ShortformBridge.shared.play(step.query) }
        default:
            break
        }
    }

    // MARK: - Options

    private func optionsChanged(_ next: DetailOptions) {
        let previous = options
        options = next
        env.optionsStore.save(next)
        let onlyBar = { () -> Bool in
            var a = previous, b = next
            a.barCollapsed = false
            b.barCollapsed = false
            return a == b
        }()
        if onlyBar { return }
        if previous.layout == .floatingPreview, next.layout == .floatingPreview, previewShown {
            ShortformBridge.shared.close()
            previewShown = false
        }
        render(restartMatching: false)
    }

    @objc private func optionsReset() {
        options = env.optionsStore.load()
        optionBar.setOptions(options)
        render(restartMatching: false)
    }

    @objc private func catalogChanged() {
        if let updated = env.catalog.product(id: product.productId), updated != product {
            product = updated
            buildContent()
        }
        Self.resolved.removeAll()
        render(restartMatching: true)
    }
}
