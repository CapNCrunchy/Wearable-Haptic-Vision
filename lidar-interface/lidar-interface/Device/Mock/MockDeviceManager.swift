//
//  MockDeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import Observation

@Observable
class MockDeviceManager: DeviceManager {
    var discoveredDevices: [Device]
    var connectedDevice: Device?
    var scanning: Bool
    
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
}
