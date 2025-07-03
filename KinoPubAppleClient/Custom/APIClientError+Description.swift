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
      print("🔗 [API Error] URL Error - неправильный URL запроса")
      return "Неправильный URL запроса"
    case .invalidUrlParams:
      print("🔗 [API Error] Invalid URL Params - неверные параметры URL")
      return "Неверные параметры URL"
    case .decodingError(let error):
      print("📦 [API Error] Decoding Error - ошибка парсинга данных: \(error)")
      return "Ошибка парсинга данных: \(error.localizedDescription)"
    case .networkError(let error):
      print("🌐 [API Error] Network Error - сетевая ошибка: \(error)")
      if let error = error as? BackendError {
        print("🔧 [API Error] Backend Error Code: \(error.errorCode), Message: \(error.errorDescription ?? "No description")")
        return error.errorDescription ?? error.localizedDescription
      }
      return "Сетевая ошибка: \(error.localizedDescription)"
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
