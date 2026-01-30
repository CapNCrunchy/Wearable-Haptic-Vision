//
//  MockDevice.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import Foundation
import Observation

@Observable
class MockDevice: Device {
    var id: String
    var name: String
    var connection: DeviceConnection
    
    init(id: String = "mock-device-id",
         name: String = "Mock Device",
         connection: DeviceConnection = .disconnected) {
        self.id = id
        self.name = name
        self.connection = connection
    }
    
    func setConnection(_ connection: DeviceConnection) {
        self.connection = connection
    }
    
    func sendData(_ data: Data) {
        // No-op for preview
    }
}
