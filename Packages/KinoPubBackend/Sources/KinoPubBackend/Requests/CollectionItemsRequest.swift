//
//  CollectionItemsRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct CollectionItemsRequest: Endpoint {
  
  public var id: Int
  public var page: Int
  public var perpage: Int
  
  public init(id: Int, page: Int = 1, perpage: Int = 30) {
    self.id = id
    self.page = page
    self.perpage = perpage
  }
  
  public var path: String {
    "/v1/collections/view"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String: Any]? {
    [
      "id": id,
      "page": page,
      "perpage": perpage
    ]
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { true }
} 