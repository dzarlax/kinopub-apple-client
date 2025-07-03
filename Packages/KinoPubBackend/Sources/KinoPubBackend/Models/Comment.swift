//
//  Comment.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct Comment: Codable, Identifiable {
  public let id: Int
  public let author: String
  public let message: String
  public let date: String
  public let rating: Int?
  public let avatar: String?
  public let likes: Int
  public let dislikes: Int
  public let replies: [Comment]?
  
  enum CodingKeys: String, CodingKey {
    case id
    case author
    case message
    case date
    case rating
    case avatar
    case likes
    case dislikes
    case replies
  }
} 