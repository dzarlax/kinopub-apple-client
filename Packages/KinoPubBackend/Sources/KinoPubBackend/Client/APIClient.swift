//
//  APIClient.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class APIClient {
  private let session: URLSessionProtocol
  private let requestBuilder: RequestBuilder
  private let baseUrl: URL
  private var plugins: [APIClientPlugin]
  private let cacheManager: CacheManaging
  
  public init(
    baseUrl: String, 
    plugins: [APIClientPlugin] = [], 
    session: URLSessionProtocol = URLSessionImpl(session: .shared),
    cacheManager: CacheManaging = MemoryCacheManager()
  ) {
    self.baseUrl = URL(string: baseUrl)!
    self.plugins = plugins
    self.session = session
    self.requestBuilder = RequestBuilder(baseURL: self.baseUrl)
    self.cacheManager = cacheManager
  }

  public func performRequest<T: Codable>(
    with requestData: Endpoint, 
    decodingType: T.Type
  ) async throws -> T {
    
    // Check cache first for cacheable requests
    if let cacheableRequest = requestData as? CacheableRequest {
      switch cacheableRequest.cachePolicy {
      case .cacheFirst, .memoryOnly:
        if let cachedResult = cacheManager.get(for: cacheableRequest.cacheKey, type: T.self) {
          return cachedResult
        }
      case .noCache, .networkFirst:
        break
      }
    }
    
    // Build request
    guard let request = requestBuilder.build(with: requestData) else {
      throw APIClientError.invalidUrlParams
    }

    let preparedRequest = plugins.reduce(request) { $1.prepare(request) }
    
    // Notify plugins
    plugins.forEach { $0.willSend(preparedRequest) }

    // Perform network request
    let (data, response) = try await session.data(for: preparedRequest)

    // Notify plugins
    plugins.forEach { $0.didReceive(response, data: data) }

    // Decode response
    let result = try decode(T.self, from: data, throwDecodingErrorImmediately: false)
    
    // Cache result if applicable
    if let cacheableRequest = requestData as? CacheableRequest,
       case .memoryOnly = cacheableRequest.cachePolicy {
      cacheManager.set(result, for: cacheableRequest.cacheKey, ttl: cacheableRequest.cachePolicy.ttl)
    }
    
    return result
  }
  
  // MARK: - Cache Management
  public func clearCache() {
    cacheManager.clear()
  }
  
  public func removeCacheEntry(for key: String) {
    cacheManager.remove(for: key)
  }

  // MARK: - Private Methods
  private func decode<T: Codable>(
    _ type: T.Type,
    from data: Data,
    throwDecodingErrorImmediately: Bool
  ) throws -> T where T: Codable {
    do {
      let result = try JSONDecoder().decode(T.self, from: data)
      return result
    } catch {
      if throwDecodingErrorImmediately {
        throw APIClientError.decodingError(error)
      }
      
      // Try to decode as backend error
      let result = try decode(BackendError.self, from: data, throwDecodingErrorImmediately: true)
      throw APIClientError.networkError(result)
    }
  }
}
