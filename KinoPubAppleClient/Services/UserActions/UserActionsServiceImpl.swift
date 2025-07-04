//
//  UserActionsServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubBackend
import KinoPubKit
import KinoPubLogging
import OSLog

class UserActionsServiceImpl: UserActionsService {
  
  private let apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func addBookmark(id: Int) async throws {
    let request = AddBookmarkRequest(item: id, folder: nil)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }
  
  func removeBookmark(id: Int) async throws {
    let request = RemoveBookmarkRequest(item: id, folder: nil)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }
  
  func toggleBookmark(id: Int, folder: Int?) async throws {
    // Проверим текущее состояние элемента
    let currentFolders = try await getItemFolders(id: id)
    
    if currentFolders.isEmpty {
      // Элемент не в закладках - пробуем добавить
      do {
        // Сначала пробуем добавить в указанную папку
        Logger.app.info("Trying to add item \(id) to folder \(folder?.description ?? "default")")
        let addRequest = AddBookmarkRequest(item: id, folder: folder)
        let response = try await apiClient.performRequest(with: addRequest, decodingType: EmptyResponseData.self)
        
        // Проверяем статус ответа
        if response.status == 200 {
          Logger.app.info("Successfully added item \(id) to folder \(folder?.description ?? "default")")
        } else {
          Logger.app.error("Server returned error status \(response.status) for item \(id)")
          throw APIClientError.custom("Не удалось добавить в закладки: статус \(response.status)")
        }
      } catch {
        Logger.app.error("Failed to add item \(id) to folder \(folder?.description ?? "default"): \(error)")
        
        // Если не удалось добавить в конкретную папку, пробуем добавить в дефолтную
        if folder != nil {
          Logger.app.info("Trying fallback: adding item \(id) to default folder")
          do {
            let defaultAddRequest = AddBookmarkRequest(item: id, folder: nil)
            let fallbackResponse = try await apiClient.performRequest(with: defaultAddRequest, decodingType: EmptyResponseData.self)
            
            if fallbackResponse.status == 200 {
              Logger.app.info("Successfully added item \(id) to default folder as fallback")
            } else {
              Logger.app.error("Fallback returned error status \(fallbackResponse.status) for item \(id)")
              throw APIClientError.custom("Не удалось добавить в закладки: статус \(fallbackResponse.status)")
            }
          } catch let fallbackError {
            Logger.app.error("Fallback also failed for item \(id): \(fallbackError)")
            throw fallbackError
          }
        } else {
          // Если и в дефолтную не удается, пробрасываем ошибку
          throw error
        }
      }
    } else {
      // Элемент в закладках - удаляем из указанной папки (или из всех, если папка не указана)
      Logger.app.info("Trying to remove item \(id) from folder \(folder?.description ?? "all folders")")
      let removeRequest = RemoveBookmarkRequest(item: id, folder: folder)
      let response = try await apiClient.performRequest(with: removeRequest, decodingType: EmptyResponseData.self)
      
      if response.status == 200 {
        Logger.app.info("Successfully removed item \(id) from folder \(folder?.description ?? "all folders")")
      } else {
        Logger.app.error("Server returned error status \(response.status) when removing item \(id)")
        throw APIClientError.custom("Не удалось удалить из закладок: статус \(response.status)")
      }
    }
  }
  
  func getBookmarkFolders() async throws -> [BookmarkFolder] {
    let request = GetBookmarkFoldersRequest()
    let response = try await apiClient.performRequest(with: request, decodingType: BookmarkFoldersResponse.self)
    return response.items
  }
  
  func getItemFolders(id: Int) async throws -> [BookmarkFolder] {
    let request = GetItemFoldersRequest(item: id)
    let response = try await apiClient.performRequest(with: request, decodingType: ItemFoldersResponse.self)
    return response.folders
  }
  
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws {
    let request = MarkTimeRequest(id: id, time: time, video: video, season: season)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }
  
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.ToggleWatchingResponse {
    let request = ToggleWatchingRequest(id: id, video: video ?? 1, season: season ?? 1)
    let response = try await apiClient.performRequest(with: request, decodingType: KinoPubBackend.ToggleWatchingResponse.self)
    
    return KinoPubKit.ToggleWatchingResponse(
      status: response.status,
      watched: response.watched
    )
  }
  
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> KinoPubBackend.WatchData {
    let request = GetWatchingDataRequest(id: id, video: video, season: season)
    return try await apiClient.performRequest(with: request, decodingType: KinoPubBackend.WatchData.self)
  }
  
  func fetchWatchingInfo(id: Int, video: Int?, season: Int?) async throws -> KinoPubKit.WatchData {
    let request = GetWatchingDataRequest(id: id, video: video, season: season)
    let backendData = try await apiClient.performRequest(with: request, decodingType: KinoPubBackend.WatchData.self)
    
    // Преобразуем из KinoPubBackend в KinoPubKit
    return convertWatchData(from: backendData)
  }
  
  // MARK: - Private Methods
  
  /// Преобразует данные из KinoPubBackend.WatchData в KinoPubKit.WatchData
  private func convertWatchData(from backendData: KinoPubBackend.WatchData) -> KinoPubKit.WatchData {
    // Преобразуем эпизоды из сезонов
    let convertedSeasons = backendData.item.seasons?.map { backendSeason in
      let convertedEpisodes = backendSeason.episodes.map { backendEpisode in
        KinoPubKit.WatchData.WatchDataVideoItem(
          id: backendEpisode.id,
          number: backendEpisode.number,
          title: backendEpisode.title,
          time: backendEpisode.time,
          status: backendEpisode.status
        )
      }
      
      return KinoPubKit.WatchData.Season(
        id: backendSeason.id,
        number: backendSeason.number,
        status: backendSeason.status,
        episodes: convertedEpisodes
      )
    }
    
    // Преобразуем видео
    let convertedVideos = backendData.item.videos?.map { backendVideo in
      KinoPubKit.WatchData.WatchDataVideoItem(
        id: backendVideo.id,
        number: backendVideo.number,
        title: backendVideo.title,
        time: backendVideo.time,
        status: backendVideo.status
      )
    }
    
    // Создаем итоговый объект
    let convertedItem = KinoPubKit.WatchData.WatchDataItem(
      seasons: convertedSeasons,
      videos: convertedVideos
    )
    
    return KinoPubKit.WatchData(item: convertedItem)
  }
}
