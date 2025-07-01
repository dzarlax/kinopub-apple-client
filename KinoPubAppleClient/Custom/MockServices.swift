//
//  MockServices.swift  
//  KinoPubAppleClient
//
//  Created by AI Assistant on 01.07.2025.
//

import Foundation
import KinoPubBackend
import KinoPubKit

// MARK: - Mock Video Content Service
class VideoContentServiceMock: VideoContentService {
  var shouldThrowError = false
  var mockItems: [MediaItem] = []
  var mockMediaItem: MediaItem = MediaItem.mock()
  var mockBookmarks: [Bookmark] = []
  
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return PaginatedData(
      items: mockItems.isEmpty ? [MediaItem.mock()] : mockItems,
      pagination: Pagination(total: 1, perPage: 20, currentPage: page ?? 1, lastPage: 1)
    )
  }
  
  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return PaginatedData(
      items: mockItems.isEmpty ? [MediaItem.mock()] : mockItems,
      pagination: Pagination(total: 1, perPage: 20, currentPage: page ?? 1, lastPage: 1)
    )
  }
  
  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return SingleItemData(item: mockMediaItem)
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return ArrayData(items: mockBookmarks)
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return ArrayData(items: mockItems)
  }
}

// MARK: - Mock Authorization Service
class AuthorizationServiceMock: AuthorizationService {
  var shouldThrowError = false
  
  func authenticate(with userCode: String) async throws -> VerificationResponse {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return VerificationResponse(
      userCode: "mock_user_code",
      deviceCode: "mock_device_code",
      verificationURL: "https://mock.url",
      verificationURIComplete: "https://mock.url/complete",
      expiresIn: 1800,
      interval: 5
    )
  }
  
  func refreshToken() async throws {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
  }
  
  func verifyDeviceCode(_ deviceCode: String) async throws -> AccessToken {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return AccessToken(
      accessToken: "mock_access_token",
      tokenType: "bearer",
      expiresIn: 3600,
      refreshToken: "mock_refresh_token"
    )
  }
  
  func logout() {
    // Mock implementation
  }
}

// MARK: - Mock Access Token Service  
class AccessTokenServiceMock: AccessTokenService {
  private var mockToken: AccessToken?
  
  func token<T>() -> T? where T: Decodable, T: Encodable {
    return mockToken as? T
  }
  
  func save(token: AccessToken) {
    mockToken = token
  }
  
  func clear() {
    mockToken = nil
  }
}

// MARK: - Mock User Service
class UserServiceMock: UserService {
  var shouldThrowError = false
  
  func userData() async throws -> UserDataResponse {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return UserDataResponse(
      user: UserData(
        id: 1,
        username: "mock_user",
        profile: UserData.Profile(
          avatar: nil,
          gender: "male",
          birthdate: nil,
          reg_date: "2024-01-01"
        ),
        subscription: UserData.Subscription(
          active: true,
          till: "2024-12-31",
          type: "premium"
        )
      )
    )
  }
}

// MARK: - Mock User Actions Service
class UserActionsServiceMock: UserActionsService {
  var shouldThrowError = false
  
  func toggleWatching(itemId: Int) async throws -> EmptyResponseData {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return EmptyResponseData()
  }
  
  func markTime(itemId: Int, time: Double, duration: Double, video: Int) async throws -> EmptyResponseData {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return EmptyResponseData()
  }
  
  func getWatchingData(itemId: Int) async throws -> SingleItemData<WatchData> {
    if shouldThrowError {
      throw APIClientError.networkError(BackendError(error: "Mock error", errorDescription: "Test error"))
    }
    
    return SingleItemData(
      item: WatchData(
        watching: WatchingMetadata(status: 1, time: 0),
        videos: []
      )
    )
  }
}

// MARK: - Mock Extensions
extension MediaItem {
  static func mock(id: Int = 1) -> MediaItem {
    MediaItem(
      id: id,
      title: "Mock Title",
      originalTitle: "Mock Original Title",
      year: 2024,
      type: "movie",
      poster: Posters(
        small: "https://mock.url/poster_small.jpg",
        medium: "https://mock.url/poster_medium.jpg",
        big: "https://mock.url/poster_big.jpg"
      ),
      plot: "Mock plot description",
      cast: "Mock Cast",
      director: "Mock Director",
      genre: [MediaGenre(id: 1, title: "Action")],
      country: [Country(id: 1, title: "USA")],
      duration: Duration(average: 120, total: 120),
      rating: MediaItem.Rating(imdb: 8.5, kinopoisk: 8.0, votes: MediaItem.Rating.Votes(imdb: 1000, kinopoisk: 500)),
      created: "2024-01-01T00:00:00Z",
      updated: "2024-01-01T00:00:00Z",
      seasons: nil,
      videos: [],
      trailer: nil,
      subtitles: [],
      bookmarks: nil,
      watching: nil
    )
  }
} 