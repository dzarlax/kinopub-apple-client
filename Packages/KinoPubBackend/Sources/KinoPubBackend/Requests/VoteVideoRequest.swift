//
//  VoteVideoRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct VoteVideoRequest: Endpoint {
  
  public var id: Int
  public var rating: Int // 1-10 rating scale
  
  public init(id: Int, rating: Int) {
    self.id = id
    self.rating = max(1, min(10, rating)) // Ensure rating is between 1-10
  }
  
  public var path: String {
    "/v1/vote"
  }
  
  public var method: String {
    "POST"
  }
  
  public var parameters: [String: Any]? {
    [
      "id": id,
      "rating": rating
    ]
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { false }
} 