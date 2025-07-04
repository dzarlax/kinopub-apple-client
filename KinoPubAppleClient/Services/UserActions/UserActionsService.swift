//
//  UserActionsService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubKit
import KinoPubBackend

protocol UserActionsServiceProtocol {
  func addBookmark(id: Int) async throws
  func removeBookmark(id: Int) async throws
  func toggleBookmark(id: Int, folder: Int?) async throws
  func getBookmarkFolders() async throws -> [BookmarkFolder]
  func getItemFolders(id: Int) async throws -> [BookmarkFolder]
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.ToggleWatchingResponse
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> KinoPubBackend.WatchData
  func fetchWatchingInfo(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.WatchData
}

typealias UserActionsService = UserActionsServiceProtocol

extension UserActionsService {
  func toggleWatching(id: Int, video: Int?) async throws -> KinoPubKit.ToggleWatchingResponse {
    return try await toggleWatching(id: id, video: video, season: nil)
  }
  
  func markWatch(id: Int, time: Int, video: Int?) async throws {
    return try await markWatch(id: id, time: time, video: video, season: nil)
  }
  
  func fetchWatchMark(id: Int, video: Int?) async throws -> KinoPubBackend.WatchData {
    return try await fetchWatchMark(id: id, video: video, season: nil)
  }
  
  func fetchWatchingInfo(id: Int, video: Int?) async throws -> KinoPubKit.WatchData {
    return try await fetchWatchingInfo(id: id, video: video, season: nil)
  }
}

// MARK: - Mock Implementation

class MockUserActionsService: UserActionsService {
  
  func addBookmark(id: Int) async throws {
    // Mock implementation
  }
  
  func removeBookmark(id: Int) async throws {
    // Mock implementation
  }
  
  func toggleBookmark(id: Int, folder: Int?) async throws {
    // Mock implementation
  }
  
  func getBookmarkFolders() async throws -> [BookmarkFolder] {
    // Mock implementation - возвращаем тестовые папки
    return [
      BookmarkFolder(id: 1, title: "Фильмы", views: 10, count: "5", created: 1234567890, updated: 1234567890),
      BookmarkFolder(id: 2, title: "Сериалы", views: 20, count: "10", created: 1234567890, updated: 1234567890),
      BookmarkFolder(id: 3, title: "Мультфильмы", views: 5, count: "3", created: 1234567890, updated: 1234567890)
    ]
  }
  
  func getItemFolders(id: Int) async throws -> [BookmarkFolder] {
    // Mock implementation - возвращаем случайные папки для элемента
    return [
      BookmarkFolder(id: 1, title: "Фильмы", views: 10, count: "5", created: 1234567890, updated: 1234567890)
    ]
  }
  
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.ToggleWatchingResponse {
    return KinoPubKit.ToggleWatchingResponse(status: 200, watched: 1)
  }
  
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws {
    // Mock implementation
  }
  
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> KinoPubBackend.WatchData {
    // Mock implementation - создаем простую структуру для тестирования
    return KinoPubBackend.WatchData.mock
  }
  
  func fetchWatchingInfo(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.WatchData {
    // Создаем мок-данные для тестирования
    let episode = KinoPubKit.WatchData.WatchDataVideoItem(
      id: 1,
      number: 1,
      title: "Test Episode",
      time: 0.0,
      status: 0
    )
    
    let season = KinoPubKit.WatchData.Season(
      id: 1,
      number: 1,
      status: 0,
      episodes: [episode]
    )
    
    let item = KinoPubKit.WatchData.WatchDataItem(
      seasons: [season],
      videos: [episode]
    )
    
    return KinoPubKit.WatchData(item: item)
  }
}
