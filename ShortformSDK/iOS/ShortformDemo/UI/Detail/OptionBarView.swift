import UIKit

/// The product-detail option bar: Layout · Position · Card · Preview, each a menu. Collapsible.
final class OptionBarView: UIView {
    var onChange: ((DetailOptions) -> Void)?

    private(set) var options: DetailOptions
    private let scroll = UIScrollView()
    private let buttons = UIStackView()
    private let layoutButton = UIButton(type: .system)
    private let positionButton = UIButton(type: .system)
    private let cardButton = UIButton(type: .system)
    private let previewButton = UIButton(type: .system)
    private let collapseButton = UIButton(type: .system)
    private let expandButton = UIButton(type: .system)
    private let separator = UIView()

    init(options: DetailOptions) {
        self.options = options
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground

        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(buttons)
        for b in [layoutButton, positionButton, cardButton, previewButton] {
            b.showsMenuAsPrimaryAction = true
            buttons.addArrangedSubview(b)
        }

        var collapse = UIButton.Configuration.plain()
        collapse.image = UIImage(systemName: "chevron.up")
        collapseButton.configuration = collapse
        collapseButton.accessibilityLabel = L("option_collapse")
        collapseButton.addTarget(self, action: #selector(toggleCollapsed), for: .touchUpInside)
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.setContentHuggingPriority(.required, for: .horizontal)

        var expand = UIButton.Configuration.plain()
        expand.title = L("option_expand")
        expand.image = UIImage(systemName: "slider.horizontal.3")
        expand.imagePadding = 6
        expand.buttonSize = .small
        expandButton.configuration = expand
        expandButton.addTarget(self, action: #selector(toggleCollapsed), for: .touchUpInside)
        expandButton.translatesAutoresizingMaskIntoConstraints = false

        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scroll)
        addSubview(collapseButton)
        addSubview(expandButton)
        addSubview(separator)

        let margins = layoutMarginsGuide
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: collapseButton.leadingAnchor, constant: -4),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -6),
            buttons.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            buttons.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            buttons.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            buttons.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            collapseButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            collapseButton.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            expandButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            expandButton.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            expandButton.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -2),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setOptions(_ options: DetailOptions) {
        self.options = options
        refresh()
    }

    // MARK: - Private

    @objc private func toggleCollapsed() {
        update { $0.barCollapsed.toggle() }
    }

    private func update(_ change: (inout DetailOptions) -> Void) {
        var next = options
        change(&next)
        guard next != options else { return }
        options = next
        refresh()
        onChange?(next)
    }

    private func refresh() {
        let collapsed = options.barCollapsed
        scroll.isHidden = collapsed
        collapseButton.isHidden = collapsed
        expandButton.isHidden = !collapsed

        configure(layoutButton, title: L("option_layout"), value: L(options.layout.titleKey))
        configure(positionButton, title: L("option_position"), value: L(options.position.titleKey))
        configure(cardButton, title: L("option_card"), value: L("option_card_type_format", options.cardType))
        configure(previewButton, title: L("option_preview"), value: L(options.previewCorner.titleKey))

        let embedded = options.layout.surface == .embedded
        cardButton.isEnabled = embedded
        previewButton.isEnabled = options.layout == .floatingPreview
        positionButton.isEnabled = options.layout != .floatingPreview

        layoutButton.menu = UIMenu(title: L("option_layout"), children: DetailOptions.Layout.allCases.map { layout in
            UIAction(title: L(layout.titleKey), state: options.layout == layout ? .on : .off) { [weak self] _ in
                self?.update { $0.layout = layout }
            }
        })
        positionButton.menu = UIMenu(title: L("option_position"), children: DetailOptions.Position.allCases.map { position in
            UIAction(title: L(position.titleKey), state: options.position == position ? .on : .off) { [weak self] _ in
                self?.update { $0.position = position }
            }
        })
        cardButton.menu = cardMenu()
        previewButton.menu = previewMenu()
    }

    private func cardMenu() -> UIMenu {
        let types = UIMenu(title: L("option_card_type"), options: .displayInline, children: DetailOptions.cardTypes.map { type in
            UIAction(title: L("option_card_type_format", type), state: options.cardType == type ? .on : .off) { [weak self] _ in
                self?.update { $0.cardType = type }
            }
        })
        func toggle(_ key: String, _ path: WritableKeyPath<DetailOptions, Bool>) -> UIAction {
            UIAction(title: L(key), state: options[keyPath: path] ? .on : .off) { [weak self] _ in
                self?.update { $0[keyPath: path].toggle() }
            }
        }
        let visibility = UIMenu(title: "", options: .displayInline, children: [
            toggle("option_card_title", \.showTitle),
            toggle("option_card_view_count", \.showViewCount),
            toggle("option_card_product_count", \.showProductCount),
            toggle("option_card_autoplay", \.autoplay),
        ])
        let columns = UIMenu(title: L("option_card_columns"), children: DetailOptions.columnChoices.map { n in
            let action = UIAction(title: "\(n)", state: options.columns == n ? .on : .off) { [weak self] _ in
                self?.update { $0.columns = n }
            }
            // The iOS SDK picks the column count for the screen width; the choice is kept for parity with Android.
            action.attributes = .disabled
            return action
        })
        columns.subtitle = L("option_card_columns_note")
        return UIMenu(title: L("option_card"), children: [types, visibility, columns])
    }

    private func previewMenu() -> UIMenu {
        let corners = UIMenu(title: L("option_preview_corner"), children: DetailOptions.Corner.allCases.map { corner in
            UIAction(title: L(corner.titleKey), state: options.previewCorner == corner ? .on : .off) { [weak self] _ in
                self?.update { $0.previewCorner = corner }
            }
        })
        let sizes = UIMenu(title: L("option_preview_size"), children: DetailOptions.PreviewSize.allCases.map { size in
            UIAction(title: L(size.titleKey), state: options.previewSize == size ? .on : .off) { [weak self] _ in
                self?.update { $0.previewSize = size }
            }
        })
        let counts = UIMenu(title: L("option_preview_max_count"), children: DetailOptions.maxCountChoices.map { n in
            UIAction(title: "\(n)", state: options.previewMaxCount == n ? .on : .off) { [weak self] _ in
                self?.update { $0.previewMaxCount = n }
            }
        })
        return UIMenu(title: L("option_preview"), children: [corners, sizes, counts])
    }

    private func configure(_ button: UIButton, title: String, value: String) {
        var config = UIButton.Configuration.gray()
        config.title = title
        config.subtitle = value
        config.titleAlignment = .leading
        config.buttonSize = .small
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        button.configuration = config
    }
}
