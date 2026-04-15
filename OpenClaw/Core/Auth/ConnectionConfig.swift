import Foundation

struct ConnectionConfig: Codable, Equatable {
    var host: String       // host or full gateway/control URL
    var port: Int           // fallback port for host-only input
    var useTLS: Bool        // legacy hint for host-only input
    var token: String       // gateway auth token

    static func normalizeGatewayEndpoint(_ rawValue: String, fallbackPort: Int, useTLS: Bool) -> (host: String, port: Int) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (rawValue, fallbackPort)
        }

        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme?.lowercased() {
            if scheme == "ws" || scheme == "wss" {
                return (trimmed, components.port ?? fallbackPort)
            }

            if scheme == "http" || scheme == "https" {
                var normalized = components
                normalized.scheme = (scheme == "https") ? "wss" : "ws"
                let resolvedPort = components.port ?? ((scheme == "https") ? 443 : 80)
                if normalized.path.isEmpty {
                    normalized.path = "/"
                }
                if let urlString = normalized.string {
                    return (urlString, resolvedPort)
                }
            }
        }

        return (trimmed, fallbackPort)
    }

    var websocketURL: URL {
        let normalized = Self.normalizeGatewayEndpoint(host, fallbackPort: port, useTLS: useTLS)
        if normalized.host.hasPrefix("ws://") || normalized.host.hasPrefix("wss://") {
            return URL(string: normalized.host)!
        }
        let scheme = useTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(normalized.host):\(normalized.port)")!
    }

    var httpBaseURL: URL {
        let wsURL = websocketURL
        var components = URLComponents(url: wsURL, resolvingAgainstBaseURL: false)!
        components.scheme = wsURL.scheme == "wss" ? "https" : "http"
        return components.url!
    }

    var displayName: String {
        let normalized = Self.normalizeGatewayEndpoint(host, fallbackPort: port, useTLS: useTLS)
        if normalized.host.hasPrefix("ws://") || normalized.host.hasPrefix("wss://") {
            return normalized.host
        }
        return "\(normalized.host):\(normalized.port)"
    }
}

// MARK: - Keychain Storage

enum ConnectionStore {
    private static let key = "ai.openclaw.mobile.connection"

    static func save(_ config: ConnectionConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> ConnectionConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ConnectionConfig.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
