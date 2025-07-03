//
//  CommentsRequest.swift
//  
//
//  Created by Dzarlax on 02.01.2025.
//

import Foundation

public struct CommentsRequest: Endpoint {
  
  public var id: Int
  public var video: Int = -1
  public var season: Int = -1
  
  public init(id: Int, video: Int? = nil, season: Int? = nil) {
    self.id = id
    self.video = video ?? -1
    self.season = season ?? -1
  }
  
  public var path: String {
    "/v1/comments"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String: Any]? {
    [
      "id": id,
      "video": video,
      "season": season
    ].filter({ $0.value != -1 })
  }
  
  public var headers: [String: String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { true }
} 