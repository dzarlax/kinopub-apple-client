//
//  GetItemFoldersRequest.swift
//
//
//  Created by Kirill Kunst on 4.07.2025.
//

import Foundation

public struct GetItemFoldersRequest: Endpoint {
  
  public let item: Int
  
  public init(item: Int) {
    self.item = item
  }

  public var path: String {
    "/v1/bookmarks/get-item-folders"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["item": item]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
} 