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
    @State private var selectedDeviceId: String?
    
    var body: some View {
        List(selection: $selectedDeviceId) {
            Section {
                if bluetoothManager.state == .poweredOn {
                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { peripheral in
                        Text(peripheral.name ?? "Unknown device")
                            .tag(peripheral.identifier)
                        
                        Spacer()
                        if bluetoothManager.connecting {
                            ProgressView()
                        } else if bluetoothManager.connectedDevice != nil {
                            Image(systemName: "checkmark")
                        }
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
        .onChange(of: bluetoothManager.connectedDevice) {oldState, newState in
            // device successfully connected
            if oldState == nil && newState != nil {
                
            }
        }
    }
}
