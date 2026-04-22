//
//  ToggleLiDARSessionIntent.swift
//  lidar-interface
//
//  Created by Colin McClure on 4/15/26.
//

import AppIntents
import SwiftUI

/// App Intent that toggles the LiDAR collection session
/// Can be assigned to the Action Button in iOS Settings
struct ToggleLiDARSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle LiDAR Session"
    
    static var description = IntentDescription("Starts or stops the LiDAR depth collection session.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Get the app's main state
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootView = window.rootViewController?.view else {
            throw IntentError.message("Could not access app state")
        }
        
        // Access the app state through the environment
        // We'll use a shared manager to coordinate this
        await LiDARSessionCoordinator.shared.toggleSession()
        
        return .result()
    }
}

/// Singleton coordinator for managing LiDAR session state across the app and intents
@MainActor
class LiDARSessionCoordinator: ObservableObject {
    static let shared = LiDARSessionCoordinator()
    
    @Published var isSessionActive: Bool = false
    
    // References to the managers (set by AppView)
    weak var deviceManager: BLEDeviceManager?
    weak var collectionService: LiDARCollectionService?
    
    private init() {}
    
    /// Toggle the LiDAR session - connects device if needed, then toggles collection
    func toggleSession() async {
        guard let deviceManager = deviceManager,
              let collectionService = collectionService else {
            TTSService.shared.speak("App not initialized", rate: 0.55, interrupting: true)
            return
        }
        
        if collectionService.collecting {
            // Stop the session
            collectionService.stop()
            collectionService.collecting = false
            isSessionActive = false
            TTSService.shared.announceSessionStopped()
        } else {
            // Start the session
            // First ensure device is connected
            if deviceManager.connectedDevice?.connection != .connected {
                // Try to reconnect to paired device
                if let pairedDevice = deviceManager.connectedDevice {
                    deviceManager.connectDevice(pairedDevice)
                    
                    // Wait for connection (with timeout)
                    var attempts = 0
                    while deviceManager.connectedDevice?.connection != .connected && attempts < 30 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        attempts += 1
                    }
                    
                    if deviceManager.connectedDevice?.connection != .connected {
                        TTSService.shared.speak("Failed to connect to device", rate: 0.55, interrupting: true)
                        return
                    }
                } else {
                    TTSService.shared.speak("No device paired", rate: 0.55, interrupting: true)
                    return
                }
            }
            
            // Now start collection
            collectionService.start()
            collectionService.collecting = true
            isSessionActive = true
            TTSService.shared.announceSessionStarted()
        }
    }
}

/// App Shortcuts Provider - makes the intent discoverable
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
