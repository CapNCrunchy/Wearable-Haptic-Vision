//
//  DeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

protocol DeviceManager {
    var discoveredDevices: [Device] { get }
    var connectedDevice: Device? { get set }
    var scanning: Bool { get }
    
    func discoverDevices()
    func connectDevice(_ device: Device)
    func disconnectDevice()
    func disconnectAndRemoveDevice()
}
