import UIKit

/// Settings (⚙︎): access key, catalog URL, brand color, layout defaults reset, SDK event log, demo reset.
final class SettingsViewController: UITableViewController, UIColorPickerViewControllerDelegate {
    private enum Row {
        case accessKey, sdkVersion
        case catalogURL, catalogStatus, catalogReload
        case brandColor, brandReset
        case layoutReset
        case eventLog, demoReset
    }

    private struct Section {
        let title: String
        let rows: [Row]
        var footer: String?
    }

    private var sections: [Section] = []
    private var env: AppEnvironment { .shared }
    private var reloading = false

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("settings_title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: AppEnvironment.catalogDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: AppEnvironment.brandDidChange, object: nil)
        refresh()
    }

    @objc private func done() {
        dismiss(animated: true)
    }

    @objc private func refresh() {
        let failed = env.loaded.remoteFailed ? L("settings_catalog_failed") : nil
        sections = [
            Section(title: L("settings_section_sdk"), rows: [.accessKey, .sdkVersion], footer: L("settings_access_key_footer")),
            Section(title: L("settings_section_catalog"), rows: [.catalogURL, .catalogStatus, .catalogReload], footer: failed),
            Section(title: L("settings_section_branding"), rows: [.brandColor, .brandReset]),
            Section(title: L("settings_section_layout"), rows: [.layoutReset]),
            Section(title: L("settings_section_diagnostics"), rows: [.eventLog, .demoReset]),
        ]
        tableView.reloadData()
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.valueCell()
        cell.accessoryType = .none
        cell.accessoryView = nil
        cell.selectionStyle = .default
        switch sections[indexPath.section].rows[indexPath.row] {
        case .accessKey:
            content.text = L("settings_access_key")
            content.secondaryText = sourceText(env.accessKeySource)
            cell.accessoryType = .disclosureIndicator
        case .sdkVersion:
            content.text = L("settings_sdk_version")
            content.secondaryText = ShortformBridge.shared.sdkVersion
            cell.selectionStyle = .none
        case .catalogURL:
            content.text = L("settings_catalog_url")
            if let host = env.catalogURL?.host {
                content.secondaryText = host
            } else {
                content.secondaryText = L("settings_value_not_set")
            }
            cell.accessoryType = .disclosureIndicator
        case .catalogStatus:
            content.text = L("settings_catalog_source")
            let source: String
            switch env.loaded.source {
            case .remote: source = L("settings_catalog_source_remote")
            case .cache: source = L("settings_catalog_source_cache")
            case .bundled: source = L("settings_catalog_source_bundled")
            }
            content.secondaryText = L("settings_catalog_status_format", source, env.catalog.products.count)
            cell.selectionStyle = .none
        case .catalogReload:
            content = UIListContentConfiguration.cell()
            content.text = reloading ? L("settings_catalog_reloading") : L("settings_catalog_reload")
            content.textProperties.color = view.tintColor
        case .brandColor:
            content.text = L("settings_brand_color")
            let swatch = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            swatch.backgroundColor = env.brandColor
            swatch.layer.cornerRadius = 12
            cell.accessoryView = swatch
        case .brandReset:
            content = UIListContentConfiguration.cell()
            content.text = L("settings_brand_reset")
            content.textProperties.color = view.tintColor
        case .layoutReset:
            content = UIListContentConfiguration.cell()
            content.text = L("settings_layout_reset")
            content.textProperties.color = view.tintColor
        case .eventLog:
            content.text = L("settings_event_log")
            content.secondaryText = "\(EventLog.shared.snapshot.count)"
            cell.accessoryType = .disclosureIndicator
        case .demoReset:
            content = UIListContentConfiguration.cell()
            content.text = L("settings_demo_reset")
            content.textProperties.color = .systemRed
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .accessKey: editAccessKey()
        case .catalogURL: editCatalogURL()
        case .catalogReload: reloadCatalog()
        case .brandColor:
            let picker = UIColorPickerViewController()
            picker.selectedColor = env.brandColor
            picker.supportsAlpha = false
            picker.delegate = self
            present(picker, animated: true)
        case .brandReset:
            env.setBrandColor(nil)
        case .layoutReset:
            env.optionsStore.reset()
            toast(L("settings_layout_reset_done"))
        case .eventLog:
            navigationController?.pushViewController(EventLogViewController(), animated: true)
        case .demoReset:
            confirmDemoReset()
        case .sdkVersion, .catalogStatus:
            break
        }
    }

    // MARK: - Actions

    private func sourceText(_ source: AppEnvironment.ValueSource) -> String {
        switch source {
        case .settings: return L("settings_value_from_settings")
        case .localConfig: return L("settings_value_from_local_config")
        case .none: return L("settings_value_not_set")
        }
    }

    private func editAccessKey() {
        let alert = UIAlertController(title: L("settings_access_key"), message: L("settings_access_key_message"), preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = L("settings_access_key_placeholder")
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: L("settings_cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings_use_local_config"), style: .destructive) { [weak self] _ in
            self?.env.setAccessKeyOverride(nil)
            self?.refresh()
        })
        alert.addAction(UIAlertAction(title: L("settings_save"), style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text.nonEmpty else { return }
            self?.env.setAccessKeyOverride(text)
            self?.refresh()
        })
        present(alert, animated: true)
    }

    private func editCatalogURL() {
        let alert = UIAlertController(title: L("settings_catalog_url"), message: L("settings_catalog_url_message"), preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: L("settings_cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings_use_local_config"), style: .destructive) { [weak self] _ in
            self?.env.setCatalogURLOverride(nil)
            self?.reloadCatalog()
        })
        alert.addAction(UIAlertAction(title: L("settings_save"), style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text.nonEmpty else { return }
            guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
                self?.toast(L("settings_catalog_url_invalid"))
                return
            }
            self?.env.setCatalogURLOverride(text)
            self?.reloadCatalog()
        })
        present(alert, animated: true)
    }

    private func reloadCatalog() {
        guard !reloading else { return }
        reloading = true
        refresh()
        Task { @MainActor [weak self] in
            await AppEnvironment.shared.reloadCatalog()
            self?.reloading = false
            self?.refresh()
        }
    }

    private func confirmDemoReset() {
        let alert = UIAlertController(title: L("settings_demo_reset"), message: L("settings_demo_reset_message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("settings_cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings_demo_reset_confirm"), style: .destructive) { [weak self] _ in
            Task { @MainActor in
                await AppEnvironment.shared.resetDemo()
                let presenter = self?.presentingViewController
                self?.dismiss(animated: true) {
                    (presenter as? UINavigationController)?.popToRootViewController(animated: true)
                }
            }
        })
        present(alert, animated: true)
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("settings_ok"), style: .default))
        present(alert, animated: true)
    }

    // MARK: - Color picker

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        env.setBrandColor(viewController.selectedColor)
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        env.setBrandColor(viewController.selectedColor)
    }
}

/// SDK callbacks received by the app, newest first.
final class EventLogViewController: UITableViewController {
    private var entries: [EventLog.Entry] = []
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("settings_event_log")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("settings_event_log_clear"), style: .plain,
                                                            target: self, action: #selector(clear))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: EventLog.didChange, object: nil)
        reload()
    }

    @objc private func reload() {
        entries = EventLog.shared.snapshot
        tableView.reloadData()
    }

    @objc private func clear() {
        EventLog.shared.clear()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(entries.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        cell.selectionStyle = .none
        if let entry = entries[safe: indexPath.row] {
            content.text = "\(formatter.string(from: entry.date))  \(entry.name)"
            content.textProperties.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            content.secondaryText = entry.detail.isEmpty ? nil : entry.detail
            content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            content.secondaryTextProperties.color = .secondaryLabel
        } else {
            content.text = L("settings_event_log_empty")
            content.textProperties.color = .secondaryLabel
        }
        cell.contentConfiguration = content
        return cell
    }
}
