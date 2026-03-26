import Foundation
import Combine

/// Manages agent chat interactions over the gateway protocol.
@MainActor
final class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isAgentTyping = false
    @Published var currentStreamText = ""

    private let gateway: GatewayClient
    private var currentRunId: String?

    init(gateway: GatewayClient) {
        self.gateway = gateway
        setupEventHandlers()
    }

    // MARK: - Send Message

    func send(_ text: String, sessionKey: String? = nil) async throws {
        // Add user message
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)

        isAgentTyping = true
        currentStreamText = ""

        var params: [String: Any] = [
            "message": text,
            "idempotencyKey": UUID().uuidString
        ]
        if let key = sessionKey {
            params["sessionKey"] = key
        }

        let response = try await gateway.sendRequest(method: "agent", params: params)

        if !response.ok {
            isAgentTyping = false
            let errorMsg = response.error?.message ?? "Unknown error"
            messages.append(ChatMessage(role: .system, content: "Error: \(errorMsg)"))
            return
        }

        // RunId for streaming
        if let payload = response.payload?.dict,
           let runId = payload["runId"] as? String {
            currentRunId = runId
        }
    }

    // MARK: - Event Handlers

    private func setupEventHandlers() {
        gateway.onEvent("agent.stream") { [weak self] payload in
            Task { @MainActor in
                self?.handleAgentStream(payload)
            }
        }

        gateway.onEvent("agent.done") { [weak self] payload in
            Task { @MainActor in
                self?.handleAgentDone(payload)
            }
        }
    }

    private func handleAgentStream(_ payload: AnyCodable?) {
        guard let dict = payload?.dict,
              let stream = dict["stream"] as? String else { return }

        if stream == "text" || stream == "content" {
            if let text = dict["text"] as? String ?? (dict["data"] as? [String: Any])?["text"] as? String {
                currentStreamText += text
            }
        }
    }

    private func handleAgentDone(_ payload: AnyCodable?) {
        isAgentTyping = false

        if !currentStreamText.isEmpty {
            messages.append(ChatMessage(role: .assistant, content: currentStreamText))
            currentStreamText = ""
        } else if let dict = payload?.dict,
                  let text = dict["text"] as? String ?? dict["message"] as? String {
            messages.append(ChatMessage(role: .assistant, content: text))
        }

        currentRunId = nil
    }
}
