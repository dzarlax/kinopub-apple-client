//
//  Collection.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct CollectionPosters: Codable {
  public let small: String?
  public let medium: String?
  public let big: String?
  
  public init(small: String? = nil, medium: String? = nil, big: String? = nil) {
    self.small = small
    self.medium = medium
    self.big = big
  }
}

public struct Collection: Codable, Identifiable {
  public let id: Int
  public let title: String
  public let watchers: Int
  public let views: Int
  public let created: Int
  public let updated: Int
  public let posters: CollectionPosters?
  
  public init(id: Int, title: String, watchers: Int, views: Int, created: Int, updated: Int, posters: CollectionPosters?) {
    self.id = id
    self.title = title
    self.watchers = watchers
    self.views = views
    self.created = created
    self.updated = updated
    self.posters = posters
  }
  
  // Computed properties for compatibility
  public var itemsCount: Int { views }
  public var poster: String? { posters?.medium ?? posters?.big ?? posters?.small }
  public var createdAt: String? { 
    let date = Date(timeIntervalSince1970: TimeInterval(created))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
  public var updatedAt: String? {
    let date = Date(timeIntervalSince1970: TimeInterval(updated))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
  public var description: String? { nil }
} 