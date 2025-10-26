//
//  BLETransmitterView.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/26/25.
//

import SwiftUI

struct BLETransmitterView: View {
    @Environment(BluetoothManager.self) var bluetoothManager
    @State private var timer: Timer?
    @State private var currentValue: Float = 0.0
    
    var body: some View {
        Text("Currently Sending: \(currentValue)")
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    currentValue = Float.random(in: 0...1)
                    let data = withUnsafeBytes(of: &currentValue) { Data($0) }
                    bluetoothManager.sendData(data)
                }
            }
            .onDisappear {
                timer?.invalidate()
                currentValue = 0.0
            }
    }  
}
