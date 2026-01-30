//
//  Device.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import Foundation

enum DeviceConnection {
    case connected
    case connecting
    case disconnected
    case disconnecting
}

protocol Device {
    var id: String { get }
    var name: String { get }
    var connection: DeviceConnection { get }
    
    func setConnection(_ connection: DeviceConnection)
    func sendData(_ data: Data)
}
