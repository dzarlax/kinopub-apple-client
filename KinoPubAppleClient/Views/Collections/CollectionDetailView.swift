//
//  CollectionDetailView.swift
//  KinoPubAppleClient
//
//  Created by Dzarlax on 02.01.2025.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct CollectionDetailView: View {
  let collection: Collection
  @StateObject private var viewModel = CollectionDetailViewModel()
  @EnvironmentObject var appContext: AppContext
  
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
  ]
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Collection Header
        VStack(alignment: .leading, spacing: 12) {
          Text(collection.title)
            .font(.largeTitle.bold())
          
          if let description = collection.description {
            Text(description)
              .font(.body)
              .foregroundColor(.secondary)
          }
          
          HStack {
            Image(systemName: "rectangle.stack.fill")
              .foregroundColor(.blue)
            Text("\(collection.itemsCount) фильмов")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
        .padding(.horizontal)
        
        Divider()
        
        // Collection Items
        if viewModel.isLoading && viewModel.items.isEmpty {
          VStack {
            ProgressView("Загружаем элементы подборки...")
              .padding()
            Text("Это может занять некоторое время")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
          .onAppear {
            print("🔄 [CollectionDetailView UI] Показываем ProgressView - isLoading: \(viewModel.isLoading), items.count: \(viewModel.items.count)")
          }
        } else if viewModel.items.isEmpty && !viewModel.isLoading {
          VStack {
            Image(systemName: "tray")
              .font(.system(size: 48))
              .foregroundColor(.secondary)
            Text("В этой подборке пока нет элементов")
              .font(.headline)
              .foregroundColor(.secondary)
            Text("Попробуйте обновить позже")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
          .onAppear {
            print("📭 [CollectionDetailView UI] Показываем пустое состояние - isLoading: \(viewModel.isLoading), items.count: \(viewModel.items.count)")
          }
        } else {
          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.items) { item in
              NavigationLink(value: CollectionsRoutes.details(item)) {
                ContentItemView(item: item)
              }
              .buttonStyle(PlainButtonStyle())
            }
          }
          .padding(.horizontal)
          .onAppear {
            print("🎬 [CollectionDetailView UI] Показываем сетку элементов - isLoading: \(viewModel.isLoading), items.count: \(viewModel.items.count)")
          }
        }
      }
    }
    .navigationTitle(collection.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      print("👀 [CollectionDetailView] onAppear вызван для коллекции: \(collection.title) (ID: \(collection.id))")
      print("📊 [CollectionDetailView] Текущее состояние - isLoading: \(viewModel.isLoading), items.count: \(viewModel.items.count)")
    }
    .refreshable {
      print("🔄 [CollectionDetailView] Пользователь запросил обновление")
      await viewModel.refresh(contentService: appContext.contentService)
    }
    .task {
      print("⚡ [CollectionDetailView] .task начинает выполнение для коллекции: \(collection.title)")
      print("🏗️ [CollectionDetailView] Настройки task - collectionId: \(collection.id)")
      await viewModel.loadItems(
        collectionId: collection.id,
        contentService: appContext.contentService
      )
      print("🏁 [CollectionDetailView] .task завершен для коллекции: \(collection.title)")
    }
    .alert("Ошибка", isPresented: $viewModel.showError) {
      Button("OK") { viewModel.showError = false }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}

// MARK: - ViewModel

@MainActor
class CollectionDetailViewModel: ObservableObject {
  @Published var items: [MediaItem] = []
  @Published var isLoading = false
  @Published var showError = false
  @Published var errorMessage = ""
  
  private var currentPage = 1
  private var collectionId: Int?
  
  func loadItems(collectionId: Int, contentService: VideoContentService) async {
    guard !isLoading else { 
      print("⚠️ [Collection Detail] Уже идет загрузка, пропускаем")
      return 
    }
    
    self.collectionId = collectionId
    isLoading = true
    print("🔄 [Collection Detail] Начинаем загрузку элементов подборки \(collectionId), страница: \(currentPage)")
    
    do {
      // Небольшая задержка для стабилизации навигации
      print("⏳ [Collection Detail] Ждем 0.5 секунды для стабилизации...")
      try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
      
      // Проверяем, не был ли запрос отменен
      try Task.checkCancellation()
      print("✓ [Collection Detail] Проверка отмены пройдена, продолжаем...")
      
      let response = try await contentService.fetchCollectionItems(
        id: collectionId,
        page: currentPage
      )
      
      // Еще одна проверка после получения ответа
      try Task.checkCancellation()
      
      print("✅ [Collection Detail] Получен ответ - status: \(response.status)")
      print("📊 [Collection Detail] Коллекция: \(response.collection.title)")
      print("📝 [Collection Detail] Элементов в ответе: \(response.items.count)")
      
      if response.items.isEmpty {
        print("⚠️ [Collection Detail] Массив элементов пустой!")
      } else {
        print("🎬 [Collection Detail] Первый элемент: \(response.items[0].title ?? "без названия")")
      }
      
      items.append(contentsOf: response.items)
      print("📋 [Collection Detail] Общее количество элементов в UI: \(items.count)")
      
    } catch {
      // Специальная обработка отмены задачи
      if error is CancellationError {
        print("⏹ [Collection Detail] Запрос отменен пользователем - это нормально")
        // Не показываем ошибку для отмененных запросов
      } else {
        print("❌ [Collection Detail] Ошибка загрузки элементов: \(error)")
        if let apiError = error as? APIClientError {
          print("📡 [Collection Detail] API Error: \(apiError)")
          errorMessage = "Ошибка API: \(apiError.localizedDescription)"
        } else {
          print("🔧 [Collection Detail] Общая ошибка: \(error.localizedDescription)")
          errorMessage = "Ошибка: \(error.localizedDescription)"
        }
        showError = true
      }
    }
    
    isLoading = false
    print("🏁 [Collection Detail] Загрузка завершена")
  }
  
  func refresh(contentService: VideoContentService) async {
    guard let collectionId = collectionId else { 
      print("⚠️ [Collection Detail] Refresh: collectionId отсутствует")
      return 
    }
    print("🔄 [Collection Detail] Начинаем обновление коллекции \(collectionId)")
    items.removeAll()
    currentPage = 1
    await loadItems(collectionId: collectionId, contentService: contentService)
  }
}

#Preview {
  NavigationView {
    CollectionDetailView(
      collection: Collection(
        id: 1,
        title: "Топ фильмы 2024",
        watchers: 10,
        views: 25,
        created: Int(Date().timeIntervalSince1970),
        updated: Int(Date().timeIntervalSince1970),
        posters: nil
      )
    )
    .environmentObject(AppContext.mock())
  }
} 