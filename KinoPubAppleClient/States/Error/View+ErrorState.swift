//
//  View+ErrorState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI
import PopupView
import KinoPubUI

/// Extension for the View protocol to handle error states.
extension View {
  
  /// Displays a popup with an error message when the error state is true.
  /// - Parameter state: A binding to the error state.
  /// - Returns: A modified view with error handling.
  func handleError(state: Binding<ErrorState>) -> some View {
    self.alert(
      "Error",
      isPresented: .constant(state.wrappedValue.isError),
      actions: {
        Button("OK") {
          state.wrappedValue = .noError
        }
        
        if let error = state.wrappedValue.error,
           error.recoverySuggestion != nil {
          Button("Retry") {
            // Можно добавить retry логику здесь
            state.wrappedValue = .noError
          }
        }
      },
      message: {
        VStack(alignment: .leading, spacing: 8) {
          if let error = state.wrappedValue.error {
            Text(error.localizedDescription)
            
            if let recoverySuggestion = error.recoverySuggestion {
              Text(recoverySuggestion)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    )
  }
  
}
