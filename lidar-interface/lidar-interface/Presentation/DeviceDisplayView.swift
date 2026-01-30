//
//  DeviceDisplayView.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/29/26.
//  UI/UX components developed with assistance of Claude AI.
//  (https://claude.ai/share/afe1cbc2-9d92-42ca-9378-1021bd101e8f)
//

import SwiftUI

// MARK: - Main Container View
struct DeviceDisplayView: View {
    var deviceManager: DeviceManager
    @State private var showingDeviceList = false
    
    var body: some View {
        if let device = deviceManager.connectedDevice {
            DevicePill(
                deviceName: device.name,
                isConnected: device.connection == .connected,
                onConnectionToggle: {
                    device.connection == .connected ? deviceManager.disconnectDevice() : deviceManager.connectDevice(device)
                },
                onRemove: {
                    deviceManager.disconnectAndRemoveDevice()
                }
            )
        } else {
            NoDevicePill(
                onAddDevice: {
                    showingDeviceList = true
                }
            )
            .sheet(isPresented: $showingDeviceList) {
                AvailableDevicesSheet(
                    availableDevices: deviceManager.discoveredDevices,
                    isScanning: deviceManager.scanning,
                    onSelectDevice: { selectedDevice in
                        deviceManager.connectDevice(selectedDevice)
                        showingDeviceList = false
                    }
                )
            }
        }
    }
}

// MARK: - Available Devices Sheet
struct AvailableDevicesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var availableDevices: [Device] = []
    var isScanning = false
    
    var onSelectDevice: (Device) -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Available Devices")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)
                
                // Scanning indicator
                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Scanning for devices...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                
                // Device list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableDevices, id: \.id) { device in
                            DeviceListItem(device: device) {
                                onSelectDevice(device)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - Device List Item
struct DeviceListItem: View {
    let device: Device
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Bluetooth icon
                Image(systemName: "bluetooth")
                    .font(.system(size: 20))
                    .foregroundColor(.blue.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                    )
                
                // Device name
                Text(device.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                // Glass effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .background(
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
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - No Device Paired View
struct NoDevicePill: View {
    var onAddDevice: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Bluetooth icon
            Image(systemName: "bluetooth.slash")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.6))
            
            // Text
            Text("No device paired")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Add device button
            Button(action: onAddDevice) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.4))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Glass effect
            ZStack {
                // Background blur
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .background(
                        Capsule()
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
        )
        .background(
            // Inner glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 5)
        )
    }
}

// MARK: - BLE Device Pill (Connected State)
struct DevicePill: View {
    let deviceName: String
    let isConnected: Bool
    var onConnectionToggle: () -> Void
    var onRemove: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection status indicator
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: isConnected ? .green.opacity(0.6) : .red.opacity(0.6), radius: 4)
            
            // Device name
            Text(deviceName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Connection status text
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
            
            // Connect/Disconnect button
            Button(action: onConnectionToggle) {
                Image(systemName: isConnected ? "xmark.circle.fill" : "power.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isConnected ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Glass effect
            ZStack {
                // Background blur
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .background(
                        Capsule()
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
        )
        .background(
            // Inner glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 5)
        )
        .contextMenu {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove Device", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("BLE Device Pill") {
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
        
        VStack {
            DeviceDisplayView(deviceManager: MockDeviceManager(
                discoveredDevices: [
                    MockDevice(id: "device-1", name: "Device 1", connection: .disconnected),
                    MockDevice(id: "device-2", name: "Device 2", connection: .disconnected)
                ],
            ))
                .padding(.horizontal)
                .padding(.top, 60)
            
            Spacer()
        }
    }
}
