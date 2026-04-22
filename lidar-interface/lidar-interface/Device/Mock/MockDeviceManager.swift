//
//  MockDeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import Combine

class MockDeviceManager: DeviceManager, ObservableObject {
    @Published var discoveredDevices: [Device]
    @Published var connectedDevice: Device?
    @Published var scanning: Bool
    
    init(discoveredDevices: [Device] = [],
         connectedDevice: Device? = nil,
         scanning: Bool = false) {
        self.discoveredDevices = discoveredDevices
        self.connectedDevice = connectedDevice
        self.scanning = scanning
    }
    
    func discoverDevices() {
        scanning = true
    }
    
    func stopScanning() {
        scanning = false
    }
    
    func connectDevice(_ device: Device) {
        connectedDevice = device
        device.setConnection(.connected)
    }
    
    func disconnectDevice() {
        if connectedDevice?.connection != .connected { return }
        connectedDevice!.setConnection(.disconnected)
    }
    
    func disconnectAndRemoveDevice() {
        disconnectDevice()
        connectedDevice = nil
    }
    
    func reconnectToPairedDevice() {
        // No-op for mock - could simulate reconnection if needed for testing
    }
}
