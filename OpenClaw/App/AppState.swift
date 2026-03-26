import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: String, CaseIterable {
        case chat, sessions, cron, nodes, settings

        var label: String {
            switch self {
            case .chat: "Chat"
            case .sessions: "Sessions"
            case .cron: "Cron"
            case .nodes: "Nodes"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .chat: "bubble.left.and.bubble.right.fill"
            case .sessions: "list.bullet.rectangle.portrait.fill"
            case .cron: "clock.fill"
            case .nodes: "antenna.radiowaves.left.and.right"
            case .settings: "gearshape.fill"
            }
        }
    }

    @Published var selectedTab: Tab = .chat
    @Published var isConnecting = false
}
