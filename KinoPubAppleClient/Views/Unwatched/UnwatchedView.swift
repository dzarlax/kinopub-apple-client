//
//  UnwatchedView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.01.2025.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct UnwatchedView: View {
  @StateObject private var viewModel = UnwatchedViewModel()
  @EnvironmentObject var appContext: AppContext
  @State private var selectedType: UnwatchedRequest.ContentType = .all
  
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
  ]
  
  var body: some View {
    NavigationView {
      VStack {
        // Filter picker
        Picker("Тип контента", selection: $selectedType) {
          Text("Все").tag(UnwatchedRequest.ContentType.all)
          Text("Фильмы").tag(UnwatchedRequest.ContentType.movies)
          Text("Сериалы").tag(UnwatchedRequest.ContentType.series)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: selectedType) { _, newValue in
          Task {
            await viewModel.changeType(newValue)
          }
        }
        
        ScrollView {
          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.items) { item in
              NavigationLink(destination: MediaItemViewWrapper(mediaItemId: String(item.id))) {
                UnwatchedItemCard(item: item)
              }
              .buttonStyle(PlainButtonStyle())
            }
          }
          .padding()
        }
      }
      .navigationTitle("Недосмотренное")
      .refreshable {
        await viewModel.refresh()
      }
      .task {
        await viewModel.loadUnwatched(
          type: selectedType,
          contentService: appContext.contentService
        )
      }
      .alert("Ошибка", isPresented: $viewModel.showError) {
        Button("OK") { viewModel.showError = false }
      } message: {
        Text(viewModel.errorMessage)
      }
    }
  }
}

struct UnwatchedItemCard: View {
  let item: MediaItem
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Poster with progress indicator
      ZStack(alignment: .bottom) {
        ContentItemView(item: item)
        
        // Progress bar
        if let watching = item.watching {
          ProgressView(value: watching.time, total: watching.duration)
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            .scaleEffect(x: 1, y: 0.5, anchor: .center)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
      }
      
      // Title and progress info
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.caption.bold())
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        
        if let watching = item.watching {
          HStack {
            Text("Просмотрено:")
              .font(.caption2)
              .foregroundColor(.secondary)
            Text("\(Int(watching.time / 60)):\(String(format: \"%02d\", Int(watching.time.truncatingRemainder(dividingBy: 60))))")
              .font(.caption2)
              .foregroundColor(.blue)
          }
          
          let progress = watching.time / watching.duration
          Text("\(Int(progress * 100))% завершено")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

// MARK: - ViewModel

@MainActor
class UnwatchedViewModel: ObservableObject {
  @Published var items: [MediaItem] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  private var currentPage = 1
  private var currentType: UnwatchedRequest.ContentType = .all
  
  func loadUnwatched(
    type: UnwatchedRequest.ContentType,
    contentService: VideoContentService
  ) async {
    guard !isLoading else { return }
    
    currentType = type
    isLoading = true
    
    do {
      let response = try await contentService.fetchUnwatched(
        type: type,
        page: currentPage
      )
      items.append(contentsOf: response.data)
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
    
    isLoading = false
  }
  
  func changeType(_ newType: UnwatchedRequest.ContentType) async {
    items.removeAll()
    currentPage = 1
    currentType = newType
    // Will reload automatically due to task refresh
  }
  
  func refresh() async {
    items.removeAll()
    currentPage = 1
    // Will reload in next frame
  }
}

#Preview {
  UnwatchedView()
    .environmentObject(AppContext.mock())
} 