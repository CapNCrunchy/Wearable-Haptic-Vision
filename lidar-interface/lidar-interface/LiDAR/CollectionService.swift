//
//  CollectionService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/19/26.
//

import Combine

protocol CollectionService: AnyObject, ObservableObject {
    var depthMap: [[Float]]? { get set }
    var collecting: Bool { get set }
    
    // Publisher that emits depth map updates
    var depthMapPublisher: AnyPublisher<[[Float]]?, Never> { get }
    
    func toggleCollection()
    func start()
    func stop()
}
