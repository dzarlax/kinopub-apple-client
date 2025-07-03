//
//  ViewingHistory.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct ViewingHistory: Codable, Identifiable {
  public let id: Int
  public let mediaItem: MediaItem
  public let watchedAt: String
  public let progress: Double // 0.0 to 1.0
  public let duration: Int // in seconds
  public let position: Int // current position in seconds
  public let isCompleted: Bool
  public let episode: Episode?
  public let season: Season?
  
  enum CodingKeys: String, CodingKey {
    case id
    case mediaItem = "item"
    case watchedAt = "watched_at"
    case progress
    case duration
    case position
    case isCompleted = "completed"
    case episode
    case season
  }
} 