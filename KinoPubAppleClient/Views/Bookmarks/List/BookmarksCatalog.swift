//
//  BookmarksCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class BookmarksCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var bag = Set<AnyCancellable>()

  @Published public var items: [Bookmark] = Bookmark.skeletonMock()

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    do {
      items = try await contentService.fetchBookmarks().items
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      errorHandler.setError(error)
    }
  }

  

  @Sendable @MainActor
  func refresh() async {
    items = Bookmark.skeletonMock()
    Logger.app.debug("refetch bookmarks")
    await fetchItems()
  }
  
  // Новый метод для обновления с callback для очистки моделей
  @Sendable @MainActor
  func refreshWithModelsCleanup(onModelsCleanup: @escaping () -> Void) async {
    items = Bookmark.skeletonMock()
    onModelsCleanup() // Очищаем модели закладок
    Logger.app.debug("refetch bookmarks with models cleanup")
    await fetchItems()
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
