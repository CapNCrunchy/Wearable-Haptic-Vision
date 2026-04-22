//
//  DeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import Combine

protocol DeviceManager: AnyObject, ObservableObject {
    var discoveredDevices: [Device] { get set }
    var connectedDevice: Device? { get set }
    var scanning: Bool { get set }
    
    func discoverDevices()
    func stopScanning()
    func connectDevice(_ device: Device)
    func disconnectDevice()
    func disconnectAndRemoveDevice()
    func reconnectToPairedDevice()
}
