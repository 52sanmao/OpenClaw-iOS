import Foundation

// MARK: - Protocol Version
enum GatewayProtocolVersion {
    static let current = 3
}

// MARK: - Frame Types
enum FrameType: String, Codable {
    case req, res, event
}

// MARK: - Request Frame
struct RequestFrame: Codable {
    let type: String
    let id: String
    let method: String
    let params: AnyCodable?

    init(method: String, params: [String: Any]? = nil) {
        self.type = "req"
        self.id = UUID().uuidString
        self.method = method
        self.params = params.map { AnyCodable($0) }
    }
}

// MARK: - Response Frame
struct ResponseFrame: Codable {
    let type: String
    let id: String
    let ok: Bool
    let payload: AnyCodable?
    let error: ErrorShape?
}

struct ErrorShape: Codable {
    let code: String
    let message: String
    let retryable: Bool?
}

// MARK: - Event Frame
struct EventFrame: Codable {
    let type: String
    let event: String
    let payload: AnyCodable?
    let seq: Int?
}

// MARK: - Generic Gateway Frame (for initial parsing)
struct GatewayFrame: Codable {
    let type: String
    let id: String?
    let method: String?
    let ok: Bool?
    let payload: AnyCodable?
    let error: ErrorShape?
    let event: String?
    let seq: Int?
}

// MARK: - Connect Params
struct ConnectParams: Codable {
    let minProtocol: Int
    let maxProtocol: Int
    let client: ClientInfo
    let role: String
    let scopes: [String]
    let auth: AuthParams?
    let locale: String
    let userAgent: String

    struct ClientInfo: Codable {
        let id: String
        let version: String
        let platform: String
        let mode: String
    }

    struct AuthParams: Codable {
        let token: String?
    }
}

// MARK: - Hello OK
struct HelloOkPayload: Codable {
    let type: String
    let `protocol`: Int
    let server: ServerInfo?
    let policy: PolicyInfo?
    let auth: AuthResult?

    struct ServerInfo: Codable {
        let version: String
        let host: String?
        let connId: String?
    }

    struct PolicyInfo: Codable {
        let tickIntervalMs: Int?
        let maxPayload: Int?
    }

    struct AuthResult: Codable {
        let deviceToken: String?
        let role: String?
        let scopes: [String]?
    }
}

// MARK: - Agent Event
struct AgentEvent: Codable {
    let runId: String
    let seq: Int
    let stream: String
    let ts: Int
    let data: [String: AnyCodable]
}
