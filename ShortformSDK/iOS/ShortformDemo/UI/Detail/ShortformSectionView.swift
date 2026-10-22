import UIKit

/// "Shortform for this product" / "Related shortform": an embedded SDK list, a button, or a message.
final class ShortformSectionView: UIView {
    let embed = ShortformEmbedView()
    var onAction: (() -> Void)?

    private let header = SectionHeaderView(title: L("detail_shortform_title"))
    private let actionButton = UIButton(type: .system)
    private let messageLabel = UILabel()
    private let buttonRow = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [header, embed, buttonRow, messageLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.buttonSize = .large
        actionButton.configuration = config
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.addSubview(actionButton)
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: buttonRow.layoutMarginsGuide.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: buttonRow.layoutMarginsGuide.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: buttonRow.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: buttonRow.bottomAnchor),
        ])

        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        showMessage(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Header text: the product's own shortform, or "Related shortform" for the tag and fallback steps.
    func setTitle(related: Bool, matchedBy: String?) {
        header.titleLabel.text = L(related ? "detail_related_title" : "detail_shortform_title")
        header.setNote(matchedBy.map { L("detail_matched_by_format", $0) })
    }

    func showEmbedded() {
        embed.isHidden = false
        buttonRow.isHidden = true
        messageLabel.isHidden = true
    }

    func showButton(_ title: String, note: String? = nil) {
        embed.stopVideos()
        embed.isHidden = true
        actionButton.configuration?.title = title
        buttonRow.isHidden = false
        messageLabel.text = note
        messageLabel.isHidden = note == nil
    }

    func showMessage(_ text: String?) {
        embed.stopVideos()
        embed.isHidden = true
        buttonRow.isHidden = true
        messageLabel.text = text
        messageLabel.isHidden = text == nil
        if text != nil {
            header.titleLabel.text = L("detail_shortform_title")
            header.setNote(nil)
        }
    }

    @objc private func actionTapped() {
        onAction?()
    }
}
