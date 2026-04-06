import Foundation

/// Persists proxy configuration in UserDefaults and triggers a session rebuild
/// whenever settings are applied.
final class ProxySettings: ObservableObject {
    static let shared = ProxySettings()

    @Published private(set) var useProxy: Bool
    @Published private(set) var host: String
    @Published private(set) var port: Int

    private enum Keys {
        static let enabled = "proxy.enabled"
        static let host    = "proxy.host"
        static let port    = "proxy.port"
    }

    private init() {
        useProxy = UserDefaults.standard.bool(forKey: Keys.enabled)
        host = UserDefaults.standard.string(forKey: Keys.host) ?? ""
        let saved = UserDefaults.standard.integer(forKey: Keys.port)
        port = saved > 0 ? saved : 1080
    }

    /// Persists settings and immediately rebuilds the shared URLSession.
    func apply(useProxy: Bool, host: String, port: Int) {
        UserDefaults.standard.set(useProxy, forKey: Keys.enabled)
        UserDefaults.standard.set(host,     forKey: Keys.host)
        UserDefaults.standard.set(port,     forKey: Keys.port)
        self.useProxy = useProxy
        self.host     = host
        self.port     = port
        NetworkSession.shared.rebuild()
    }
}
