//
//  SessionView.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/19/26.
//  UI elements generated with assistance by Claude

import SwiftUI
import Combine
import AVFoundation

// MARK: - Session Control View
struct SessionView<Service: CollectionService, Manager: DeviceManager>: View {
    @ObservedObject var deviceManager: Manager
    @ObservedObject var collectionService: Service
    
    var body: some View {
        Button(action: {
            Task {
                await SessionManager.shared.toggleSession()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: collectionService.collecting ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 20))
                Text(collectionService.collecting ? "Stop Session" : "Start Session")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        collectionService.collecting
                            ? Color.red.opacity(0.6)
                            : Color.green.opacity(0.6)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(deviceManager.connectedDevice == nil || deviceManager.connectedDevice?.connection != .connected)
        .opacity(deviceManager.connectedDevice == nil || deviceManager.connectedDevice?.connection != .connected ? 0.5 : 1.0)
    }
}

// MARK: - Preview
#Preview("Session Control") {
    ZStack {
        // Background gradient for glass effect visibility
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.4),
                Color(red: 0.2, green: 0.1, blue: 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Not collecting state with MockCollectionService
            SessionView(
                deviceManager: MockDeviceManager(
                    connectedDevice: MockDevice(id: "device-1", name: "Test Device", connection: .connected)
                ),
                collectionService: MockCollectionService.staticMock(depthMap: nil)
            )
            
            // Collecting state with animated mock
            SessionView(
                deviceManager: MockDeviceManager(
                    connectedDevice: MockDevice(id: "device-1", name: "Test Device", connection: .connected)
                ),
                collectionService: MockCollectionService.animatedMock()
            )
            
            // No device connected (disabled state)
            SessionView(
                deviceManager: MockDeviceManager(connectedDevice: nil),
                collectionService: MockCollectionService.staticMock(depthMap: nil)
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}
