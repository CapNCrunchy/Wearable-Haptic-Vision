//
//  LiDARDisplayView.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/22/26.
//  UI elements generated with assistance by Claude

import SwiftUI

struct LiDARDisplayView<Service: CollectionService>: View {
    @ObservedObject var collectionService: Service
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                Text("Depth Heatmap")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Heatmap visualization
            if let depthMap = collectionService.depthMap, !depthMap.isEmpty {
                DepthHeatmapView(depthMap: depthMap)
            } else {
                NoDataView()
            }
        }
        .padding(.vertical, 16)
        .background(
            // Glass effect
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 20)
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
        )
        .background(
            // Inner glow
            RoundedRectangle(cornerRadius: 20)
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

// MARK: - Depth Heatmap View
struct DepthHeatmapView: View {
    let depthMap: [[Float]]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                guard let row = depthMap.first else { return }
                
                let segmentWidth = width / CGFloat(row.count)
                
                for (index, proximity) in row.enumerated() {
                    let x = CGFloat(index) * segmentWidth
                    let rect = CGRect(x: x, y: 0, width: segmentWidth, height: height)
                    
                    let color = proximityToColor(proximity)
                    
                    context.fill(
                        Path(rect),
                        with: .color(color)
                    )
                }
                
                let gradientHeight = height
                for index in 0..<(row.count - 1) {
                    let x = CGFloat(index + 1) * segmentWidth
                    let leftProximity = row[index]
                    let rightProximity = row[index + 1]
                    
                    let leftColor = proximityToColor(leftProximity)
                    let rightColor = proximityToColor(rightProximity)
                    
                    let gradientWidth = segmentWidth * 0.5
                    let gradientRect = CGRect(
                        x: x - gradientWidth / 2,
                        y: 0,
                        width: gradientWidth,
                        height: gradientHeight
                    )
                    
                    let gradient = Gradient(colors: [leftColor, rightColor])
                    context.fill(
                        Path(gradientRect),
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: gradientRect.minX, y: 0),
                            endPoint: CGPoint(x: gradientRect.maxX, y: 0)
                        )
                    )
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(height: 120)
        .padding(.horizontal, 16)
    }
    
    // Convert proximity value to heat color
    private func proximityToColor(_ proximity: Float) -> Color {
        // proximity: 0.0 (far) to 1.0 (close)
        let value = CGFloat(proximity)
        
        // Create a heat gradient: blue (cold/far) -> green -> yellow -> red (hot/close)
        switch value {
        case 0.0..<0.25:
            // Blue to Cyan
            let t = value / 0.25
            return Color(
                red: 0.1 * t,
                green: 0.3 + (0.5 * t),
                blue: 0.8
            )
        case 0.25..<0.5:
            // Cyan to Green
            let t = (value - 0.25) / 0.25
            return Color(
                red: 0.1 + (0.2 * t),
                green: 0.8,
                blue: 0.8 - (0.5 * t)
            )
        case 0.5..<0.75:
            // Green to Yellow
            let t = (value - 0.5) / 0.25
            return Color(
                red: 0.3 + (0.7 * t),
                green: 0.8,
                blue: 0.3 - (0.3 * t)
            )
        default:
            // Yellow to Red
            let t = (value - 0.75) / 0.25
            return Color(
                red: 1.0,
                green: 0.8 - (0.6 * t),
                blue: 0.0
            )
        }
    }
}

// MARK: - No Data View
struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.metering.none")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.4))
            Text("No depth data")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview
#Preview("LiDAR Heatmap") {
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
            // Mock service with sample data
            LiDARDisplayView(
                collectionService: MockCollectionService.staticMock(
                    depthMap: [[0.1, 0.3, 0.5, 0.7, 0.9, 0.7, 0.4, 0.2]]
                )
            )
            
            // No data state
            LiDARDisplayView(
                collectionService: MockCollectionService.staticMock(depthMap: nil)
            )
            
            // Animated mock (updates every 0.5 seconds)
            LiDARDisplayView(
                collectionService: MockCollectionService.animatedMock()
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

