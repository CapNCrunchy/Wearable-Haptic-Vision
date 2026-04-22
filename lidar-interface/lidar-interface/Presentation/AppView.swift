//
//  AppView.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/29/26.
//  UI elements generated with assistance by Claude

import SwiftUI

struct AppView: View {
    @State private var deviceManager = BLEDeviceManager()
    @State private var collectionService = LiDARCollectionService()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // Determine if we're in landscape mode
    // On iPhone, verticalSizeClass changes from .regular (portrait) to .compact (landscape)
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
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
            
            // Main content - responsive layout
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .onAppear {
            collectionService.observeDeviceConnection(deviceManager)
            
            SessionManager.shared.configure(
                deviceManager: deviceManager,
                collectionService: collectionService
            )
        }
    }
    
    // MARK: - Portrait Layout (Original)
    
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.top, 60)
                .padding(.bottom, 28)
            
            // Device connection section
            VStack(spacing: 12) {
                SectionHeader(title: "Device", icon: "antenna.radiowaves.left.and.right")
                DeviceDisplayView(deviceManager: deviceManager)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Heatmap section
            VStack(spacing: 12) {
                SectionHeader(title: "Depth Visualization", icon: "chart.bar.fill")
                LiDARDisplayView(collectionService: collectionService)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            // Session control section
            VStack(spacing: 12) {
                SectionHeader(title: "Session Control", icon: "play.circle")
                SessionView(deviceManager: deviceManager, collectionService: collectionService)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Landscape Layout (Optimized)
    
    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            // Compact header for landscape
            compactHeaderView
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            HStack(spacing: 20) {
                // Left column - Device and Session Control
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        SectionHeader(title: "Device", icon: "antenna.radiowaves.left.and.right")
                        DeviceDisplayView(deviceManager: deviceManager)
                    }
                    
                    VStack(spacing: 12) {
                        SectionHeader(title: "Session Control", icon: "play.circle")
                        SessionView(deviceManager: deviceManager, collectionService: collectionService)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: 400)
                .padding(.leading, 20)
                
                // Right column - Depth Visualization (larger)
                VStack(spacing: 12) {
                    SectionHeader(title: "Depth Visualization", icon: "chart.bar.fill")
                    LiDARDisplayView(collectionService: collectionService)
                    Spacer()
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Header Views
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .blue.opacity(0.5), radius: 10)
            
            Text("Wearable Haptic Vision")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var compactHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .blue.opacity(0.5), radius: 10)
            
            Text("Wearable Haptic Vision")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview("App View - No Device") {
    AppView()
}

#Preview("App View - Device Connected, Not Collecting") {
    let mockDeviceManager = MockDeviceManager(
        discoveredDevices: [
            MockDevice(id: "device-1", name: "ESP32 Sensor", connection: .disconnected),
            MockDevice(id: "device-2", name: "Arduino Board", connection: .disconnected)
        ],
        connectedDevice: MockDevice(
            id: "device-1",
            name: "ESP32 Sensor",
            connection: .connected
        )
    )
    
    let mockCollectionService = MockCollectionService.staticMock(depthMap: nil)
    
    return ZStack {
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
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fingers.spread.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .blue.opacity(0.5), radius: 10)
                
                Text("Wearable Haptic Vision")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 60)
            .padding(.bottom, 28)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Device", icon: "antenna.radiowaves.left.and.right")
                
                DeviceDisplayView(deviceManager: mockDeviceManager)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Depth Visualization", icon: "chart.bar.fill")
                
                LiDARDisplayView(collectionService: mockCollectionService)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Session Control", icon: "play.circle")
                
                SessionView(deviceManager: mockDeviceManager, collectionService: mockCollectionService)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

#Preview("App View - Active Session") {
    let mockDeviceManager = MockDeviceManager(
        connectedDevice: MockDevice(
            id: "device-1",
            name: "ESP32 Sensor",
            connection: .connected
        )
    )
    
    let mockCollectionService = MockCollectionService.animatedMock(updateInterval: 0.5)
    
    return ZStack {
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
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fingers.spread.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .blue.opacity(0.5), radius: 10)
                
                Text("Wearable Haptic Vision")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 60)
            .padding(.bottom, 28)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Device", icon: "antenna.radiowaves.left.and.right")
                
                DeviceDisplayView(deviceManager: mockDeviceManager)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Depth Visualization", icon: "chart.bar.fill")
                
                LiDARDisplayView(collectionService: mockCollectionService)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                SectionHeader(title: "Session Control", icon: "play.circle")
                
                SessionView(deviceManager: mockDeviceManager, collectionService: mockCollectionService)
            }
            .padding(.horizontal, 20)
            
            Spacer()    
        }
    }
}
