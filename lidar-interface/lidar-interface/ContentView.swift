//
//  ContentView.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/19/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            PeripheralDeviceListView()
            
            .navigationTitle("Connect Accessory")
            .navigationSubtitle("Select the wearable haptic feedback device you want connect to.")
        }
    }
}

// TODO: figure out how to mock the manager better to test independent of physical hardware
#Preview {
    let mockManager = BluetoothManager()
    
    ContentView()
        .environment(mockManager)
}
