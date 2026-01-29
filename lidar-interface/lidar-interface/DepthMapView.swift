//
//  DepthMapView.swift
//  lidar-interface
//
//  Created by Colin McClure on 11/14/25.
//

import SwiftUI

struct HeatMapGridView: View {
    let proximityGrid: [[Float]]
    let gridRows: Int
    let gridCols: Int
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = (geometry.size.width - CGFloat(gridCols - 1) * 2) / CGFloat(gridCols)
            let cellHeight = (geometry.size.height - CGFloat(gridRows - 1) * 2) / CGFloat(gridRows)
            
            VStack(spacing: 2) {
                ForEach(0..<gridRows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<gridCols, id: \.self) { col in
                            Rectangle()
                                .fill(heatMapColor(for: proximityGrid[row][col]))
                                .frame(width: cellWidth, height: cellHeight)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    func heatMapColor(for proximity: Float) -> Color {
        if proximity == 0.0 {
            return Color.black.opacity(0.2)
        }
        
        if proximity < 0.33 {
            let t = Double(proximity / 0.33)
            return Color(red: 0, green: t * 0.5, blue: 1.0)
        } else if proximity < 0.66 {
            let t = Double((proximity - 0.33) / 0.33)
            return Color(red: t, green: 0.5 + t * 0.5, blue: 1.0 - t)
        } else {
            let t = Double((proximity - 0.66) / 0.34)
            return Color(red: 1.0, green: 1.0 - t, blue: 0)
        }
    }
}

struct DepthMapView: View {
    @StateObject private var depthCaptureService = DepthCaptureService()
    @State private var sendData = false
    
    @Environment(BluetoothManager.self) var bluetoothManager
    
    var body: some View {
        VStack(spacing: 20) {
            if let grid = depthCaptureService.depthMap {
                HeatMapGridView(
                    proximityGrid: grid,
                    gridRows: 2,
                    gridCols: 3
                )
                .frame(height: 400)
                .padding()
            } else {
                Text("Waiting for LiDAR data...")
                    .foregroundColor(.gray)
                    .frame(height: 400)
            }
            
            Button(sendData ? "Sending" : "Send") {
                sendData.toggle()
            }
            .padding()
            .background(sendData ? Color.blue : Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        .onAppear {
            depthCaptureService.start()
        }
        .onChange(of: depthCaptureService.depthMap) { _, newValue in
            let shouldSend = sendData
            
            Task.detached(priority: .utility) {
                if (shouldSend) {
                    await serializeAndSend()
                    
                    await MainActor.run {
                        sendData = false
                    }
                }
            }
        }
    }
    
    func serializeAndSend() async {
        guard let depthMap = depthCaptureService.depthMap else { return }
        
        do {
            let jsonData = try JSONEncoder().encode(depthMap)
            bluetoothManager.sendData(jsonData)
        } catch {
            return
        }
    }
}
