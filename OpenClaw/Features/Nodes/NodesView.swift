import SwiftUI

struct NodesView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading nodes...")
                } else if nodes.isEmpty {
                    ContentUnavailableView(
                        "No Nodes",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Paired devices will appear here.")
                    )
                } else {
                    List(nodes) { node in
                        NodeRow(node: node)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Nodes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadNodes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await loadNodes() }
        }
    }

    private func loadNodes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await gateway.sendRequest(method: "system-presence")

            guard response.ok,
                  let payload = response.payload?.dict,
                  let entries = payload["entries"] as? [[String: Any]] else { return }

            nodes = entries.compactMap { dict in
                guard let deviceId = dict["deviceId"] as? String else { return nil }
                return NodeInfo(
                    deviceId: deviceId,
                    host: dict["host"] as? String,
                    platform: dict["platform"] as? String,
                    version: dict["version"] as? String,
                    caps: dict["caps"] as? [String],
                    lastSeen: nil
                )
            }
        } catch {}
    }
}

struct NodeRow: View {
    let node: NodeInfo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: node.platformIcon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(node.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let platform = node.platform {
                        Text(platform)
                    }
                    if let version = node.version {
                        Text("v\(version)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let caps = node.caps, !caps.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(caps.prefix(4), id: \.self) { cap in
                            Text(cap)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
