//
//  BookmarkModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

@MainActor
class BookmarkModel: ObservableObject {

  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler

  public var bookmark: Bookmark
  @Published public var items: [MediaItem] = MediaItem.skeletonMock()
  @Published public var isRefreshing: Bool = false

  init(bookmark: Bookmark, itemsService: VideoContentService, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.bookmark = bookmark
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    isRefreshing = true
    defer { isRefreshing = false }
    
    do {
      items = try await contentService.fetchBookmarkItems(id: "\(bookmark.id)").items
    } catch {
      Logger.app.debug("fetch bookmark items error: \(error)")
      errorHandler.setError(error)
    }
  }

  @MainActor
  func refresh() {
    items = MediaItem.skeletonMock()
    Task {
      Logger.app.debug("refetch bookmark items")
      await fetchItems()
    }
  }
  
  @MainActor
  func refreshAsync() async {
    items = MediaItem.skeletonMock()
    Logger.app.debug("refetch bookmark items async")
    await fetchItems()
  }

}
