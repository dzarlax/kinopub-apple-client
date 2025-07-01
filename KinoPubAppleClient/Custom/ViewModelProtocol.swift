//
//  ViewModelProtocol.swift
//  KinoPubAppleClient
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation
import SwiftUI

// MARK: - ViewModel Protocol
@MainActor
protocol ViewModelProtocol: ObservableObject {
  associatedtype State
  associatedtype Action
  
  var state: State { get }
  
  func send(_ action: Action) async
  func onAppear() async
  func onDisappear()
}

// MARK: - Default Implementation
extension ViewModelProtocol {
  func onAppear() async {}
  func onDisappear() {}
}

// MARK: - Stateful ViewModel
@MainActor
protocol StatefulViewModelProtocol: ViewModelProtocol where State: Equatable {
  var previousState: State? { get set }
  
  func stateDidChange(from oldState: State?, to newState: State)
}

extension StatefulViewModelProtocol {
  func updateState(_ newState: State) {
    let oldState = state
    if oldState != newState {
      previousState = oldState
      stateDidChange(from: oldState, to: newState)
    }
  }
}

// MARK: - Loadable State
protocol LoadableState {
  var isLoading: Bool { get }
  var hasError: Bool { get }
  var error: AppError? { get }
}

// MARK: - Retryable ViewModel
@MainActor
protocol RetryableViewModelProtocol: ViewModelProtocol {
  func retry() async
}

// MARK: - Refreshable ViewModel  
@MainActor
protocol RefreshableViewModelProtocol: ViewModelProtocol {
  func refresh() async
}

// MARK: - View Modifier for ViewModels
struct ViewModelModifier<ViewModel: ViewModelProtocol>: ViewModifier {
  @StateObject private var viewModel: ViewModel
  
  init(viewModel: @autoclosure @escaping () -> ViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel())
  }
  
  func body(content: Content) -> some View {
    content
      .environmentObject(viewModel)
      .task {
        await viewModel.onAppear()
      }
      .onDisappear {
        viewModel.onDisappear()
      }
  }
}

extension View {
  func withViewModel<ViewModel: ViewModelProtocol>(_ viewModel: @autoclosure @escaping () -> ViewModel) -> some View {
    self.modifier(ViewModelModifier(viewModel: viewModel()))
  }
} 