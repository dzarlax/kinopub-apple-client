//
//  BackendError.swift
//
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

public enum BackendErrorCode: String, Codable {
  case authorizationPending = "authorization_pending"
  case invalidClient = "invalid_client"
  case unauthorized = "unauthorized"
  case itemNotFound = "Requested item not found."
  case unknown = "unknown"
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    self = BackendErrorCode(rawValue: value) ?? .unknown
  }
}

public struct BackendError: Error, Codable {
  public var status: Int
  public var errorCode: BackendErrorCode
  public var errorDescription: String?

  private enum CodingKeys: String, CodingKey {
    case status
    case errorCode = "error"
    case errorDescription = "error_description"
  }
}
