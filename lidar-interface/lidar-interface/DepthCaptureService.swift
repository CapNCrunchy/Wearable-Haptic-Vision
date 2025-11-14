//
//  DepthCaptureService.swift
//  lidar-interface
//
//  Created by Colin McClure on 11/14/25.
//

import ARKit
import Combine

class DepthCaptureService: NSObject, ObservableObject, ARSessionDelegate {
    private var arSession: ARSession
    
    @Published var depthMap: [[Float]]?
    
    let DEPTH_ROWS: Int = 2
    let DEPTH_COLS: Int = 3
    
    let MAX_DISTANCE: Float = 5.0
    let MIN_DISTANCE: Float = 0.3
    
    override init() {
        arSession = ARSession()
        super.init()
        arSession.delegate = self
    }
    
    func start() {
        let config = ARWorldTrackingConfiguration()
        
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            return
        }
        
        config.frameSemantics = .sceneDepth
        arSession.run(config)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else {
            return
        }
        
        let depthMap = depthData.depthMap
        let processed = processDepthMap(depthMap, rows: DEPTH_ROWS, cols: DEPTH_COLS)
        
        DispatchQueue.main.async {
            self.depthMap = processed
        }
    }
    
    func processDepthMap(_ depthMap: CVPixelBuffer, rows: Int, cols: Int) -> [[Float]] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let buffer = CVPixelBufferGetBaseAddress(depthMap)!.assumingMemoryBound(to: Float32.self)
        
        let cellWidth = width / cols
        let cellHeight = height / rows
        
        var proximityGrid: [[Float]] = []
        
        for row in 0..<rows {
            var rowData: [Float] = []
            
            for col in 0..<cols {
                let startX = col * cellWidth
                let startY = row * cellHeight
                let endX = min(startX + cellWidth, width)
                let endY = min(startY + cellHeight, height)
                
                var minDepth: Float = Float.infinity
                
                for y in startY..<endY {
                    for x in startX..<endX {
                        let index = y * width + x
                        let depth = buffer[index]
                        
                        if depth > 0 && depth < 10.0 {
                            minDepth = min(minDepth, depth)
                        }
                    }
                }
                
                let proximity: Float
                if minDepth.isFinite {
                    let clampedDepth = max(min(minDepth, MAX_DISTANCE), MIN_DISTANCE)
                    proximity = 1.0 - ((clampedDepth) - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE)
                } else {
                    proximity = 0.0
                }
                
                rowData.append(proximity)
            }
            
            proximityGrid.append(rowData)
        }
        
        return proximityGrid
    }
}
