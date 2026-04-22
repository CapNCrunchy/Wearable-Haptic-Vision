//
//  MockCollectionService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/19/26.
//  MockCollectionService was created with assistance by Claude

import Foundation
import Combine

class MockCollectionService: ObservableObject, CollectionService {
    @Published var depthMap: [[Float]]?
    @Published var collecting: Bool = false
    
    // Publisher for depth map updates
    var depthMapPublisher: AnyPublisher<[[Float]]?, Never> {
        $depthMap.eraseToAnyPublisher()
    }
    
    private var timer: Timer?
    private let updateInterval: TimeInterval
    private let rows: Int
    private let cols: Int
    
    init(
        updateInterval: TimeInterval = 0.5,
        rows: Int = 1,
        cols: Int = 8,
        initialDepthMap: [[Float]]? = nil
    ) {
        self.updateInterval = updateInterval
        self.rows = rows
        self.cols = cols
        self.depthMap = initialDepthMap
    }
    
    deinit {
        stop()
    }
    
    func toggleCollection() {
        if collecting {
            stop()
        } else {
            start()
        }
        collecting.toggle()
    }
    
    func start() {
        guard timer == nil else { return }
        
        // Generate initial data if none exists
        if depthMap == nil {
            generateRandomDepthMap()
        }
        
        // Start timer to continuously update depth map
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.generateRandomDepthMap()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func observeDeviceConnection<Manager: DeviceManager>(_ deviceManager: Manager) {
        // No-op for mock - could add test behavior if needed
    }
    
    private func generateRandomDepthMap() {
        var newDepthMap: [[Float]] = []
        
        for _ in 0..<rows {
            var rowData: [Float] = []
            
            var previousValue: Float = Float.random(in: 0.0...1.0)
            
            for col in 0..<cols {
                let variation = Float.random(in: -0.2...0.2)
                var newValue = previousValue + variation
                
                newValue = max(0.0, min(1.0, newValue))
                
                rowData.append(newValue)
                previousValue = newValue
            }
            
            newDepthMap.append(rowData)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.depthMap = newDepthMap
        }
    }
}

// MARK: - Static Mock Services for Previews

extension MockCollectionService {
    static func staticMock(depthMap: [[Float]]?) -> MockCollectionService {
        let service = MockCollectionService(initialDepthMap: depthMap)
        service.collecting = depthMap != nil
        return service
    }
    
    static func animatedMock(updateInterval: TimeInterval = 0.5) -> MockCollectionService {
        let service = MockCollectionService(updateInterval: updateInterval)
        service.start()
        service.collecting = true
        return service
    }
}
