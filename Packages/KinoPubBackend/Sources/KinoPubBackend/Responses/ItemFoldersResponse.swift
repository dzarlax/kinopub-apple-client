//
//  ItemFoldersResponse.swift
//
//
//  Created by Kirill Kunst on 4.07.2025.
//

import Foundation

public struct ItemFoldersResponse: Codable {
  public let status: Int
  public let folders: [BookmarkFolder]
} 