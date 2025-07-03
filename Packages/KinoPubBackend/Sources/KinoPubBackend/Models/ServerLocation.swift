//
//  ServerLocation.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct ServerLocation: Codable, Identifiable {
  public let id: String
  public let title: String
  public let country: String
  public let region: String?
  public let city: String?
  public let ping: Int?
  public let bandwidth: String?
  public let isRecommended: Bool
  
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case country
    case region
    case city
    case ping
    case bandwidth
    case isRecommended = "recommended"
  }
} 