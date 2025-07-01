//
//  ItemDetailsRequest.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct ItemDetailsRequest: Endpoint, CacheableRequest {
  public let id: String
  
  public init(id: String) {
    self.id = id
  }
  
  public var path: String {
    "/v1/items/\(id)"
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
  
  public var forceSendAsGetParams: Bool { 
    false 
  }
  
  // MARK: - CacheableRequest
  public var cachePolicy: CachePolicy {
    .memoryOnly(ttl: 600) // 10 minutes for item details
  }
  
  public var cacheKey: String {
    "item_details_\(id)"
  }
}
