//
//  CollectionsView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.01.2025.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct CollectionsView: View {
  @StateObject private var viewModel = CollectionsViewModel()
  @EnvironmentObject var appContext: AppContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  
  var body: some View {
    NavigationStack(path: $navigationState.collectionsRoutes) {
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(viewModel.collections) { collection in
            NavigationLink(destination: 
              CollectionDetailView(collection: collection)
                .onAppear {
                  print("🔄 [Navigation] CollectionDetailView появился для коллекции: \(collection.title)")
                }
                .environmentObject(appContext)
            ) {
              CollectionCard(collection: collection)
                .onAppear {
                  print("📋 [CollectionsView] Карточка коллекции отображена: \(collection.title) (ID: \(collection.id))")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle()) // Ограничиваем область нажатия формой контента
            .simultaneousGesture(TapGesture().onEnded {
              print("👆 [Navigation] Пользователь нажал на коллекцию: \(collection.title) (ID: \(collection.id))")
              print("🎯 [Navigation] Начинаем переход к деталям коллекции...")
              print("🔗 [Navigation] NavigationLink активирован для коллекции: \(collection.title)")
            })
          }
        }
        .padding()
      }
      .navigationTitle("Подборки")
      .navigationDestination(for: CollectionsRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: CollectionsRoutesLinkProvider(),
                                              errorHandler: errorHandler))
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .seasons(let seasons):
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: CollectionsRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: CollectionsRoutesLinkProvider()))
        }
      }
      .refreshable {
        await viewModel.refresh(contentService: appContext.contentService)
      }
      .task {
        await viewModel.loadCollections(contentService: appContext.contentService)
      }
      .alert("Ошибка", isPresented: $viewModel.showError) {
        Button("OK") { viewModel.showError = false }
      } message: {
        Text(viewModel.errorMessage)
      }
    }
  }
}

struct CollectionCard: View {
  let collection: Collection
  
  var body: some View {
    HStack(spacing: 16) {
      // Collection Poster
      AsyncImage(url: URL(string: collection.poster ?? "")) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay(
            Image(systemName: "photo.stack")
              .font(.title)
              .foregroundColor(.gray)
          )
      }
      .frame(width: 120, height: 160)
      .clipped()
      .cornerRadius(8)
      
      // Collection Info
      VStack(alignment: .leading, spacing: 8) {
        Text(collection.title)
          .font(.headline)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        
        if let description = collection.description {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
        
        Spacer()
        
        HStack {
          Image(systemName: "rectangle.stack")
            .foregroundColor(.blue)
          Text("\(collection.itemsCount) фильмов")
            .font(.caption)
            .foregroundColor(.secondary)
          
          Spacer()
          
          if let updatedAt = collection.updatedAt {
            Text("Обновлено: \(formatDate(updatedAt))")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .frame(height: 180) // Фиксируем высоту карточки
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
  
  private func formatDate(_ dateString: String) -> String {
    // Simple date formatting - can be improved
    let components = dateString.split(separator: "-")
    if components.count >= 3 {
      return "\(components[2]).\(components[1]).\(components[0])"
    }
    return dateString
  }
}

// MARK: - ViewModel

@MainActor
class CollectionsViewModel: ObservableObject {
  @Published var collections: [Collection] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  private var currentPage = 1
  
  func loadCollections(contentService: VideoContentService) async {
    guard !isLoading else { 
      print("⏹ [Collections] Загрузка уже идет, пропускаем")
      return 
    }
    
    print("🔄 [Collections] Загружаем подборки, страница: \(currentPage)")
    isLoading = true
    
    do {
      let response = try await contentService.fetchCollections(page: currentPage)
      print("✅ [Collections] Получено \(response.items.count) подборок")
      print("📋 [Collections] Список подборок:")
      for (index, collection) in response.items.enumerated() {
        print("   \(index + 1). \(collection.title) (ID: \(collection.id), фильмов: \(collection.itemsCount))")
      }
      collections.append(contentsOf: response.items)
      print("📊 [Collections] Всего подборок в массиве: \(collections.count)")
    } catch {
      print("❌ [Collections] Ошибка загрузки подборок: \(error)")
      errorMessage = error.localizedDescription
      showError = true
    }
    
    isLoading = false
    print("🏁 [Collections] Загрузка завершена")
  }
  
  func refresh(contentService: VideoContentService) async {
    collections.removeAll()
    currentPage = 1
    await loadCollections(contentService: contentService)
  }
}

#Preview {
  CollectionsView()
    .environmentObject(AppContext.mock())
} 