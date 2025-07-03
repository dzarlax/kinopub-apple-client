//
//  CollectionsRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct CollectionsRequest: Endpoint {
  
  public var page: Int
  public var perpage: Int
  
  public init(page: Int = 1, perpage: Int = 30) {
    self.page = page
    self.perpage = perpage
  }
  
  public var path: String {
    "/v1/collections"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String: Any]? {
    [
      "page": page,
      "perpage": perpage
    ]
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { true }
} 