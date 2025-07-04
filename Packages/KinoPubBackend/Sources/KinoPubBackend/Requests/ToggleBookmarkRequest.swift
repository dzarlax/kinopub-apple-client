//
//  ToggleBookmarkRequest.swift
//
//
//  Created by Kirill Kunst on 4.07.2025.
//

import Foundation

public struct ToggleBookmarkRequest: Endpoint {
  
  public let item: Int
  public let folder: Int?
  
  public init(item: Int, folder: Int? = nil) {
    self.item = item
    self.folder = folder
  }

  public var path: String {
    "/v1/bookmarks/toggle-item"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    var params: [String: Any] = ["item": item]
    if let folder = folder {
      params["folder"] = folder
    }
    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
} 