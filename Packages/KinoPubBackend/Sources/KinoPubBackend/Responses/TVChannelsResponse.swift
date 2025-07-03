//
//  TVChannelsResponse.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct TVChannelsResponse: Codable {
  public let status: Int
  public let channels: [TVChannel]
  
  public init(status: Int, channels: [TVChannel]) {
    self.status = status
    self.channels = channels
  }
  
  enum CodingKeys: String, CodingKey {
    case status
    case channels
  }
} 