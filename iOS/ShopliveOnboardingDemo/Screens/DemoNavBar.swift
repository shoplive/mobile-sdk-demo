//
//  DemoNavBar.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//

import UIKit

/// The prototype's .navbar — back button on the left, title, one action on the right.
final class DemoNavBar: UIView {

    private let onBack: (() -> Void)?
    private let onAction: (() -> Void)?

    init(title: String,
         actionSymbol: String? = nil,
         onAction: (() -> Void)? = nil,
         onBack: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onAction = onAction
        super.init(frame: .zero)

        backgroundColor = UIColor.white.withAlphaComponent(0.96)

        let hairline = UIView()
        hairline.backgroundColor = DemoTheme.hairline

        let stack = UIStackView.demo(.horizontal, spacing: 8, alignment: .center)

        if onBack != nil {
            let back = UIButton(type: .system)
            back.setTitle("‹", for: .normal)
            back.setTitleColor(DemoTheme.textSecondary, for: .normal)
            back.titleLabel?.font = .systemFont(ofSize: 26, weight: .regular)
            back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
            back.widthAnchor.constraint(equalToConstant: 24).isActive = true
            stack.addArrangedSubview(back)
        }

        let titleLabel = UILabel.demo(title, size: 15, weight: .bold, lines: 1)
        stack.addArrangedSubview(titleLabel)

        if let symbol = actionSymbol {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(spacer)

            let action = UIButton(type: .system)
            action.setTitle(symbol, for: .normal)
            action.setTitleColor(DemoTheme.textSecondary, for: .normal)
            action.titleLabel?.font = .systemFont(ofSize: 18)
            action.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            stack.addArrangedSubview(action)
        }

        addSubview(stack); addSubview(hairline)
        stack.translatesAutoresizingMaskIntoConstraints = false
        hairline.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11),

            hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func backTapped() { onBack?() }
    @objc private func actionTapped() { onAction?() }
}

/// The prototype's .btn (p / o / s)
final class DemoButton: UIButton {

    enum Style { case primary, outline, secondary }

    private let style: Style
    private let compact: Bool

    init(_ title: String, style: Style = .primary, compact: Bool = false) {
        self.style = style
        self.compact = compact
        super.init(frame: .zero)

        layer.cornerRadius = compact ? 10 : DemoTheme.Radius.button

        let foreground: UIColor
        switch style {
        case .primary:
            backgroundColor = DemoTheme.brand
            foreground = .white
        case .outline:
            backgroundColor = .white
            foreground = DemoTheme.brand
            layer.borderWidth = 1.5
            layer.borderColor = DemoTheme.brand.cgColor
        case .secondary:
            backgroundColor = DemoTheme.fill
            foreground = DemoTheme.text
        }

        // Once you use UIButton.Configuration, setTitle/setTitleColor/titleLabel.font are ignored —
        // the title styling has to be specified inside the configuration too.
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: compact ? 11 : 15, leading: 14,
                                                       bottom: compact ? 11 : 15, trailing: 14)
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: compact ? 12.5 : 14.5, weight: .bold),
            .foregroundColor: foreground,
        ]))
        configuration = config
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// This is a configuration-based button, so replacing the title also goes through configuration.
    func setDemoTitle(_ title: String) {
        let foreground: UIColor
        switch style {
        case .primary: foreground = .white
        case .outline: foreground = DemoTheme.brand
        case .secondary: foreground = DemoTheme.text
        }
        configuration?.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: compact ? 12.5 : 14.5, weight: .bold),
            .foregroundColor: foreground,
        ]))
    }

    func setEnabledAppearance(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1 : 0.4
    }
}

/// The prototype's .fab
final class DemoFab: UIButton {

    init(_ title: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.07, alpha: 1)
        layer.cornerRadius = 17

        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: UIColor.white,
        ]))
        configuration = config

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 9
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
