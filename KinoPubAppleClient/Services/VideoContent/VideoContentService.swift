//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem>
  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem>
  func fetchBookmarks() async throws -> ArrayData<Bookmark>
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem>
  func fetchComments(for id: Int, video: Int?, season: Int?) async throws -> ArrayData<Comment>
  func voteForVideo(id: Int, rating: Int) async throws -> EmptyResponseData
  func fetchServerLocations() async throws -> ArrayData<ServerLocation>
  func fetchUnwatched(type: UnwatchedRequest.ContentType, page: Int?) async throws -> PaginatedData<MediaItem>
  func clearHistory(type: ClearHistoryRequest.ClearType) async throws -> EmptyResponseData
  func fetchTVChannels(page: Int?) async throws -> TVChannelsResponse
  func fetchCollections(page: Int?) async throws -> PaginatedData<Collection>
  func fetchCollectionItems(id: Int, page: Int?) async throws -> CollectionDetailResponse
  func fetchSimilarVideos(for id: Int, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchViewingHistory(page: Int?) async throws -> PaginatedData<ViewingHistory>
}

protocol VideoContentServiceProvider {
  var contentService: VideoContentService { get set }
}

struct VideoContentServiceMock: VideoContentService {

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    return SingleItemData.mock(data: MediaItem.mock())
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    return ArrayData.mock(data: [])
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    return ArrayData.mock(data: [])
  }
  
  func fetchComments(for id: Int, video: Int?, season: Int?) async throws -> ArrayData<Comment> {
    return ArrayData.mock(data: [])
  }
  
  func voteForVideo(id: Int, rating: Int) async throws -> EmptyResponseData {
    return EmptyResponseData(status: 200)
  }
  
  func fetchServerLocations() async throws -> ArrayData<ServerLocation> {
    return ArrayData.mock(data: [])
  }
  
  func fetchUnwatched(type: UnwatchedRequest.ContentType, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }
  
  func clearHistory(type: ClearHistoryRequest.ClearType) async throws -> EmptyResponseData {
    return EmptyResponseData(status: 200)
  }
  
  func fetchTVChannels(page: Int?) async throws -> TVChannelsResponse {
    return TVChannelsResponse(status: 200, channels: [])
  }
  
  func fetchCollections(page: Int?) async throws -> PaginatedData<Collection> {
    return PaginatedData.mock(data: [])
  }
  
  func fetchCollectionItems(id: Int, page: Int?) async throws -> CollectionDetailResponse {
    // Create mock collection
    let mockCollection = Collection(
      id: id,
      title: "Mock Collection",
      watchers: 10,
      views: 100,
      created: Int(Date().timeIntervalSince1970),
      updated: Int(Date().timeIntervalSince1970),
      posters: nil as CollectionPosters?
    )
    
    return CollectionDetailResponse(
      status: 200,
      collection: mockCollection,
      items: []
    )
  }
  
  func fetchSimilarVideos(for id: Int, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }
  
  func fetchViewingHistory(page: Int?) async throws -> PaginatedData<ViewingHistory> {
    return PaginatedData.mock(data: [])
  }
}
