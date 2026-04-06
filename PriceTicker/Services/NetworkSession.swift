import Foundation

/// Shared network layer. Exposes `dataTaskPublisher` so callers are decoupled
/// from URLSession directly — this lets us rebuild the session transparently
/// when proxy settings change without touching any call site.
final class NetworkSession {
    static let shared = NetworkSession()

    private var urlSession: URLSession = NetworkSession.buildSession()

    private init() {}

    /// Called by ProxySettings.apply() after new settings are saved.
    /// Invalidates the old session first to release its connection pool.
    func rebuild() {
        urlSession.invalidateAndCancel()
        urlSession = NetworkSession.buildSession()
    }

    func dataTaskPublisher(for url: URL) -> URLSession.DataTaskPublisher {
        urlSession.dataTaskPublisher(for: url)
    }

    private static func buildSession() -> URLSession {
        let s = ProxySettings.shared
        let config = URLSessionConfiguration.ephemeral
        if s.useProxy && !s.host.trimmingCharacters(in: .whitespaces).isEmpty {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable:  true,
                kCFNetworkProxiesHTTPProxy:   s.host,
                kCFNetworkProxiesHTTPPort:    s.port,
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy:  s.host,
                kCFNetworkProxiesHTTPSPort:   s.port,
            ] as [AnyHashable: Any]
        }
        config.timeoutIntervalForRequest  = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }
}
