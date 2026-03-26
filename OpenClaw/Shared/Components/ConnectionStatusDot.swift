import SwiftUI

struct ConnectionStatusDot: View {
    let state: GatewayClient.ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var dotColor: Color {
        switch state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .gray
        case .error: .red
        }
    }

    private var label: String {
        switch state {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Offline"
        case .error: "Error"
        }
    }
}
