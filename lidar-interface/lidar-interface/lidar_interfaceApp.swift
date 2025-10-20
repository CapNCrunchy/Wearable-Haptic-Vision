//
//  lidar_interfaceApp.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/19/25.
//

import SwiftUI

@main
struct lidar_interfaceApp: App {
    @State private var bluetoothManager = BluetoothManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(bluetoothManager)
        }
    }
}
