//
//  TVChannel.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct TVChannel: Codable, Identifiable {
  public let id: Int
  public let name: String
  public let title: String
  public let logos: TVChannelLogos
  public let stream: String
  public let embed: String
  public let current: String
  public let playlist: String
  public let status: String?
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case title
    case logos
    case stream
    case embed
    case current
    case playlist
    case status
  }
}

public struct TVChannelLogos: Codable {
  public let s: String
  public let m: String
  
  enum CodingKeys: String, CodingKey {
    case s
    case m
  }
} 