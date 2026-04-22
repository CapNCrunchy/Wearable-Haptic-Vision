//
//  SessionManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 4/15/26.
//

import Foundation
import Combine

/// Manages the LiDAR collection session lifecycle
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isActive: Bool = false
    
    private var cancellable: AnyCancellable?
    private weak var deviceManager: (any DeviceManager)?
    private weak var collectionService: (any CollectionService)?
    
    private init() {}
    
    /// Register the managers with the session manager
    func configure(deviceManager: any DeviceManager, collectionService: any CollectionService) {
        self.deviceManager = deviceManager
        self.collectionService = collectionService
    }
    
    /// Toggle the session - connects device if needed, then toggles collection
    func toggleSession() async {
        guard let deviceManager = deviceManager,
              let collectionService = collectionService else {
            TTSService.shared.speak("Session manager not configured", rate: 0.55, interrupting: true)
            return
        }
        
        if collectionService.collecting {
            // Stop the session
            stopSession()
        } else {
            // Start the session
            await startSession()
        }
    }
    
    /// Start the session (connects device if needed, then starts collection)
    func startSession() async {
        guard let deviceManager = deviceManager,
              let collectionService = collectionService else {
            return
        }
        
        // Check if device is connected
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
        
        // Start collection
        collectionService.start()
        collectionService.collecting = true
        isActive = true
        
        // TTS feedback
        TTSService.shared.announceSessionStarted()
        
        // Subscribe to depth map updates
        cancellable = collectionService.depthMapPublisher
            .compactMap { $0 } // Filter out nil values
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] depthMap in
                self?.sendDepthData(depthMap)
            }
    }
    
    /// Stop the session
    func stopSession() {
        guard let collectionService = collectionService else {
            return
        }
        
        // Stop collection
        collectionService.stop()
        collectionService.collecting = false
        isActive = false
        
        // Cancel data subscription
        cancellable?.cancel()
        cancellable = nil
        
        // TTS feedback
        TTSService.shared.announceSessionStopped()
    }
    
    /// Send depth data to the connected device
    private func sendDepthData(_ depthMap: [[Float]]) {
        guard let device = deviceManager?.connectedDevice else {
            return
        }
        
        // Flatten the 2D array and convert to binary
        let flattenedData = depthMap.flatMap { $0 }
        
        var data = Data()
        for value in flattenedData {
            var floatValue = value
            data.append(Data(bytes: &floatValue, count: MemoryLayout<Float>.size))
        }
        
        device.sendData(data)
    }
}
