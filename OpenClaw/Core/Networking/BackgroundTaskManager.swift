import Foundation
import BackgroundTasks
import UIKit

/// Manages background app refresh to maintain gateway connection
/// and deliver notifications when the app is backgrounded.
@MainActor
enum BackgroundTaskManager {
    nonisolated static let refreshTaskId = "ai.openclaw.mobile.refresh"

    nonisolated static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskId,
            using: .main
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            refreshTask.expirationHandler = {
                refreshTask.setTaskCompleted(success: false)
            }
            nonisolated(unsafe) let t = refreshTask
            Task { @MainActor in
                let gateway = GatewayClient.shared
                scheduleRefresh()

                if gateway.connectionState != .connected {
                    if let config = ConnectionStore.load() {
                        try? await gateway.connect(config: config)
                    }
                }

                if gateway.connectionState == .connected {
                    _ = try? await gateway.sendRequest(method: "ping")
                }

                t.setTaskCompleted(success: true)
            }
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
