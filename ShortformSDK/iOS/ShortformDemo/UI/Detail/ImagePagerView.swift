import UIKit

/// Horizontally paged product images with a page control.
final class ImagePagerView: UIView, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let pageControl = UIPageControl()

    init(urls: [String]) {
        super.init(frame: .zero)
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        scroll.addSubview(stack)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.hidesForSinglePage = true
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.5)
        pageControl.addTarget(self, action: #selector(pageTapped), for: .valueChanged)
        addSubview(pageControl)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        let sources: [String?] = urls.isEmpty ? [nil] : urls
        for url in sources {
            let imageView = RemoteImageView()
            imageView.setURL(url)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(imageView)
            imageView.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor).isActive = true
        }
        pageControl.numberOfPages = sources.count
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = max(scrollView.bounds.width, 1)
        pageControl.currentPage = Int((scrollView.contentOffset.x / width).rounded())
    }

    @objc private func pageTapped() {
        let x = CGFloat(pageControl.currentPage) * scroll.bounds.width
        scroll.setContentOffset(CGPoint(x: x, y: 0), animated: true)
    }

    /// Keeps the current page after a size change.
    override func layoutSubviews() {
        let page = pageControl.currentPage
        super.layoutSubviews()
        let x = CGFloat(page) * scroll.bounds.width
        if abs(scroll.contentOffset.x - x) > 1, !scroll.isDragging, !scroll.isDecelerating {
            scroll.contentOffset = CGPoint(x: x, y: 0)
        }
    }
}
