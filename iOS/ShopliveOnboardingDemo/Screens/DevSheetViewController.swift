//
//  DevSheetViewController.swift  (V1 · developer sheet)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  One sheet, two tabs — which events arrive (Log), and what changes when you flip an option
//  (Options).
//  The options tab is the home for every configuration field that no mission covers.
//

import UIKit
import ShoplivePlayerSDK

final class DevSheetViewController: UIViewController {

    enum Tab { case log, options }

    /// The target for the runtime controls (isMuted/resizeMode/reload/send/overlayUI).
    /// Only valid while a player is on screen.
    static weak var activePlayer: (AnyObject & ShoplivePlayerControlling)?

    private var currentTab: Tab
    private let segmented = UISegmentedControl(items: [L("dev.tab.log"), L("dev.tab.options")])
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let footer = UIStackView()

    init(initialTab: Tab = .log) {
        self.currentTab = initialTab
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DemoTheme.sheetBackground
        build()
        render()

        NotificationCenter.default.addObserver(
            forName: EventLog.didChange, object: nil, queue: .main) { [weak self] _ in
                guard self?.currentTab == .log else { return }
                self?.render()
            }
        NotificationCenter.default.addObserver(
            forName: DemoConfigStore.didChange, object: nil, queue: .main) { [weak self] _ in
                guard self?.currentTab == .options else { return }
                self?.render()
            }
    }

    func select(_ tab: Tab) {
        self.currentTab = tab
        segmented.selectedSegmentIndex = currentTab == .log ? 0 : 1
        render()
    }

    @objc private func tabChanged() {
        currentTab = segmented.selectedSegmentIndex == 0 ? .log : .options
        render()
    }

    // MARK: - Render

    private func render() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        footer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = currentTab == .log ? DemoTheme.sheetBackground : .white
        contentStack.layoutMargins = UIEdgeInsets(top: 12, left: 15, bottom: 24, right: 15)
        currentTab == .log ? renderLog() : renderOptions()
    }

    // MARK: - Log tab

    private func renderLog() {
        let entries = EventLog.shared.entries

        if entries.isEmpty {
            contentStack.addArrangedSubview(
                UILabel.demo(L("dev.log.empty"), size: 11,
                             color: UIColor(white: 0.43, alpha: 1)))
        } else {
            for entry in entries {
                contentStack.addArrangedSubview(logRow(entry))
            }
        }

        // Prototype V1 rule: two fixed callouts.
        let notice = UILabel.demo(
            L("dev.log.notice"),
            size: 9.5, color: UIColor(white: 0.55, alpha: 1))
        let noticeBox = UIView()
        noticeBox.backgroundColor = DemoTheme.sheetPanel
        noticeBox.layer.cornerRadius = 8
        noticeBox.addSubview(notice)
        notice.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            notice.topAnchor.constraint(equalTo: noticeBox.topAnchor, constant: 10),
            notice.bottomAnchor.constraint(equalTo: noticeBox.bottomAnchor, constant: -10),
            notice.leadingAnchor.constraint(equalTo: noticeBox.leadingAnchor, constant: 10),
            notice.trailingAnchor.constraint(equalTo: noticeBox.trailingAnchor, constant: -10),
        ])
        contentStack.addArrangedSubview(spacer(10))
        contentStack.addArrangedSubview(noticeBox)

        let copy = DemoButton(L("dev.log.copy"), style: .secondary, compact: true)
        copy.backgroundColor = DemoTheme.sheetLine
        copy.addTarget(self, action: #selector(copyLog), for: .touchUpInside)

        let clear = DemoButton(L("dev.log.clear"), style: .secondary, compact: true)
        clear.backgroundColor = DemoTheme.sheetLine
        clear.addTarget(self, action: #selector(clearLog), for: .touchUpInside)

        footer.addArrangedSubview(copy)
        footer.addArrangedSubview(clear)
    }

    private func logRow(_ entry: EventLog.Entry) -> UIView {
        let color: UIColor
        switch entry.kind {
        case .event:   color = UIColor(red: 0.475, green: 0.757, blue: 1.0, alpha: 1)
        case .request: color = UIColor(red: 1.0, green: 0.651, blue: 0.341, alpha: 1)
        case .error:   color = UIColor(red: 1.0, green: 0.482, blue: 0.447, alpha: 1)
        case .sdk:     color = UIColor(red: 0.494, green: 0.906, blue: 0.529, alpha: 1)
        }

        let text = NSMutableAttributedString(
            string: entry.time + " ",
            attributes: [.font: DemoTheme.mono, .foregroundColor: UIColor(white: 0.43, alpha: 1)])
        text.append(NSAttributedString(
            string: entry.kind.rawValue + " ",
            attributes: [.font: UIFont.monospacedSystemFont(ofSize: 10.5, weight: .bold),
                         .foregroundColor: color]))
        text.append(NSAttributedString(
            string: entry.message,
            attributes: [.font: DemoTheme.mono, .foregroundColor: DemoTheme.sheetText]))

        let label = UILabel()
        label.attributedText = text
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }

    @objc private func copyLog() {
        UIPasteboard.general.string = EventLog.shared.plainText
        DemoToast.show(L("dev.toast.copied"), in: view)
    }

    @objc private func clearLog() {
        EventLog.shared.clear()
    }

    // MARK: - Options tab

    private func renderOptions() {
        let store = DemoConfigStore.shared

        contentStack.addArrangedSubview(group(L("dev.group.auth")))
        contentStack.addArrangedSubview(row("setUser", "guest", store.authMode.rawValue) {
            let all = DemoConfigStore.AuthMode.allCases
            let next = all[(all.firstIndex(of: store.authMode)! + 1) % all.count]
            store.authMode = next
            DemoAuthApplier.applyCurrentSelection()
        })

        contentStack.addArrangedSubview(group(L("dev.group.pip")))
        contentStack.addArrangedSubview(sliderRow("pip.scale", "0.4", value: Float(store.pipScale),
                                                  min: 0.2, max: 0.8) { store.pipScale = CGFloat($0) })
        contentStack.addArrangedSubview(row("pip.defaultPosition", "bottomRight", store.pipPosition.logLabel) {
            let all = DemoConfigStore.pipPositionCycle
            let idx = all.firstIndex(where: { $0.logLabel == store.pipPosition.logLabel }) ?? 0
            store.pipPosition = all[(idx + 1) % all.count]
        })
        contentStack.addArrangedSubview(row("pip.isOSPipEnabled", "true", "\(store.isOSPipEnabled)") {
            store.isOSPipEnabled.toggle()
        })
        contentStack.addArrangedSubview(row("navigation.actionOnNavigation", "pip", store.actionOnNavigation.logLabel) {
            store.actionOnNavigation = store.actionOnNavigation.next
        })

        contentStack.addArrangedSubview(group(L("dev.group.overlay")))
        contentStack.addArrangedSubview(row("overlay.ui", "builtIn", store.overlayUI.logLabel) {
            store.overlayUI = store.overlayUI.toggled
            if let player = Self.activePlayer {
                PlayerConfigurationFactory.applyRuntimeOverlay(store.overlayUI, to: player)
            }
        })
        contentStack.addArrangedSubview(row("appearance.indicatorColor", "white", currentColorName()) {
            let all = DemoConfigStore.indicatorColorCycle
            let idx = all.firstIndex(where: { $0.1 == store.indicatorColor }) ?? 0
            store.indicatorColor = all[(idx + 1) % all.count].1
        })
        contentStack.addArrangedSubview(row("sound.muteOnStart", "false", "\(store.muteOnStart)") {
            store.muteOnStart.toggle()
        })

        contentStack.addArrangedSubview(group(L("dev.group.control")))
        contentStack.addArrangedSubview(row("isMuted", "false", "\(store.isMuted)") {
            store.isMuted.toggle()
            Self.activePlayer?.isMuted = store.isMuted
            EventLog.shared.log(.sdk, "isMuted = \(store.isMuted)")
        })
        contentStack.addArrangedSubview(row("resizeMode", "fill", store.resizeMode.logLabel) {
            store.resizeMode = store.resizeMode.toggled
            Self.activePlayer?.resizeMode = store.resizeMode
            EventLog.shared.log(.sdk, "resizeMode = .\(store.resizeMode.logLabel)")
        })
        contentStack.addArrangedSubview(actionRow("reload()", L("dev.action.call")) {
            guard let player = Self.activePlayer else {
                EventLog.shared.log(.error, "reload() — " + L("dev.error.noPlayer")); return
            }
            player.reload()
            EventLog.shared.log(.sdk, "reload() — restart the current campaign (stop→play)")
        })
        contentStack.addArrangedSubview(actionRow("send(command:)", L("dev.action.send")) {
            guard let player = Self.activePlayer else {
                EventLog.shared.log(.error, "send() — " + L("dev.error.noPlayer")); return
            }
            DemoPlayerDelegate.sendHighlightProduct(sku: "A-1024", to: player)
        })
        contentStack.addArrangedSubview(actionRow("enter/exitPictureInPicture()", L("dev.action.toggle")) {
            guard let player = Self.activePlayer else {
                EventLog.shared.log(.error, "PIP — " + L("dev.error.noPlayer")); return
            }
            PipSetup.toggle(player)
        })

        contentStack.addArrangedSubview(group(L("dev.group.advanced")))
        contentStack.addArrangedSubview(row("pip.isInAppPipEnabled", "true", "\(store.isInAppPipEnabled)") {
            store.isInAppPipEnabled.toggle()
        })
        contentStack.addArrangedSubview(row("pip.padding", "0", "\(Int(store.pipPadding))") {
            store.pipPadding = store.pipPadding >= 24 ? 0 : store.pipPadding + 8
        })
        contentStack.addArrangedSubview(row("pip.floatingOffset", "0", "\(Int(store.pipFloatingOffset))") {
            store.pipFloatingOffset = store.pipFloatingOffset >= 24 ? 0 : store.pipFloatingOffset + 8
        })
        contentStack.addArrangedSubview(row("pip.fixedWidth", "nil",
                                            store.pipFixedWidth.map { "\(Int($0))" } ?? "nil") {
            store.pipFixedWidth = store.pipFixedWidth == nil ? 160 : nil
        })
        contentStack.addArrangedSubview(row("sound.mixWithOthers", "false", "\(store.mixWithOthers)") {
            store.mixWithOthers.toggle()
        })
        contentStack.addArrangedSubview(row("sound.autoResumeOnCallEnded", "true", "\(store.autoResumeOnCallEnded)") {
            store.autoResumeOnCallEnded.toggle()
        })
        contentStack.addArrangedSubview(row("appearance.allowScreenCapture", "false", "\(store.allowScreenCapture)") {
            store.allowScreenCapture.toggle()
        })
        contentStack.addArrangedSubview(row("navigation.shareScheme", "nil", store.shareScheme ?? "nil") {
            store.shareScheme = store.shareScheme == nil ? "shopliveDemo://share" : nil
        })
        contentStack.addArrangedSubview(row("customParameters", "{}",
                                            store.customParameters.isEmpty ? "{}" : "{tier:vip}") {
            store.customParameters = store.customParameters.isEmpty ? ["tier": "vip"] : [:]
        })
        contentStack.addArrangedSubview(row("ShoplivePlayOptions.referrer", "nil", store.referrer ?? "nil") {
            store.referrer = store.referrer == nil ? "dev_sheet" : nil
        })
        contentStack.addArrangedSubview(row("ShoplivePlayOptions.keepWindowStateOnPlayExecuted", "false",
                                            "\(store.keepWindowStateOnPlayExecuted)") {
            store.keepWindowStateOnPlayExecuted.toggle()
        })

        contentStack.addArrangedSubview(spacer(6))
        contentStack.addArrangedSubview(DemoTipView(.warn, L("dev.unwired.warning")))
        contentStack.addArrangedSubview(UILabel.demo(L("dev.hint.cycle"), size: 10.5, color: DemoTheme.textTertiary))
    }

    private func currentColorName() -> String {
        DemoConfigStore.indicatorColorCycle
            .first { $0.1 == DemoConfigStore.shared.indicatorColor }?.0 ?? "custom"
    }

    // MARK: - Option row factories

    private func group(_ title: String) -> UIView {
        let label = UILabel.demo(title.uppercased(), size: 10.5, weight: .heavy, color: DemoTheme.textTertiary)
        let wrapper = UIStackView.demo(.vertical, spacing: 0, [spacer(8), label])
        return wrapper
    }

    private func row(_ name: String, _ defaultValue: String, _ value: String,
                     _ action: @escaping () -> Void) -> UIView {
        let nameLabel = UILabel.demo(name, size: 11.5, weight: .bold)
        nameLabel.font = .monospacedSystemFont(ofSize: 11.5, weight: .bold)
        let defaultLabel = UILabel.demo(L("dev.default", defaultValue), size: 10, color: DemoTheme.textTertiary)
        let left = UIStackView.demo(.vertical, spacing: 1, [nameLabel, defaultLabel])

        let valueButton = UIButton(type: .system)
        valueButton.setTitle(value, for: .normal)
        valueButton.setTitleColor(DemoTheme.brand, for: .normal)
        valueButton.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        valueButton.addAction(UIAction { [weak self] _ in
            action()
            DemoConfigStore.shared.notifyChanged()
            self?.render()
        }, for: .touchUpInside)

        return hairlineRow(left: left, right: valueButton)
    }

    private func actionRow(_ name: String, _ label: String, _ action: @escaping () -> Void) -> UIView {
        let nameLabel = UILabel.demo(name, size: 11.5, weight: .bold)
        nameLabel.font = .monospacedSystemFont(ofSize: 11.5, weight: .bold)

        let button = UIButton(type: .system)
        button.setTitle(label, for: .normal)
        button.setTitleColor(DemoTheme.brand, for: .normal)
        button.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        return hairlineRow(left: nameLabel, right: button)
    }

    private func sliderRow(_ name: String, _ defaultValue: String, value: Float,
                           min: Float, max: Float, _ onChange: @escaping (Float) -> Void) -> UIView {
        let nameLabel = UILabel.demo(name, size: 11.5, weight: .bold)
        nameLabel.font = .monospacedSystemFont(ofSize: 11.5, weight: .bold)
        let valueLabel = UILabel.demo(String(format: "%.2f", value), size: 12, weight: .bold, color: DemoTheme.brand)

        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.tintColor = DemoTheme.brand
        slider.addAction(UIAction { [weak valueLabel] action in
            guard let slider = action.sender as? UISlider else { return }
            onChange(slider.value)
            valueLabel?.text = String(format: "%.2f", slider.value)
            DemoConfigStore.shared.notifyChanged()
        }, for: .valueChanged)

        let top = hairlineRow(left: UIStackView.demo(.vertical, spacing: 1, [
            nameLabel, UILabel.demo(L("dev.default", defaultValue), size: 10, color: DemoTheme.textTertiary),
        ]), right: valueLabel, hairline: false)

        return UIStackView.demo(.vertical, spacing: 2, [top, slider])
    }

    private func hairlineRow(left: UIView, right: UIView, hairline: Bool = true) -> UIView {
        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView.demo(.horizontal, spacing: 8, alignment: .center, [left, spacerView, right])
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)

        guard hairline else { return row }

        let container = UIView()
        let line = UIView()
        line.backgroundColor = UIColor(red: 0.945, green: 0.949, blue: 0.957, alpha: 1)
        container.addSubview(row); container.addSubview(line)
        row.translatesAutoresizingMaskIntoConstraints = false
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
        ])
        return container
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: - Layout

    private func build() {
        segmented.selectedSegmentIndex = currentTab == .log ? 0 : 1
        segmented.addTarget(self, action: #selector(tabChanged), for: .valueChanged)

        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.isLayoutMarginsRelativeArrangement = true

        footer.axis = .horizontal
        footer.spacing = 7
        footer.distribution = .fillEqually
        footer.isLayoutMarginsRelativeArrangement = true
        footer.layoutMargins = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

        view.addSubview(segmented)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(footer)

        [segmented, scrollView, contentStack, footer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            footer.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}
