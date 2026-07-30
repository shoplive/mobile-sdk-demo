//
//  StartViewController.swift  (S1 · start)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  One screen to choose between watching immediately with no input and trying it with your own keys.
//  The input form starts collapsed — "take a tour" should catch the eye first.
//

import UIKit

final class StartViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private var isFormExpanded = false

    private let accessKeyField = StartViewController.makeField(placeholder: L("start.field.accessKey.placeholder"))
    private let campaignKeyField = StartViewController.makeField(placeholder: L("start.field.campaignKey.placeholder"))
    private let streamTokenField = StartViewController.makeField(placeholder: L("start.field.streamToken.placeholder"))

    private lazy var tourButton = DemoButton(L("start.tour"), style: .primary)
    private lazy var ownButton = DemoButton(L("start.own.collapsed"), style: .outline)
    private lazy var formContainer = UIView()

    /// If credentials already exist, expand the form when S1 is reopened (i.e. entered via ⚙).
    init(expandForm: Bool = false) {
        self.isFormExpanded = expandForm
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        build()
        restore()
        applyFormVisibility()
    }

    // MARK: - Actions

    @objc private func startTour() {
        guard DemoDefaults.isAvailable else {
            DemoToast.show(L("start.toast.tourMissing"), in: view)
            expandForm()
            return
        }
        DemoCredentials.shared.mode = .tour
        ShopliveBootstrap.initialize(accessKey: DemoCredentials.shared.accessKey)
        UserSetup.applyGuest()
        goToMissionList()
    }

    @objc private func toggleForm() {
        isFormExpanded ? collapseForm() : expandForm()
    }

    private func expandForm() {
        isFormExpanded = true
        ownButton.setDemoTitle(L("start.own.expanded"))
        applyFormVisibility()
    }

    private func collapseForm() {
        isFormExpanded = false
        ownButton.setDemoTitle(L("start.own.collapsed"))
        applyFormVisibility()
    }

    private func applyFormVisibility() {
        formContainer.isHidden = !isFormExpanded
        ownButton.setDemoTitle(isFormExpanded ? L("start.own.expanded") : L("start.own.collapsed"))
    }

    @objc private func validateAndStart() {
        let accessKey = accessKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let campaignKey = campaignKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let streamToken = streamTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !accessKey.isEmpty, !campaignKey.isEmpty else {
            DemoToast.show(L("start.toast.required"), in: view)
            return
        }

        let credentials = DemoCredentials.shared
        credentials.mode = .own
        credentials.accessKey = accessKey
        credentials.campaignKey = campaignKey
        credentials.streamToken = streamToken

        // All that is validated here is "are the fields filled in". Whether the keys are actually
        // valid is decided by the SDK on first playback, and on failure the reason arrives as an
        // error event (-102 auth failed / 9000 accessKey not set / 9003 campaign not found /
        // 9900 network).
        ShopliveBootstrap.initialize(accessKey: accessKey)
        DemoAuthApplier.applyCurrentSelection()

        DemoToast.show(L("start.toast.initialized"), in: view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.goToMissionList()
        }
    }

    private func goToMissionList() {
        navigationController?.setViewControllers([MissionListViewController()], animated: true)
    }

    private func restore() {
        let credentials = DemoCredentials.shared
        accessKeyField.text = credentials.enteredAccessKey
        campaignKeyField.text = credentials.enteredCampaignKey
        streamTokenField.text = credentials.streamToken
        tourButton.setEnabledAppearance(true)
    }

    // MARK: - Layout

    private func build() {
        stack.axis = .vertical
        stack.spacing = 9
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 44, left: 16, bottom: 40, right: 16)

        // Logo + title
        let logo = UIView()
        logo.backgroundColor = DemoTheme.brand
        logo.layer.cornerRadius = 16
        let play = UILabel.demo("▶", size: 25, color: .white)
        play.textAlignment = .center
        logo.addSubview(play)
        play.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 54),
            logo.heightAnchor.constraint(equalToConstant: 54),
            play.centerXAnchor.constraint(equalTo: logo.centerXAnchor),
            play.centerYAnchor.constraint(equalTo: logo.centerYAnchor),
        ])
        let logoRow = UIStackView.demo(.horizontal, alignment: .leading, [logo, UIView()])

        let title = UILabel.demo(L("start.title"), size: 23, weight: .heavy)
        let subtitle = UILabel.demo(
            L("start.subtitle"),
            size: 12.5, color: DemoTheme.textSecondary)

        stack.addArrangedSubview(logoRow)
        stack.addArrangedSubview(spacer(10))
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(spacer(8))

        tourButton.addTarget(self, action: #selector(startTour), for: .touchUpInside)
        stack.addArrangedSubview(tourButton)

        let tourNote = UILabel.demo(
            DemoDefaults.isAvailable
                ? L("start.tourNote.available")
                : L("start.tourNote.missing"),
            size: 11.5, color: DemoDefaults.isAvailable ? DemoTheme.textSecondary : DemoTheme.warn)
        stack.addArrangedSubview(tourNote)
        stack.addArrangedSubview(spacer(6))

        ownButton.addTarget(self, action: #selector(toggleForm), for: .touchUpInside)
        stack.addArrangedSubview(ownButton)

        buildForm()
        stack.addArrangedSubview(formContainer)

        stack.addArrangedSubview(spacer(6))
        stack.addArrangedSubview(DemoTipView(.ok, L("start.tip.code")))
        stack.addArrangedSubview(DemoTipView(.info, L("start.tip.privacy")))

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        scrollView.keyboardDismissMode = .onDrag
        [scrollView, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildForm() {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = DemoTheme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = DemoTheme.hairline.cgColor

        let validate = DemoButton(L("start.validate"), style: .primary)
        validate.addTarget(self, action: #selector(validateAndStart), for: .touchUpInside)

        let inner = UIStackView.demo(.vertical, spacing: 11, [
            DemoTipView(.info, L("start.form.tip")),
            fieldGroup(L("start.field.accessKey"), accessKeyField, hint: L("start.field.accessKey.hint")),
            fieldGroup(L("start.field.campaignKey"), campaignKeyField, hint: L("start.field.campaignKey.hint")),
            fieldGroup(L("start.field.streamToken"), streamTokenField, hint: L("start.field.streamToken.hint")),
        ])
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        card.addSubview(inner)
        inner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        let container = UIStackView.demo(.vertical, spacing: 9, [card, validate])
        formContainer.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: formContainer.topAnchor),
            container.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor),
        ])
    }

    private func fieldGroup(_ title: String, _ field: UITextField, hint: String) -> UIView {
        let label = UILabel.demo(title, size: 11.5, weight: .bold, color: UIColor(white: 0.22, alpha: 1))
        let hintLabel = UILabel.demo(hint, size: 10.5, color: DemoTheme.textTertiary)
        return UIStackView.demo(.vertical, spacing: 5, [label, field, hintLabel])
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    private static func makeField(placeholder: String) -> UITextField {
        let f = UITextField()
        f.placeholder = placeholder
        f.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        f.backgroundColor = UIColor(red: 0.98, green: 0.984, blue: 0.988, alpha: 1)
        f.layer.cornerRadius = 10
        f.layer.borderWidth = 1
        f.layer.borderColor = UIColor(red: 0.863, green: 0.875, blue: 0.898, alpha: 1).cgColor
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.clearButtonMode = .whileEditing
        f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        f.leftViewMode = .always
        f.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return f
    }
}
