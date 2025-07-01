//
//  ErrorHandler.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubLogging
import OSLog

// MARK: - App Errors
enum AppError: LocalizedError {
  case networkError(Error)
  case authenticationRequired
  case dataCorrupted
  case downloadFailed(String)
  case unknown(Error)
  
  var errorDescription: String? {
    switch self {
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .authenticationRequired:
      return "Authentication required"
    case .dataCorrupted:
      return "Data corrupted"
    case .downloadFailed(let reason):
      return "Download failed: \(reason)"
    case .unknown(let error):
      return "Unknown error: \(error.localizedDescription)"
    }
  }
  
  var recoverySuggestion: String? {
    switch self {
    case .networkError:
      return "Check your internet connection and try again"
    case .authenticationRequired:
      return "Please log in to continue"
    case .dataCorrupted:
      return "Please refresh the data"
    case .downloadFailed:
      return "Try downloading again"
    case .unknown:
      return "Please try again or contact support"
    }
  }
}

// MARK: - Error State
enum ErrorState {
  case noError
  case error(AppError)
  
  var isError: Bool {
    if case .error = self {
      return true
    }
    return false
  }
  
  var error: AppError? {
    if case .error(let appError) = self {
      return appError
    }
    return nil
  }
}

// MARK: - Error Handler
@MainActor
class ErrorHandler: ObservableObject {
  @Published var state: ErrorState = .noError
  
  func setError(_ error: Error) {
    Logger.app.error("Error occurred: \(error.localizedDescription)")
    
    let appError: AppError
    if let apiError = error as? APIClientError {
      appError = .networkError(apiError)
    } else {
      appError = .unknown(error)
    }
    
    state = .error(appError)
  }
  
  func setError(_ appError: AppError) {
    Logger.app.error("App error occurred: \(appError.localizedDescription ?? "Unknown")")
    state = .error(appError)
  }
  
  func clearError() {
    state = .noError
  }
  
  // MARK: - Helper methods for common errors
  func handleNetworkError(_ error: Error) {
    setError(.networkError(error))
  }
  
  func handleAuthError() {
    setError(.authenticationRequired)
  }
  
  func handleDownloadError(_ reason: String) {
    setError(.downloadFailed(reason))
  }
}
