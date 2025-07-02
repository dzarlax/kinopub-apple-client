//
//  APIClientError+Description.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

// MARK: - API Client Error Helper
struct APIClientErrorHelper {
  static func description(for error: APIClientError) -> String {
    switch error {
    case .urlError:
      return "Wrong URL"
    case .invalidUrlParams:
      return "Invalid URL params"
    case .decodingError(let error):
      return "Decoding issue: \(error)"
    case .networkError(let error):
      if let error = error as? BackendError {
        return error.errorDescription ?? error.localizedDescription
      }
      return "Networking issue: \(error)"
    }
  }

  static func isAuthorizationPending(_ error: APIClientError) -> Bool {
    switch error {
    case .networkError(let error):
      if let backendError = error as? BackendError, backendError.errorCode == .authorizationPending {
        return true
      }
      return false
    default: 
      return false
    }
  }
}

// MARK: - Extension for convenience
extension APIClientError {
  var localizedDescription: String {
    APIClientErrorHelper.description(for: self)
  }

  var isAuthorizationPending: Bool {
    APIClientErrorHelper.isAuthorizationPending(self)
  }
}
