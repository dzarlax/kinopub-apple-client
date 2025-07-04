//
//  GetBookmarkFoldersRequest.swift
//
//
//  Created by Kirill Kunst on 4.07.2025.
//

import Foundation

public struct GetBookmarkFoldersRequest: Endpoint {
  
  public init() {}

  public var path: String {
    "/v1/bookmarks"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    nil
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
} 