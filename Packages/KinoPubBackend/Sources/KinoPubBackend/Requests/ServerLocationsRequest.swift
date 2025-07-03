//
//  ServerLocationsRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct ServerLocationsRequest: Endpoint {
  
  public init() {}
  
  public var path: String {
    "/v1/server/locations"
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