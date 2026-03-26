import SwiftUI

struct RootView: View {
    @EnvironmentObject var gateway: GatewayClient
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if gateway.connectionState == .connected {
                MainTabView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gateway.connectionState)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                tab.view
                    .tabItem {
                        Label(tab.label, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(.orange)
    }
}

private extension AppState.Tab {
    @ViewBuilder
    var view: some View {
        switch self {
        case .chat: ChatView()
        case .sessions: SessionsView()
        case .cron: CronView()
        case .nodes: NodesView()
        case .settings: SettingsView()
        }
    }
}
