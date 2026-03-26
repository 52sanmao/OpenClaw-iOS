import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var sessions: [SessionInfo] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading sessions...")
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "list.bullet.rectangle.portrait",
                        description: Text("Active sessions will appear here.")
                    )
                } else {
                    List(sessions) { session in
                        SessionRow(session: session)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadSessions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await loadSessions() }
        }
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await gateway.sendRequest(
                method: "sessions.list",
                params: [
                    "limit": 50,
                    "includeDerivedTitles": true,
                    "includeLastMessage": true
                ]
            )

            guard response.ok,
                  let payload = response.payload?.dict,
                  let sessionsArray = payload["sessions"] as? [[String: Any]] else { return }

            sessions = sessionsArray.compactMap { dict in
                guard let key = dict["key"] as? String else { return nil }
                return SessionInfo(
                    key: key,
                    agentId: dict["agentId"] as? String,
                    label: dict["label"] as? String,
                    lastActive: nil,
                    derivedTitle: dict["derivedTitle"] as? String,
                    lastMessage: dict["lastMessage"] as? String,
                    kind: dict["kind"] as? String
                )
            }
        } catch {
            // Silently fail, user can retry
        }
    }
}

struct SessionRow: View {
    let session: SessionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let kind = session.kind {
                    Text(kind)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            if let lastMessage = session.lastMessage {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let agentId = session.agentId {
                Text("Agent: \(agentId)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
