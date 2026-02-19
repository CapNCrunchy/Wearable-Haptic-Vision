//
//  CollectionService.swift
//  lidar-interface
//
//  Created by Colin McClure on 2/19/26.
//

protocol CollectionService {
    var depthMap: [[Float]]? { get }
    
    var collecting: Bool { get }
    
    mutating func toggleCollection()
}
