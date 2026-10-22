import UIKit

/// Search: suggested keywords; while typing, demo products first, then other matches. The demo section never disappears.
final class SearchViewController: UITableViewController, UISearchBarDelegate {
    private enum Section {
        case keywords([String])
        case demo([Product], placeholder: Bool)
        case others([Product])
    }

    private let searchBar = UISearchBar()
    private var sections: [Section] = []
    private var query = ""

    private var catalog: Catalog { AppEnvironment.shared.catalog }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("search_title")
        navigationItem.backButtonDisplayMode = .minimal
        installSettingsButton()
        searchBar.placeholder = L("home_search_placeholder")
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        navigationItem.titleView = searchBar
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        NotificationCenter.default.addObserver(self, selector: #selector(catalogChanged), name: AppEnvironment.catalogDidChange, object: nil)
        rebuild()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if query.isEmpty { searchBar.becomeFirstResponder() }
    }

    @objc private func catalogChanged() { rebuild() }

    private func rebuild() {
        let result = SearchEngine.search(query, in: catalog)
        if query.nonEmpty == nil {
            sections = [.keywords(SearchEngine.suggestedKeywords(in: catalog)), .demo(result.demo, placeholder: false)]
        } else {
            sections = [.demo(result.demo, placeholder: result.demoIsPlaceholder), .others(result.others)]
        }
        tableView.reloadData()
    }

    // MARK: - Search bar

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query = searchText
        rebuild()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let q = query.nonEmpty else { return }
        searchBar.resignFirstResponder()
        navigationController?.pushViewController(ResultsViewController(query: q), animated: true)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .keywords(let k): return k.count
        case .demo(let p, _): return max(p.count, 1)
        case .others(let p): return max(p.count, 1)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .keywords: return L("search_suggested")
        case .demo: return L("search_demo_products")
        case .others: return L("search_other_results")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if case .demo(_, let placeholder) = sections[section], placeholder { return L("search_demo_placeholder") }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        switch sections[indexPath.section] {
        case .keywords(let keywords):
            content.text = keywords[indexPath.row]
            content.image = UIImage(systemName: "magnifyingglass")
        case .demo(let products, _):
            if let product = products[safe: indexPath.row] {
                configure(&content, product, badge: true)
            } else {
                content.text = L("search_no_demo_products")
                content.textProperties.color = .secondaryLabel
                cell.accessoryType = .none
                cell.selectionStyle = .none
            }
        case .others(let products):
            if let product = products[safe: indexPath.row] {
                configure(&content, product, badge: false)
            } else {
                content.text = L("search_no_results")
                content.textProperties.color = .secondaryLabel
                cell.accessoryType = .none
                cell.selectionStyle = .none
            }
        }
        cell.contentConfiguration = content
        return cell
    }

    private func configure(_ content: inout UIListContentConfiguration, _ product: Product, badge: Bool) {
        let price = PriceFormatter.string(product.salePrice, currency: product.currency)
        let hasShortform = AvailabilityStore.shared.hasShortform(product.productId) == true
        content.text = (hasShortform ? "▶ " : "") + product.name
        content.secondaryText = [product.brand, price].compactMap { $0 }.joined(separator: " · ")
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: badge ? "play.rectangle" : "bag")
        content.imageProperties.tintColor = badge ? view.tintColor : .secondaryLabel
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .keywords(let keywords):
            let keyword = keywords[indexPath.row]
            navigationController?.pushViewController(ResultsViewController(query: keyword), animated: true)
        case .demo(let products, _), .others(let products):
            guard let product = products[safe: indexPath.row] else { return }
            navigationController?.pushViewController(ProductDetailViewController(product: product), animated: true)
        }
    }
}
