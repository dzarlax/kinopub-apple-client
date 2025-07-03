//
//  ToggleWatchingResponse.swift
//
//
//  Created by Dzarlax on 15.01.2025.
//

import Foundation

public struct ToggleWatchingResponse: Codable {
  public let status: Int
  public let watched: Int // 0 - отмечено как непросмотренные, 1 - отмечено как просмотренные
  
  public var isWatched: Bool {
    return watched == 1
  }
} 