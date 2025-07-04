//
//  BookmarkFoldersResponse.swift
//
//
//  Created by Kirill Kunst on 4.07.2025.
//

import Foundation

public struct BookmarkFoldersResponse: Codable {
  public let status: Int
  public let items: [BookmarkFolder]
}

public struct BookmarkFolder: Codable, Identifiable, Hashable {
  public let id: Int
  public let title: String
  public let views: Int
  public let count: String
  public let created: Int
  public let updated: Int
  
  public init(id: Int, title: String, views: Int, count: String, created: Int, updated: Int) {
    self.id = id
    self.title = title
    self.views = views
    self.count = count
    self.created = created
    self.updated = updated
  }
} 