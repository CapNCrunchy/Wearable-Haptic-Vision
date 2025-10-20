//
//  PeripheralDeviceListView.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/20/25.
//

import SwiftUI
import CoreBluetooth

// TODO: figure out how to break this down into multiple components to better preview each
struct PeripheralDeviceListView: View {
    @Environment(BluetoothManager.self) var bluetoothManager
    
    var body: some View {
        List {
            Section {
                if bluetoothManager.state == .poweredOn {
                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { peripheral in
                        Text(peripheral.name ?? "Unknown device")
                    }
                } else if bluetoothManager.state != .resetting {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 40))
                        
                        Text("Bluetooth Not Available")
                            .font(.callout)
                            .bold(true)
                        
                        Text("Please turn Bluetooth on or enable it in privacy settings.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                HStack {
                    Text("Devices")
                    if bluetoothManager.scanning {
                        ProgressView()
                    }
                }
            }
        }
        .onChange(of: bluetoothManager.state) { _, newState in
            if newState == .poweredOn && !bluetoothManager.scanning {
                bluetoothManager.startScanning()
            }
        }
    }
}
