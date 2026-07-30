//
//  ProductDetailViewController.swift  (V2 · product detail)
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The screen that results from routing navigation(url). Product landings are commonly modals in real
//  apps too, so this is a modal rather than a pushed screen.
//  It shows the received URL verbatim so you can see with your own eyes that "the app received this
//  URL and opened this screen".
//

import UIKit
import ShoplivePlayerSDK

final class ProductDetailViewController: UIViewController {

    private let receivedURL: URL
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(receivedURL: URL) {
        self.receivedURL = receivedURL
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
        view.backgroundColor = .white
        build()
    }

    private func build() {
        let store = DemoConfigStore.shared

        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        stack.addArrangedSubview(UILabel.demo(L("product.title"), size: 13, weight: .bold))

        stack.addArrangedSubview(DemoTipView(.ok, L("product.tip.routed", receivedURL.absoluteString)))

        // Mock product content
        let hero = UIView()
        hero.backgroundColor = UIColor(red: 1.0, green: 0.85, blue: 0.886, alpha: 1)
        hero.layer.cornerRadius = DemoTheme.Radius.card
        hero.heightAnchor.constraint(equalToConstant: 130).isActive = true
        stack.addArrangedSubview(hero)

        stack.addArrangedSubview(UILabel.demo(L("product.name"), size: 15, weight: .heavy))
        stack.addArrangedSubview(UILabel.demo(L("product.price"), size: 18, weight: .heavy, color: DemoTheme.brand))

        // actionOnNavigation switching
        let policyName = UILabel.demo("actionOnNavigation", size: 11.5, weight: .bold)
        policyName.font = .monospacedSystemFont(ofSize: 11.5, weight: .bold)

        let policyButton = UIButton(type: .system)
        policyButton.setTitle(store.actionOnNavigation.logLabel, for: .normal)
        policyButton.setTitleColor(DemoTheme.brand, for: .normal)
        policyButton.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)

        let explanation = DemoTipView(.info, store.actionOnNavigation.explanation)

        policyButton.addAction(UIAction { [weak self] _ in
            store.actionOnNavigation = store.actionOnNavigation.next
            policyButton.setTitle(store.actionOnNavigation.logLabel, for: .normal)
            EventLog.shared.log(.sdk, "actionOnNavigation = .\(store.actionOnNavigation.logLabel) (applies from the next playback)")
            self?.replaceExplanation()
        }, for: .touchUpInside)

        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let policyRow = UIStackView.demo(.horizontal, spacing: 8, alignment: .center,
                                         [policyName, spacerView, policyButton])
        stack.addArrangedSubview(policyRow)
        stack.addArrangedSubview(explanation)
        explanationView = explanation

        stack.addArrangedSubview(DemoTipView(.warn, L("product.warn.mustHandle")))

        // PIP status note — while floating, the SDK window stays above this modal.
        if let player = DevSheetViewController.activePlayer, player.isInPictureInPicture {
            stack.addArrangedSubview(DemoTipView(.ok, L("product.pip.active")))
        }

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
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

    private weak var explanationView: DemoTipView?

    private func replaceExplanation() {
        guard let old = explanationView, let index = stack.arrangedSubviews.firstIndex(of: old) else { return }
        let fresh = DemoTipView(.info, DemoConfigStore.shared.actionOnNavigation.explanation)
        stack.removeArrangedSubview(old)
        old.removeFromSuperview()
        stack.insertArrangedSubview(fresh, at: index)
        explanationView = fresh
    }
}
