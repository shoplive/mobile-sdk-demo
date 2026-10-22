import Foundation

/// Loads the catalog: catalog URL → last good copy on the device → bundled sample.
final class CatalogStore {
    enum Source: String, Equatable {
        case remote
        case cache
        case bundled
    }

    struct Loaded: Equatable {
        var catalog: Catalog
        var source: Source
        /// Why the catalog URL was not used, when it was set but failed.
        var remoteFailed: Bool
    }

    typealias Fetcher = (URL) async throws -> Data

    private let cacheURL: URL
    private let bundledURL: URL?
    private let fetch: Fetcher

    init(cacheURL: URL, bundledURL: URL?, fetch: @escaping Fetcher = CatalogStore.urlSessionFetch) {
        self.cacheURL = cacheURL
        self.bundledURL = bundledURL
        self.fetch = fetch
    }

    static var defaultCacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("shortform-demo-catalog.json")
    }

    static var bundledSampleURL: URL? {
        Bundle.main.url(forResource: "catalog.sample", withExtension: "json")
    }

    static func urlSessionFetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Never throws: the bundled sample is the last resort, and an empty catalog is returned only when even that is
    /// missing or invalid.
    func load(remoteURL: URL?) async -> Loaded {
        var remoteFailed = false
        if let remoteURL {
            do {
                let data = try await fetch(remoteURL)
                let catalog = try Catalog.parse(data)
                try? data.write(to: cacheURL, options: .atomic)
                return Loaded(catalog: catalog, source: .remote, remoteFailed: false)
            } catch {
                remoteFailed = true
            }
        }
        if remoteURL != nil, let data = try? Data(contentsOf: cacheURL), let catalog = try? Catalog.parse(data) {
            return Loaded(catalog: catalog, source: .cache, remoteFailed: remoteFailed)
        }
        if let bundledURL, let data = try? Data(contentsOf: bundledURL), let catalog = try? Catalog.parse(data) {
            return Loaded(catalog: catalog, source: .bundled, remoteFailed: remoteFailed)
        }
        return Loaded(catalog: Catalog(products: []), source: .bundled, remoteFailed: remoteFailed)
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
