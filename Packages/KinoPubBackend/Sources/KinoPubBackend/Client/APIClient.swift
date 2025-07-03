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
    
    print("🚀 [APIClient] Начинаем запрос: \(requestData.path)")
    print("🔧 [APIClient] Декодируем как: \(T.self)")
    
    // Check cache first for cacheable requests
    if let cacheableRequest = requestData as? CacheableRequest {
      switch cacheableRequest.cachePolicy {
      case .cacheFirst, .memoryOnly:
        if let cachedResult = cacheManager.get(for: cacheableRequest.cacheKey, type: T.self) {
          print("💾 [APIClient] Возвращаем данные из кеша для: \(requestData.path)")
          return cachedResult
        }
      case .noCache, .networkFirst:
        break
      }
    }
    
    // Build request
    guard let request = requestBuilder.build(with: requestData) else {
      print("❌ [APIClient] Не удалось построить запрос для: \(requestData.path)")
      throw APIClientError.invalidUrlParams
    }

    print("📡 [APIClient] URL: \(request.url?.absoluteString ?? "неизвестный")")
    print("🔍 [APIClient] Метод: \(request.httpMethod ?? "неизвестный")")

    let preparedRequest = plugins.reduce(request) { $1.prepare(request) }
    
    // Notify plugins
    plugins.forEach { $0.willSend(preparedRequest) }

    do {
      print("⏳ [APIClient] Выполняем сетевой запрос...")
      // Perform network request
      let (data, response) = try await session.data(for: preparedRequest)
      print("✅ [APIClient] Получили ответ, размер данных: \(data.count) байт")
      
      // Notify plugins
      plugins.forEach { $0.didReceive(response, data: data) }
      
      // Check if request was cancelled after completion
      try Task.checkCancellation()

      return try handleResponse(data: data, type: T.self, requestData: requestData)
      
    } catch {
      print("❌ [APIClient] Ошибка запроса \(requestData.path): \(error)")
      
      // Special handling for cancellation
      if let urlError = error as? URLError, urlError.code == .cancelled {
        print("⏹ [APIClient] Запрос отменен (URLError.cancelled): \(requestData.path)")
      } else if error is CancellationError {
        print("⏹ [APIClient] Запрос отменен (CancellationError): \(requestData.path)")
      }
      
      throw error
    }

  }
  
  // MARK: - Response Handling
  private func handleResponse<T: Codable>(
    data: Data, 
    type: T.Type, 
    requestData: Endpoint
  ) throws -> T {
    print("🔄 [APIClient] Начинаем декодирование ответа...")
    
    // Decode response
    let result = try decode(T.self, from: data, throwDecodingErrorImmediately: false)
    print("✅ [APIClient] Успешно декодирован ответ для: \(requestData.path)")
    
    // Cache result if applicable
    if let cacheableRequest = requestData as? CacheableRequest,
       case .memoryOnly = cacheableRequest.cachePolicy {
      cacheManager.set(result, for: cacheableRequest.cacheKey, ttl: cacheableRequest.cachePolicy.ttl)
      print("💾 [APIClient] Результат сохранен в кеш для: \(requestData.path)")
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
    print("🔄 [API Decode] Попытка декодирования как \(T.self), размер данных: \(data.count) байт")
    
    do {
      let result = try JSONDecoder().decode(T.self, from: data)
      print("✅ [API Decode] Успешно декодировано как \(T.self)")
      return result
    } catch {
      print("❌ [API Decode] Не удалось декодировать как \(T.self)")
      print("🔍 [API Decode] Ошибка декодирования: \(error)")
      
      if throwDecodingErrorImmediately {
        print("⚡ [API Decode] Сразу выбрасываем ошибку декодирования")
        throw APIClientError.decodingError(error)
      }
      
      // Log the response data for debugging
      print("🔍 [API Decode] Анализируем ответ сервера...")
      if let jsonString = String(data: data, encoding: .utf8) {
        print("📄 [API Response] JSON: \(jsonString)")
      } else {
        print("📄 [API Response] Raw data size: \(data.count) bytes")
      }
      
      print("🔄 [API Decode] Пытаемся декодировать как BackendError...")
      // Try to decode as backend error
      let result = try decode(BackendError.self, from: data, throwDecodingErrorImmediately: true)
      print("✅ [API Decode] Успешно декодировано как BackendError")
      throw APIClientError.networkError(result)
    }
  }
}
