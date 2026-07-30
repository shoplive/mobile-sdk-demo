//
//  DemoTheme.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  The colors and typography of the prototype (shoplive-onboarding-demo-prototype.html), ported to
//  UIKit.
//

import UIKit

enum DemoTheme {

    static let brand = UIColor(red: 1.0, green: 0.176, blue: 0.333, alpha: 1)   // #FF2D55
    static let ok = UIColor(red: 0.18, green: 0.63, blue: 0.26, alpha: 1)       // #2EA043
    static let info = UIColor(red: 0.30, green: 0.60, blue: 1.0, alpha: 1)      // #4C9AFF
    static let warn = UIColor(red: 0.82, green: 0.60, blue: 0.13, alpha: 1)     // #D29922

    static let text = UIColor(white: 0.07, alpha: 1)
    static let textSecondary = UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    static let textTertiary = UIColor(red: 0.61, green: 0.64, blue: 0.69, alpha: 1)
    static let hairline = UIColor(red: 0.925, green: 0.925, blue: 0.94, alpha: 1)
    static let fill = UIColor(red: 0.949, green: 0.953, blue: 0.965, alpha: 1)

    // Developer sheet (dark)
    static let sheetBackground = UIColor(red: 0.051, green: 0.067, blue: 0.09, alpha: 1)  // #0D1117
    static let sheetPanel = UIColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1)      // #161B22
    static let sheetLine = UIColor(red: 0.129, green: 0.149, blue: 0.18, alpha: 1)        // #21262D
    static let sheetText = UIColor(red: 0.788, green: 0.82, blue: 0.851, alpha: 1)        // #C9D1D9

    static let mono = UIFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)

    enum Radius {
        static let card: CGFloat = 14
        static let button: CGFloat = 13
        static let sheet: CGFloat = 18
        static let pill: CGFloat = 6
    }
}

// MARK: - Shared view factories

extension UILabel {
    static func demo(_ text: String,
                     size: CGFloat,
                     weight: UIFont.Weight = .regular,
                     color: UIColor = DemoTheme.text,
                     lines: Int = 0) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.numberOfLines = lines
        return l
    }
}

extension UIStackView {
    static func demo(_ axis: NSLayoutConstraint.Axis,
                     spacing: CGFloat = 0,
                     alignment: UIStackView.Alignment = .fill,
                     _ views: [UIView] = []) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = axis
        s.spacing = spacing
        s.alignment = alignment
        return s
    }
}

/// The prototype's .tip box (three kinds: info / warn / ok).
final class DemoTipView: UIView {

    enum Kind { case info, warn, ok }

    init(_ kind: Kind, _ text: String) {
        super.init(frame: .zero)

        let accent: UIColor
        let bg: UIColor
        switch kind {
        case .info: accent = DemoTheme.info;  bg = UIColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1)
        case .warn: accent = DemoTheme.warn;  bg = UIColor(red: 1.0, green: 0.976, blue: 0.925, alpha: 1)
        case .ok:   accent = DemoTheme.ok;    bg = UIColor(red: 0.937, green: 0.98, blue: 0.945, alpha: 1)
        }

        backgroundColor = bg
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = accent.withAlphaComponent(0.35).cgColor

        let bar = UIView()
        bar.backgroundColor = accent
        let label = UILabel.demo(text, size: 12, color: DemoTheme.text.withAlphaComponent(0.85))

        addSubview(bar); addSubview(label)
        bar.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 3),

            label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 11),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// The prototype's toast.
enum DemoToast {
    static func show(_ message: String, in view: UIView) {
        let label = UILabel.demo(message, size: 11.5, weight: .semibold, color: .white)
        label.textAlignment = .center
        let box = UIView()
        box.backgroundColor = UIColor(white: 0.07, alpha: 0.93)
        box.layer.cornerRadius = 20
        box.addSubview(label)
        view.addSubview(box)

        box.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -76),
            box.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.84),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -15),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -9),
        ])

        box.alpha = 0
        UIView.animate(withDuration: 0.18, animations: { box.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.6, animations: { box.alpha = 0 }) { _ in
                box.removeFromSuperview()
            }
        }
    }
}
