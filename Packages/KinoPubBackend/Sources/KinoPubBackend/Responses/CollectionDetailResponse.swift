//
//  CollectionDetailResponse.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct CollectionDetailResponse: Codable {
  public let status: Int
  public let collection: Collection
  public let items: [MediaItem]
  
  public init(status: Int, collection: Collection, items: [MediaItem]) {
    self.status = status
    self.collection = collection
    self.items = items
  }
} 