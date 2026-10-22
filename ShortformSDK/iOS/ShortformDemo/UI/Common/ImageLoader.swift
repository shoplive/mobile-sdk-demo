import UIKit

/// Minimal image loader with an in-memory cache.
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()

    @discardableResult
    func load(_ urlString: String?, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        guard let s = urlString, let url = URL(string: s) else {
            completion(nil)
            return nil
        }
        if let image = cache.object(forKey: url as NSURL) {
            completion(image)
            return nil
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image { self?.cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }
}

/// Image view that loads a URL and shows a neutral placeholder until then.
final class RemoteImageView: UIImageView {
    private var task: URLSessionDataTask?
    private var currentURL: String?
    private let placeholder = UIImageView(image: UIImage(systemName: "photo"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = .secondarySystemBackground
        placeholder.tintColor = .tertiaryLabel
        placeholder.contentMode = .scaleAspectFit
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 32),
            placeholder.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setURL(_ url: String?) {
        guard url != currentURL || image == nil else { return }
        task?.cancel()
        currentURL = url
        image = nil
        placeholder.isHidden = false
        task = ImageLoader.shared.load(url) { [weak self] image in
            guard let self, self.currentURL == url else { return }
            self.image = image
            self.placeholder.isHidden = image != nil
        }
    }
}
