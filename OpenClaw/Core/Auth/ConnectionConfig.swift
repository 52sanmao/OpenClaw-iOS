import Foundation

struct ConnectionConfig: Codable, Equatable {
    var host: String       // e.g. "192.168.1.10" or "mybox.tailnet.ts.net"
    var port: Int           // e.g. 18789
    var useTLS: Bool        // wss:// vs ws://
    var token: String       // gateway auth token

    var websocketURL: URL {
        let scheme = useTLS ? "wss" : "ws"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }

    var httpBaseURL: URL {
        let scheme = useTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }

    var displayName: String {
        "\(host):\(port)"
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
