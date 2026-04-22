//
//  LiDARCollectionService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/19/26.
//

import ARKit
import Combine

class LiDARCollectionService: NSObject, ARSessionDelegate, ObservableObject, CollectionService {
    private var arSession: ARSession
    
    @Published var depthMap: [[Float]]?
    @Published var collecting: Bool
    
    private let targetFrameRate: Double = 30.0
    private var cancellables = Set<AnyCancellable>()
    
    var depthMapPublisher: AnyPublisher<[[Float]]?, Never> {
        $depthMap
            .throttle(for: .seconds(1.0 / targetFrameRate), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    let DEPTH_ROWS: Int = 1
    let DEPTH_COLS: Int = 8
    
    let MAX_DISTANCE: Float = 5.0
    let MIN_DISTANCE: Float = 0.3
    
    override init() {
        arSession = ARSession()
        self.collecting = false
        super.init()
        arSession.delegate = self
    }
    
    func observeDeviceConnection<Manager: DeviceManager>(_ deviceManager: Manager) {
        deviceManager.objectWillChange
            .sink { [weak self] _ in
                if let device = deviceManager.connectedDevice {
                    if device.connection == .disconnected || device.connection == .disconnecting {
                        if self?.collecting == true {
                            self?.stop()
                            self?.collecting = false
                            TTSService.shared.announceCollectionStoppedByDisconnection()
                        }
                    }
                } else {
                    if self?.collecting == true {
                        self?.stop()
                        self?.collecting = false
                        TTSService.shared.announceCollectionStoppedByDisconnection()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleCollection() {
        if collecting {
            stop()
        } else {
            start()
        }
        
        self.collecting.toggle()
    }
    
    func start() {
        let config = ARWorldTrackingConfiguration()
        
        if !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            return
        }
        
        config.frameSemantics = .sceneDepth
        arSession.run(config)
    }
    
    func stop() {
        arSession.pause()
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
