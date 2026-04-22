//
//  SessionManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 4/15/26.
//

import Foundation
import Combine

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isActive: Bool = false
    
    private var cancellable: AnyCancellable?
    private var connectionObserver: AnyCancellable?
    private weak var deviceManager: BLEDeviceManager?
    private weak var collectionService: (any CollectionService)?
    
    // Auto-reconnect configuration
    private let maxReconnectAttempts = 2
    private var reconnectAttempts = 0
    
    private init() {}
    
    func configure(deviceManager: BLEDeviceManager, collectionService: any CollectionService) {
        self.deviceManager = deviceManager
        self.collectionService = collectionService
        
        setupConnectionObserver()
    }
    
    private func setupConnectionObserver() {
        guard let deviceManager = deviceManager else { return }
        
        connectionObserver = deviceManager.$connectedDevice
            .compactMap { $0 as? BLEDevice }
            .flatMap { device in
                // Observe the connection state of the BLE device
                device.$connection
            }
            .sink { [weak self] connectionState in
                Task { @MainActor in
                    await self?.handleConnectionChange(connectionState: connectionState)
                }
            }
    }
    
    private func handleConnectionChange(connectionState: DeviceConnection) async {
        guard isActive,
              let deviceManager = deviceManager,
              let collectionService = collectionService,
              let device = deviceManager.connectedDevice else {
            return
        }
        
        if connectionState == .disconnected {
            guard reconnectAttempts < maxReconnectAttempts else {
                TTSService.shared.speak("Connection lost. Session stopped.", rate: 0.55, interrupting: true)
                stopSession()
                reconnectAttempts = 0
                return
            }
            
            reconnectAttempts += 1
            TTSService.shared.speak("Connection lost. Reconnecting, attempt \(reconnectAttempts)", rate: 0.55, interrupting: true)
            
            if collectionService.collecting {
                collectionService.stop()
                collectionService.collecting = false
            }
            
            deviceManager.connectDevice(device)
            
            var attempts = 0
            while device.connection != .connected && attempts < 30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            if device.connection == .connected {
                reconnectAttempts = 0
                
                collectionService.start()
                collectionService.collecting = true
                
                TTSService.shared.speak("Reconnected successfully. Session resumed.", rate: 0.55, interrupting: true)
            } else {
                TTSService.shared.speak("Reconnection failed", rate: 0.55, interrupting: true)
            }
        }
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
        
        reconnectAttempts = 0
        
        if deviceManager.connectedDevice?.connection != .connected {
            if let pairedDevice = deviceManager.connectedDevice {
                deviceManager.connectDevice(pairedDevice)
                
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
        
        collectionService.start()
        collectionService.collecting = true
        isActive = true
        
        TTSService.shared.announceSessionStarted()
        
        cancellable = collectionService.depthMapPublisher
            .compactMap { $0 } // Filter out nil values
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] depthMap in
                self?.sendDepthData(depthMap)
            }
    }
    
    func stopSession() {
        guard let collectionService = collectionService else {
            return
        }
        
        collectionService.stop()
        collectionService.collecting = false
        isActive = false
        
        reconnectAttempts = 0
        
        cancellable?.cancel()
        cancellable = nil
        
        TTSService.shared.announceSessionStopped()
    }
    
    private func sendDepthData(_ depthMap: [[Float]]) {
        guard let device = deviceManager?.connectedDevice else {
            return
        }
        
        let flattenedData = depthMap.flatMap { $0 }
        
        var data = Data()
        for value in flattenedData {
            var floatValue = value
            data.append(Data(bytes: &floatValue, count: MemoryLayout<Float>.size))
        }
        
        device.sendData(data)
    }
}
