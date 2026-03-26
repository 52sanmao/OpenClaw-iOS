import Foundation
import Combine

/// Core WebSocket client for the OpenClaw Gateway protocol.
@MainActor
final class GatewayClient: ObservableObject {
    static let shared = GatewayClient()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    // MARK: - Published State
    @Published var connectionState: ConnectionState = .disconnected
    @Published var serverVersion: String = ""
    @Published var serverHost: String = ""
    @Published var uptimeMs: Int = 0

    // MARK: - Private
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingRequests: [String: CheckedContinuation<ResponseFrame, Error>] = [:]
    private var eventHandlers: [String: [(AnyCodable?) -> Void]] = [:]
    private var tickTimer: Timer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var config: ConnectionConfig? {
        ConnectionStore.load()
    }

    private init() {}

    // MARK: - Connect

    func connect(config: ConnectionConfig? = nil) async throws {
        let cfg = config ?? self.config
        guard let cfg else {
            throw GatewayError.noConfig
        }

        connectionState = .connecting

        // Save config for reconnection
        ConnectionStore.save(cfg)

        let url = cfg.websocketURL
        let session = URLSession(configuration: .default)
        self.urlSession = session

        let ws = session.webSocketTask(with: url)
        self.webSocket = ws
        ws.resume()

        // Start receiving
        startReceiving()

        // Send connect handshake
        let connectParams: [String: Any] = [
            "minProtocol": GatewayProtocolVersion.current,
            "maxProtocol": GatewayProtocolVersion.current,
            "client": [
                "id": "openclaw-ios",
                "version": "0.1.0",
                "platform": "ios",
                "mode": "ui"
            ] as [String: Any],
            "role": "operator",
            "scopes": ["operator.read", "operator.write"],
            "auth": ["token": cfg.token] as [String: Any],
            "locale": Locale.current.identifier,
            "userAgent": "openclaw-ios/0.1.0"
        ]

        let response = try await sendRequest(method: "connect", params: connectParams)

        guard response.ok else {
            let msg = response.error?.message ?? "Connection rejected"
            connectionState = .error(msg)
            throw GatewayError.connectionRejected(msg)
        }

        // Parse hello-ok
        if let payloadData = try? JSONSerialization.data(withJSONObject: (response.payload?.value as? [String: Any]) ?? [:]),
           let hello = try? decoder.decode(HelloOkPayload.self, from: payloadData) {
            serverVersion = hello.server?.version ?? ""
            serverHost = hello.server?.host ?? ""
            if let tickMs = hello.policy?.tickIntervalMs {
                startTickTimer(intervalMs: tickMs)
            }
        }

        connectionState = .connected
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        tickTimer?.invalidate()
        tickTimer = nil
        pendingRequests.removeAll()
        connectionState = .disconnected
    }

    // MARK: - Send Request

    @discardableResult
    func sendRequest(method: String, params: [String: Any]? = nil) async throws -> ResponseFrame {
        let frame = RequestFrame(method: method, params: params)
        let data = try encoder.encode(frame)

        guard let ws = webSocket else {
            throw GatewayError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[frame.id] = continuation
            ws.send(.data(data)) { [weak self] error in
                if let error {
                    Task { @MainActor in
                        self?.pendingRequests.removeValue(forKey: frame.id)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fire-and-forget send (for ticks, etc.)
    func sendFrame(_ frame: RequestFrame) {
        guard let data = try? encoder.encode(frame),
              let ws = webSocket else { return }
        ws.send(.data(data)) { _ in }
    }

    // MARK: - Event Subscription

    func onEvent(_ eventName: String, handler: @escaping (AnyCodable?) -> Void) {
        eventHandlers[eventName, default: []].append(handler)
    }

    // MARK: - Private

    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.startReceiving() // Continue receiving
                case .failure(let error):
                    self?.connectionState = .error(error.localizedDescription)
                    self?.attemptReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: return
        }

        guard let frame = try? decoder.decode(GatewayFrame.self, from: data) else { return }

        switch frame.type {
        case "res":
            if let id = frame.id, let continuation = pendingRequests.removeValue(forKey: id) {
                let response = ResponseFrame(
                    type: "res",
                    id: id,
                    ok: frame.ok ?? false,
                    payload: frame.payload,
                    error: frame.error
                )
                continuation.resume(returning: response)
            }

        case "event":
            if let eventName = frame.event {
                eventHandlers[eventName]?.forEach { $0(frame.payload) }
            }

        default:
            break
        }
    }

    private func startTickTimer(intervalMs: Int) {
        tickTimer?.invalidate()
        let interval = TimeInterval(intervalMs) / 1000.0
        tickTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendTick()
            }
        }
    }

    private func sendTick() {
        let frame = RequestFrame(method: "tick", params: ["ts": Int(Date().timeIntervalSince1970 * 1000)])
        sendFrame(frame)
    }

    private func attemptReconnect() {
        guard let config else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            try? await connect(config: config)
        }
    }
}

// MARK: - Errors

enum GatewayError: LocalizedError {
    case noConfig
    case notConnected
    case connectionRejected(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noConfig: "No gateway configuration found"
        case .notConnected: "Not connected to gateway"
        case .connectionRejected(let msg): "Connection rejected: \(msg)"
        case .timeout: "Request timed out"
        case .invalidResponse: "Invalid response from gateway"
        }
    }
}
