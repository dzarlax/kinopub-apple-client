//
//  AddBookmarkRequest.swift
//
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation

public struct AddBookmarkRequest: Endpoint {
  
  public let id: Int
  
  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/bookmarks/add"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    ["id": id]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
} 