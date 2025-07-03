//
//  ClearHistoryRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct ClearHistoryRequest: Endpoint {
  
  public enum ClearType {
    case media(id: Int)
    case item(id: Int)
    case all
  }
  
  public var clearType: ClearType
  
  public init(clearType: ClearType) {
    self.clearType = clearType
  }
  
  public var path: String {
    switch clearType {
    case .media:
      return "/v1/watching/history/media"
    case .item:
      return "/v1/watching/history/item"
    case .all:
      return "/v1/watching/history"
    }
  }
  
  public var method: String {
    "DELETE"
  }
  
  public var parameters: [String: Any]? {
    switch clearType {
    case .media(let id), .item(let id):
      return ["id": id]
    case .all:
      return nil
    }
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { false }
} 