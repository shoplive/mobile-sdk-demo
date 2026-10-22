import UIKit

/// Results: product grid (2 · 3 columns or list) with an optional shortform strip on top (the results' skus).
final class ResultsViewController: UIViewController {
    private enum Source {
        case query(String)
        case vertical(Catalog.Vertical)
    }

    private enum Keys {
        static let layout = "shortformDemo.results.layout"
        static let strip = "shortformDemo.results.strip"
    }

    private let source: Source
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let countLabel = UILabel()
    private let layoutControl = UISegmentedControl()
    private let stripSwitch = UISwitch()
    private let stripHeader = SectionHeaderView(title: L("results_shortform_strip"))
    private let stripView = ShortformEmbedView()
    private let emptyLabel = UILabel()
    private let grid = ProductGrid()
    private var products: [Product] = []

    init(query: String) {
        source = .query(query)
        super.init(nibName: nil, bundle: nil)
    }

    init(vertical: Catalog.Vertical) {
        source = .vertical(vertical)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.backButtonDisplayMode = .minimal
        installSettingsButton()
        switch source {
        case .query(let q): title = L("results_title_format", q)
        case .vertical(let v): title = v.title.current
        }

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
        ])

        for (i, layout) in ProductGridLayout.allCases.enumerated() {
            layoutControl.insertSegment(withTitle: L(layout.titleKey), at: i, animated: false)
        }
        let defaults = UserDefaults.standard
        let savedLayout = ProductGridLayout(rawValue: defaults.integer(forKey: Keys.layout)) ?? .grid2
        layoutControl.selectedSegmentIndex = savedLayout.rawValue
        layoutControl.addTarget(self, action: #selector(layoutChanged), for: .valueChanged)
        grid.layout = savedLayout
        grid.adaptsToWidth = false

        stripSwitch.isOn = defaults.object(forKey: Keys.strip) as? Bool ?? true
        stripSwitch.addTarget(self, action: #selector(stripChanged), for: .valueChanged)
        stripSwitch.accessibilityLabel = L("results_shortform_strip")
        let stripLabel = UILabel()
        stripLabel.text = L("results_shortform_strip")
        stripLabel.font = .preferredFont(forTextStyle: .footnote)

        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = .secondaryLabel

        let toggleRow = UIStackView(arrangedSubviews: [countLabel, UIView(), stripLabel, stripSwitch])
        toggleRow.spacing = 8
        toggleRow.alignment = .center
        let controls = UIStackView(arrangedSubviews: [layoutControl, toggleRow])
        controls.axis = .vertical
        controls.spacing = 8
        controls.isLayoutMarginsRelativeArrangement = true
        controls.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        stack.addArrangedSubview(controls)

        stack.addArrangedSubview(stripHeader)
        stack.addArrangedSubview(stripView)

        emptyLabel.text = L("results_empty")
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        stack.addArrangedSubview(emptyLabel)
        stack.addArrangedSubview(grid.collectionView)
        grid.onSelect = { [weak self] product in
            self?.navigationController?.pushViewController(ProductDetailViewController(product: product), animated: true)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent), name: AppEnvironment.catalogDidChange, object: nil)
        reloadContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        grid.layoutIfWidthChanged()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.stripView.notifyRotated() }
    }

    @objc private func reloadContent() {
        let catalog = AppEnvironment.shared.catalog
        let queryText: String
        switch source {
        case .query(let q):
            products = SearchEngine.search(q, in: catalog).allMatches
            queryText = q
        case .vertical(let v):
            products = catalog.products(in: v)
            queryText = ""
        }
        countLabel.text = L("results_count_format", products.count)
        grid.products = products
        emptyLabel.isHidden = !products.isEmpty

        var stripQuery = ShortformMatcher.resultsQuery(for: products, query: queryText, in: catalog)
        if stripQuery == nil, case .vertical(let v) = source, !v.tags.isEmpty {
            stripQuery = ShortformQuery(tags: v.tags)
        }
        let showStrip = stripSwitch.isOn && stripQuery != nil
        stripHeader.isHidden = !showStrip
        stripView.isHidden = !showStrip
        if showStrip, let stripQuery, stripView.query != stripQuery || stripView.kind == nil {
            stripView.configure(kind: .horizontal, query: stripQuery, style: ShortformEmbedView.Style())
        }
        if !showStrip { stripView.stopVideos() }
    }

    @objc private func layoutChanged() {
        guard let layout = ProductGridLayout(rawValue: layoutControl.selectedSegmentIndex) else { return }
        grid.layout = layout
        UserDefaults.standard.set(layout.rawValue, forKey: Keys.layout)
    }

    @objc private func stripChanged() {
        UserDefaults.standard.set(stripSwitch.isOn, forKey: Keys.strip)
        if stripSwitch.isOn { stripView.configureAgainIfNeeded() }
        reloadContent()
    }
}

private extension ShortformEmbedView {
    func configureAgainIfNeeded() {
        guard let kind, let query else { return }
        configure(kind: kind, query: query, style: style)
    }
}
