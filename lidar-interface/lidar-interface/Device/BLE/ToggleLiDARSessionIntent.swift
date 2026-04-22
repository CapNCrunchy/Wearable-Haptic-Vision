//
//  ToggleLiDARSessionIntent.swift
//  lidar-interface
//
//  Created by Colin McClure on 4/15/26.
//

import AppIntents

struct ToggleLiDARSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle LiDAR Session"
    
    static var description = IntentDescription("Starts or stops the LiDAR depth collection session. If stopped, connects to the paired device and starts collection. If running, stops collection.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        await SessionManager.shared.toggleSession()
        return .result()
    }
}

struct LiDARAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleLiDARSessionIntent(),
            phrases: [
                "Toggle \(.applicationName) session",
                "Start \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Toggle Session",
            systemImageName: "sensor.fill"
        )
    }
}
