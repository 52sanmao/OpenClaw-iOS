import SwiftUI

@main
struct OpenClawApp: App {
    @StateObject private var gateway = GatewayClient.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gateway)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
