//
//  VideoContentServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

final class VideoContentServiceImpl: VideoContentService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ShortcutItemsRequest(shortcut: shortcut, contentType: contentType, page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = SearchItemsRequest(contentType: nil, page: page, query: query)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    let request = ItemDetailsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: SingleItemData<MediaItem>.self)
    return response
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    let request = BookmarksRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Bookmark>.self)
    return response
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    let request = BookmarkItemsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaItem>.self)
    return response
  }
  
  // MARK: - New API Methods
  
  func fetchComments(for id: Int, video: Int?, season: Int?) async throws -> ArrayData<Comment> {
    let request = CommentsRequest(id: id, video: video, season: season)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Comment>.self)
    return response
  }
  
  func voteForVideo(id: Int, rating: Int) async throws -> EmptyResponseData {
    let request = VoteVideoRequest(id: id, rating: rating)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: EmptyResponseData.self)
    return response
  }
  
  func fetchServerLocations() async throws -> ArrayData<ServerLocation> {
    let request = ServerLocationsRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<ServerLocation>.self)
    return response
  }
  
  func fetchUnwatched(type: UnwatchedRequest.ContentType, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = UnwatchedRequest(type: type, page: page ?? 1)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }
  
  func clearHistory(type: ClearHistoryRequest.ClearType) async throws -> EmptyResponseData {
    let request = ClearHistoryRequest(clearType: type)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: EmptyResponseData.self)
    return response
  }
  
  func fetchTVChannels(page: Int?) async throws -> TVChannelsResponse {
    let pageNumber = page ?? 1
    print("🌐 [API] Запрос ТВ каналов, страница: \(pageNumber)")
    
    do {
      let request = TVChannelsRequest(page: pageNumber)
      print("📡 [API] Отправляем запрос: \(request.path)")
      let response = try await apiClient.performRequest(with: request,
                                                        decodingType: TVChannelsResponse.self)
      print("✅ [API] Получен ответ для ТВ каналов: \(response.channels.count) элементов")
      return response
    } catch {
      print("❌ [API] Ошибка запроса ТВ каналов: \(error)")
      throw error
    }
  }
  
  func fetchCollections(page: Int?) async throws -> PaginatedData<Collection> {
    let pageNumber = page ?? 1
    print("🌐 [API] Запрос подборок, страница: \(pageNumber)")
    
    do {
      let request = CollectionsRequest(page: pageNumber)
      print("📡 [API] Отправляем запрос: \(request.path)")
      let response = try await apiClient.performRequest(with: request,
                                                        decodingType: PaginatedData<Collection>.self)
      print("✅ [API] Получен ответ для подборок: \(response.items.count) элементов")
      return response
    } catch {
      print("❌ [API] Ошибка запроса подборок: \(error)")
      throw error
    }
  }
  
  func fetchCollectionItems(id: Int, page: Int?) async throws -> CollectionDetailResponse {
    let pageNumber = page ?? 1
    print("🌐 [API] Запрос элементов подборки \(id), страница: \(pageNumber)")
    
    do {
      let request = CollectionItemsRequest(id: id, page: pageNumber)
      print("📡 [API] Отправляем запрос: \(request.path)")
      let response = try await apiClient.performRequest(with: request,
                                                        decodingType: CollectionDetailResponse.self)
      print("✅ [API] Получен ответ для элементов подборки: \(response.items.count) элементов")
      return response
    } catch {
      print("❌ [API] Ошибка запроса элементов подборки: \(error)")
      throw error
    }
  }
  
  func fetchSimilarVideos(for id: Int, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = SimilarVideosRequest(id: id, page: page ?? 1)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }
  
  func fetchViewingHistory(page: Int?) async throws -> PaginatedData<ViewingHistory> {
    let request = ViewingHistoryRequest(page: page ?? 1)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<ViewingHistory>.self)
    return response
  }

}
