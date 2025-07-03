//
//  EmptyResponseData.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct EmptyResponseData: Codable {
  public var status: Int
  
  public init(status: Int = 200) {
    self.status = status
  }
}
