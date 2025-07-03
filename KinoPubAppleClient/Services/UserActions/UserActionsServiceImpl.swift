//
//  UserActionsServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubBackend
import KinoPubKit

class UserActionsServiceImpl: UserActionsService {
  
  private let apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func addBookmark(id: Int) async throws {
    let request = AddBookmarkRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }
  
  func removeBookmark(id: Int) async throws {
    let request = RemoveBookmarkRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
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
