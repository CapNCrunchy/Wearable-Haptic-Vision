//
//  ContentView.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/19/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(BluetoothManager.self) var bluetoothManager
    
    var body: some View {
        if !bluetoothManager.connecting && bluetoothManager.connectedDevice != nil {
            NavigationStack {
                DepthMapView()
                
                .navigationTitle("Depth Map View")
            }
        } else {
            NavigationStack {
                PeripheralDeviceListView()
                
                .navigationTitle("Connect Accessory")
                .navigationSubtitle("Select the wearable haptic feedback device you want connect to.")
            }
        }
    }
}

// TODO: figure out how to mock the manager better to test independent of physical hardware
#Preview {
    let mockManager = BluetoothManager()
    
    ContentView()
        .environment(mockManager)
}
