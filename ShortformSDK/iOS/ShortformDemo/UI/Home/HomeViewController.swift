import UIKit

/// Home: search bar, vertical chips, "Today's shortform" strip, featured products.
final class HomeViewController: UIViewController, UISearchBarDelegate {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let searchBar = UISearchBar()
    private let statusLabel = UILabel()
    private let chipsScroll = UIScrollView()
    private let chipsStack = UIStackView()
    private let shortformHeader = SectionHeaderView(title: L("home_today_shortform"))
    private let shortformView = ShortformEmbedView()
    private let featuredHeader = SectionHeaderView(title: L("home_featured"))
    private let grid = ProductGrid()
    private var checker: AvailabilityChecker?
    private var observers: [NSObjectProtocol] = []

    private var env: AppEnvironment { .shared }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("home_title")
        view.backgroundColor = .systemBackground
        navigationItem.backButtonDisplayMode = .minimal
        installSettingsButton()

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
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
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
        ])

        searchBar.placeholder = L("home_search_placeholder")
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        stack.addArrangedSubview(searchBar)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        stack.addArrangedSubview(statusLabel)

        chipsScroll.showsHorizontalScrollIndicator = false
        chipsScroll.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.spacing = 8
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.addSubview(chipsStack)
        NSLayoutConstraint.activate([
            chipsScroll.heightAnchor.constraint(equalToConstant: 40),
            chipsStack.topAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.bottomAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            chipsStack.heightAnchor.constraint(equalTo: chipsScroll.frameLayoutGuide.heightAnchor),
        ])
        stack.addArrangedSubview(chipsScroll)

        stack.addArrangedSubview(shortformHeader)
        stack.addArrangedSubview(shortformView)
        stack.addArrangedSubview(featuredHeader)
        stack.addArrangedSubview(grid.collectionView)
        grid.onSelect = { [weak self] product in self?.open(product) }

        checker = AvailabilityChecker(container: view)

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AppEnvironment.catalogDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadContent()
        })
        observers.append(center.addObserver(forName: AppEnvironment.accessKeyDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadContent()
        })
        reloadContent()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        grid.layoutIfWidthChanged()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.shortformView.notifyRotated() }
    }

    private func reloadContent() {
        let catalog = env.catalog

        var notes: [String] = []
        if env.loaded.source == .bundled { notes.append(L("home_catalog_bundled")) }
        if env.loaded.source == .cache { notes.append(L("home_catalog_cached")) }
        if env.accessKey == nil { notes.append(L("home_access_key_missing")) }
        statusLabel.text = notes.joined(separator: "\n")
        statusLabel.isHidden = notes.isEmpty

        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, vertical) in catalog.verticals.enumerated() {
            var config = UIButton.Configuration.tinted()
            config.title = vertical.title.current
            config.cornerStyle = .capsule
            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipsStack.addArrangedSubview(button)
        }
        chipsScroll.isHidden = catalog.verticals.isEmpty

        let query = ShortformQuery(collectionId: catalog.home?.collectionId.nonEmpty)
        shortformView.configure(kind: .horizontal, query: query, style: ShortformEmbedView.Style())

        let featured = catalog.featuredProducts
        grid.products = featured.isEmpty ? Array(catalog.products.prefix(8)) : featured
        featuredHeader.isHidden = grid.products.isEmpty
        if env.accessKey != nil { checker?.check(grid.products) }
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard let vertical = env.catalog.verticals[safe: sender.tag] else { return }
        navigationController?.pushViewController(ResultsViewController(vertical: vertical), animated: true)
    }

    private func open(_ product: Product) {
        navigationController?.pushViewController(ProductDetailViewController(product: product), animated: true)
    }

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        navigationController?.pushViewController(SearchViewController(), animated: true)
        return false
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
