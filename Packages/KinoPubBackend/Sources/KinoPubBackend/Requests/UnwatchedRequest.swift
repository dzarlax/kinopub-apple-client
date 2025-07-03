//
//  UnwatchedRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct UnwatchedRequest: Endpoint {
  
  public enum ContentType: String {
    case movies = "movie"
    case series = "serial"
    case all = ""
  }
  
  public var type: ContentType
  public var page: Int
  public var perpage: Int
  
  public init(type: ContentType = .all, page: Int = 1, perpage: Int = 30) {
    self.type = type
    self.page = page
    self.perpage = perpage
  }
  
  public var path: String {
    "/v1/watching/serials"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String: Any]? {
    var params: [String: Any] = [
      "page": page,
      "perpage": perpage
    ]
    
    if type != .all {
      params["type"] = type.rawValue
    }
    
    return params
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { true }
} 